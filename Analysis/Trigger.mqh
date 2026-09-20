//+------------------------------------------------------------------+
//| Analysis/Trigger.mqh                                             |
//| Avaliacao do gatilho: entrada, stop, alvo, score, filtros e      |
//| registro da operacao simulada.                                   |
//|                                                                  |
//| >>> Este e o modulo para mexer quando quiser mudar criterios     |
//| >>> de entrada, pesos do score ou regras de alvo/risco.          |
//|                                                                  |
//| Depende de: praticamente tudo que veio antes - Analysis/Levels,  |
//|             Analysis/Zone, Execution/RealOrders,                 |
//|             Execution/VirtualTrades, UI/Draw, Core/Stats.        |
//|                                                                  |
//| PONTO IMPORTANTE DO DESENHO                                      |
//| A funcao NUNCA aborta. Mesmo quando o gatilho e rejeitado, ela   |
//| monta a operacao virtual e a registra. E isso que permite medir  |
//| o custo de cada filtro depois, no CSV.                           |
//|                                                                  |
//| kind = 0 -> gatilho de PULLBACK (ICS classico)                   |
//| kind = 1 -> entrada no ROMPIMENTO                                |
//+------------------------------------------------------------------+
#ifndef __ICSM_TRIGGER_MQH__
#define __ICSM_TRIGGER_MQH__

void EvaluateTrigger(const IcsBar &b, int kind)
{
   bool   isPb   = (kind == 0);
   int    dir    = g_s.dir;
   double height = g_zone.hi - g_zone.lo;
   double nv     = NormalVol(MinOfDay(b.t));
   double atr5   = ATRArr(g_m5, 14);
   double leg    = MathAbs(g_s.impExt - g_s.origin);

   //--- qualidade do pullback (so faz sentido em kind = 0)
   double pbVolRatio = isPb ? 99 : 0;
   if(isPb && g_s.pbBars > 0 && g_s.impBars > 0 && g_s.impVol > 0)
      pbVolRatio = (g_s.pbVol / g_s.pbBars) / (g_s.impVol / g_s.impBars);
   double pbContra = 0;
   if(isPb) pbContra = (g_s.impDelta > 0) ? MathMax(0.0, -g_s.pbDelta) / g_s.impDelta : 99;
   double retrUsed = isPb ? g_s.retr : 0;

   //--- qualidade da barra de gatilho
   double trigVolRatio = b.vol / nv;
   double trigDeltaPct = (b.vol > 0) ? 100.0 * b.delta * dir / b.vol : 0;

   //--- evidencias institucionais acumuladas na zona
   bool   hasAbs  = ZoneHasAbsorption();
   bool   hasTest = (dir > 0) ? g_zone.testLow : g_zone.testHigh;
   bool   hasV    = (dir > 0) ? g_zone.sweptLow : g_zone.sweptHigh;

   //--- entrada e stop -----------------------------------------------
   double entry   = b.c + dir * InpSlipPts;
   double stopRef = g_s.pbExt;
   if(!isPb)
   {
      if(InpBrkStopMode == ICS_BSTOP_POC)       stopRef = g_zone.poc;
      else if(InpBrkStopMode == ICS_BSTOP_ZONE) stopRef = (dir > 0) ? g_zone.lo : g_zone.hi;
      else                                      stopRef = (dir > 0) ? b.l : b.h;
   }
   double stop    = (dir > 0) ? RoundDn(stopRef - InpStopBufPts) : RoundUp(stopRef + InpStopBufPts);
   double risk    = (entry - stop) * dir;
   if(InpMinStopATR > 0 && atr5 > 0 && risk < InpMinStopATR * atr5)
   {
      double sp = entry - dir * InpMinStopATR * atr5;
      stop = (dir > 0) ? RoundDn(sp) : RoundUp(sp);
      risk = (entry - stop) * dir;
   }
   double costPts = (g_pointValue > 0) ? InpCostPerContract / g_pointValue : 0;
   double riskEff = MathMax(risk + InpSlipPts + costPts, 1.0);

   //--- alvo ----------------------------------------------------------
   double lv[];
   string nm[];
   GatherLevels(lv, nm, dir);
   if(InpExitMode == ICS_EXIT_TRAIL) ArrayResize(lv, 0);   // trailing: sem alvo no obstaculo
   double target = 0, bestDist = DBL_MAX;
   string tsrc   = "";
   for(int i = 0; i < ArraySize(lv); i++)
   {
      double dist = (lv[i] - entry) * dir;
      if(dist <= 2 * g_tick) continue;
      double tp = lv[i] - dir * InpTargetOffsetPts;
      if(InpTargetMode == ICS_TGT_FIRST_RR)
      {
         double rrx = ((tp - entry) * dir - costPts) / riskEff;
         if(rrx < InpMinRR) continue;
      }
      if(dist < bestDist) { bestDist = dist; target = tp; tsrc = nm[i]; }
   }
   if(target == 0)
   {
      if(isPb)
      {
         target = g_s.pbExt + dir * InpProjMult * leg;
         tsrc   = "projecao do impulso";
      }
      else
      {
         target = b.c + dir * InpProjMult * height;
         tsrc   = "projecao da zona";
      }
   }
   target = (dir > 0) ? RoundDn(target) : RoundUp(target);
   double reward = (target - entry) * dir;
   double rr     = (reward - costPts) / riskEff;
   if(InpExitMode == ICS_EXIT_TRAIL)
   {
      // R:R avaliado na projecao; a ordem usa um alvo de seguranca mais distante
      double far = entry + dir * reward * MathMax(InpTrailTpMult, 1.0);
      target = (dir > 0) ? RoundDn(far) : RoundUp(far);
      tsrc   = tsrc + " (trailing)";
   }

   //--- score (0-100) -------------------------------------------------
   double sc = 0;
   sc += (g_ctx == dir) ? 15 : ((g_ctx == 0) ? 7 : 0);
   sc += hasAbs  ? 10 : 0;
   sc += hasTest ? 10 : 0;
   sc += hasV    ? 10 : 0;
   sc += 10 * Clamp01((g_s.brkVolRatio - 1.0) / MathMax(2 * InpBrkVolMult - 1.0, 0.1));
   sc += 10 * Clamp01(g_s.brkDeltaPct / MathMax(2 * InpBrkDeltaPct, 1.0));
   if(isPb)
   {
      sc += (g_s.retr <= InpPbGoodRetr) ? 10 : 5;
      sc += 10 * Clamp01((1.0 - pbVolRatio) / 0.7);
   }
   else sc += 10;
   sc += (trigDeltaPct > 0 && trigVolRatio >= 1.0) ? 5 : 0;
   sc += 10 * Clamp01((rr - 1.0) / 2.0);

   //--- filtros -------------------------------------------------------
   string why = "";
   int    mod = MinOfDay(b.t) + 1;
   if(g_replay)                                        AddReason(why, "reprocessamento");
   if(HasOpenTrade())                                  AddReason(why, "posicao aberta");
   if(mod < g_sessStart + InpNoEntryFirstMin || mod >= g_lastEntry) AddReason(why, "horario");
   if(g_tradesToday >= InpMaxTradesDay)                AddReason(why, "limite de operacoes do dia");
   if(g_lossesToday >= InpMaxLossesDay)                AddReason(why, "limite de perdas do dia");
   if(InpCtxFilter == ICS_CTX_BLOCK   && g_ctx == -dir) AddReason(why, "contra o contexto");
   if(InpCtxFilter == ICS_CTX_REQUIRE && g_ctx != dir)  AddReason(why, "sem contexto a favor");
   if(InpBrkMaxVolMult > 0 && g_s.brkVolRatio > InpBrkMaxVolMult) AddReason(why, "rompimento climatico");
   if(!InpBaseline)
   {
      if(isPb && pbVolRatio > InpPbMaxVolRatio) AddReason(why, "pullback com volume alto");
      if(isPb && pbContra > InpPbMaxDeltaRatio) AddReason(why, "delta contrario forte no pullback");
      if(trigVolRatio < InpTrigVolMult)     AddReason(why, "gatilho sem volume");
      if(trigDeltaPct <= InpTrigMinDeltaPct) AddReason(why, "gatilho sem delta");
      if(InpReqAbsorption && !hasAbs)       AddReason(why, "sem absorcao");
      if(InpReqTest && !hasTest)            AddReason(why, "sem teste");
   }
   if(atr5 > 0 && risk > InpMaxStopATR * atr5) AddReason(why, "stop largo");
   if(risk < 2 * g_tick)                       AddReason(why, "stop curto");
   if(rr < InpMinRR)                           AddReason(why, "RR insuficiente (" + tsrc + ")");
   if(sc < InpMinScore)                        AddReason(why, "score baixo");

   //--- execucao ------------------------------------------------------
   bool   taken  = (why == "");
   string status = taken ? "EXECUTADO" : "REJEITADO";
   if(taken && OrdersAllowed() && !g_replay)
   {
      if(!SendOrder(dir, stop, target))
      {
         taken  = false;
         status = "ERRO_ORDEM";
         why    = "falha no envio da ordem";
      }
   }
   else if(!taken && InpExecuteAll && g_isTester && !g_replay && mod < g_flat && !HasRealPosition())
   {
      // modo de estudo: executa tambem os rejeitados para medir o custo dos filtros
      if(SendOrder(dir, stop, target)) status = "ESTUDO_EXECUTADO";
   }
   if(taken)
   {
      g_tradesToday++;
      if(!g_isTester && !g_replay && InpAlerts)
      {
         string msg = StringFormat("ICS %s %s | entrada ~%.0f stop %.0f alvo %.0f | R:R %.1f | score %.0f",
                                   dir > 0 ? "COMPRA" : "VENDA", _Symbol, entry, stop, target, rr, sc);
         Alert(msg);
         if(InpPush) SendNotification(msg);
      }
   }
   else CountReasons(why);
   g_signals++;

   //--- registro da operacao simulada ---------------------------------
   string ctxs = (g_ctx > 0) ? "alta" : ((g_ctx < 0) ? "baixa" : "neutro");
   string info = IntegerToString(g_signals) + ";" + TimeToString(b.t, TIME_DATE) + ";" +
                 TimeToString(b.t + 60, TIME_MINUTES) + ";" + (dir > 0 ? "COMPRA" : "VENDA") + ";" +
                 (isPb ? "PULLBACK" : "ROMPIMENTO") + ";" +
                 status + ";" + why + ";" + F(sc, 0) + ";" + ctxs + ";" +
                 IntegerToString(g_zone.id) + ";" + F(g_zone.lo, 0) + ";" + F(g_zone.hi, 0) + ";" +
                 IntegerToString(g_zone.m5bars) + ";" + F(g_zone.relvol, 2) + ";" +
                 B(hasAbs) + ";" + B(hasTest) + ";" + B(hasV) + ";" +
                 F(g_s.brkVolRatio, 2) + ";" + F(g_s.brkDeltaPct, 0) + ";" +
                 F(retrUsed * 100, 0) + ";" + F(pbVolRatio, 2) + ";" + F(pbContra, 2) + ";" +
                 F(trigVolRatio, 2) + ";" + F(trigDeltaPct, 0) + ";" +
                 F(entry, 0) + ";" + F(stop, 0) + ";" + F(target, 0) + ";" + tsrc + ";" +
                 F(risk, 0) + ";" + F(reward, 0) + ";" + F(rr, 2);

   int k = ArraySize(g_vt);
   ArrayResize(g_vt, k + 1);
   g_vt[k].active   = true;
   g_vt[k].taken    = taken;
   g_vt[k].kind     = kind;
   g_vt[k].dir      = dir;
   g_vt[k].startSeq = b.seq;
   g_vt[k].bars     = 0;
   g_vt[k].entry    = entry;
   g_vt[k].stop     = stop;
   g_vt[k].target   = target;
   g_vt[k].risk     = risk;
   g_vt[k].mae      = 0;
   g_vt[k].mfe      = 0;
   g_vt[k].be       = false;
   g_vt[k].trail    = InpTrailATR * atr5;
   g_vt[k].info     = info;

   //--- desenho -------------------------------------------------------
   string tip = StringFormat("%s %s %s | score %.0f | RR %.2f | %s", isPb ? "PULLBACK" : "ROMPIMENTO", dir > 0 ? "COMPRA" : "VENDA", status, sc, rr,
                             why == "" ? "todos os filtros ok" : why);
   color clr = taken ? (dir > 0 ? clrLime : clrRed) : clrGray;
   DrawMark(b.t, dir > 0 ? b.l : b.h, dir > 0 ? 241 : 242, clr, tip, dir > 0);
   if(taken)
   {
      datetime t1 = b.t + InpTimeStopBars * 60;
      DrawLevel(b.t, t1, entry,  clrWhite, STYLE_DOT,   "entrada");
      DrawLevel(b.t, t1, stop,   clrRed,   STYLE_SOLID, "stop");
      DrawLevel(b.t, t1, target, clrLime,  STYLE_SOLID, "alvo: " + tsrc);
   }
   LogEvent(isPb ? "GATILHO" : "ENTRADA_ROMPIMENTO", b.t, b.c, dir, status + " score=" + F(sc, 0) + " " + why);

   if(isPb) RetireZone("gatilho avaliado");
}

#endif // __ICSM_TRIGGER_MQH__
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Analysis/StateMachine.mqh                                        |
//| Maquina de estados do setup, barra M1 a barra M1.                |
//|                                                                  |
//| Depende de: Core/Utils.mqh, Data/VolumeNormals.mqh,              |
//|             Analysis/Zone.mqh (RetireZone),                      |
//|             Execution/Logger.mqh, e do prototipo de              |
//|             EvaluateTrigger (Core/Prototypes.mqh).               |
//|                                                                  |
//| FLUXO DOS ESTADOS                                                |
//|                                                                  |
//|   ST_IDLE  --(ZoneDetector achou congestao)--> ST_ZONE           |
//|                                                                  |
//|   ST_ZONE      ZoneBar()                                         |
//|     - marca TESTE_FUNDO / TESTE_TOPO (toque com volume baixo)    |
//|     - marca ARMADILHA (saiu fraco e voltou dentro do prazo)      |
//|     - fechou fora COM volume e delta -> StartBreakout            |
//|     - fechou fora SEM fluxo por InpZoneStaleBars -> encerra      |
//|                                                                  |
//|   ST_BREAKOUT  BreakoutBar()                                     |
//|     - voltou para dentro: armadilha ou rompimento falho -> ZONE  |
//|     - avancou InpContMult x altura da zona -> ST_IMPULSE         |
//|     - passou InpContBars sem avancar -> encerra                  |
//|                                                                  |
//|   ST_IMPULSE   ImpulseBar()                                      |
//|     - novo extremo: reinicia a contagem do pullback              |
//|     - retracao entre InpPbMinRetr e InpPbMaxRetr qualifica       |
//|     - rompeu o micro-extremo do pullback -> GATILHO              |
//|                                                                  |
//| Qualquer estado pode cair para ST_IDLE via RetireZone().         |
//+------------------------------------------------------------------+
#ifndef __ICSM_STATEMACHINE_MQH__
#define __ICSM_STATEMACHINE_MQH__

//+------------------------------------------------------------------+
//| Recalcula volume/delta/barras do impulso (rompimento -> extremo) |
//+------------------------------------------------------------------+
void RecalcImpulse()
{
   g_s.impVol = 0; g_s.impDelta = 0; g_s.impBars = 0;
   int a = IdxOf(g_s.brkSeq), z = IdxOf(g_s.impExtSeq);
   if(a < 0 || z < 0) return;
   for(int i = a; i <= z; i++)
   {
      g_s.impVol   += g_m1[i].vol;
      g_s.impDelta += g_m1[i].delta * g_s.dir;
      g_s.impBars++;
   }
}

//+------------------------------------------------------------------+
//| Recalcula volume/delta/barras e extremo do pullback.             |
//| lastSeq permite excluir a barra de gatilho das estatisticas.     |
//+------------------------------------------------------------------+
void RecalcPullback(long lastSeq = -1)
{
   g_s.pbVol = 0; g_s.pbDelta = 0; g_s.pbBars = 0;
   g_s.pbExt = g_s.impExt;
   g_s.pbExtSeq = g_s.impExtSeq;
   int a = IdxOf(g_s.impExtSeq);
   if(a < 0) return;
   int n = ArraySize(g_m1);
   if(lastSeq >= 0)
   {
      int z = IdxOf(lastSeq);
      if(z >= 0) n = z + 1;
   }
   for(int i = a + 1; i < n; i++)
   {
      g_s.pbBars++;
      g_s.pbVol   += g_m1[i].vol;
      g_s.pbDelta += g_m1[i].delta * g_s.dir;
      if(g_s.dir > 0 ? (g_m1[i].l < g_s.pbExt) : (g_m1[i].h > g_s.pbExt))
      {
         g_s.pbExt    = (g_s.dir > 0) ? g_m1[i].l : g_m1[i].h;
         g_s.pbExtSeq = g_m1[i].seq;
      }
   }
}

//+------------------------------------------------------------------+
//| Extremo do intervalo [fromSeq, toSeq] na direcao dada.           |
//| E o nivel cujo rompimento dispara a entrada.                     |
//+------------------------------------------------------------------+
double MicroExtreme(long fromSeq, long toSeq, int dir)
{
   int a = IdxOf(fromSeq), z = IdxOf(toSeq);
   if(a < 0 || z < 0 || z < a) return (dir > 0) ? DBL_MAX : -DBL_MAX;
   double e = (dir > 0) ? -DBL_MAX : DBL_MAX;
   for(int i = a; i <= z; i++)
      e = (dir > 0) ? MathMax(e, g_m1[i].h) : MathMin(e, g_m1[i].l);
   return e;
}

//+------------------------------------------------------------------+
//| Inicia o setup no rompimento: guarda referencias e, se a entrada |
//| no rompimento estiver ligada, ja avalia o gatilho                |
//+------------------------------------------------------------------+
void StartBreakout(const IcsBar &b, int dir, double volRatio, double dpct)
{
   ZeroMemory(g_s);
   g_s.dir         = dir;
   g_s.brkSeq      = b.seq;
   g_s.brkTime     = b.t;
   g_s.brkVolRatio = volRatio;
   g_s.brkDeltaPct = dpct;
   g_s.impExt      = (dir > 0) ? b.h : b.l;
   g_s.impExtSeq   = b.seq;

   //--- origem do impulso: extremo oposto nas ultimas barras antes do rompimento
   int bi = IdxOf(b.seq);
   double org = (dir > 0) ? b.l : b.h;
   for(int i = bi - 1; i >= 0 && i >= bi - InpOriginLookback; i--)
   {
      if(DayStart(g_m1[i].t) != g_day) break;
      org = (dir > 0) ? MathMin(org, g_m1[i].l) : MathMax(org, g_m1[i].h);
   }
   g_s.origin = org;

   //--- extremo do dia antes do rompimento (vira candidato a alvo)
   double ext = (dir > 0) ? -1.0 : DBL_MAX;
   for(int i = bi - 1; i >= 0; i--)
   {
      if(DayStart(g_m1[i].t) != g_day) break;
      ext = (dir > 0) ? MathMax(ext, g_m1[i].h) : MathMin(ext, g_m1[i].l);
   }
   if(ext < 0 || ext == DBL_MAX) ext = 0;
   g_s.dayExtBefore = ext;

   g_state = ST_BREAKOUT;
   LogEvent("ROMPIMENTO", b.t, dir > 0 ? b.l : b.h, dir,
            StringFormat("Z%d vol=%sx delta=%s%%", g_zone.id, F(volRatio, 2), F(dpct, 0)));
   if(InpEntryMode != ICS_ENTRY_PULLBACK) EvaluateTrigger(b, 1);
}

//+------------------------------------------------------------------+
//| ST_ZONE: testes de borda, armadilhas e deteccao do rompimento    |
//+------------------------------------------------------------------+
void ZoneBar(const IcsBar &b)
{
   double nv = NormalVol(MinOfDay(b.t));

   //--- teste de demanda / oferta: toca a borda com volume baixo e volta
   if(b.l <= g_zone.lo + InpTouchTolPts && b.c >= g_zone.lo && b.vol <= InpTestVolMult * nv)
   {
      if(!g_zone.testLow) LogEvent("TESTE_FUNDO", b.t, b.l, 1, StringFormat("Z%d vol=%sx", g_zone.id, F(b.vol / nv, 2)));
      g_zone.testLow = true;
   }
   if(b.h >= g_zone.hi - InpTouchTolPts && b.c <= g_zone.hi && b.vol <= InpTestVolMult * nv)
   {
      if(!g_zone.testHigh) LogEvent("TESTE_TOPO", b.t, b.h, -1, StringFormat("Z%d vol=%sx", g_zone.id, F(b.vol / nv, 2)));
      g_zone.testHigh = true;
   }

   bool inside = (b.c <= g_zone.hi && b.c >= g_zone.lo);
   if(inside)
   {
      //--- padrao V: saiu sem fluxo e devolveu dentro do prazo de armadilha
      if(g_zone.outUp > 0 && b.seq - g_zone.outUpSeq <= InpTrapBars)
      {
         g_zone.sweptHigh = true;
         LogEvent("ARMADILHA", b.t, b.h, 1, StringFormat("Z%d: saida fraca acima devolvida", g_zone.id));
      }
      if(g_zone.outDn > 0 && b.seq - g_zone.outDnSeq <= InpTrapBars)
      {
         g_zone.sweptLow = true;
         LogEvent("ARMADILHA", b.t, b.l, -1, StringFormat("Z%d: saida fraca abaixo devolvida", g_zone.id));
      }
      g_zone.outUp = 0;
      g_zone.outDn = 0;
      return;
   }

   //--- fechou fora: qualifica como rompimento?
   int    dir      = (b.c > g_zone.hi) ? 1 : -1;
   double volRatio = b.vol / nv;
   double dpct     = (b.vol > 0) ? 100.0 * b.delta * dir / b.vol : 0;
   bool   volOk    = InpBaseline || volRatio >= InpBrkVolMult;
   bool   deltaOk  = InpBaseline || dpct >= InpBrkDeltaPct;
   if(volOk && deltaOk)
   {
      StartBreakout(b, dir, volRatio, dpct);
      return;
   }

   //--- fora sem fluxo: conta e eventualmente encerra a zona
   if(dir > 0)
   {
      if(g_zone.outUp == 0) g_zone.outUpSeq = b.seq;
      g_zone.outUp++;
      g_zone.outDn = 0;
      if(g_zone.outUp > InpZoneStaleBars) RetireZone("saida para cima sem fluxo");
   }
   else
   {
      if(g_zone.outDn == 0) g_zone.outDnSeq = b.seq;
      g_zone.outDn++;
      g_zone.outUp = 0;
      if(g_zone.outDn > InpZoneStaleBars) RetireZone("saida para baixo sem fluxo");
   }
}

//+------------------------------------------------------------------+
//| ST_BREAKOUT: aceitacao fora da zona e continuidade               |
//+------------------------------------------------------------------+
void BreakoutBar(const IcsBar &b)
{
   int  dir = g_s.dir;
   long k   = b.seq - g_s.brkSeq;
   if(dir > 0 && b.h > g_s.impExt) { g_s.impExt = b.h; g_s.impExtSeq = b.seq; }
   if(dir < 0 && b.l < g_s.impExt) { g_s.impExt = b.l; g_s.impExtSeq = b.seq; }

   bool inside = (dir > 0) ? (b.c <= g_zone.hi) : (b.c >= g_zone.lo);
   if(inside)
   {
      if(k <= InpAcceptBars)
      {
         g_s.insideCount++;
         if(g_s.insideCount <= InpAcceptBars - InpAcceptMin) return;   // retorno tolerado
      }
      if(k <= InpTrapBars)
      {
         if(dir > 0) g_zone.sweptHigh = true;
         else        g_zone.sweptLow  = true;
         LogEvent("ARMADILHA", b.t, dir > 0 ? b.h : b.l, dir,
                  StringFormat("Z%d: rompimento devolvido em %d barras", g_zone.id, (int)k));
      }
      else
         LogEvent("ROMPIMENTO_FALHOU", b.t, b.c, dir, StringFormat("Z%d", g_zone.id));
      g_state      = ST_ZONE;
      g_zone.outUp = 0;
      g_zone.outDn = 0;
      return;
   }

   if(k < InpAcceptBars) return;

   double height = g_zone.hi - g_zone.lo;
   double move   = (dir > 0) ? g_s.impExt - g_zone.hi : g_zone.lo - g_s.impExt;
   if(move >= InpContMult * height)
   {
      g_state = ST_IMPULSE;
      RecalcImpulse();
      RecalcPullback();
      g_s.pbQualified = false;
      g_s.pbCount     = 0;
      LogEvent("DESLOCAMENTO", b.t, g_s.impExt, dir,
               StringFormat("Z%d avanco=%.0f pts (altura %.0f)", g_zone.id, move, height));
      return;
   }
   if(k >= InpContBars) RetireZone("rompimento sem continuidade");
}

//+------------------------------------------------------------------+
//| Encaminha o gatilho de pullback (ou descarta se a entrada de     |
//| pullback estiver desligada)                                      |
//+------------------------------------------------------------------+
void PullbackTrigger(const IcsBar &b)
{
   if(InpEntryMode == ICS_ENTRY_BREAKOUT) RetireZone("gatilho de pullback (entrada desativada)");
   else                                   EvaluateTrigger(b, 0);
}

//+------------------------------------------------------------------+
//| ST_IMPULSE: acompanha o pullback e dispara o gatilho             |
//+------------------------------------------------------------------+
void ImpulseBar(const IcsBar &b)
{
   int  dir    = g_s.dir;
   bool newExt = (dir > 0) ? (b.h > g_s.impExt) : (b.l < g_s.impExt);
   if(newExt)
   {
      //--- novo extremo na mesma barra que retomou o micro-extremo: e gatilho
      if(g_s.pbQualified && b.seq > g_s.pbExtSeq)
      {
         double microN = MicroExtreme(g_s.pbExtSeq, b.seq - 1, dir);
         bool   trigN  = (dir > 0) ? (b.c > microN) : (b.c < microN);
         if(trigN)
         {
            RecalcPullback(b.seq - 1);      // estatisticas do pullback sem a barra de gatilho
            PullbackTrigger(b);
            return;
         }
      }
      //--- pullback valido que nao gerou gatilho: conta e eventualmente desiste
      if(g_s.pbQualified)
      {
         g_s.pbCount++;
         LogEvent("PULLBACK_SEM_GATILHO", b.t, b.c, dir, StringFormat("Z%d", g_zone.id));
         if(g_s.pbCount >= InpMaxPullbacks)
         {
            RetireZone("alem do primeiro pullback (spike channel)");
            return;
         }
      }
      g_s.impExt      = (dir > 0) ? b.h : b.l;
      g_s.impExtSeq   = b.seq;
      g_s.pbQualified = false;
      RecalcImpulse();
      return;
   }

   RecalcPullback();
   double leg = MathAbs(g_s.impExt - g_s.origin);
   if(leg <= 0) { RetireZone("impulso invalido"); return; }
   g_s.retr = MathAbs(g_s.impExt - g_s.pbExt) / leg;

   bool backInside = (dir > 0) ? (b.c <= g_zone.hi) : (b.c >= g_zone.lo);
   if(backInside)                  { RetireZone("pullback aceito dentro da zona"); return; }
   if(g_s.retr > InpPbMaxRetr)     { RetireZone("retracao acima do maximo"); return; }
   if(g_s.pbBars > InpPbMaxBars)   { RetireZone("pullback longo demais"); return; }
   if(g_s.retr >= InpPbMinRetr)    g_s.pbQualified = true;
   if(!g_s.pbQualified || b.seq <= g_s.pbExtSeq) return;

   double micro = MicroExtreme(g_s.pbExtSeq, b.seq - 1, dir);
   bool   trig  = (dir > 0) ? (b.c > micro) : (b.c < micro);
   if(trig)
   {
      RecalcPullback(b.seq - 1);            // estatisticas do pullback sem a barra de gatilho
      PullbackTrigger(b);
   }
}

//+------------------------------------------------------------------+
//| Despacha a barra para o handler do estado corrente               |
//+------------------------------------------------------------------+
void RunStateMachine(const IcsBar &b)
{
   if(g_state == ST_ZONE)          ZoneBar(b);
   else if(g_state == ST_BREAKOUT) BreakoutBar(b);
   else if(g_state == ST_IMPULSE)  ImpulseBar(b);
}

#endif // __ICSM_STATEMACHINE_MQH__
//+------------------------------------------------------------------+

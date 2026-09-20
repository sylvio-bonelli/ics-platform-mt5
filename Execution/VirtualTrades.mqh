//+------------------------------------------------------------------+
//| Execution/VirtualTrades.mqh                                      |
//| Operacoes simuladas.                                             |
//|                                                                  |
//| Depende de: Core/Utils.mqh, Execution/Logger.mqh (WriteLine).    |
//|                                                                  |
//| CONCEITO CENTRAL DO ESTUDO: todo gatilho avaliado vira uma       |
//| operacao virtual, tenha sido EXECUTADO ou REJEITADO. As          |
//| rejeitadas continuam sendo acompanhadas ate o desfecho, e isso e |
//| o que permite responder "o filtro X esta me protegendo ou me     |
//| custando dinheiro?" ao comparar as duas populacoes no CSV.       |
//|                                                                  |
//| Premissa conservadora: quando a barra toca stop e alvo no mesmo  |
//| minuto, assume-se o STOP.                                        |
//+------------------------------------------------------------------+
#ifndef __ICSM_VIRTUALTRADES_MQH__
#define __ICSM_VIRTUALTRADES_MQH__

//+------------------------------------------------------------------+
//| Encerra uma operacao virtual, grava a linha final no CSV e       |
//| acumula as estatisticas por tipo de setup                        |
//+------------------------------------------------------------------+
void CloseVirtual(int k, datetime t, double exitPrice, string reason)
{
   if(!g_vt[k].active) return;
   int    dir = g_vt[k].dir;
   double pts = (exitPrice - g_vt[k].entry) * dir;
   double r   = (g_vt[k].risk > 0) ? pts / g_vt[k].risk : 0;
   double brl = pts * g_pointValue * InpLots - InpCostPerContract * InpLots;

   WriteLine(g_fSig, g_vt[k].info + ";" + TS(t) + ";" + F(exitPrice, 0) + ";" + reason + ";" +
                     F(pts, 0) + ";" + F(r, 2) + ";" + F(g_vt[k].mae, 0) + ";" + F(g_vt[k].mfe, 0) + ";" + F(brl, 2));

   int kd = g_vt[k].kind;
   if(kd < 0 || kd > 2) kd = 0;
   g_kAll[kd]++;
   g_kR[kd]   += r;
   g_kBRL[kd] += brl;
   if(pts > 0) g_kWin[kd]++;
   if(g_vt[k].taken) { g_kTkN[kd]++; g_kTkR[kd] += r; }

   if(g_vt[k].taken)
   {
      g_tkN++;
      g_tkSumR   += r;
      g_tkSumPts += pts;
      g_tkSumBRL += brl;
      if(brl > 0) { g_tkWins++; g_tkGrossWin += brl; }
      else          g_tkGrossLoss += -brl;
      if(pts < 0) g_lossesToday++;
   }
   else
   {
      g_rjN++;
      g_rjSumR += r;
      if(pts > 0) g_rjWins++;
   }
   g_vt[k].active = false;
}

//+------------------------------------------------------------------+
//| Encerra todas as operacoes virtuais abertas no preco corrente    |
//+------------------------------------------------------------------+
void CloseAllVirtual(string reason)
{
   int n = ArraySize(g_m1);
   if(n == 0) return;
   double   c = g_m1[n - 1].c;
   datetime t = g_m1[n - 1].t;
   for(int k = 0; k < ArraySize(g_vt); k++)
      if(g_vt[k].active)
         CloseVirtual(k, t, c - g_vt[k].dir * InpSlipPts, reason);
}

//+------------------------------------------------------------------+
//| Novo stop pelo trailing. Retorna o stop atual se nao mudar.      |
//| Usado tanto pelas operacoes virtuais quanto pela posicao real -  |
//| e por isso que a funcao nao toca em nenhum estado global.        |
//+------------------------------------------------------------------+
double TrailStop(int dir, double entry, double risk, double best, double curStop, double trail, bool &be)
{
   if(InpExitMode != ICS_EXIT_TRAIL || risk <= 0) return curStop;
   double fav = (best - entry) * dir;
   double ns  = curStop;
   if(fav >= InpBEAtR * risk)
   {
      double bePx = entry + dir * g_tick;
      if((bePx - ns) * dir > 0) ns = bePx;
      be = true;
   }
   if(fav >= InpTrailStartR * risk && trail > 0)
   {
      double tp = best - dir * trail;
      tp = (dir > 0) ? RoundDn(tp) : RoundUp(tp);
      if((tp - ns) * dir > 0) ns = tp;
   }
   return ns;
}

//+------------------------------------------------------------------+
//| Desespero (pavio de rejeicao >= X o corpo) + corpo cheio         |
//| contrario na barra seguinte. Overlay de saida: nao espera o      |
//| trailing e vale nos dois modos (FIXED e TRAIL).                  |
//+------------------------------------------------------------------+
bool ReversalExitSignal(int dir, long minSeq)
{
   if(!InpReversalExit) return false;
   int n = ArraySize(g_m1);
   if(n < 2) return false;
   if(g_m1[n - 2].seq < minSeq) return false;
   if(DayStart(g_m1[n - 2].t) != g_day || DayStart(g_m1[n - 1].t) != g_day) return false;

   double body = BarBody(g_m1[n - 2]);
   if(body < g_tick) return false;
   double wick = (dir > 0) ? BarWickUp(g_m1[n - 2]) : BarWickDn(g_m1[n - 2]);
   if(wick < InpDespWickMult * body) return false;

   double range = g_m1[n - 1].h - g_m1[n - 1].l;
   if(range < g_tick) return false;
   if(BarBody(g_m1[n - 1]) / range < InpFullBodyFrac) return false;
   return (dir > 0) ? (g_m1[n - 1].c < g_m1[n - 1].o) : (g_m1[n - 1].c > g_m1[n - 1].o);
}

//+------------------------------------------------------------------+
//| Avanca todas as operacoes virtuais uma barra M1                  |
//+------------------------------------------------------------------+
void UpdateVirtualTrades(const IcsBar &b)
{
   for(int k = 0; k < ArraySize(g_vt); k++)
   {
      if(!g_vt[k].active || b.seq <= g_vt[k].startSeq) continue;
      int dir = g_vt[k].dir;
      g_vt[k].bars++;
      double adverse = (dir > 0) ? g_vt[k].entry - b.l : b.h - g_vt[k].entry;
      double favor   = (dir > 0) ? b.h - g_vt[k].entry : g_vt[k].entry - b.l;
      if(adverse > g_vt[k].mae) g_vt[k].mae = adverse;
      if(favor   > g_vt[k].mfe) g_vt[k].mfe = favor;

      bool hitStop = (dir > 0) ? (b.l <= g_vt[k].stop)   : (b.h >= g_vt[k].stop);
      bool hitTgt  = (dir > 0) ? (b.h >= g_vt[k].target) : (b.l <= g_vt[k].target);

      if(hitStop)                                   // conservador: stop antes do alvo
      {
         double moved = (g_vt[k].stop - g_vt[k].entry) * dir;
         string why   = (moved > g_tick) ? "TRAILING" : ((moved >= 0) ? "ZERO_A_ZERO" : "STOP");
         CloseVirtual(k, b.t, g_vt[k].stop - dir * InpSlipPts, why);
      }
      else if(hitTgt)
         CloseVirtual(k, b.t, g_vt[k].target, "ALVO");
      else if(ReversalExitSignal(dir, g_vt[k].startSeq))
         CloseVirtual(k, b.t, b.c - dir * InpSlipPts, "REVERSAO");
      else if(!g_vt[k].be && g_vt[k].bars >= InpTimeStopBars &&
              (b.c - g_vt[k].entry) * dir < InpTimeStopMinR * g_vt[k].risk)
         CloseVirtual(k, b.t, b.c - dir * InpSlipPts, "TEMPO");
      else if(MinOfDay(b.t) + 1 >= g_flat)
         CloseVirtual(k, b.t, b.c - dir * InpSlipPts, "FIM_DIA");
      else
      {
         double best = g_vt[k].entry + dir * g_vt[k].mfe;
         bool   be   = g_vt[k].be;
         g_vt[k].stop = TrailStop(dir, g_vt[k].entry, g_vt[k].risk, best, g_vt[k].stop, g_vt[k].trail, be);
         g_vt[k].be   = be;
      }
   }
}

#endif // __ICSM_VIRTUALTRADES_MQH__
//+------------------------------------------------------------------+

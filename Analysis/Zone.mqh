//+------------------------------------------------------------------+
//| Analysis/Zone.mqh                                                |
//| Ciclo de vida da zona institucional: POC proprio, encerramento e |
//| consulta de absorcao associada.                                  |
//|                                                                  |
//| Depende de: Core/Utils.mqh, Execution/Logger.mqh (LogEvent),     |
//|             UI/Draw.mqh (DrawZone), Core/Stats.mqh (CountIn).    |
//|                                                                  |
//| A DETECCAO da zona esta em Analysis/ZoneDetector.mqh.            |
//| Aqui ficam as operacoes sobre a zona JA existente.               |
//|                                                                  |
//| Ao ser encerrada, a zona nao desaparece: suas bordas e seu POC   |
//| vao para g_doneHi / g_doneLo / g_donePoc e passam a ser          |
//| candidatos a alvo em Analysis/Levels.mqh.                        |
//+------------------------------------------------------------------+
#ifndef __ICSM_ZONE_MQH__
#define __ICSM_ZONE_MQH__

//+------------------------------------------------------------------+
//| Encerra a zona corrente, arquiva seus niveis e volta a ST_IDLE.  |
//| g_zoneMinStart impede que a proxima zona detectada comece antes  |
//| do fim desta (evita redetectar a mesma congestao).               |
//+------------------------------------------------------------------+
void RetireZone(string reason)
{
   if(g_state == ST_IDLE) return;
   int k = ArraySize(g_doneHi);
   ArrayResize(g_doneHi, k + 1);
   ArrayResize(g_doneLo, k + 1);
   ArrayResize(g_donePoc, k + 1);
   g_doneHi[k]  = g_zone.hi;
   g_doneLo[k]  = g_zone.lo;
   g_donePoc[k] = g_zone.poc;
   int n = ArraySize(g_m1);
   datetime last = (n > 0) ? g_m1[n - 1].t + 60 : g_zone.t1;
   if(last > g_zone.t1) g_zone.t1 = last;
   g_zoneMinStart = last;
   if(!g_replay) CountIn(g_retName, g_retCnt, reason);
   LogEvent("ZONA_ENCERRADA", last, g_zone.poc, 0, StringFormat("Z%d: %s", g_zone.id, reason));
   DrawZone(true);
   g_s.rejOn = false;
   g_state   = ST_IDLE;
}

//+------------------------------------------------------------------+
//| POC da zona: histograma proprio, construido com o VWAP de cada   |
//| barra M1 dentro da janela da zona (nao usa o perfil do dia)      |
//+------------------------------------------------------------------+
double ZonePoc(datetime t0, datetime t1, double lo, double hi)
{
   int nb = (int)MathCeil((hi - lo) / InpProfileStep) + 1;
   if(nb < 1)   nb = 1;
   if(nb > 400) nb = 400;
   double acc[];
   ArrayResize(acc, nb);
   ArrayInitialize(acc, 0.0);
   for(int i = ArraySize(g_m1) - 1; i >= 0; i--)
   {
      if(g_m1[i].t < t0) break;
      if(g_m1[i].t >= t1) continue;
      int k = (int)MathFloor((g_m1[i].vwap - lo) / InpProfileStep);
      if(k < 0)   k = 0;
      if(k >= nb) k = nb - 1;
      acc[k] += g_m1[i].vol;
   }
   int bi = ArrayMaximum(acc);
   if(bi < 0) bi = 0;
   return lo + bi * InpProfileStep + InpProfileStep / 2.0;
}

//+------------------------------------------------------------------+
//| Houve absorcao dentro da zona (ou logo antes dela) antes do      |
//| rompimento? Usado no score e no filtro InpReqAbsorption.         |
//+------------------------------------------------------------------+
bool ZoneHasAbsorption()
{
   datetime from = g_zone.t0 - InpAbsLookback * 60;
   for(int i = 0; i < ArraySize(g_abs); i++)
      if(g_abs[i].t >= from && g_abs[i].t <= g_s.brkTime &&
         g_abs[i].price >= g_zone.lo - InpTouchTolPts && g_abs[i].price <= g_zone.hi + InpTouchTolPts)
         return true;
   return false;
}

#endif // __ICSM_ZONE_MQH__
//+------------------------------------------------------------------+

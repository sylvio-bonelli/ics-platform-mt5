//+------------------------------------------------------------------+
//| Analysis/ZoneDetector.mqh                                        |
//| MARCACAO DA AREA: deteccao da zona institucional no M5.          |
//|                                                                  |
//| >>> Este e o modulo para mexer quando a regra de marcacao        |
//| >>> de area precisar evoluir. Ele nao e chamado por mais         |
//| >>> ninguem alem de ProcessBar, via OnM5Close().                 |
//|                                                                  |
//| Depende de: Core/Utils.mqh (ATRArr), Data/VolumeNormals.mqh,     |
//|             Analysis/Zone.mqh (ZonePoc), UI/Draw.mqh,            |
//|             Execution/Logger.mqh.                                |
//|                                                                  |
//| ALGORITMO                                                        |
//| A cada M5 fechado, testa janelas do MAIOR para o MENOR tamanho   |
//| (InpZoneMaxBars -> InpZoneMinBars) e fica com a primeira que     |
//| passar nos tres criterios. Testar do maior para o menor faz a    |
//| zona abranger o maximo de congestao possivel.                    |
//|                                                                  |
//| Criterios:                                                       |
//|   1. Amplitude  <= InpZoneMaxRangeATR x ATR(M5)   -> e estreita  |
//|   2. Eficiencia <= InpZoneMaxER                   -> nao anda    |
//|      ER = |fechamento - abertura| / caminho percorrido           |
//|   3. Volume relativo >= InpZoneMinRelVol          -> tem gente   |
//|      (criterio 3 e ignorado no modo BASELINE)                    |
//|                                                                  |
//| Enquanto a zona existe, a janela pode ser reajustada a cada M5   |
//| (evento ZONA_AJUSTADA). Se a janela mudar de bordas, os          |
//| contadores de "fora da zona" sao zerados.                        |
//+------------------------------------------------------------------+
#ifndef __ICSM_ZONEDETECTOR_MQH__
#define __ICSM_ZONEDETECTOR_MQH__

void OnM5Close()
{
   if(g_state != ST_IDLE && g_state != ST_ZONE) return;
   int n = ArraySize(g_m5);
   if(n < InpZoneMinBars + 1) return;
   double atr5 = ATRArr(g_m5, 14);
   if(atr5 <= 0) return;

   //--- procura a maior janela que ainda qualifica como congestao
   int    best = -1;
   double bhi = 0, blo = 0, bvol = 0, ber = 0, brv = 0;
   for(int W = InpZoneMaxBars; W >= InpZoneMinBars; W--)
   {
      int s = n - W;
      if(s < 1) continue;
      if(DayStart(g_m5[s].t) != g_day) continue;      // nao atravessa dias
      if(g_m5[s].t < g_zoneMinStart) continue;        // nao redetecta zona ja encerrada
      double hi = g_m5[s].h, lo = g_m5[s].l, vol = 0, nv = 0;
      double path = MathAbs(g_m5[s].c - g_m5[s].o);
      for(int i = s; i < n; i++)
      {
         hi   = MathMax(hi, g_m5[i].h);
         lo   = MathMin(lo, g_m5[i].l);
         vol += g_m5[i].vol;
         nv  += NormalVol5(g_m5[i].t);
         if(i > s) path += MathAbs(g_m5[i].c - g_m5[i - 1].c);
      }
      if(hi - lo > InpZoneMaxRangeATR * atr5) continue;
      double er = (path > 0) ? MathAbs(g_m5[n - 1].c - g_m5[s].o) / path : 0;
      if(er > InpZoneMaxER) continue;
      double rv = (nv > 0) ? vol / nv : 0;
      if(!InpBaseline && rv < InpZoneMinRelVol) continue;
      best = s; bhi = hi; blo = lo; bvol = vol; ber = er; brv = rv;
      break;
   }

   datetime tEnd = g_m5[n - 1].t + 300;
   if(best < 0)
   {
      // nenhuma janela qualifica: mantem a zona existente, so estende o desenho
      if(g_state == ST_ZONE) { g_zone.t1 = tEnd; DrawZone(false); }
      return;
   }

   bool isNew   = (g_state == ST_IDLE);
   bool changed = isNew || bhi != g_zone.hi || blo != g_zone.lo;
   if(isNew)
   {
      g_zoneCounter++;
      ZeroMemory(g_zone);
      g_zone.id = g_zoneCounter;
      g_state   = ST_ZONE;
   }
   g_zone.t0     = g_m5[best].t;
   g_zone.t1     = tEnd;
   g_zone.hi     = bhi;
   g_zone.lo     = blo;
   g_zone.vol    = bvol;
   g_zone.er     = ber;
   g_zone.relvol = brv;
   g_zone.m5bars = n - best;
   g_zone.poc    = ZonePoc(g_zone.t0, tEnd, blo, bhi);
   if(changed)
   {
      g_zone.outUp = 0;
      g_zone.outDn = 0;
      LogEvent(isNew ? "ZONA_CRIADA" : "ZONA_AJUSTADA", tEnd, g_zone.poc, 0,
               StringFormat("Z%d %.0f-%.0f barrasM5=%d ER=%s volRel=%s", g_zone.id, blo, bhi,
                            g_zone.m5bars, F(ber, 2), F(brv, 2)));
   }
   DrawZone(false);
}

#endif // __ICSM_ZONEDETECTOR_MQH__
//+------------------------------------------------------------------+

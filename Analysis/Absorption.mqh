//+------------------------------------------------------------------+
//| Analysis/Absorption.mqh                                          |
//| Deteccao de absorcao no M1.                                      |
//|                                                                  |
//| Depende de: Core/Utils.mqh (ATRArr), Data/VolumeNormals.mqh,     |
//|             Execution/Logger.mqh (LogEvent).                     |
//|                                                                  |
//| DEFINICAO OPERACIONAL: volume muito acima do normal produzindo   |
//| deslocamento muito pequeno. Alguem esta absorvendo a agressao    |
//| sem deixar o preco andar.                                        |
//|                                                                  |
//| Avalia janelas de 1, 2 e 3 barras M1 (g = 1..3) e para na        |
//| primeira que qualificar. Exige 3 barras de intervalo desde a     |
//| ultima absorcao registrada para nao duplicar o mesmo evento.     |
//|                                                                  |
//| O resultado alimenta g_abs[], consultado por ZoneHasAbsorption() |
//| em Analysis/Zone.mqh.                                            |
//+------------------------------------------------------------------+
#ifndef __ICSM_ABSORPTION_MQH__
#define __ICSM_ABSORPTION_MQH__

void DetectAbsorption()
{
   int n = ArraySize(g_m1);
   if(n < 2) return;
   int na = ArraySize(g_abs);
   if(na > 0 && g_m1[n - 1].seq - g_abs[na - 1].seq < 3) return;
   double atr1 = ATRArr(g_m1, 14);
   if(atr1 <= 0) return;
   for(int g = 1; g <= 3; g++)
   {
      int s = n - g;
      if(s < 0) break;
      if(DayStart(g_m1[s].t) != g_day) break;
      double vol = 0, nv = 0, dl = 0;
      double hi = g_m1[s].h, lo = g_m1[s].l;
      for(int i = s; i < n; i++)
      {
         vol += g_m1[i].vol;
         nv  += NormalVol(MinOfDay(g_m1[i].t));
         dl  += g_m1[i].delta;
         hi   = MathMax(hi, g_m1[i].h);
         lo   = MathMin(lo, g_m1[i].l);
      }
      double disp = MathAbs(g_m1[n - 1].c - g_m1[s].o);
      if(vol >= InpAbsVolMult * nv && disp <= InpAbsMaxDispATR * atr1)
      {
         ArrayResize(g_abs, na + 1);
         g_abs[na].t     = g_m1[n - 1].t;
         g_abs[na].seq   = g_m1[n - 1].seq;
         g_abs[na].price = (hi + lo) / 2.0;
         g_abs[na].side  = (dl > 0) ? 1 : ((dl < 0) ? -1 : 0);
         LogEvent("ABSORCAO", g_m1[n - 1].t, lo, 0,
                  StringFormat("barras=%d vol=%.0f normal=%.0f delta=%.0f", g, vol, nv, dl));
         return;
      }
   }
}

#endif // __ICSM_ABSORPTION_MQH__
//+------------------------------------------------------------------+

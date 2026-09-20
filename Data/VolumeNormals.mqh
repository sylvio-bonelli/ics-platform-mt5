//+------------------------------------------------------------------+
//| Data/VolumeNormals.mqh                                           |
//| Volume "normal" por horario do dia.                              |
//|                                                                  |
//| Depende de: Config/Inputs.mqh, Core/Globals.mqh, Core/Utils.mqh. |
//|                                                                  |
//| IDEIA: o volume do WIN nao e comparavel entre horarios - a       |
//| abertura e o fechamento sao naturalmente muito mais volumosos.   |
//| Entao, em vez de comparar com uma media movel simples, guardamos |
//| o perfil minuto-a-minuto dos ultimos N dias e comparamos cada    |
//| barra com o que e normal NAQUELE minuto (janela de +-2 minutos   |
//| para suavizar).                                                  |
//|                                                                  |
//| Fallback: enquanto nao houver InpVolMinDays dias de historico,   |
//| usa a media das ultimas 20 barras M1.                            |
//+------------------------------------------------------------------+
#ifndef __ICSM_VOLUMENORMALS_MQH__
#define __ICSM_VOLUMENORMALS_MQH__

//+------------------------------------------------------------------+
//| Recalcula g_norm[] a partir de g_volHist[] (chamado na virada    |
//| do dia, em StartDay)                                             |
//+------------------------------------------------------------------+
void ComputeNormals()
{
   g_normReady = (g_volDays >= InpVolMinDays);
   ArrayInitialize(g_norm, 0.0);
   if(!g_normReady) return;
   for(int m = 0; m < 1440; m++)
   {
      double s = 0;
      int    c = 0;
      for(int d = 0; d < g_volDays; d++)
         for(int k = m - 2; k <= m + 2; k++)
         {
            if(k < 0 || k >= 1440) continue;
            s += g_volHist[d * 1440 + k];
            c++;
         }
      g_norm[m] = (c > 0) ? s / c : 0.0;
   }
}

//+------------------------------------------------------------------+
//| Volume normal de UMA barra M1 no minuto informado                |
//+------------------------------------------------------------------+
double NormalVol(int mod)
{
   if(mod < 0) mod = 0;
   if(mod > 1439) mod = 1439;
   if(g_normReady && g_norm[mod] > 0) return MathMax(g_norm[mod], 1.0);
   int sz = ArraySize(g_m1);
   if(sz == 0) return 1.0;
   double s = 0;
   int    c = 0;
   for(int i = sz - 1; i >= 0 && c < 20; i--) { s += g_m1[i].vol; c++; }
   return MathMax(s / MathMax(c, 1), 1.0);
}

//+------------------------------------------------------------------+
//| Volume normal de UMA barra M5 (soma dos 5 minutos)               |
//+------------------------------------------------------------------+
double NormalVol5(datetime t)
{
   int m = MinOfDay(t);
   double s = 0;
   for(int k = 0; k < 5; k++) s += NormalVol(m + k);
   return s;
}

#endif // __ICSM_VOLUMENORMALS_MQH__
//+------------------------------------------------------------------+

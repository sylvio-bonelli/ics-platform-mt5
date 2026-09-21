//+------------------------------------------------------------------+
//| Data/BarBuilder.mqh                                              |
//| Montagem das barras M1 (com fluxo) e agregacao para M5.          |
//|                                                                  |
//| Depende de: Core/Globals.mqh, Core/Utils.mqh,                    |
//|             Data/VolumeProfile.mqh (ProfAdd), Data/Flow.mqh.     |
//|                                                                  |
//| FillFromRates  -> OHLCV basico a partir do MqlRates              |
//| LoadBarTicks   -> reprocessa os ticks da barra para obter        |
//|                   buy/sell/delta/VWAP reais e alimentar o perfil |
//| UpdateM5       -> agrega M1 em M5 e devolve quantos M5 fecharam  |
//+------------------------------------------------------------------+
#ifndef __ICSM_BARBUILDER_MQH__
#define __ICSM_BARBUILDER_MQH__

//+------------------------------------------------------------------+
//| Preenche a barra com o OHLCV do MqlRates (sem fluxo)             |
//+------------------------------------------------------------------+
void FillFromRates(IcsBar &b, const MqlRates &r)
{
   ZeroMemory(b);
   b.t    = r.time;
   b.o    = r.open;
   b.h    = r.high;
   b.l    = r.low;
   b.c    = r.close;
   b.vol  = (double)(r.real_volume > 0 ? r.real_volume : r.tick_volume);
   b.vwap = (r.high + r.low + r.close) / 3.0;
}

//+------------------------------------------------------------------+
//| Reprocessa os negocios do minuto para obter delta e VWAP reais.  |
//| Tambem alimenta o Volume Profile e os contadores de diagnostico. |
//| Retorna false se a barra nao tiver negocios utilizaveis.         |
//+------------------------------------------------------------------+
bool LoadBarTicks(IcsBar &b)
{
   ResetLastError();
   g_barTicks     = 0;
   g_barTicksFlag = 0;
   g_barBid       = 0;
   g_barAsk       = 0;
   int n = CopyTicksRange(_Symbol, g_ticks, COPY_TICKS_TRADE,
                          (ulong)((long)b.t * 1000), (ulong)(((long)b.t + 60) * 1000 - 1));
   g_dgBars++;
   if(n <= 0) return false;
   g_barTicks = n;
   double vol = 0, buy = 0, sell = 0, pv = 0;
   for(int i = 0; i < n; i++)
   {
      double p = g_ticks[i].last;
      double v = (double)g_ticks[i].volume;
      if(v <= 0) v = g_ticks[i].volume_real;
      bool fb = (g_ticks[i].flags & TICK_FLAG_BUY)  != 0;
      bool fs = (g_ticks[i].flags & TICK_FLAG_SELL) != 0;
      g_dgTicks++;
      if(v <= 0) g_dgZeroVol++;
      if(fb != fs)
      {
         g_dgFlag++;
         g_barTicksFlag++;
      }
      else if(!fb && !fs) g_dgNoFlag++;
      if(g_ticks[i].bid > 0) g_barBid = g_ticks[i].bid;
      if(g_ticks[i].ask > 0) g_barAsk = g_ticks[i].ask;
      if(p <= 0 || v <= 0) continue;
      int side = TickSide(g_ticks[i]);
      vol += v;
      pv  += p * v;
      if(side > 0) buy += v;
      else if(side < 0) sell += v;
      ProfAdd(p, v);
   }
   if(vol <= 0) return false;
   g_dgBarsTicks++;
   b.vol   = vol;
   b.buy   = buy;
   b.sell  = sell;
   b.delta = buy - sell;
   b.vwap  = pv / vol;
   return true;
}

//+------------------------------------------------------------------+
//| Fecha a barra M5 em formacao e a empurra para g_m5[]             |
//+------------------------------------------------------------------+
void PushM5()
{
   int n = ArraySize(g_m5);
   if(n >= 3000)
   {
      ArrayRemove(g_m5, 0, 1000);
      n = ArraySize(g_m5);
   }
   ArrayResize(g_m5, n + 1, 500);
   g_m5[n] = g_m5cur;
   g_m5Open = false;
}

//+------------------------------------------------------------------+
//| Agrega uma barra M1 na M5 corrente.                              |
//| Retorna quantas barras M5 fecharam nesta chamada (0, 1 ou 2).    |
//+------------------------------------------------------------------+
int UpdateM5(const IcsBar &b)
{
   datetime bt = (datetime)(((long)b.t / 300) * 300);
   int closed = 0;
   if(g_m5Open && g_m5cur.t != bt) { PushM5(); closed++; }
   if(!g_m5Open)
   {
      g_m5cur   = b;
      g_m5cur.t = bt;
      g_m5Open  = true;
   }
   else
   {
      g_m5cur.h      = MathMax(g_m5cur.h, b.h);
      g_m5cur.l      = MathMin(g_m5cur.l, b.l);
      g_m5cur.c      = b.c;
      g_m5cur.vol   += b.vol;
      g_m5cur.buy   += b.buy;
      g_m5cur.sell  += b.sell;
      g_m5cur.delta += b.delta;
   }
   if((((long)b.t) + 60) % 300 == 0) { PushM5(); closed++; }
   return closed;
}

#endif // __ICSM_BARBUILDER_MQH__
//+------------------------------------------------------------------+

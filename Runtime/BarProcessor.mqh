//+------------------------------------------------------------------+
//| Runtime/BarProcessor.mqh                                         |
//| Pipeline de processamento de barras e carga de historico.        |
//|                                                                  |
//| Depende de: praticamente todos os modulos anteriores.            |
//|                                                                  |
//| ESTE E O CORACAO DA ORQUESTRACAO. ProcessBar define a ORDEM em   |
//| que tudo acontece a cada barra M1 - mudar essa ordem muda o      |
//| comportamento do EA, entao mexa com cuidado:                     |
//|                                                                  |
//|   1. atualiza maxima/minima/VWAP do dia e o volume por minuto    |
//|   2. numera a barra (seq) e a guarda em g_m1                     |
//|   3. agrega no M5                                                |
//|   4. (so ao vivo) contexto -> operacoes virtuais -> posicao real |
//|      -> absorcao -> maquina de estados -> zona (se M5 fechou)    |
//|                                                                  |
//| live = false durante a carga de historico: as barras entram nos  |
//| acumuladores mas nao geram sinais.                               |
//|                                                                  |
//| DIAGNOSTICO DE DADOS                                             |
//| DataLooksBad / PrintDataDiag existem porque o delta depende de   |
//| ticks reais com lado agressor. Se o testador descartar os ticks  |
//| ("real ticks discarded" no Diario), todo o fluxo fica invalido   |
//| e os resultados nao significam nada - o aviso alerta para isso.  |
//+------------------------------------------------------------------+
#ifndef __ICSM_BARPROCESSOR_MQH__
#define __ICSM_BARPROCESSOR_MQH__

//+------------------------------------------------------------------+
//| Contexto do dia pela VWAP: preco acima da VWAP e VWAP subindo    |
//| = contexto de alta (e o espelho para baixa)                      |
//+------------------------------------------------------------------+
void UpdateContext(const IcsBar &b)
{
   int n = ArraySize(g_m1);
   int k = n - 1 - InpCtxSlopeBars;
   double past = (k >= 0 && DayStart(g_m1[k].t) == g_day) ? g_m1[k].dvwap : 0;
   g_ctx = 0;
   if(past > 0)
   {
      if(b.c > b.dvwap && b.dvwap > past)      g_ctx = 1;
      else if(b.c < b.dvwap && b.dvwap < past) g_ctx = -1;
   }
}

//+------------------------------------------------------------------+
//| Processa uma barra M1 completa                                   |
//+------------------------------------------------------------------+
void ProcessBar(IcsBar &b, bool live)
{
   //--- acumuladores do dia
   if(g_dayHigh < 0 || b.h > g_dayHigh) g_dayHigh = b.h;
   if(g_dayLow  < 0 || b.l < g_dayLow)  g_dayLow  = b.l;
   g_vwapPV += b.vwap * b.vol;
   g_vwapV  += b.vol;
   b.dvwap   = (g_vwapV > 0) ? g_vwapPV / g_vwapV : b.c;
   g_volToday[MinOfDay(b.t)] += b.vol;
   b.seq = g_nextSeq++;

   //--- guarda na janela deslizante de M1
   int n = ArraySize(g_m1);
   if(n >= 6000)
   {
      ArrayRemove(g_m1, 0, 2000);
      g_m1First += 2000;
      n = ArraySize(g_m1);
   }
   ArrayResize(g_m1, n + 1, 1000);
   g_m1[n] = b;

   int closedM5 = UpdateM5(b);
   if(!live) return;                 // carga de historico: nao gera sinais

   UpdateContext(b);
   UpdateVirtualTrades(b);
   if(!g_replay) ManageRealPosition(b);
   DetectAbsorption();
   RunStateMachine(b);
   if(closedM5 > 0) OnM5Close();
   if(g_draw) UpdatePanel();
   LogBar(b);
}

//+------------------------------------------------------------------+
//| Os dados de fluxo parecem inutilizaveis?                         |
//+------------------------------------------------------------------+
bool DataLooksBad()
{
   if(g_dgBars < 30) return false;
   double pBars = (double)g_dgBarsTicks / g_dgBars;
   double pFlag = (g_dgTicks > 0) ? (double)g_dgFlag / g_dgTicks : 0;
   return (pBars < 0.9 || (InpDeltaMode != ICS_DELTA_QUOTE && pFlag < 0.5));
}

//+------------------------------------------------------------------+
//| Relatorio de qualidade dos dados de fluxo                        |
//+------------------------------------------------------------------+
void PrintDataDiag()
{
   double pBars = (g_dgBars > 0)  ? 100.0 * g_dgBarsTicks / g_dgBars : 0;
   double pFlag = (g_dgTicks > 0) ? 100.0 * g_dgFlag / g_dgTicks : 0;
   double pZero = (g_dgTicks > 0) ? 100.0 * g_dgZeroVol / g_dgTicks : 0;
   PrintFormat("Dados: %I64d barras | %.1f%% com negocios | %I64d negocios | %.1f%% com lado agressor | %.1f%% sem volume",
               g_dgBars, pBars, g_dgTicks, pFlag, pZero);
   if(DataLooksBad())
      Print("AVISO DADOS: negocios sem volume ou sem lado agressor. O testador provavelmente descartou os ticks reais ",
            "(procure 'real ticks discarded' no Diario) e o delta ficou invalido. Rode o teste no simbolo WIN_ICS.");
}

//+------------------------------------------------------------------+
//| Processa as barras M1 fechadas desde a ultima chamada.           |
//| A barra do minuto corrente NUNCA e processada (so barra fechada).|
//+------------------------------------------------------------------+
void ProcessPending(datetime now)
{
   datetime curMin = (datetime)(((long)now / 60) * 60);
   datetime from   = g_lastBarTime + 60;
   datetime to     = curMin - 60;
   if(to < from) return;
   MqlRates r[];
   int n = CopyRates(_Symbol, PERIOD_M1, from, to, r);
   if(n <= 0) return;
   for(int i = 0; i < n; i++)
   {
      if(r[i].time <= g_lastBarTime || r[i].time >= curMin) continue;
      CheckDay(r[i].time);
      IcsBar b;
      FillFromRates(b, r[i]);
      if(!LoadBarTicks(b)) ProfAddRange(b.l, b.h, b.vol);   // sem ticks: sem delta
      ProcessBar(b, true);
      g_lastBarTime = r[i].time;
   }
   if(!g_dgWarned && !g_replay && DataLooksBad())
   {
      g_dgWarned = true;
      PrintDataDiag();
   }
}

//+------------------------------------------------------------------+
//| Carga inicial: dias anteriores, apenas para formar o volume      |
//| normal por horario e o perfil do dia anterior (live = false)     |
//+------------------------------------------------------------------+
void LoadHistory()
{
   datetime now   = TimeCurrent();
   datetime today = DayStart(now);
   datetime from  = today - (g_volCap * 2 + 7) * 86400;
   MqlRates r[];
   ResetLastError();
   int n = CopyRates(_Symbol, PERIOD_M1, from, today - 1, r);
   if(n <= 0)
   {
      PrintFormat("Aviso: sem historico M1 anterior (erro %d). O volume normal usara media movel no inicio.", GetLastError());
      g_lastBarTime = today - 60;
      return;
   }
   for(int i = 0; i < n; i++)
   {
      CheckDay(r[i].time);
      IcsBar b;
      FillFromRates(b, r[i]);
      ProfAddRange(b.l, b.h, b.vol);
      ProcessBar(b, false);
   }
   g_lastBarTime = r[n - 1].time;
   PrintFormat("ICS Modular: historico carregado (%d barras M1 anteriores a %s)", n, TimeToString(today, TIME_DATE));
}

#endif // __ICSM_BARPROCESSOR_MQH__
//+------------------------------------------------------------------+

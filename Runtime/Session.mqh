//+------------------------------------------------------------------+
//| Runtime/Session.mqh                                              |
//| Ciclo do pregao: abertura, encerramento e deteccao da virada.    |
//|                                                                  |
//| Depende de: Data/VolumeNormals.mqh, Data/VolumeProfile.mqh,      |
//|             Data/BarBuilder.mqh (PushM5),                        |
//|             Execution/VirtualTrades.mqh, Execution/RealOrders,   |
//|             Analysis/Zone.mqh (RetireZone).                      |
//|                                                                  |
//| EndDay e o momento em que o perfil do dia vira "perfil anterior" |
//| (POC/VAH/VAL/maxima/minima) e o volume do dia entra no buffer    |
//| circular que alimenta o volume normal por horario.               |
//+------------------------------------------------------------------+
#ifndef __ICSM_SESSION_MQH__
#define __ICSM_SESSION_MQH__

//+------------------------------------------------------------------+
//| Inicia um novo dia: zera acumuladores, perfil e estado do setup  |
//+------------------------------------------------------------------+
void StartDay(datetime d)
{
   g_day        = d;
   g_dayHigh    = -1;
   g_dayLow     = -1;
   g_vwapPV     = 0;
   g_vwapV      = 0;
   g_tradesToday= 0;
   g_lossesToday= 0;
   g_ctx        = 0;
   ArrayInitialize(g_volToday, 0.0);
   ProfReset();
   ComputeNormals();
   g_state        = ST_IDLE;
   g_s.rejOn      = false;
   g_zoneMinStart = 0;
   ArrayResize(g_doneHi, 0);
   ArrayResize(g_doneLo, 0);
   ArrayResize(g_donePoc, 0);
   ArrayResize(g_abs, 0);
   ArrayResize(g_vt, 0);
}

//+------------------------------------------------------------------+
//| Encerra o dia: arquiva o perfil, o volume por horario e fecha    |
//| tudo que estiver aberto (virtual e real)                         |
//+------------------------------------------------------------------+
void EndDay()
{
   if(g_m5Open) PushM5();

   //--- perfil do dia vira referencia do dia seguinte
   double poc, vah, val;
   if(ProfValueArea(poc, vah, val))
   {
      g_prevPoc  = poc;
      g_prevVah  = vah;
      g_prevVal  = val;
      g_prevHigh = g_dayHigh;
      g_prevLow  = g_dayLow;
      g_hasPrev  = true;
   }

   //--- volume por horario entra no buffer circular
   double tot = 0;
   for(int i = 0; i < 1440; i++) tot += g_volToday[i];
   if(tot > 0 && g_volCap > 0)
   {
      for(int i = 0; i < 1440; i++) g_volHist[g_volHead * 1440 + i] = g_volToday[i];
      g_volHead = (g_volHead + 1) % g_volCap;
      if(g_volDays < g_volCap) g_volDays++;
   }

   CloseAllVirtual("FIM_DIA");
   if(g_state != ST_IDLE) RetireZone("fim do dia");
   CloseRealPosition("fim do dia");
}

//+------------------------------------------------------------------+
//| Detecta a virada de dia a partir do timestamp da barra           |
//+------------------------------------------------------------------+
void CheckDay(datetime t)
{
   datetime d = DayStart(t);
   if(d == g_day) return;
   if(g_day != 0) EndDay();
   StartDay(d);
}

#endif // __ICSM_SESSION_MQH__
//+------------------------------------------------------------------+

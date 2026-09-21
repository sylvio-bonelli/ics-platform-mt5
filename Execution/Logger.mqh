//+------------------------------------------------------------------+
//| Execution/Logger.mqh                                             |
//| Arquivos CSV e registro de eventos do setup.                     |
//|                                                                  |
//| Depende de: Core/Utils.mqh (WriteLine, TS, F, B), Core/Stats.mqh |
//|             (CountIn, CountOf), UI/Draw.mqh (DrawMark),          |
//|             Data/VolumeNormals.mqh (NormalVol).                  |
//|                                                                  |
//| Arquivos na pasta COMUM do MetaTrader (Common\Files):            |
//|   ICS_Modular_{tipo}_{simbolo}_{modo}_{ambiente}_{YYYYMMDD}[_tag]|
//|                                                                  |
//| tipo = sinais | eventos | barras | ordens | run | funil          |
//| ambiente = live | tester  -- impede que o Testador apague o live |
//+------------------------------------------------------------------+
#ifndef __ICSM_LOGGER_MQH__
#define __ICSM_LOGGER_MQH__

//+------------------------------------------------------------------+
void AddKV(string &s, string k, string v)
{
   if(s != "") s += "|";
   s += k + "=" + v;
}

//+------------------------------------------------------------------+
string StateName(int st)
{
   if(st == ST_ZONE)     return "ZONE";
   if(st == ST_BREAKOUT) return "BREAKOUT";
   if(st == ST_IMPULSE)  return "IMPULSE";
   return "IDLE";
}

//+------------------------------------------------------------------+
string CsvStem()
{
   string modo = InpBaseline ? "baseline" : "completo";
   string d    = TimeToString(TimeCurrent(), TIME_DATE);
   StringReplace(d, ".", "");
   string stem = _Symbol + "_" + modo + "_" + g_env + "_" + d;
   if(InpRunTag != "") stem += "_" + InpRunTag;
   return stem;
}

//+------------------------------------------------------------------+
string InputsSnapshot()
{
   string s = "";
   AddKV(s, "InpTradeEnabled",    B(InpTradeEnabled));
   AddKV(s, "InpLiveOrders",      B(InpLiveOrders));
   AddKV(s, "InpExecuteAll",      B(InpExecuteAll));
   AddKV(s, "InpBaseline",        B(InpBaseline));
   AddKV(s, "InpLots",            F(InpLots, 2));
   AddKV(s, "InpMagic",           IntegerToString((int)InpMagic));
   AddKV(s, "InpRunTag",          InpRunTag);
   AddKV(s, "InpLogBars",         B(InpLogBars));
   AddKV(s, "InpDeltaMode",       IntegerToString((int)InpDeltaMode));
   AddKV(s, "InpVolDays",         IntegerToString(InpVolDays));
   AddKV(s, "InpVolMinDays",      IntegerToString(InpVolMinDays));
   AddKV(s, "InpCtxFilter",       IntegerToString((int)InpCtxFilter));
   AddKV(s, "InpCtxSlopeBars",    IntegerToString(InpCtxSlopeBars));
   AddKV(s, "InpEntryMode",       IntegerToString((int)InpEntryMode));
   AddKV(s, "InpBrkStopMode",     IntegerToString((int)InpBrkStopMode));
   AddKV(s, "InpBrkMaxVolMult",   F(InpBrkMaxVolMult, 2));
   AddKV(s, "InpSessionStart",    InpSessionStart);
   AddKV(s, "InpNoEntryFirstMin", IntegerToString(InpNoEntryFirstMin));
   AddKV(s, "InpLastEntry",       InpLastEntry);
   AddKV(s, "InpFlatTime",        InpFlatTime);
   AddKV(s, "InpZoneMinBars",     IntegerToString(InpZoneMinBars));
   AddKV(s, "InpZoneMaxBars",     IntegerToString(InpZoneMaxBars));
   AddKV(s, "InpZoneMaxRangeATR", F(InpZoneMaxRangeATR, 2));
   AddKV(s, "InpZoneMaxER",       F(InpZoneMaxER, 2));
   AddKV(s, "InpZoneMinRelVol",   F(InpZoneMinRelVol, 2));
   AddKV(s, "InpZoneStaleBars",   IntegerToString(InpZoneStaleBars));
   AddKV(s, "InpTouchTolPts",     F(InpTouchTolPts, 0));
   AddKV(s, "InpRejectEntry",     B(InpRejectEntry));
   AddKV(s, "InpRejectMinRetr",   F(InpRejectMinRetr, 2));
   AddKV(s, "InpRejectMaxBars",   IntegerToString(InpRejectMaxBars));
   AddKV(s, "InpAbsVolMult",      F(InpAbsVolMult, 2));
   AddKV(s, "InpAbsMaxDispATR",   F(InpAbsMaxDispATR, 2));
   AddKV(s, "InpAbsLookback",     IntegerToString(InpAbsLookback));
   AddKV(s, "InpReqAbsorption",   B(InpReqAbsorption));
   AddKV(s, "InpTestVolMult",     F(InpTestVolMult, 2));
   AddKV(s, "InpReqTest",         B(InpReqTest));
   AddKV(s, "InpBrkVolMult",      F(InpBrkVolMult, 2));
   AddKV(s, "InpBrkDeltaPct",     F(InpBrkDeltaPct, 0));
   AddKV(s, "InpAcceptBars",      IntegerToString(InpAcceptBars));
   AddKV(s, "InpAcceptMin",       IntegerToString(InpAcceptMin));
   AddKV(s, "InpTrapBars",        IntegerToString(InpTrapBars));
   AddKV(s, "InpContMult",        F(InpContMult, 2));
   AddKV(s, "InpContBars",        IntegerToString(InpContBars));
   AddKV(s, "InpHoldEntry",       B(InpHoldEntry));
   AddKV(s, "InpHoldBars",        IntegerToString(InpHoldBars));
   AddKV(s, "InpOriginLookback",  IntegerToString(InpOriginLookback));
   AddKV(s, "InpPbMinRetr",       F(InpPbMinRetr, 2));
   AddKV(s, "InpPbGoodRetr",      F(InpPbGoodRetr, 2));
   AddKV(s, "InpPbMaxRetr",       F(InpPbMaxRetr, 2));
   AddKV(s, "InpPbMaxBars",       IntegerToString(InpPbMaxBars));
   AddKV(s, "InpMaxPullbacks",    IntegerToString(InpMaxPullbacks));
   AddKV(s, "InpPbMaxVolRatio",   F(InpPbMaxVolRatio, 2));
   AddKV(s, "InpPbMaxDeltaRatio", F(InpPbMaxDeltaRatio, 2));
   AddKV(s, "InpTrigVolMult",     F(InpTrigVolMult, 2));
   AddKV(s, "InpTrigMinDeltaPct", F(InpTrigMinDeltaPct, 0));
   AddKV(s, "InpStopBufPts",      F(InpStopBufPts, 0));
   AddKV(s, "InpMaxStopATR",      F(InpMaxStopATR, 2));
   AddKV(s, "InpMinRR",           F(InpMinRR, 2));
   AddKV(s, "InpTargetMode",      IntegerToString((int)InpTargetMode));
   AddKV(s, "InpTargetOffsetPts", F(InpTargetOffsetPts, 0));
   AddKV(s, "InpProjMult",        F(InpProjMult, 2));
   AddKV(s, "InpMinScore",        F(InpMinScore, 0));
   AddKV(s, "InpSlipPts",         F(InpSlipPts, 0));
   AddKV(s, "InpCostPerContract", F(InpCostPerContract, 2));
   AddKV(s, "InpMinStopATR",      F(InpMinStopATR, 2));
   AddKV(s, "InpExitMode",        IntegerToString((int)InpExitMode));
   AddKV(s, "InpBEAtR",           F(InpBEAtR, 2));
   AddKV(s, "InpTrailStartR",     F(InpTrailStartR, 2));
   AddKV(s, "InpTrailATR",        F(InpTrailATR, 2));
   AddKV(s, "InpTrailTpMult",     F(InpTrailTpMult, 2));
   AddKV(s, "InpTimeStopBars",    IntegerToString(InpTimeStopBars));
   AddKV(s, "InpTimeStopMinR",    F(InpTimeStopMinR, 2));
   AddKV(s, "InpReversalExit",    B(InpReversalExit));
   AddKV(s, "InpDespWickMult",    F(InpDespWickMult, 2));
   AddKV(s, "InpFullBodyFrac",    F(InpFullBodyFrac, 2));
   AddKV(s, "InpMaxTradesDay",    IntegerToString(InpMaxTradesDay));
   AddKV(s, "InpMaxLossesDay",    IntegerToString(InpMaxLossesDay));
   return s;
}

//+------------------------------------------------------------------+
string SignalKey(datetime barT, string setup, int dir)
{
   return TimeToString(barT + 60, TIME_DATE | TIME_MINUTES) + "|" + setup + "|" +
          (dir > 0 ? "COMPRA" : "VENDA");
}

//+------------------------------------------------------------------+
string EventKey(string type, datetime t, int dir)
{
   if(type == "ZONA_CRIADA" || type == "ZONA_AJUSTADA" || type == "ZONA_ENCERRADA")
      return "Z|" + IntegerToString((long)g_zone.t0) + "|" +
             IntegerToString((int)MathRound(g_zone.lo)) + "|" +
             IntegerToString((int)MathRound(g_zone.hi));
   string d = (dir > 0) ? "C" : ((dir < 0) ? "V" : "");
   return TS(t) + "|" + type + "|" + d;
}

//+------------------------------------------------------------------+
void InitRunContext()
{
   g_env = g_isTester ? "tester" : "live";
   string stamp = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);
   StringReplace(stamp, ".", "");
   StringReplace(stamp, ":", "");
   StringReplace(stamp, " ", "_");
   g_runId = stamp + (g_isTester ? "_T_" : "_L_") +
             IntegerToString((int)AccountInfoInteger(ACCOUNT_LOGIN));
}

//+------------------------------------------------------------------+
void CloseFiles()
{
   if(g_fSig != INVALID_HANDLE) { FileClose(g_fSig); g_fSig = INVALID_HANDLE; }
   if(g_fEvt != INVALID_HANDLE) { FileClose(g_fEvt); g_fEvt = INVALID_HANDLE; }
   if(g_fRun != INVALID_HANDLE) { FileClose(g_fRun); g_fRun = INVALID_HANDLE; }
   if(g_fBar != INVALID_HANDLE) { FileClose(g_fBar); g_fBar = INVALID_HANDLE; }
   if(g_fOrd != INVALID_HANDLE) { FileClose(g_fOrd); g_fOrd = INVALID_HANDLE; }
   if(g_fFun != INVALID_HANDLE) { FileClose(g_fFun); g_fFun = INVALID_HANDLE; }
}

//+------------------------------------------------------------------+
void WriteRun(string fase)
{
   double pBars = (g_dgBars > 0)  ? 100.0 * g_dgBarsTicks / g_dgBars : 0;
   double pFlag = (g_dgTicks > 0) ? 100.0 * g_dgFlag / g_dgTicks : 0;
   double pZero = (g_dgTicks > 0) ? 100.0 * g_dgZeroVol / g_dgTicks : 0;
   double rExec = (g_tkN > 0) ? g_tkSumR / g_tkN : 0;
   double rRej  = (g_rjN > 0) ? g_rjSumR / g_rjN : 0;
   WriteLine(g_fRun,
             fase + ";" + g_runId + ";" + g_env + ";" +
             IntegerToString((int)AccountInfoInteger(ACCOUNT_LOGIN)) + ";" +
             AccountInfoString(ACCOUNT_SERVER) + ";" +
             _Symbol + ";" + ICSM_VERSION + ";" +
             B(g_isTester) + ";" + B(InpTradeEnabled) + ";" + B(InpLiveOrders) + ";" +
             IntegerToString((int)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE)) + ";" +
             F(g_pointValue, 4) + ";" +
             IntegerToString((int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)) + ";" +
             InputsSnapshot() + ";" +
             F(pBars, 1) + ";" + F(pFlag, 1) + ";" + F(pZero, 1) + ";" +
             IntegerToString(g_signals) + ";" + IntegerToString(g_tkN) + ";" +
             IntegerToString(g_rjN) + ";" + F(rExec, 2) + ";" + F(rRej, 2));
}

//+------------------------------------------------------------------+
void WriteFunnel(string fase)
{
   double pBars = (g_dgBars > 0)  ? 100.0 * g_dgBarsTicks / g_dgBars : 0;
   double pFlag = (g_dgTicks > 0) ? 100.0 * g_dgFlag / g_dgTicks : 0;
   double pZero = (g_dgTicks > 0) ? 100.0 * g_dgZeroVol / g_dgTicks : 0;
   double rExec = (g_tkN > 0) ? g_tkSumR / g_tkN : 0;
   double rRej  = (g_rjN > 0) ? g_rjSumR / g_rjN : 0;
   int testes = CountOf(g_evName, g_evCnt, "TESTE_FUNDO") + CountOf(g_evName, g_evCnt, "TESTE_TOPO");
   WriteLine(g_fFun,
             fase + ";" + g_runId + ";" + g_env + ";" +
             TimeToString(g_day, TIME_DATE) + ";" +
             IntegerToString(CountOf(g_evName, g_evCnt, "ZONA_CRIADA")) + ";" +
             IntegerToString(CountOf(g_evName, g_evCnt, "ZONA_AJUSTADA")) + ";" +
             IntegerToString(CountOf(g_evName, g_evCnt, "ABSORCAO")) + ";" +
             IntegerToString(testes) + ";" +
             IntegerToString(CountOf(g_evName, g_evCnt, "ROMPIMENTO")) + ";" +
             IntegerToString(CountOf(g_evName, g_evCnt, "ARMADILHA")) + ";" +
             IntegerToString(CountOf(g_evName, g_evCnt, "ROMPIMENTO_FALHOU")) + ";" +
             IntegerToString(CountOf(g_evName, g_evCnt, "ENTRADA_ROMPIMENTO")) + ";" +
             IntegerToString(CountOf(g_evName, g_evCnt, "ACEITACAO")) + ";" +
             IntegerToString(CountOf(g_evName, g_evCnt, "DESLOCAMENTO")) + ";" +
             IntegerToString(CountOf(g_evName, g_evCnt, "PULLBACK_SEM_GATILHO")) + ";" +
             IntegerToString(CountOf(g_evName, g_evCnt, "GATILHO")) + ";" +
             IntegerToString(CountOf(g_evName, g_evCnt, "VAZAMENTO")) + ";" +
             IntegerToString(CountOf(g_evName, g_evCnt, "RETESTE_FALHO")) + ";" +
             IntegerToString(CountOf(g_evName, g_evCnt, "RETESTE_SEM_GATILHO")) + ";" +
             IntegerToString(g_signals) + ";" + IntegerToString(g_tkN) + ";" +
             IntegerToString(g_rjN) + ";" + F(rExec, 2) + ";" + F(rRej, 2) + ";" +
             F(pBars, 1) + ";" + F(pFlag, 1) + ";" + F(pZero, 1));
}

//+------------------------------------------------------------------+
void OpenFiles()
{
   if(!g_files) return;
   string stem  = CsvStem();
   int    flags = FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON | FILE_SHARE_READ;
   g_fSig = FileOpen("ICS_Modular_sinais_"  + stem + ".csv", flags);
   g_fEvt = FileOpen("ICS_Modular_eventos_" + stem + ".csv", flags);
   g_fBar = FileOpen("ICS_Modular_barras_"  + stem + ".csv", flags);
   g_fOrd = FileOpen("ICS_Modular_ordens_"  + stem + ".csv", flags);
   g_fRun = FileOpen("ICS_Modular_run_"     + stem + ".csv", flags);
   g_fFun = FileOpen("ICS_Modular_funil_"   + stem + ".csv", flags);
   if(g_fSig == INVALID_HANDLE || g_fEvt == INVALID_HANDLE)
      PrintFormat("Aviso: nao foi possivel criar os CSV (erro %d)", GetLastError());

   string hdr = "run_id;ambiente;versao;chave;id;data;hora_entrada;direcao;setup;status;motivos;score;contexto;zona_id;zona_min;zona_max;";
   hdr += "zona_barras_m5;zona_vol_rel;absorcao;teste;padrao_v;romp_vol_x;romp_delta_pct;";
   hdr += "retracao_pct;pullback_vol_ratio;pullback_delta_contra;gatilho_vol_x;gatilho_delta_pct;";
   hdr += "entrada;stop;alvo;fonte_alvo;risco_pts;retorno_pts;rr_liquido;";
   hdr += "bid;ask;spread;slip_modelo;proc_lag_s;";
   hdr += "saida_hora;saida_preco;saida_motivo;resultado_pts;resultado_R;mae_pts;mfe_pts;resultado_brl";
   WriteLine(g_fSig, hdr);
   WriteLine(g_fEvt, "run_id;ambiente;zona_id;estado;chave;hora;evento;direcao;preco;detalhes");
   WriteLine(g_fBar, "run_id;ambiente;t;seq;o;h;l;c;vol;buy;sell;delta;vwap;dvwap;ticks;ticks_flag;normal_vol;bid;ask;spread;proc_lag_s;estado;zona_id;ctx");
   WriteLine(g_fOrd, "run_id;ambiente;sinal_id;acao;ticket;retcode;preco_req;preco_fill;sl;tp;bid;ask;desvio_pts;hora");
   WriteLine(g_fRun, "fase;run_id;ambiente;conta;servidor;simbolo;versao;is_tester;trade_enabled;live_orders;filling;point_value;spread;inputs;pct_barras_tick;pct_tick_flag;pct_vol_zero;sinais;executados;rejeitados;r_medio_exec;r_medio_rej");
   WriteLine(g_fFun, "fase;run_id;ambiente;data;zonas;ajustes;absorcoes;testes;rompimentos;armadilhas;romp_falhos;entradas_romp;aceitacoes;deslocamentos;pb_sem_gatilho;gatilhos;vazamentos;reteste_falho;reteste_sem;sinais;executados;rejeitados;r_medio_exec;r_medio_rej;pct_barras_tick;pct_tick_flag;pct_vol_zero");
}

//+------------------------------------------------------------------+
void LogBar(const IcsBar &b)
{
   if(!InpLogBars) return;
   double bid = (g_barBid > 0) ? g_barBid : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = (g_barAsk > 0) ? g_barAsk : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double spr = (bid > 0 && ask > 0) ? (ask - bid) : 0;
   double lag = (double)((long)TimeCurrent() - ((long)b.t + 60));
   WriteLine(g_fBar,
             g_runId + ";" + g_env + ";" + TS(b.t) + ";" +
             IntegerToString((int)b.seq) + ";" +
             F(b.o, 0) + ";" + F(b.h, 0) + ";" + F(b.l, 0) + ";" + F(b.c, 0) + ";" +
             F(b.vol, 0) + ";" + F(b.buy, 0) + ";" + F(b.sell, 0) + ";" +
             F(b.delta, 0) + ";" + F(b.vwap, 1) + ";" + F(b.dvwap, 1) + ";" +
             IntegerToString(g_barTicks) + ";" + IntegerToString(g_barTicksFlag) + ";" +
             F(NormalVol(MinOfDay(b.t)), 0) + ";" +
             F(bid, 0) + ";" + F(ask, 0) + ";" + F(spr, 0) + ";" + F(lag, 0) + ";" +
             StateName(g_state) + ";" + IntegerToString(g_zone.id) + ";" +
             IntegerToString(g_ctx));
}

//+------------------------------------------------------------------+
void LogOrder(string acao, int sinalId, ulong ticket, uint retcode,
              double precoReq, double precoFill, double sl, double tp)
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double dev = (precoFill > 0 && precoReq > 0) ? (precoFill - precoReq) : 0;
   WriteLine(g_fOrd,
             g_runId + ";" + g_env + ";" +
             IntegerToString(sinalId) + ";" + acao + ";" +
             IntegerToString((long)ticket) + ";" + IntegerToString((int)retcode) + ";" +
             F(precoReq, 0) + ";" + F(precoFill, 0) + ";" + F(sl, 0) + ";" + F(tp, 0) + ";" +
             F(bid, 0) + ";" + F(ask, 0) + ";" + F(dev, 0) + ";" +
             TS(TimeCurrent()));
}

//+------------------------------------------------------------------+
void LogEvent(string type, datetime t, double price, int dir, string info)
{
   string d = (dir > 0) ? "C" : ((dir < 0) ? "V" : "");
   if(!g_replay) CountIn(g_evName, g_evCnt, type);
   WriteLine(g_fEvt,
             g_runId + ";" + g_env + ";" +
             IntegerToString(g_zone.id) + ";" + StateName(g_state) + ";" +
             EventKey(type, t, dir) + ";" +
             TS(t) + ";" + type + ";" + d + ";" + F(price, 0) + ";" + info);
   if(!g_draw) return;
   if(type == "ROMPIMENTO")
      DrawMark(t, price, dir > 0 ? 233 : 234, dir > 0 ? clrDodgerBlue : clrOrange, type + ": " + info, dir > 0);
   else if(type == "ARMADILHA")
      DrawMark(t, price, 251, clrYellow, type + ": " + info, dir < 0);
   else if(type == "ABSORCAO")
      DrawMark(t, price, 108, clrMagenta, type + ": " + info, true);
   else if(type == "TESTE_FUNDO")
      DrawMark(t, price, 159, clrAqua, type + ": " + info, true);
   else if(type == "TESTE_TOPO")
      DrawMark(t, price, 159, clrAqua, type + ": " + info, false);
}

#endif // __ICSM_LOGGER_MQH__
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Core/Globals.mqh                                                 |
//| Estado compartilhado do EA.                                      |
//|                                                                  |
//| Depende de: Config/Defines.mqh (structs), Trade\Trade.mqh.       |
//|                                                                  |
//| Em MQL5 NAO existe linker: o compilador precisa ver a declaracao |
//| de uma variavel global ANTES do primeiro uso. Por isso este      |
//| arquivo e incluido logo depois de Inputs e antes de qualquer     |
//| modulo funcional.                                                |
//|                                                                  |
//| Convencao: prefixo g_ para tudo que e global.                    |
//+------------------------------------------------------------------+
#ifndef __ICSM_GLOBALS_MQH__
#define __ICSM_GLOBALS_MQH__

#include <Trade\Trade.mqh>

//--- negociacao -----------------------------------------------------
CTrade    g_trade;

//--- series de barras -----------------------------------------------
IcsBar    g_m1[];               // historico M1 (janela deslizante)
long      g_m1First   = 0;      // seq da primeira barra ainda em g_m1
long      g_nextSeq   = 0;      // proximo numero sequencial a atribuir
IcsBar    g_m5[];               // historico M5 agregado
IcsBar    g_m5cur;              // barra M5 em formacao
bool      g_m5Open    = false;
datetime  g_lastBarTime = 0;
datetime  g_curMinute   = 0;

//--- modo de execucao -----------------------------------------------
bool      g_replay    = false;  // true enquanto reprocessa historico (nao opera)
bool      g_isTester  = false;
bool      g_draw      = false;
bool      g_files     = false;
string    g_runId     = "";     // identidade da run (data_hora_L|T_conta)
string    g_env       = "";     // live | tester

//--- simbolo --------------------------------------------------------
double    g_tick      = 5.0;
double    g_pointValue= 0.2;

//--- horarios (minutos do dia) --------------------------------------
int       g_sessStart = 540, g_lastEntry = 1020, g_flat = 1095;

//--- volume normal por horario --------------------------------------
double    g_volHist[];          // g_volCap dias x 1440 minutos
int       g_volCap = 10, g_volDays = 0, g_volHead = 0;
double    g_volToday[1440];
double    g_norm[1440];
bool      g_normReady = false;

//--- volume profile do dia ------------------------------------------
double    g_prof[PROF_SIZE];
double    g_profBase = 0;
bool      g_profInit = false;
double    g_prevPoc = 0, g_prevVah = 0, g_prevVal = 0, g_prevHigh = 0, g_prevLow = 0;
bool      g_hasPrev = false;

//--- estado do dia --------------------------------------------------
datetime  g_day = 0;
double    g_dayHigh = -1, g_dayLow = -1, g_vwapPV = 0, g_vwapV = 0;
int       g_tradesToday = 0, g_lossesToday = 0;
int       g_ctx = 0;            // contexto: +1 alta, -1 baixa, 0 neutro

//--- leitura de fluxo (ticks) ---------------------------------------
MqlTick   g_ticks[];
double    g_lastTradePrice = 0;
int       g_lastSide = 0;
int       g_barTicks = 0;       // negocios do ultimo LoadBarTicks
int       g_barTicksFlag = 0;   // desses, quantos tinham flag BUY/SELL
double    g_barBid = 0;         // bid do ultimo tick do minuto (0 = ausente)
double    g_barAsk = 0;

//--- setup em andamento ---------------------------------------------
IcsZone   g_zone;
IcsSetup  g_s;
int       g_state = ST_IDLE;
int       g_zoneCounter = 0;
datetime  g_zoneMinStart = 0;
double    g_doneHi[], g_doneLo[], g_donePoc[];   // zonas ja encerradas (viram niveis)
IcsAbs    g_abs[];
IcsVTrade g_vt[];

//--- posicao real ---------------------------------------------------
double    g_realRisk = 0;
double    g_realBest = 0, g_realTrail = 0;
bool      g_realBE = false;
int       g_realSignalId = 0;   // id do sinal que abriu a posicao real

//--- arquivos e objetos grafico -------------------------------------
int       g_fSig = INVALID_HANDLE, g_fEvt = INVALID_HANDLE;
int       g_fRun = INVALID_HANDLE, g_fBar = INVALID_HANDLE;
int       g_fOrd = INVALID_HANDLE, g_fFun = INVALID_HANDLE;
long      g_objN = 0;

//--- diagnostico de qualidade dos dados -----------------------------
long      g_dgBars = 0, g_dgBarsTicks = 0, g_dgTicks = 0, g_dgFlag = 0, g_dgNoFlag = 0, g_dgZeroVol = 0;
bool      g_dgWarned = false;

//--- estatisticas ---------------------------------------------------
int       g_signals = 0;
int       g_tkN = 0, g_tkWins = 0;
double    g_tkSumR = 0, g_tkSumPts = 0, g_tkSumBRL = 0, g_tkGrossWin = 0, g_tkGrossLoss = 0;
int       g_rjN = 0, g_rjWins = 0;
double    g_rjSumR = 0;
string    g_rsnName[];          // motivos de rejeicao
string    g_evName[], g_retName[];
int       g_kAll[4], g_kWin[4], g_kTkN[4];       // [0] pb [1] romp [2] aceit [3] reteste
double    g_kR[4], g_kBRL[4], g_kTkR[4];
int       g_evCnt[], g_retCnt[];
int       g_rsnCnt[];

#endif // __ICSM_GLOBALS_MQH__
//+------------------------------------------------------------------+

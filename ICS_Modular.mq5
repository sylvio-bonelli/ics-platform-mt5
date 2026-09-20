//+------------------------------------------------------------------+
//| ICS_Modular.mq5                                                       |
//| ICS - Institutional Continuation Setup - prova de conceito       |
//| Mini indice (WIN), grafico M1                                    |
//|                                                                  |
//| Fluxo: zona institucional (M5) -> rompimento com fluxo (M1)      |
//|        -> aceitacao e continuidade -> primeiro pullback fraco    |
//|        -> retomada do fluxo -> entrada                           |
//|                                                                  |
//| Todos os sinais (executados e rejeitados) sao simulados e        |
//| gravados em CSV na pasta comum do MetaTrader (Common\Files).     |
//|                                                                  |
//| ------------------------------------------------------------     |
//| ESTE ARQUIVO CONTEM APENAS:                                      |
//|   - as #property do EA                                           |
//|   - a ORDEM DE INCLUDE dos modulos                               |
//|   - os handlers de evento do MetaTrader (OnInit/OnTick/...)      |
//|                                                                  |
//| Toda a logica vive nos .mqh. Ver ARCHITECTURE.md para o mapa     |
//| completo de responsabilidades e dependencias.                    |
//|                                                                  |
//| AVISO SOBRE A ORDEM DOS INCLUDES                                 |
//| MQL5 nao tem linker: o #include e inclusao textual e tudo vira   |
//| uma unica unidade de compilacao. Variaveis globais PRECISAM ser  |
//| declaradas antes do primeiro uso, entao a ordem abaixo nao e     |
//| arbitraria - ela segue as camadas do projeto, de baixo para      |
//| cima. Ao acrescentar um modulo, respeite a camada dele.          |
//+------------------------------------------------------------------+
#property copyright "ICS - Institutional Continuation Setup"
#property version   "0.19"
#property description "Prova de conceito do ICS no WIN (M1)."
#property description "Zona institucional -> rompimento com fluxo -> primeiro pullback fraco -> retomada."

//--- camada 0: contratos de dados e parametros ----------------------
#include "Config/Defines.mqh"
#include "Config/Inputs.mqh"

//--- camada 1: estado global e utilitarios puros --------------------
#include "Core/Globals.mqh"
#include "Core/Prototypes.mqh"
#include "Core/Utils.mqh"
#include "Core/Stats.mqh"

//--- camada 2: dados de mercado -------------------------------------
#include "Data/VolumeNormals.mqh"
#include "Data/VolumeProfile.mqh"
#include "Data/Flow.mqh"

//--- camada 3: saida (desenho e arquivos) ---------------------------
#include "UI/Draw.mqh"
#include "Execution/Logger.mqh"

//--- camada 4: construcao de barras ---------------------------------
#include "Data/BarBuilder.mqh"

//--- camada 5: execucao ---------------------------------------------
#include "Execution/VirtualTrades.mqh"
#include "Execution/RealOrders.mqh"

//--- camada 6: analise ----------------------------------------------
#include "Analysis/Zone.mqh"
#include "Analysis/Levels.mqh"
#include "Analysis/Absorption.mqh"
#include "Analysis/ZoneDetector.mqh"
#include "Analysis/StateMachine.mqh"
#include "Analysis/Reject.mqh"
#include "Analysis/Trigger.mqh"

//--- camada 7: orquestracao -----------------------------------------
#include "UI/Panel.mqh"
#include "Runtime/Session.mqh"
#include "Runtime/BarProcessor.mqh"
#include "Runtime/Summary.mqh"

//+------------------------------------------------------------------+
//| Inicializacao                                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- caracteristicas do simbolo
   double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   g_tick = (ts > 0) ? ts : 1.0;
   if(StringFind(_Symbol, "WIN") == 0 && g_tick < 5.0) g_tick = 5.0;
   g_pointValue = (ts > 0 && tv > 0) ? tv / ts : 0.2;

   //--- validacao dos parametros
   g_sessStart = ParseHM(InpSessionStart);
   g_lastEntry = ParseHM(InpLastEntry);
   g_flat      = ParseHM(InpFlatTime);
   if(g_sessStart < 0 || g_lastEntry < 0 || g_flat < 0)
   {
      Print("Horario invalido nos parametros (use HH:MM)");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpAcceptMin > InpAcceptBars)
   {
      Print("Aceitacao: o minimo nao pode ser maior que o numero de barras");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpHoldBars < 1)
   {
      Print("Manter: o numero de candles deve ser >= 1");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpRejectMaxBars < 1)
   {
      Print("Reteste falho: o prazo em barras deve ser >= 1");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpRejectMinRetr <= 0 || InpRejectMinRetr > 1)
   {
      Print("Reteste falho: a retracao minima deve estar em (0, 1]");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpDespWickMult <= 0 || InpFullBodyFrac <= 0 || InpFullBodyFrac > 1)
   {
      Print("Reversao: pavio/corpo deve ser > 0 e a fracao de corpo cheio entre 0 e 1");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(StringFind(_Symbol, "WIN$") >= 0)
      Print("AVISO: WIN$ nao tem lado agressor nem bid/ask. Use o contrato (ex.: WINV26) ou WIN_ICS.");

   //--- buffers de estatistica e volume
   ArrayInitialize(g_kAll, 0);
   ArrayInitialize(g_kWin, 0);
   ArrayInitialize(g_kTkN, 0);
   ArrayInitialize(g_kR, 0.0);
   ArrayInitialize(g_kBRL, 0.0);
   ArrayInitialize(g_kTkR, 0.0);
   g_volCap = MathMax(1, MathMin(InpVolDays, 60));
   ArrayResize(g_volHist, g_volCap * 1440);
   ArrayInitialize(g_volHist, 0.0);

   //--- modo de execucao
   g_isTester = (MQLInfoInteger(MQL_TESTER) != 0);
   g_draw     = InpDraw && (!g_isTester || MQLInfoInteger(MQL_VISUAL_MODE) != 0);
   g_files    = (MQLInfoInteger(MQL_OPTIMIZATION) == 0);

   g_trade.SetExpertMagicNumber((ulong)InpMagic);
   g_trade.SetTypeFillingBySymbol(_Symbol);
   g_trade.SetDeviationInPoints((ulong)(InpSlipPts * 2));

   //--- carga de historico com sinais desligados (g_replay)
   OpenFiles();
   g_replay = true;
   LoadHistory();
   if(!g_isTester) ProcessPending(TimeCurrent());
   g_replay = false;

   if(!g_isTester && InpTradeEnabled && !InpLiveOrders)
      Print("ICS Modular ao vivo: ordens BLOQUEADAS (somente alertas). Para operar, ative 'AO VIVO: permitir ordens reais'.");
   PrintFormat("ICS Modular v0.19 iniciado em %s | tick %.0f | R$ %.2f/ponto | modo %s | ordens %s",
               _Symbol, g_tick, g_pointValue, InpBaseline ? "BASELINE" : "COMPLETO", OrdersAllowed() ? "sim" : "nao");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Tick: o EA so trabalha na virada do minuto                       |
//+------------------------------------------------------------------+
void OnTick()
{
   datetime now    = TimeCurrent();
   datetime curMin = (datetime)(((long)now / 60) * 60);
   if(curMin == g_curMinute) return;
   g_curMinute = curMin;
   ProcessPending(now);
}

//+------------------------------------------------------------------+
//| Encerramento                                                     |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   CloseAllVirtual("FIM_TESTE");
   PrintSummary();
   if(g_fSig != INVALID_HANDLE) FileClose(g_fSig);
   if(g_fEvt != INVALID_HANDLE) FileClose(g_fEvt);
   g_fSig = INVALID_HANDLE;
   g_fEvt = INVALID_HANDLE;
   Comment("");
}

//+------------------------------------------------------------------+
//| Criterio personalizado de otimizacao                             |
//+------------------------------------------------------------------+
double OnTester()
{
   CloseAllVirtual("FIM_TESTE");
   return g_tkSumR;   // soma de R das operacoes executadas
}
//+------------------------------------------------------------------+

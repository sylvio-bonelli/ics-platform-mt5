//+------------------------------------------------------------------+
//| Config/Defines.mqh                                               |
//| Constantes, enums de parametros e estruturas de dados do ICS.    |
//|                                                                  |
//| Modulo mais baixo da hierarquia: NAO depende de nada.            |
//| Qualquer campo novo em IcsZone / IcsSetup / IcsVTrade entra aqui.|
//+------------------------------------------------------------------+
#ifndef __ICSM_DEFINES_MQH__
#define __ICSM_DEFINES_MQH__

//--- tamanho do vetor do Volume Profile do dia (niveis de preco)
#define PROF_SIZE   1200

//--- estados da maquina de estados (ver Analysis/StateMachine.mqh)
#define ST_IDLE     0   // sem zona candidata
#define ST_ZONE     1   // zona institucional ativa, aguardando rompimento
#define ST_BREAKOUT 2   // rompeu, aguardando aceitacao / continuidade
#define ST_IMPULSE  3   // deslocamento confirmado, monitorando pullback

//+------------------------------------------------------------------+
//| Enums de parametros                                              |
//+------------------------------------------------------------------+
enum ENUM_ICS_DELTA
{
   ICS_DELTA_AUTO  = 0,   // Automatico (flags; sem flag = regra de cotacao)
   ICS_DELTA_FLAGS = 1,   // Somente flags da corretora
   ICS_DELTA_QUOTE = 2    // Somente regra de cotacao (bid/ask)
};

enum ENUM_ICS_CTX
{
   ICS_CTX_OFF     = 0,   // Nao filtrar
   ICS_CTX_BLOCK   = 1,   // Bloquear operacoes contra o contexto
   ICS_CTX_REQUIRE = 2    // Exigir contexto a favor
};

enum ENUM_ICS_TARGET
{
   ICS_TGT_FIRST    = 0,  // Primeiro obstaculo (estrito)
   ICS_TGT_FIRST_RR = 1   // Primeiro nivel que atenda o R:R minimo
};

enum ENUM_ICS_ENTRY
{
   ICS_ENTRY_PULLBACK = 0, // Pullback apos o rompimento (ICS original)
   ICS_ENTRY_BREAKOUT = 1, // No rompimento com fluxo
   ICS_ENTRY_BOTH     = 2  // Ambos (comparacao)
};

enum ENUM_ICS_BSTOP
{
   ICS_BSTOP_BAR  = 0,     // Extremo do candle de rompimento
   ICS_BSTOP_POC  = 1,     // POC da zona
   ICS_BSTOP_ZONE = 2      // Borda oposta da zona
};

enum ENUM_ICS_EXIT
{
   ICS_EXIT_FIXED = 0,     // Alvo fixo no primeiro obstaculo
   ICS_EXIT_TRAIL = 1      // Breakeven + trailing (deixa a tendencia correr)
};

//+------------------------------------------------------------------+
//| Estruturas                                                       |
//+------------------------------------------------------------------+

//--- barra agregada (M1 ou M5) com fluxo
struct IcsBar
{
   datetime t;                                   // abertura da barra
   double   o, h, l, c;
   double   vol, buy, sell, delta, vwap, dvwap;  // dvwap = VWAP acumulada do dia
   long     seq;                                 // indice sequencial global da barra M1
};

//--- zona institucional detectada no M5
struct IcsZone
{
   int      id;
   datetime t0, t1;
   double   hi, lo, poc, vol, er, relvol;    // er = eficiencia direcional
   int      m5bars;
   bool     testLow, testHigh, sweptHigh, sweptLow;
   int      outUp, outDn;                    // barras consecutivas fora da zona sem fluxo
   long     outUpSeq, outDnSeq;
};

//--- setup em andamento (rompimento -> impulso -> pullback)
struct IcsSetup
{
   int      dir;                             // +1 compra, -1 venda
   long     brkSeq;
   datetime brkTime;
   double   brkVolRatio, brkDeltaPct;
   double   brkLevel;                        // borda rompida (hi compra / lo venda)
   bool     holdDone;                        // gatilho de aceitacao ja disparado ou invalidado
   int      insideCount;                     // retornos tolerados na janela de aceitacao
   double   impExt;                          // extremo do impulso
   long     impExtSeq;
   double   origin;                          // origem do impulso (base da perna)
   double   impVol, impDelta;
   int      impBars;
   double   pbExt;                           // extremo do pullback
   long     pbExtSeq;
   double   pbVol, pbDelta;
   int      pbBars;
   bool     pbQualified;                     // retracao minima atingida
   int      pbCount;                         // pullbacks ja observados
   double   retr;                            // retracao atual (0-1)
   double   dayExtBefore;                    // extremo do dia antes do rompimento
};

//--- evento de absorcao detectado no M1
struct IcsAbs
{
   datetime t;
   long     seq;
   double   price;
   int      side;
};

//--- operacao simulada (todo gatilho vira uma, executado ou rejeitado)
struct IcsVTrade
{
   bool     active;
   bool     taken;                           // passou por todos os filtros
   int      kind;                            // 0 = pullback, 1 = rompimento, 2 = aceitacao
   int      dir;
   long     startSeq;
   int      bars;
   double   entry, stop, target, risk, mae, mfe;
   bool     be;                              // ja moveu para zero-a-zero
   double   trail;
   string   info;                            // linha parcial do CSV de sinais
};

#endif // __ICSM_DEFINES_MQH__
//+------------------------------------------------------------------+

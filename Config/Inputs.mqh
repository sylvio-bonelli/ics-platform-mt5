//+------------------------------------------------------------------+
//| Config/Inputs.mqh                                                |
//| Todos os parametros de entrada do EA.                            |
//|                                                                  |
//| Depende de: Config/Defines.mqh (enums).                          |
//|                                                                  |
//| A ORDEM DOS GRUPOS AQUI e a ordem que aparece na janela de       |
//| propriedades do MetaTrader. Centralizar tudo em um unico arquivo |
//| e o que garante esse controle.                                   |
//+------------------------------------------------------------------+
#ifndef __ICSM_INPUTS_MQH__
#define __ICSM_INPUTS_MQH__

input group "=== Geral ==="
input bool   InpTradeEnabled    = true;      // Enviar ordens (false = so sinais/alertas)
input bool   InpLiveOrders      = false;     // AO VIVO: permitir ordens reais (seguranca)
input bool   InpExecuteAll      = false;     // TESTE: executar todos os gatilhos (estudo)
input bool   InpBaseline        = false;     // Modo BASELINE (desliga filtros de volume/fluxo)
input double InpLots            = 1;         // Contratos por operacao
input long   InpMagic           = 20260918;  // Numero magico
input string InpRunTag          = "";        // Sufixo dos arquivos CSV (ex.: teste1)
input bool   InpLogBars         = true;      // Gravar CSV de barras M1 (comparativo)
input bool   InpAlerts          = true;      // Alertas na tela (ao vivo)
input bool   InpPush            = false;     // Notificacao no celular (ao vivo)
input bool   InpDraw            = true;      // Desenhar zonas e sinais no grafico
input bool   InpCommaDecimal    = true;      // CSV com virgula decimal (Excel pt-BR)

input group "=== Tipo de entrada ==="
input ENUM_ICS_ENTRY InpEntryMode   = ICS_ENTRY_BOTH; // Entrada
input ENUM_ICS_BSTOP InpBrkStopMode = ICS_BSTOP_BAR;  // Stop da entrada no rompimento
input double InpBrkMaxVolMult   = 0;         // Volume maximo do rompimento (x normal, 0 = sem limite)

input group "=== Horarios (hora do servidor) ==="
input string InpSessionStart    = "09:00";   // Inicio do pregao
input int    InpNoEntryFirstMin = 15;        // Minutos sem entrada apos a abertura
input string InpLastEntry       = "17:00";   // Ultimo horario para entrada
input string InpFlatTime        = "18:15";   // Horario de zeragem

input group "=== Dados e volume ==="
input ENUM_ICS_DELTA InpDeltaMode = ICS_DELTA_AUTO; // Calculo do delta
input int    InpVolDays         = 10;        // Dias para o volume normal por horario
input int    InpVolMinDays      = 3;         // Minimo de dias (senao usa media de 20 barras)
input int    InpProfileStep     = 50;        // Passo do Volume Profile (pontos)
input double InpHvnFactor       = 1.5;       // HVN: volume >= X vezes a media dos niveis

input group "=== Contexto ==="
input ENUM_ICS_CTX InpCtxFilter = ICS_CTX_BLOCK; // Filtro de contexto (VWAP do dia)
input int    InpCtxSlopeBars    = 30;        // Barras M1 para inclinacao da VWAP

input group "=== Zona institucional (M5) ==="
input int    InpZoneMinBars     = 6;         // Minimo de barras M5
input int    InpZoneMaxBars     = 24;        // Maximo de barras M5 analisadas
input double InpZoneMaxRangeATR = 2.5;       // Amplitude maxima (x ATR M5)
input double InpZoneMaxER       = 0.30;      // Eficiencia direcional maxima (0-1)
input double InpZoneMinRelVol   = 1.0;       // Volume relativo minimo
input int    InpZoneStaleBars   = 15;        // Barras M1 fora da zona sem fluxo para encerrar
input double InpTouchTolPts     = 10;        // Tolerancia de toque nas bordas (pontos)

input group "=== Reteste falho (M1) ==="
input bool   InpRejectEntry     = true;      // Entrar no reteste que nao reconquista a zona
input double InpRejectMinRetr   = 0.20;      // Retracao minima do bounce rumo a zona
input int    InpRejectMaxBars   = 30;        // Prazo do watch apos o vazamento (barras)

input group "=== Absorcao e teste (M1) ==="
input double InpAbsVolMult      = 2.5;       // Absorcao: volume >= X vezes o normal
input double InpAbsMaxDispATR   = 0.5;       // Absorcao: deslocamento <= X vezes ATR M1
input int    InpAbsLookback     = 15;        // Absorcao: barras antes da zona consideradas
input bool   InpReqAbsorption   = false;     // Exigir absorcao
input double InpTestVolMult     = 0.7;       // Teste: volume <= X vezes o normal
input bool   InpReqTest         = false;     // Exigir teste da extremidade

input group "=== Rompimento e continuidade (M1) ==="
input double InpBrkVolMult      = 1.5;       // Rompimento: volume >= X vezes o normal
input double InpBrkDeltaPct     = 20;        // Rompimento: delta a favor >= X% do volume
input int    InpAcceptBars      = 3;         // Aceitacao: barras observadas apos o rompimento
input int    InpAcceptMin       = 2;         // Aceitacao: minimo de fechamentos fora da zona
input int    InpTrapBars        = 5;         // Armadilha: retorno a zona em ate X barras
input double InpContMult        = 1.0;       // Continuidade: avanco >= X vezes a altura da zona
input int    InpContBars        = 10;        // Continuidade: prazo em barras
input bool   InpHoldEntry       = true;      // Entrar se o rompimento se mantiver
input int    InpHoldBars        = 5;         // Manter: candles sem fechar contra o nivel
input int    InpOriginLookback  = 5;         // Barras antes do rompimento para a origem do impulso

input group "=== Pullback e gatilho (M1) ==="
input double InpPbMinRetr       = 0.20;      // Retracao minima para pullback valido
input double InpPbGoodRetr      = 0.50;      // Retracao saudavel (nota maxima)
input double InpPbMaxRetr       = 0.90;      // Retracao maxima (acima invalida)
input int    InpPbMaxBars       = 30;        // Duracao maxima do pullback (barras)
input int    InpMaxPullbacks    = 1;         // Pullbacks permitidos (1 = so o primeiro)
input double InpPbMaxVolRatio   = 0.6;       // Volume medio do pullback <= X do impulso
input double InpPbMaxDeltaRatio = 0.5;       // Delta contrario do pullback <= X do delta do impulso
input double InpTrigVolMult     = 1.0;       // Gatilho: volume >= X vezes o normal
input double InpTrigMinDeltaPct = 0;         // Gatilho: delta a favor > X% do volume

input group "=== Risco, alvo e gestao ==="
input double InpStopBufPts      = 10;        // Stop: pontos alem do extremo do pullback
input double InpMaxStopATR      = 1.5;       // Stop maximo (x ATR M5), acima descarta
input double InpMinRR           = 2.0;       // R:R minimo (liquido de custos)
input ENUM_ICS_TARGET InpTargetMode = ICS_TGT_FIRST; // Selecao do alvo
input double InpTargetOffsetPts = 5;         // Alvo: pontos antes do nivel
input double InpProjMult        = 1.0;       // Alvo sem nivel: projecao do impulso (x)
input double InpMinScore        = 0;         // Score minimo (0 = registrar todos)
input double InpSlipPts         = 5;         // Slippage estimado (pontos por execucao)
input double InpCostPerContract = 0.50;      // Custo por contrato ida+volta (R$)
input double InpMinStopATR      = 0.5;       // Stop minimo (x ATR M5, 0 = sem minimo)
input ENUM_ICS_EXIT InpExitMode = ICS_EXIT_TRAIL; // Gestao da saida
input bool   InpTrilhoSaida     = false;     // Trilho de saida (3 fatias iguais)
input double InpTrilhoPts       = 110;       // Trilho: pontos da primeira saida
input double InpTrilhoRecuo     = 0.5;       // Trilho: recuo do maximo ate a segunda saida
input double InpBEAtR           = 1.0;       // Trailing: stop no zero-a-zero apos X R
input double InpTrailStartR     = 1.5;       // Trailing: comecar a seguir apos X R
input double InpTrailATR        = 1.0;       // Trailing: distancia (x ATR M5)
input double InpTrailTpMult     = 3.0;       // Trailing: alvo de seguranca (x projecao)
input int    InpTimeStopBars    = 30;        // Stop de tempo (barras)
input double InpTimeStopMinR    = 0.5;       // Stop de tempo: sai se lucro < X R
input bool   InpReversalExit    = true;      // Saida por reversao (desespero + corpo cheio)
input double InpDespWickMult    = 2.0;       // Desespero: pavio >= X vezes o corpo
input double InpFullBodyFrac    = 0.60;      // Corpo cheio: corpo >= X da amplitude
input int    InpMaxTradesDay    = 3;         // Maximo de operacoes por dia
input int    InpMaxLossesDay    = 2;         // Para apos X perdas no dia
input double InpMaxLossDayBRL   = 0;         // Prejuizo maximo do dia (R$, 0 = off)

#endif // __ICSM_INPUTS_MQH__
//+------------------------------------------------------------------+

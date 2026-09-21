# Parâmetros de entrada — ICS_Modular

Ficha de cada `input` de [`Config/Inputs.mqh`](../Config/Inputs.mqh), escrita
para análise de backtest — não só o rótulo da janela do MetaTrader.

A **fonte da verdade** é o código. Este arquivo explica o *porquê* e o *efeito
no funil / CSV*. Se default, rótulo ou comportamento divergirem, o `.mqh` vence.

Vocabulário do setup: [`GLOSSARY.md`](GLOSSARY.md). Legenda do gráfico:
[`GRAFICO.md`](GRAFICO.md). Comparar conta real × Testador:
[`COMPARATIVO.md`](COMPARATIVO.md).

---

## Como usar na análise

Todo gatilho avaliado vira operação simulada — **executado ou rejeitado**. A
rejeitada continua sendo acompanhada até o desfecho e vai para o CSV. A pergunta
central do estudo é: *este filtro está protegendo ou custando dinheiro?* Se a
população de `REJEITADO` tiver R médio igual ou melhor que a de `EXECUTADO`, o
filtro está errado.

`EvaluateTrigger` **nunca aborta**. Os motivos de rejeição se acumulam em
`motivos` (separados por ` | `). Um gatilho pode ter vários ao mesmo tempo.

### Três modos

| Modo | Como ligar | O que muda |
|---|---|---|
| **Completo** | `InpBaseline = false` | todos os filtros de volume/fluxo valem |
| **Baseline** | `InpBaseline = true` | desliga volume/fluxo; o restante continua |
| **Estudo** | `InpExecuteAll = true` no Testador | rejeitado também envia ordem (`ESTUDO_EXECUTADO`) |

Compare Completo × Baseline no **mesmo período**. Se o baseline for igual ou
melhor, os filtros de volume/fluxo não estão agregando.

### Travas de ordem

`OrdersAllowed()` em `Core/Utils.mqh`:

```
InpTradeEnabled && (testador || InpLiveOrders)
```

Nenhuma ordem sai com `g_replay = true` (carga de histórico). As duas travas
existem de propósito — não simplifique.

### Status no CSV (`ICS_Modular_sinais_*.csv`)

| Status | Significado |
|---|---|
| `EXECUTADO` | passou em todos os filtros e a ordem foi enviada (ou teria sido, se as travas permitissem) |
| `REJEITADO` | um ou mais filtros barraram; a virtual ainda roda até o desfecho |
| `ESTUDO_EXECUTADO` | rejeitado, mas `InpExecuteAll` mandou a ordem no Testador |
| `ERRO_ORDEM` | passou nos filtros e o envio falhou |

`g_vt.taken` só fica `true` em `EXECUTADO`. `ESTUDO_EXECUTADO` abre posição no
testador, mas a linha virtual continua como não tomada — limites do dia
(`InpMaxTradesDay`, `InpMaxLossesDay`) **não** incrementam nesse caminho.

### O que este documento não faz

Não recomenda valores. Distingue **fato** (o que o código faz) de **hipótese**
de calibração. "Não operar" é decisão válida.

---

## Funil ↔ grupo de parâmetros

Ordem real da máquina de estados (`Analysis/StateMachine.mqh` +
`Analysis/ZoneDetector.mqh`). Apertar um parâmetro cedo reduz tudo que vem
depois — o funil do Diário mostra *onde* os candidatos morrem.

```
zona M5          Zona institucional
  -> absorcao    Absorcao e teste          (opcional como filtro)
  -> teste       Absorcao e teste          (opcional como filtro)
  -> rompimento  Rompimento e continuidade
  -> aceitacao   InpAcceptBars / InpAcceptMin
  -> hold        InpHoldEntry / InpHoldBars   (kind=2, nao encerra a zona)
  -> continuidade InpContMult / InpContBars
  -> pullback    Pullback e gatilho
  -> reteste     InpRejectEntry               (kind=3, vazamento sem fluxo)
  -> gatilho     EvaluateTrigger              (kind 0, 1, 2 ou 3)
  -> risco       Risco, alvo e gestao
```

Filtros de horário, contexto e limite do dia só entram no gatilho — **não**
impedem a zona de nascer. Uma zona pode existir e nenhum gatilho passar.

Motivos de `RetireZone` (CSV de eventos, não coluna `motivos` do sinal) são
listados em cada ficha quando o parâmetro encerra a zona sem chegar ao gatilho.

---

## O que o Baseline desliga

`InpBaseline = true` ignora só filtros de **volume e fluxo**. Fato no código:

| Desliga | Onde |
|---|---|
| `InpZoneMinRelVol` | `ZoneDetector.mqh` |
| `InpBrkVolMult`, `InpBrkDeltaPct` | `StateMachine.mqh` (`ZoneBar`) |
| `InpPbMaxVolRatio`, `InpPbMaxDeltaRatio` | `Trigger.mqh` |
| `InpTrigVolMult`, `InpTrigMinDeltaPct` | `Trigger.mqh` (não se aplicam a hold) |
| `InpReqAbsorption`, `InpReqTest` | `Trigger.mqh` |

**Continuam valendo:** horário, contexto VWAP, `InpBrkMaxVolMult` (rompimento
climático), stop largo/curto, R:R, score, limites do dia, `InpMaxPullbacks`,
aceitação, continuidade, retração.

O score **ainda usa** volume/delta do rompimento e do gatilho — o Baseline
afrouxa a *rejeição*, não zera a nota. Sufixo do CSV vira `baseline`.

---

## Convenções das fichas

- **Rótulo** — texto da janela do MetaTrader (comentário de fim de linha).
- **Onde** — arquivo e função que leem o valor.
- **Motivo CSV** — string em `motivos` quando o parâmetro rejeita o gatilho.
  `—` = não rejeita sozinho (muda detecção, score, gestão ou arquivo).
- **Encerramento** — motivo de `RetireZone` / evento, quando existir.
- **Para análise** — o que muda no funil se apertar ou afrouxar; interações;
  o que o parâmetro *não* mede.

Enums: valores de [`Config/Defines.mqh`](../Config/Defines.mqh).

---

## 1. Geral

### `InpTradeEnabled`

- **Tipo / default:** `bool` = `true`
- **Rótulo:** Enviar ordens (false = so sinais/alertas)
- **Onde:** `Core/Utils.mqh` (`OrdersAllowed`), `ICS_Modular.mq5` (`OnInit`)
- **Motivo CSV:** —

**O que faz.** Primeira trava. `false` impede ordem no testador **e** ao vivo.
Sinais, virtuais e CSV continuam.

**Para análise.** Deixe `true` no Testador. `false` ao vivo = só alerta. Não
muda quem passa nos filtros — só se a ordem sai.

### `InpLiveOrders`

- **Tipo / default:** `bool` = `false`
- **Rótulo:** AO VIVO: permitir ordens reais (seguranca)
- **Onde:** `Core/Utils.mqh` (`OrdersAllowed`)
- **Motivo CSV:** —

**O que faz.** Segunda trava. No testador é ignorada (`g_isTester` já libera).
Ao vivo, as duas precisam estar `true`.

**Para análise.** Default seguro. Sem efeito em backtest. Ao vivo, `true` +
`InpTradeEnabled = false` ainda bloqueia.

### `InpExecuteAll`

- **Tipo / default:** `bool` = `false`
- **Rótulo:** TESTE: executar todos os gatilhos (estudo)
- **Onde:** `Analysis/Trigger.mqh` (`EvaluateTrigger`)
- **Motivo CSV:** não cria motivo; muda `status` para `ESTUDO_EXECUTADO`

**O que faz.** Só no Testador, fora de replay, antes de `InpFlatTime` e sem
posição real: envia a ordem do gatilho rejeitado. A virtual permanece
`taken = false`.

**Para análise.** Serve para ver o P&L *real* dos rejeitados na conta do
testador. Não use ao vivo. Hipótese a testar: se `ESTUDO_EXECUTADO` tiver R
médio melhor que `EXECUTADO`, algum filtro está caro.

### `InpBaseline`

- **Tipo / default:** `bool` = `false`
- **Rótulo:** Modo BASELINE (desliga filtros de volume/fluxo)
- **Onde:** `ZoneDetector.mqh`, `StateMachine.mqh`, `Trigger.mqh`, `Logger.mqh`
- **Motivo CSV:** some os motivos de volume/fluxo listados na seção Baseline

**O que faz.** Ver tabela acima. Arquivo CSV: `*_baseline_*.csv`.

**Para análise.** Rode o mesmo período nos dois modos. Mais zonas/rompimentos
no baseline é esperado. A comparação útil é R médio e MAE das duas populações
*executadas*, não a contagem bruta.

### `InpLots`

- **Tipo / default:** `double` = `1`
- **Rótulo:** Contratos por operacao
- **Onde:** `Execution/RealOrders.mqh` (`SendOrder`), `VirtualTrades.mqh` (`CloseVirtual`)
- **Motivo CSV:** —

**O que faz.** Tamanho da ordem real e do `resultado_brl` virtual
(`pts * ponto * lots − custo * lots`). Não entra no R.

**Para análise.** R é independente do lote. `resultado_brl` escala linearmente.
Não use lote para “melhorar” o estudo — use para bater com o tamanho real.

### `InpMagic`

- **Tipo / default:** `long` = `20260918`
- **Rótulo:** Numero magico
- **Onde:** `ICS_Modular.mq5` (`OnInit`), `Execution/RealOrders.mqh`
- **Motivo CSV:** —

**O que faz.** Identifica a posição deste EA. `HasRealPosition` / `HasOpenTrade`
/ `ManageRealPosition` só enxergam esse mágico.

**Para análise.** Colidir com outro EA no mesmo símbolo = trailing cruzado e
zeragem alheia. O `ICS_EA` antigo usava `26091601` de propósito diferente.

### `InpRunTag`

- **Tipo / default:** `string` = `""`
- **Rótulo:** Sufixo dos arquivos CSV (ex.: teste1)
- **Onde:** `Execution/Logger.mqh` (`OpenFiles`)
- **Motivo CSV:** —

**O que faz.** Nome:

`ICS_Modular_{tipo}_{simbolo}_{completo|baseline}_{live|tester}_{YYYYMMDD}[_tag].csv`

O ambiente e a data já separam a run live da run do Testador no mesmo dia.
`InpRunTag` distingue uma segunda run no **mesmo** ambiente e data (ex.: dois
testes no Testador no mesmo símbolo).

**Para análise.** Sem tag, a segunda run tester do mesmo dia sobrescreve só os
arquivos `*_tester_*` — o CSV live permanece. Ver [`COMPARATIVO.md`](COMPARATIVO.md).

### `InpLogBars`

- **Tipo / default:** `bool` = `true`
- **Rótulo:** Gravar CSV de barras M1 (comparativo)
- **Onde:** `Execution/Logger.mqh` (`LogBar`), `Runtime/BarProcessor.mqh`
- **Motivo CSV:** —

**O que faz.** Uma linha por M1 com `live = true` em `ICS_Modular_barras_*.csv`
(OHLCV, delta, ticks, bid/ask, `proc_lag_s`, estado). Cabeçalho do arquivo
sempre é escrito; `false` só omite as linhas.

**Para análise.** É o arquivo que explica *por que* zona ou sinal divergiu entre
live e Testador. Desligar reduz I/O; não muda sinais. Bid/ask de barra com
`proc_lag_s` alto (catch-up) **não** é histórico — use só OHLCV/delta/ticks
nesses minutos.

### `InpAlerts`

- **Tipo / default:** `bool` = `true`
- **Rótulo:** Alertas na tela (ao vivo)
- **Onde:** `Analysis/Trigger.mqh`
- **Motivo CSV:** —

**O que faz.** `Alert()` só ao vivo, fora de replay, quando `taken`. Testador
não alerta.

**Para análise.** Sem efeito no CSV nem no funil.

### `InpPush`

- **Tipo / default:** `bool` = `false`
- **Rótulo:** Notificacao no celular (ao vivo)
- **Onde:** `Analysis/Trigger.mqh` (só se `InpAlerts`)
- **Motivo CSV:** —

**O que faz.** `SendNotification` do mesmo texto do alerta. Exige `InpAlerts`.

**Para análise.** Sem efeito no estudo.

### `InpDraw`

- **Tipo / default:** `bool` = `true`
- **Rótulo:** Desenhar zonas e sinais no grafico
- **Onde:** `ICS_Modular.mq5` → `g_draw`; `UI/Draw.mqh`, `Logger.mqh`, `Panel.mqh`
- **Motivo CSV:** —

**O que faz.** `g_draw = InpDraw && (!testador || modo visual)`. Sem desenho,
CSV e lógica permanecem.

**Para análise.** Desligar acelera otimização. Não muda sinais.

### `InpCommaDecimal`

- **Tipo / default:** `bool` = `true`
- **Rótulo:** CSV com virgula decimal (Excel pt-BR)
- **Onde:** `Core/Utils.mqh` (`F`)
- **Motivo CSV:** —

**O que faz.** Troca `.` por `,` em todo número escrito via `F()`.

**Para análise.** `true` = Excel pt-BR. `false` = pandas / R. Separador de
coluna é sempre `;`.

---

## 2. Tipo de entrada

### `InpEntryMode`

- **Tipo / default:** `ENUM_ICS_ENTRY` = `ICS_ENTRY_BOTH`
- **Rótulo:** Entrada
- **Onde:** `StateMachine.mqh` (`StartBreakout`, `PullbackTrigger`)
- **Motivo CSV:** —
- **Encerramento:** `gatilho de pullback (entrada desativada)` se só rompimento

Valores:

| Enum | O que dispara |
|---|---|
| `ICS_ENTRY_PULLBACK` | só kind=0 (ICS clássico) |
| `ICS_ENTRY_BREAKOUT` | só kind=1 no candle de rompimento; pullback encerra a zona |
| `ICS_ENTRY_BOTH` | kind=1 e, depois, kind=0 e/ou kind=2 |

**O que faz.** Coluna `setup` no CSV: `PULLBACK` / `ROMPIMENTO` / `ACEITACAO` /
`RETESTE_FALHO`. Hold (`kind=2`) depende de `InpHoldEntry`; reteste (`kind=3`)
depende de `InpRejectEntry`. Nenhum dos dois passa por este enum.

**Para análise.** `BOTH` mistura populações. Separe por `setup` antes de
comparar R. Hipótese: rompimento captura o spike e o pullback o primeiro
retorno; misturar sem estratificar esconde qual perna paga.

### `InpBrkStopMode`

- **Tipo / default:** `ENUM_ICS_BSTOP` = `ICS_BSTOP_BAR`
- **Rótulo:** Stop da entrada no rompimento
- **Onde:** `Analysis/Trigger.mqh` (kind 1; hold e pullback ignoram)
- **Motivo CSV:** indireto — `stop largo` / `stop curto` / `RR insuficiente`

Valores:

| Enum | Referência do stop (depois vem `InpStopBufPts`) |
|---|---|
| `ICS_BSTOP_BAR` | extremo do candle de rompimento |
| `ICS_BSTOP_POC` | POC da zona |
| `ICS_BSTOP_ZONE` | borda oposta (lo na compra, hi na venda) |

**O que faz.** Só na entrada de rompimento. Hold usa o extremo contrário da
janela de aceitação. Pullback usa `g_s.pbExt`.

**Para análise.** `ZONE` alarga o risco e aumenta rejeição por R:R e stop
largo. Compare `risco_pts` e `fonte_alvo` entre modos no mesmo período.

### `InpBrkMaxVolMult`

- **Tipo / default:** `double` = `0`
- **Rótulo:** Volume maximo do rompimento (x normal, 0 = sem limite)
- **Onde:** `Analysis/Trigger.mqh`
- **Motivo CSV:** `rompimento climatico`

**O que faz.** Se `> 0` e `g_s.brkVolRatio` ultrapassa o teto, rejeita. **Não**
é desligado pelo Baseline (não está no bloco `if(!InpBaseline)`).

**Para análise.** `0` = filtro morto. Hipótese: rompimento climático (clímax
de volume) já gastou o movimento. Contra-argumento: volume alto no rompimento
é exatamente o fluxo que o setup pede (`InpBrkVolMult`). Coluna:
`romp_vol_x`.

---

## 3. Horários (hora do servidor)

Strings `HH:MM` viram minutos do dia em `OnInit` (`ParseHM` → `g_sessStart`,
`g_lastEntry`, `g_flat`). Horário inválido aborta com
`INIT_PARAMETERS_INCORRECT`.

`InpSessionStart` **não** define o início da coleta: `CheckDay` / `StartDay`
viram no calendário (00:00 do servidor). O parâmetro só entra na janela de
entrada.

### `InpSessionStart`

- **Tipo / default:** `string` = `"09:00"`
- **Rótulo:** Inicio do pregao
- **Onde:** `ICS_Modular.mq5` → `g_sessStart`; janela em `Trigger.mqh`
- **Motivo CSV:** `horario` (junto com `InpNoEntryFirstMin` / `InpLastEntry`)

**O que faz.** Base da janela: entrada só a partir de
`g_sessStart + InpNoEntryFirstMin`.

**Para análise.** WIN abre ~09:00 B3; confirme o relógio do servidor (UTC-3
na maior parte do ano). Não corta volume nem zona antes disso.

### `InpNoEntryFirstMin`

- **Tipo / default:** `int` = `15`
- **Rótulo:** Minutos sem entrada apos a abertura
- **Onde:** `Analysis/Trigger.mqh`
- **Motivo CSV:** `horario`

**O que faz.** Bloqueia gatilho nos primeiros N minutos após `InpSessionStart`.
Zona, absorção e rompimento ainda ocorrem.

**Para análise.** Abrir demais cedo captura leilão residual; tarde demais
perde o primeiro impulso. Hipótese a checar: R dos `horario` rejeitados nos
primeiros 15 min vs. o restante do dia.

### `InpLastEntry`

- **Tipo / default:** `string` = `"17:00"`
- **Rótulo:** Ultimo horario para entrada
- **Onde:** `Analysis/Trigger.mqh` (`mod >= g_lastEntry`)
- **Motivo CSV:** `horario`

**O que faz.** A partir deste minuto, nenhum gatilho novo. Posições abertas
seguem até `InpFlatTime`.

**Para análise.** Folga até a zeragem precisa caber em `InpTimeStopBars`.
Apertar reduz amostra da tarde — estratifique `hora_entrada`.

### `InpFlatTime`

- **Tipo / default:** `string` = `"18:15"`
- **Rótulo:** Horario de zeragem
- **Onde:** `VirtualTrades.mqh`, `RealOrders.mqh` (`ManageRealPosition`);
  `ExecuteAll` exige `mod < g_flat`
- **Motivo CSV:** — (saída: `FIM_DIA` / `horario de zeragem`)

**O que faz.** Fecha virtuais e posição real. `EndDay` (virada de data) também
fecha com `FIM_DIA`. Day trade não carrega.

**Para análise.** Muitas saídas `FIM_DIA` com MFE alto = o movimento ainda
existia. Não é falha de alvo — é corte de sessão. Compare MFE × resultado
nessas linhas.

---

## 4. Dados e volume

### `InpDeltaMode`

- **Tipo / default:** `ENUM_ICS_DELTA` = `ICS_DELTA_AUTO`
- **Rótulo:** Calculo do delta
- **Onde:** `Data/Flow.mqh` (`TickSide`); diagnóstico em `BarProcessor.mqh`
- **Motivo CSV:** —

Valores:

| Enum | Fonte |
|---|---|
| `ICS_DELTA_AUTO` | flags; sem flag, regra de cotação |
| `ICS_DELTA_FLAGS` | só `TICK_FLAG_BUY` / `TICK_FLAG_SELL` |
| `ICS_DELTA_QUOTE` | só bid/ask / variação do último |

**O que faz.** Classifica o agressor de cada negócio. Sem lado válido, delta
e filtros de fluxo mentem. `WIN$` não serve. `DataLooksBad` avisa se
`% lado agressor < 50%` (exceto no modo `QUOTE`).

**Para análise.** Antes de calibrar volume, leia o diagnóstico do Diário. Se
os ticks foram descartados, nenhum filtro de delta é interpretável.

### `InpVolDays`

- **Tipo / default:** `int` = `10`
- **Rótulo:** Dias para o volume normal por horario
- **Onde:** `ICS_Modular.mq5` (`g_volCap = clamp 1..60`); `Session.mqh` (`EndDay`)
- **Motivo CSV:** —

**O que faz.** Profundidade do buffer circular minuto-a-minuto. Não é média
móvel de barras misturando horários.

**Para análise.** Poucos dias = normal instável (um pregão atípico puxa o
referencial). Teto 60 está no `OnInit`, não no input. Valores > 60 viram 60
sem aviso no Diário.

### `InpVolMinDays`

- **Tipo / default:** `int` = `3`
- **Rótulo:** Minimo de dias (senao usa media de 20 barras)
- **Onde:** `Data/VolumeNormals.mqh` (`ComputeNormals`, `NormalVol`)
- **Motivo CSV:** —

**O que faz.** Enquanto `g_volDays < InpVolMinDays`, `g_normReady = false` e
cada barra compara com a média das últimas 20 M1 — o fallback que o projeto
evita no regime normal.

**Para análise.** Os primeiros dias de um teste (e o começo de cada carga)
operam com referencial pior. Não misture essa janela com o corpo do backtest
sem marcar. Nunca troque o perfil por MA como solução permanente.

### `InpProfileStep`

- **Tipo / default:** `int` = `50`
- **Rótulo:** Passo do Volume Profile (pontos)
- **Onde:** `VolumeProfile.mqh`, `Zone.mqh` (`ZonePoc`), `Levels.mqh`
- **Motivo CSV:** —

**O que faz.** Largura do bin do histograma do dia e do POC da zona. HVN
dentro de ±1 passo da zona atual é ignorado como alvo.

**Para análise.** WIN tick = 5; 50 pts = 10 ticks. Passo menor = mais HVNs
(alvos mais perto, R:R pior). Passo maior = alvos mais grossos. Afeta
`fonte_alvo` e rejeição por R:R, não o funil até o gatilho.

### `InpHvnFactor`

- **Tipo / default:** `double` = `1.5`
- **Rótulo:** HVN: volume >= X vezes a media dos niveis
- **Onde:** `Data/VolumeProfile.mqh` (`ProfHVN`)
- **Motivo CSV:** —

**O que faz.** Pico local vira candidato a alvo se volume ≥ fator × média
dos níveis não vazios.

**Para análise.** Fator baixo = mais obstáculos, primeiro alvo mais perto.
Não muda entrada — muda `fonte_alvo` e `rr_liquido`.

---

## 5. Contexto

Contexto (`g_ctx`): +1 se preço acima da VWAP do dia **e** VWAP subindo nas
últimas `InpCtxSlopeBars`; −1 o espelho; 0 neutro. `UpdateContext` em
`Runtime/BarProcessor.mqh`.

### `InpCtxFilter`

- **Tipo / default:** `ENUM_ICS_CTX` = `ICS_CTX_BLOCK`
- **Rótulo:** Filtro de contexto (VWAP do dia)
- **Onde:** `Analysis/Trigger.mqh`
- **Motivo CSV:** `contra o contexto` ou `sem contexto a favor`

Valores:

| Enum | Regra |
|---|---|
| `ICS_CTX_OFF` | não filtra (ainda pontua no score) |
| `ICS_CTX_BLOCK` | rejeita se `g_ctx == −dir` |
| `ICS_CTX_REQUIRE` | rejeita se `g_ctx != dir` (neutro também cai) |

**O que faz.** Vale no Baseline. Score: +15 a favor, +7 neutro, 0 contra.

**Para análise.** `REQUIRE` é bem mais rígido que `BLOCK` — mata operação em
contexto indefinido (VWAP ainda sem inclinação). Coluna `contexto`. Hipótese:
operar contra a VWAP do dia no WIN de manhã é ruído; contra-argumento: a
primeira perna institucional *cria* o contexto e o filtro chega tarde.

### `InpCtxSlopeBars`

- **Tipo / default:** `int` = `30`
- **Rótulo:** Barras M1 para inclinacao da VWAP
- **Onde:** `Runtime/BarProcessor.mqh` (`UpdateContext`)
- **Motivo CSV:** — (muda `g_ctx`, logo os motivos de contexto)

**O que faz.** Compara VWAP atual com a de N minutos atrás no mesmo dia.
Sem histórico suficiente no dia, `g_ctx` fica 0.

**Para análise.** N maior = contexto mais lento (mais neutro no começo do
pregão). Interage com `InpNoEntryFirstMin`: os dois cortam a abertura por
razões diferentes.

---

## 6. Zona institucional (M5)

A cada M5 fechado, `OnM5Close` testa janelas do **maior para o menor**
(`InpZoneMaxBars` → `InpZoneMinBars`) e fica com a primeira que passa:

1. amplitude ≤ `InpZoneMaxRangeATR` × ATR(M5)
2. ER ≤ `InpZoneMaxER`
3. volume relativo ≥ `InpZoneMinRelVol` (ignorado no Baseline)

Não atravessa dias. Não redetecta congestão já encerrada (`g_zoneMinStart`).

### `InpZoneMinBars`

- **Tipo / default:** `int` = `6`
- **Rótulo:** Minimo de barras M5
- **Onde:** `Analysis/ZoneDetector.mqh`
- **Motivo CSV:** —

**O que faz.** Janela mínima (6 M5 = 30 min). Abaixo disso não há zona.

**Para análise.** Menor = mais zonas curtas (microcongestão). Funil: “Zonas
criadas”. Se já é baixo e o funil morre depois, o problema não é este piso.

### `InpZoneMaxBars`

- **Tipo / default:** `int` = `24`
- **Rótulo:** Maximo de barras M5 analisadas
- **Onde:** `Analysis/ZoneDetector.mqh`
- **Motivo CSV:** —

**O que faz.** Teto da busca (24 M5 = 2 h). Como o laço começa no máximo, a
zona tende a ser a maior congestão que ainda qualifica.

**Para análise.** Teto maior pode engolir o impulso anterior dentro da zona
e atrasar o rompimento. Evento `ZONA_AJUSTADA` no CSV de eventos mostra
reencaixes.

### `InpZoneMaxRangeATR`

- **Tipo / default:** `double` = `2.5`
- **Rótulo:** Amplitude maxima (x ATR M5)
- **Onde:** `Analysis/ZoneDetector.mqh`
- **Motivo CSV:** —

**O que faz.** Recusa faixa larga demais para ser congestão.

**Para análise.** Afrouxar marca tendência lenta como zona. Apertar some com
zonas reais em dias voláteis. Não há motivo de rejeição de *gatilho* aqui —
o candidato nem nasce.

### `InpZoneMaxER`

- **Tipo / default:** `double` = `0.30`
- **Rótulo:** Eficiencia direcional maxima (0-1)
- **Onde:** `Analysis/ZoneDetector.mqh`
- **Motivo CSV:** —

**O que faz.** ER = `|fecha − abre| / caminho`. O ICS quer ER **baixo**
(vai-e-volta). Ver `GLOSSARY.md`.

**Para análise.** Subir o teto aceita faixa que já anda — zona vira perna.
Coluna `zona` no sinal traz `zona_barras_m5` e extremos, não o ER; ER fica
no evento de criação/ajuste.

### `InpZoneMinRelVol`

- **Tipo / default:** `double` = `1.0`
- **Rótulo:** Volume relativo minimo
- **Onde:** `Analysis/ZoneDetector.mqh`
- **Motivo CSV:** —
- **Baseline:** desligado

**O que faz.** Volume da janela / volume normal do mesmo horário ≥ X.

**Para análise.** Piso 1.0 = “pelo menos o típico daquele horário”. Apertar
reduz zonas na primeira linha do funil. Compare `zona_vol_rel` no CSV entre
completo e baseline.

### `InpZoneStaleBars`

- **Tipo / default:** `int` = `15`
- **Rótulo:** Barras M1 fora da zona sem fluxo para encerrar
- **Onde:** `Analysis/StateMachine.mqh` (`ZoneBar`)
- **Motivo CSV:** —
- **Encerramento:** `saida para cima sem fluxo` / `saida para baixo sem fluxo`

**O que faz.** Fecha fora **sem** volume+delta de rompimento. Após N barras
consecutivas no mesmo lado, a zona morre. Contador zera se voltar para dentro
(e pode marcar armadilha). **Ignorado** quando `InpRejectEntry = true`: o
watch do reteste usa `InpRejectMaxBars` no lugar deste stale.

**Para análise.** Se o funil tem muitas zonas e poucos rompimentos, parte
morreu aqui (vazamento) — só com o reteste desligado. Afrouxar deixa a zona
viva esperando fluxo; apertar mata cedo e perde rompimento atrasado.

### `InpRejectEntry`

- **Tipo / default:** `bool` = `true`
- **Rótulo:** Entrar no reteste que nao reconquista a zona
- **Onde:** `Analysis/Reject.mqh`; `StateMachine.mqh` (`ZoneBar`); `Trigger.mqh` (kind=3)
- **Motivo CSV:** os filtros do gatilho (kind=3 aplica bounce como pullback)
- **Encerramento:** `reteste sem gatilho` / `gatilho avaliado`
- **Evento:** `VAZAMENTO` → `RETESTE_FALHO` (ou `RETESTE_SEM_GATILHO`)
- **Baseline:** o vazamento **não existe** — no Baseline todo fecha-fora vira rompimento

**O que faz.** Fecha fora da zona **sem** fluxo. Em vez de matar a zona no
stale, espera o primeiro bounce rumo à borda que **não fecha de volta
dentro**. Rompeu o micro-extremo desse bounce → `EvaluateTrigger(kind=3)`.
Stop = borda rompida (`lo` na venda, `hi` na compra) + `InpStopBufPts`.
Se aparecer fluxo no meio do watch, `StartBreakout` manda — o ICS ganha.

**Para análise.** População `RETESTE_FALHO` no CSV. É o primo do gráfico
“zona vazou, bounce falhou”. Compare R com `PULLBACK` no mesmo período. Se
esta população for pior, desligue. Hipótese contrária: sem fluxo o bounce
é o começo da reconquista, não a venda.

### `InpRejectMinRetr`

- **Tipo / default:** `double` = `0.20`
- **Rótulo:** Retracao minima do bounce rumo a zona
- **Onde:** `Analysis/Reject.mqh`
- **Motivo CSV:** — (sem retração o gatilho não nasce)
- **Validação:** `(0, 1]` em `OnInit`

**O que faz.** `|extremo do vazamento − extremo do bounce| / tamanho do
vazamento` ≥ X para qualificar o bounce. Mesma ideia de `InpPbMinRetr`.

**Para análise.** Piso baixo aceita ruído e dispara cedo. Piso alto espera
o reteste mais perto da zona (a seta do gráfico) e reduz amostra.

### `InpRejectMaxBars`

- **Tipo / default:** `int` = `30`
- **Rótulo:** Prazo do watch apos o vazamento (barras)
- **Onde:** `Analysis/Reject.mqh`
- **Motivo CSV:** —
- **Encerramento:** `reteste sem gatilho`
- **Validação:** `>= 1` em `OnInit`

**O que faz.** Sem gatilho em N M1 após a primeira barra do vazamento, a
zona morre. Substitui `InpZoneStaleBars` enquanto o reteste está ligado.

**Para análise.** Funil: `reteste sem gatilho` vs. `RETESTE_FALHO`. Prazo
curto perde o bounce da imagem (~15–20 min); longo deixa zona zumbi.

### `InpTouchTolPts`

- **Tipo / default:** `double` = `10`
- **Rótulo:** Tolerancia de toque nas bordas (pontos)
- **Onde:** `StateMachine.mqh` (teste), `Zone.mqh` (`ZoneHasAbsorption`)
- **Motivo CSV:** —

**O que faz.** Teste de fundo/topo aceita toque até 10 pts além da borda.
Absorção “na zona” também usa essa folga de preço.

**Para análise.** WIN tick = 5; 10 pts = 2 ticks. Folga maior = mais
`TESTE_*` e mais `absorcao=sim` no score. Não é filtro até
`InpReqTest` / `InpReqAbsorption`.

---

## 7. Absorção e teste (M1)

Absorção: janelas de 1–3 barras com volume ≥ `InpAbsVolMult` × normal e
deslocamento ≤ `InpAbsMaxDispATR` × ATR(M1). Intervalo mínimo de 3 barras
entre eventos. `Analysis/Absorption.mqh`.

### `InpAbsVolMult`

- **Tipo / default:** `double` = `2.5`
- **Rótulo:** Absorcao: volume >= X vezes o normal
- **Onde:** `Analysis/Absorption.mqh`
- **Motivo CSV:** — (só `sem absorcao` se `InpReqAbsorption`)

**O que faz.** Barra de volume da absorção. Evento `ABSORCAO`. Score +10 se
houve absorção associada à zona (`ZoneHasAbsorption`).

**Para análise.** Detectar ≠ exigir. Com `InpReqAbsorption = false` (default)
só mexe no score e na coluna `absorcao`. Funil: linha de absorções.

### `InpAbsMaxDispATR`

- **Tipo / default:** `double` = `0.5`
- **Rótulo:** Absorcao: deslocamento <= X vezes ATR M1
- **Onde:** `Analysis/Absorption.mqh`
- **Motivo CSV:** —

**O que faz.** Preço não pode andar: volume alto + deslocamento pequeno.

**Para análise.** Afrouxar classifica impulso como absorção. Apertar some
com absorções reais em barras um pouco mais longas.

### `InpAbsLookback`

- **Tipo / default:** `int` = `15`
- **Rótulo:** Absorcao: barras antes da zona consideradas
- **Onde:** `Analysis/Zone.mqh` (`ZoneHasAbsorption`)
- **Motivo CSV:** —

**O que faz.** Aceita absorção desde `zona.t0 − N minutos` até o horário do
rompimento, com preço dentro das bordas ± `InpTouchTolPts`.

**Para análise.** Não muda a detecção — muda se aquela absorção *conta* para
a zona atual. Lookback curto perde absorção que construiu a faixa.

### `InpReqAbsorption`

- **Tipo / default:** `bool` = `false`
- **Rótulo:** Exigir absorcao
- **Onde:** `Analysis/Trigger.mqh`
- **Motivo CSV:** `sem absorcao`
- **Baseline:** desligado

**O que faz.** Rejeita o gatilho se `ZoneHasAbsorption()` é falso.

**Para análise.** Filtro caro em amostra. Meça R de `sem absorcao` vs.
executados antes de ligar. Default desligado é consciente: absorção pontua,
não veta.

### `InpTestVolMult`

- **Tipo / default:** `double` = `0.7`
- **Rótulo:** Teste: volume <= X vezes o normal
- **Onde:** `Analysis/StateMachine.mqh` (`ZoneBar`)
- **Motivo CSV:** — (só `sem teste` se `InpReqTest`)

**O que faz.** Toque na borda + fecha de volta + volume ≤ X × normal →
`TESTE_FUNDO` / `TESTE_TOPO`. Score +10. Compra usa teste de fundo; venda,
de topo.

**Para análise.** Teto mais baixo = teste mais “fraco” e mais raro. Coluna
`teste`. Eventos no CSV de eventos.

### `InpReqTest`

- **Tipo / default:** `bool` = `false`
- **Rótulo:** Exigir teste da extremidade
- **Onde:** `Analysis/Trigger.mqh`
- **Motivo CSV:** `sem teste`
- **Baseline:** desligado

**O que faz.** Exige o teste do lado da operação.

**Para análise.** Igual absorção: meça o custo do filtro na população
rejeitada antes de exigir. Muitos setups institucionais rompem sem reteste
óbvio no M1.

---

## 8. Rompimento e continuidade (M1)

### `InpBrkVolMult`

- **Tipo / default:** `double` = `1.5`
- **Rótulo:** Rompimento: volume >= X vezes o normal
- **Onde:** `StateMachine.mqh` (`ZoneBar`); peso no score em `Trigger.mqh`
- **Motivo CSV:** —
- **Baseline:** desligado (qualquer fecha-fora vira rompimento se o delta
  também for ignorado)
- **Encerramento indireto:** sem fluxo, cai em `InpZoneStaleBars`

**O que faz.** Fecha fora + volume e delta → `StartBreakout`. Sem os dois,
é vazamento. Score normaliza `(brkVolRatio − 1) / (2×mult − 1)`.

**Para análise.** Primeiro gargalo depois da zona. Funil: “Rompimentos com
fluxo”. Coluna `romp_vol_x`. Apertar demais mata o setup antes do pullback.

### `InpBrkDeltaPct`

- **Tipo / default:** `double` = `20`
- **Rótulo:** Rompimento: delta a favor >= X% do volume
- **Onde:** `StateMachine.mqh` (`ZoneBar`); score em `Trigger.mqh`
- **Motivo CSV:** —
- **Baseline:** desligado

**O que faz.** `100 * delta * dir / vol ≥ X`. Sem delta a favor não é
rompimento com fluxo.

**Para análise.** Sensível à qualidade dos ticks (`InpDeltaMode`). Coluna
`romp_delta_pct`. Se o diagnóstico de dados for ruim, calibrar isto é teatro.

### `InpAcceptBars`

- **Tipo / default:** `int` = `3`
- **Rótulo:** Aceitacao: barras observadas apos o rompimento
- **Onde:** `StateMachine.mqh` (`BreakoutBar`); validado vs. `InpAcceptMin`
- **Motivo CSV:** —

**O que faz.** Nas primeiras N barras, retorno para dentro é tolerado até
estourar `InpAcceptBars − InpAcceptMin`. Depois disso, volta = armadilha ou
`ROMPIMENTO_FALHOU`. Continuidade (`InpContMult`) só é testada após N barras.

**Para análise.** Validação: `InpAcceptMin <= InpAcceptBars`. Janela curta =
mais `ROMPIMENTO_FALHOU` / `ARMADILHA`. Interage com `InpHoldBars` (hold
pode disparar dentro ou depois dessa janela).

### `InpAcceptMin`

- **Tipo / default:** `int` = `2`
- **Rótulo:** Aceitacao: minimo de fechamentos fora da zona
- **Onde:** `StateMachine.mqh` (`BreakoutBar`)
- **Motivo CSV:** —

**O que faz.** Retornos tolerados = `AcceptBars − AcceptMin`. Com defaults
(3 e 2), um único fecha-dentro é perdoado.

**Para análise.** Igualar os dois = zero tolerância a pavio de volta.
Afrouxar (`AcceptMin` menor) deixa rompimento sujo vivo.

### `InpTrapBars`

- **Tipo / default:** `int` = `5`
- **Rótulo:** Armadilha: retorno a zona em ate X barras
- **Onde:** `StateMachine.mqh` (`ZoneBar`, `BreakoutBar`)
- **Motivo CSV:** —

**O que faz.** Volta para dentro nesse prazo → `ARMADILHA` (`sweptHigh` /
`sweptLow`). Score +10 no padrão V do lado da operação. Depois do prazo, o
mesmo retorno em `ST_BREAKOUT` vira `ROMPIMENTO_FALHOU` (sem marcar V).

**Para análise.** Funil: armadilhas vs. rompimentos falhos. Não rejeita
gatilho sozinho — só pontua. Hipótese: V prévio melhora o R; teste na
coluna `padrao_v`.

### `InpContMult`

- **Tipo / default:** `double` = `1.0`
- **Rótulo:** Continuidade: avanco >= X vezes a altura da zona
- **Onde:** `StateMachine.mqh` (`BreakoutBar`)
- **Motivo CSV:** —
- **Evento:** `DESLOCAMENTO` → `ST_IMPULSE`

**O que faz.** Avanço do extremo do impulso vs. borda rompida ≥ X × altura.
Só depois de `InpAcceptBars`.

**Para análise.** `1.0` = andou pelo menos a altura da zona. Apertar exige
spike maior e reduz pullbacks. Funil: “Deslocamentos confirmados”. Entrada
de rompimento/hold **não** espera isto — só o pullback clássico.

### `InpContBars`

- **Tipo / default:** `int` = `10`
- **Rótulo:** Continuidade: prazo em barras
- **Onde:** `StateMachine.mqh` (`BreakoutBar`)
- **Motivo CSV:** —
- **Encerramento:** `rompimento sem continuidade`

**O que faz.** Sem `InpContMult` dentro de N barras após o rompimento, a
zona morre.

**Para análise.** Prazo curto + `ContMult` alto = muitas mortes aqui. Hold
pode já ter disparado (`kind=2`) antes disso — a zona ainda existe até o
prazo ou o deslocamento.

### `InpHoldEntry`

- **Tipo / default:** `bool` = `true`
- **Rótulo:** Entrar se o rompimento se mantiver
- **Onde:** `StateMachine.mqh` (`MaybeHoldTrigger`); `Trigger.mqh` (kind=2)
- **Motivo CSV:** os filtros do gatilho (kind=2 **não** aplica volume/delta
  de trigger)

**O que faz.** Se `InpHoldBars` candles consecutivos fecham do lado certo do
nível rompido, avalia gatilho sem encerrar a zona. Fecha contra o nível →
`holdDone`, não tenta de novo. v0.18.

**Para análise.** População `ACEITACAO` no CSV. Stop = extremo contrário da
janela desde o rompimento (não `InpBrkStopMode`). Filtros
`InpTrigVolMult` / `InpTrigMinDeltaPct` não valem neste kind. Útil para
medir aceitação vs. pullback vs. rompimento na mesma zona.

### `InpHoldBars`

- **Tipo / default:** `int` = `5`
- **Rótulo:** Manter: candles sem fechar contra o nivel
- **Onde:** `StateMachine.mqh` (`MaybeHoldTrigger`); `OnInit` exige `>= 1`
- **Motivo CSV:** —

**O que faz.** `b.seq - brkSeq >= N` e nenhum fecha contra `brkLevel`.
Também é chamado em `ST_IMPULSE` — hold atrasado ainda pode disparar.

**Para análise.** N=1 ≈ entrar no primeiro candle após o rompimento se
manteve. N alto aproxima o hold do deslocamento. Validação em `OnInit`.

### `InpOriginLookback`

- **Tipo / default:** `int` = `5`
- **Rótulo:** Barras antes do rompimento para a origem do impulso
- **Onde:** `StateMachine.mqh` (`StartBreakout`)
- **Motivo CSV:** —
- **Encerramento indireto:** `impulso invalido` se a perna ficar zerada

**O que faz.** Origem = extremo oposto nas últimas N M1 (mesmo dia) antes do
rompimento. A perna `impExt − origin` mede retração e projeção do pullback.

**Para análise.** Lookback curto = perna pequena = retração percentual
inflada (mais `retracao acima do maximo`). Lookback longo pode pegar o fundo
de outra perna. Não aparece como coluna própria; muda `retracao_pct` e o
alvo `projecao do impulso`.

---

## 9. Pullback e gatilho (M1)

Retração = `|impExt − pbExt| / |impExt − origin|`. Qualifica entre
`InpPbMinRetr` e `InpPbMaxRetr`. Gatilho = fecha além do micro-extremo da
perna de pullback (`MicroExtreme`).

### `InpPbMinRetr`

- **Tipo / default:** `double` = `0.20`
- **Rótulo:** Retracao minima para pullback valido
- **Onde:** `StateMachine.mqh` (`ImpulseBar`)
- **Motivo CSV:** —

**O que faz.** Abaixo de 20% a perna ainda não é pullback (`pbQualified`
fica falso). Romper micro-extremo nesse regime não dispara.

**Para análise.** Piso baixo aceita “pullback” que é só ruído no extremo.
Funil: “pullbacks sem gatilho” só conta pullback já qualificado.

### `InpPbGoodRetr`

- **Tipo / default:** `double` = `0.50`
- **Rótulo:** Retracao saudavel (nota maxima)
- **Onde:** `Analysis/Trigger.mqh` (score)
- **Motivo CSV:** —

**O que faz.** Retracão ≤ este valor: +10 no score; acima (mas ainda
válida): +5. Não rejeita.

**Para análise.** Só mexe em `score` e, se `InpMinScore > 0`, pode vetar
indiretamente. Default de score mínimo é 0 — este parâmetro é cosmética até
você ligar o piso.

### `InpPbMaxRetr`

- **Tipo / default:** `double` = `0.90`
- **Rótulo:** Retracao maxima (acima invalida)
- **Onde:** `StateMachine.mqh` (`ImpulseBar`)
- **Motivo CSV:** —
- **Encerramento:** `retracao acima do maximo`

**O que faz.** Retracão > 90% mata a zona (quase apagou o impulso). Volta
para dentro da zona mata com `pullback aceito dentro da zona`.

**Para análise.** Teto 0.90 é folgado. Apertar (0.62, Fibonacci) reduz
gatilhos e muda o perfil de `retracao_pct` dos executados.

### `InpPbMaxBars`

- **Tipo / default:** `int` = `30`
- **Rótulo:** Duracao maxima do pullback (barras)
- **Onde:** `StateMachine.mqh` (`ImpulseBar`)
- **Motivo CSV:** —
- **Encerramento:** `pullback longo demais`

**O que faz.** Pullback que se arrasta mais de N M1 encerra a zona.

**Para análise.** 30 min é largo no WIN. Funil some “pullback sem gatilho”
quando o tempo estoura antes do micro-extremo. Hipótese: pullback longo já
não é o primeiro retorno fraco.

### `InpMaxPullbacks`

- **Tipo / default:** `int` = `1`
- **Rótulo:** Pullbacks permitidos (1 = so o primeiro)
- **Onde:** `StateMachine.mqh` (`ImpulseBar`)
- **Motivo CSV:** —
- **Encerramento:** `alem do primeiro pullback (spike channel)`

**O que faz.** Pullback qualificado que faz novo extremo **sem** ter
rompido o micro-extremo conta 1. No teto, a zona morre. É a trava contra
entrar em spike channel (ver `GLOSSARY.md`).

**Para análise.** `1` é premissa de metodologia, não detalhe fino. Subir
para 2+ muda o setup: opera continuação madura. Compare R dessa população
antes de tratar como “mais oportunidades”.

### `InpPbMaxVolRatio`

- **Tipo / default:** `double` = `0.6`
- **Rótulo:** Volume medio do pullback <= X do impulso
- **Onde:** `Analysis/Trigger.mqh` (só kind=0)
- **Motivo CSV:** `pullback com volume alto`
- **Baseline:** desligado

**O que faz.** `(pbVol/pbBars) / (impVol/impBars) > X` rejeita. Volume do
pullback **exclui** a barra de gatilho (`RecalcPullback(seq-1)`).

**Para análise.** Definição operacional de “pullback fraco”. Coluna
`pullback_vol_ratio`. Kind 1 e 2 não usam. Hipótese: volume alto no retorno
= o outro lado chegou; contra-argumento: o primeiro pullback do WIN pode ser
barulhento e ainda funcionar.

### `InpPbMaxDeltaRatio`

- **Tipo / default:** `double` = `0.5`
- **Rótulo:** Delta contrario do pullback <= X do delta do impulso
- **Onde:** `Analysis/Trigger.mqh` (só kind=0)
- **Motivo CSV:** `delta contrario forte no pullback`
- **Baseline:** desligado

**O que faz.** Se o impulso tem delta a favor, `max(0, −pbDelta) / impDelta`.
Impulso sem delta a favor → razão 99 → rejeita quase sempre (exceto
Baseline).

**Para análise.** Coluna `pullback_delta_contra`. Mesma ressalva de dados
que `InpBrkDeltaPct`. Interage com `InpOriginLookback` (muda `impDelta`).

### `InpTrigVolMult`

- **Tipo / default:** `double` = `1.0`
- **Rótulo:** Gatilho: volume >= X vezes o normal
- **Onde:** `Analysis/Trigger.mqh` (kind 0, 1 e 3; **não** kind=2)
- **Motivo CSV:** `gatilho sem volume`
- **Baseline:** desligado

**O que faz.** Volume da barra de gatilho / normal do minuto. Hold
(aceitação) ignora este filtro.

**Para análise.** Coluna `gatilho_vol_x`. Default 1.0 é piso suave. Apertar
seleciona retomada com participação; no rompimento (kind=1) empilha com
`InpBrkVolMult` na *mesma* barra.

### `InpTrigMinDeltaPct`

- **Tipo / default:** `double` = `0`
- **Rótulo:** Gatilho: delta a favor > X% do volume
- **Onde:** `Analysis/Trigger.mqh` (kind 0, 1 e 3; **não** kind=2)
- **Motivo CSV:** `gatilho sem delta`
- **Baseline:** desligado

**O que faz.** `trigDeltaPct <= X` rejeita. Default 0 = só exige delta
estritamente a favor (zero ou contra cai). Hold ignora.

**Para análise.** Coluna `gatilho_delta_pct`. `0` já filtra barra de gatilho
neutra/contrária. Subir para 20 alinha com o rompimento e reduz amostra.

---

## 10. Risco, alvo e gestão

Entrada simulada = `fecha ± InpSlipPts`. Stop = referência −/+
`InpStopBufPts`, com piso opcional `InpMinStopATR`. R:R líquido desconta
slippage extra e `InpCostPerContract`.

`TrailStop()` é **compartilhada** entre virtual e real. Mudar um lado só
quebra a premissa do estudo.

### `InpStopBufPts`

- **Tipo / default:** `double` = `10`
- **Rótulo:** Stop: pontos alem do extremo do pullback
- **Onde:** `Analysis/Trigger.mqh`
- **Motivo CSV:** indireto (`stop largo` / `stop curto` / R:R)

**O que faz.** Folga além de `pbExt` / stop do rompimento / extremo do hold.

**Para análise.** 10 pts = 2 ticks. Aumentar alarga `risco_pts` e piora R:R.
Não é o único componente do stop — veja `InpMinStopATR` e `InpBrkStopMode`.

### `InpMaxStopATR`

- **Tipo / default:** `double` = `1.5`
- **Rótulo:** Stop maximo (x ATR M5), acima descarta
- **Onde:** `Analysis/Trigger.mqh`
- **Motivo CSV:** `stop largo`

**O que faz.** Se risco > 1.5 × ATR(M5), rejeita. Vale no Baseline.

**Para análise.** Protege contra stop atrás de zona inteira (`ICS_BSTOP_ZONE`)
em dia expandido. Rejeitados aqui costumam ter MAE teórico enorme — veja
`risco_pts` vs. ATR do dia (não está no CSV; use `mae_pts` depois).

### `InpMinRR`

- **Tipo / default:** `double` = `2.0`
- **Rótulo:** R:R minimo (liquido de custos)
- **Onde:** `Analysis/Trigger.mqh` (filtro e, se `FIRST_RR`, escolha do nível)
- **Motivo CSV:** `RR insuficiente (<fonte_alvo>)`

**O que faz.** `rr = (reward − custoPts) / (risk + slip + custoPts)`. Abaixo
do piso, rejeita. Em `ICS_TGT_FIRST_RR`, níveis próximos demais são
pulados até achar um que sirva.

**Para análise.** Vale no Baseline. Fonte no motivo e na coluna `fonte_alvo`.
Hipótese: piso 2.0 joga fora bons trades de alvo perto; contra-argumento: R
médio dos rejeitados por RR diz se o piso está caro. Trailing avalia R:R na
projeção *antes* de empurrar o alvo de segurança.

### `InpTargetMode`

- **Tipo / default:** `ENUM_ICS_TARGET` = `ICS_TGT_FIRST`
- **Rótulo:** Selecao do alvo
- **Onde:** `Analysis/Trigger.mqh` + lista em `Analysis/Levels.mqh`
- **Motivo CSV:** pode mudar a fonte do `RR insuficiente`

Valores:

| Enum | Escolha |
|---|---|
| `ICS_TGT_FIRST` | primeiro obstáculo à frente (estrito) |
| `ICS_TGT_FIRST_RR` | primeiro que ainda cumpra `InpMinRR` |

**O que faz.** Candidatos: POC/VAH/VAL/máx/mín do dia anterior, extremo do
dia antes do rompimento, zonas encerradas, HVNs fora da zona atual. Sem
nível: `InpProjMult`. Com `ICS_EXIT_TRAIL`, a lista de obstáculos é esvaziada
— o modo de alvo quase não escolhe nível (só a projeção alimenta o R:R).

**Para análise.** Em trailing, este enum tem pouco efeito prático. Em alvo
fixo, `FIRST` vs. `FIRST_RR` muda `fonte_alvo` e a taxa de `RR insuficiente`.

### `InpTargetOffsetPts`

- **Tipo / default:** `double` = `5`
- **Rótulo:** Alvo: pontos antes do nivel
- **Onde:** `Analysis/Trigger.mqh`
- **Motivo CSV:** —

**O que faz.** TP = nível − dir × 5 (1 tick). Antecipa o obstáculo.

**Para análise.** Irrelevante na projeção pura e no trailing (alvo de
segurança). Em `ICS_EXIT_FIXED`, evita fill no HVN onde o livro vira.

### `InpProjMult`

- **Tipo / default:** `double` = `1.0`
- **Rótulo:** Alvo sem nivel: projecao do impulso (x)
- **Onde:** `Analysis/Trigger.mqh`
- **Motivo CSV:** `RR insuficiente (projecao do impulso|da zona …)`

**O que faz.** Sem obstáculo à frente: pullback projeta `InpProjMult × perna`
a partir de `pbExt`; rompimento/hold projeta `× altura da zona` a partir do
fecha.

**Para análise.** Fallback frequente nos primeiros trades do dia (ainda sem
perfil anterior / HVN). Coluna `fonte_alvo`. Multiplicador baixo + `MinRR`
alto = rejeição sistemática de manhã.

### `InpMinScore`

- **Tipo / default:** `double` = `0`
- **Rótulo:** Score minimo (0 = registrar todos)
- **Onde:** `Analysis/Trigger.mqh`
- **Motivo CSV:** `score baixo`

**O que faz.** Score 0–100 (contexto, absorção, teste, V, volume/delta do
rompimento, qualidade do pullback, gatilho, R:R). `0` = nunca rejeita por
nota; todos os gatilhos entram no CSV.

**Para análise.** Mantenha 0 enquanto estuda filtros individuais. Ligar o
piso *antes* de entender os componentes mistura causas. Coluna `score`.

### `InpSlipPts`

- **Tipo / default:** `double` = `5`
- **Rótulo:** Slippage estimado (pontos por execucao)
- **Onde:** `Trigger.mqh` (entrada e `riskEff`); `VirtualTrades.mqh` (saídas);
  `ICS_Modular.mq5` (`SetDeviationInPoints = 2×`)
- **Motivo CSV:** indireto (piora R:R)

**O que faz.** Entrada conservadora no sentido do trade; saídas de stop /
reversão / tempo / fim do dia também descontam. Toque stop+alvo no mesmo
minuto assume **stop** (premissa conservadora).

**Para análise.** 5 pts = 1 tick. Inflar slippage piora `rr_liquido` e aumenta
`RR insuficiente` sem mudar o gráfico. Use o valor que você realmente toma.

### `InpCostPerContract`

- **Tipo / default:** `double` = `0.50`
- **Rótulo:** Custo por contrato ida+volta (R$)
- **Onde:** `Trigger.mqh` (`riskEff`, `rr`); `VirtualTrades.mqh` (`resultado_brl`)
- **Motivo CSV:** indireto (R:R)

**O que faz.** Corretagem+emolumentos por contrato, ida e volta. Convertido
em pontos via `g_pointValue`.

**Para análise.** Atualize quando a corretora mudar. Subestimar custo deixa
R:R otimista e `resultado_brl` inchado. Não afeta R bruto (`resultado_R` usa
pontos / risco, sem custo — o custo já entrou no *filtro* de RR, não na
coluna R). Fato: `r = pts / risk` em `CloseVirtual`; custo só no BRL e no
`rr` de entrada.

### `InpMinStopATR`

- **Tipo / default:** `double` = `0.5`
- **Rótulo:** Stop minimo (x ATR M5, 0 = sem minimo)
- **Onde:** `Analysis/Trigger.mqh`
- **Motivo CSV:** — (alarga o stop; pode causar `RR insuficiente`)

**O que faz.** Se risco < X × ATR(M5), empurra o stop para longe. `0` desliga.
Depois ainda existe rejeição dura `stop curto` se risco < 2 ticks.

**Para análise.** Evita stop dentro do ruído do WIN. Efeito colateral: piora
R:R de pullbacks rasos. Não confundir com `InpMaxStopATR` (teto que rejeita).

### `InpExitMode`

- **Tipo / default:** `ENUM_ICS_EXIT` = `ICS_EXIT_TRAIL`
- **Rótulo:** Gestao da saida
- **Onde:** `Trigger.mqh`, `VirtualTrades.mqh` (`TrailStop`), `RealOrders.mqh`
- **Motivo CSV:** — (saídas: `ALVO`, `TRAILING`, `ZERO_A_ZERO`)

Valores:

| Enum | Gestão |
|---|---|
| `ICS_EXIT_FIXED` | alvo no obstáculo; `TrailStop` não move |
| `ICS_EXIT_TRAIL` | sem alvo no obstáculo; BE + trail; TP de segurança `InpTrailTpMult` |

**O que faz.** Overlay `InpReversalExit` vale nos dois modos.

**Para análise.** Não compare R de um teste FIXED com outro TRAIL como se
fossem o mesmo sistema. MAE/MFE importam mais no trail (quanto o movimento
deu vs. quanto o trail devolveu).

### `InpBEAtR`

- **Tipo / default:** `double` = `1.0`
- **Rótulo:** Trailing: stop no zero-a-zero apos X R
- **Onde:** `VirtualTrades.mqh` (`TrailStop`) — só se `ICS_EXIT_TRAIL`
- **Motivo CSV:** — (saída `ZERO_A_ZERO` se o BE for tocado)

**O que faz.** Favorável ≥ X × risco → stop em entrada + 1 tick. Liga
`be = true`, o que **desliga** o stop de tempo.

**Para análise.** BE cedo transforma ganhadores em zeros e reduz `TEMPO`.
Hipótese: 1R é cedo demais no WIN e o ruído estopa no zero; veja frequência
de `ZERO_A_ZERO` vs. MFE dessas linhas.

### `InpTrailStartR`

- **Tipo / default:** `double` = `1.5`
- **Rótulo:** Trailing: comecar a seguir apos X R
- **Onde:** `VirtualTrades.mqh` (`TrailStop`)
- **Motivo CSV:** — (saída `TRAILING`)

**O que faz.** A partir de X R favorável, stop = extremo favorável −
`InpTrailATR` × ATR(M5), só para o lado do lucro.

**Para análise.** Deve ser ≥ `InpBEAtR` na prática (senão o BE já moveu e o
trail só aperta depois). Se `TrailStartR < BEAtR`, o trail pode começar
antes do zero a zero — o código permite.

### `InpTrailATR`

- **Tipo / default:** `double` = `1.0`
- **Rótulo:** Trailing: distancia (x ATR M5)
- **Onde:** `Trigger.mqh` (grava `g_vt.trail`); `TrailStop`; `SendOrder`
- **Motivo CSV:** —

**O que faz.** Distância do extremo. ATR é o da **entrada** (não recalcula
a cada barra).

**Para análise.** Folga maior = menos `TRAILING` prematuro, mais devolução
de MFE. Simétrico no real (`g_realTrail`).

### `InpTrailTpMult`

- **Tipo / default:** `double` = `3.0`
- **Rótulo:** Trailing: alvo de seguranca (x projecao)
- **Onde:** `Analysis/Trigger.mqh` (só `ICS_EXIT_TRAIL`)
- **Motivo CSV:** —

**O que faz.** TP da ordem = entrada + dir × reward × max(mult, 1). O R:R
do filtro continua o da projeção/obstáculo original. Teto de segurança para
o corretor, não o alvo metodológico.

**Para análise.** Saídas `ALVO` no modo trail são raras (alvo muito longe).
Se aparecerem muito, a projeção está curta ou o mult está baixo. Piso
interno é 1.0.

### `InpTimeStopBars`

- **Tipo / default:** `int` = `30`
- **Rótulo:** Stop de tempo (barras)
- **Onde:** `VirtualTrades.mqh`, `RealOrders.mqh`
- **Motivo CSV:** — (saída `TEMPO`)
- **Desenho:** linhas de entrada/stop/alvo duram N minutos

**O que faz.** Após N barras, se lucro < `InpTimeStopMinR` **e** o BE ainda
não armou, sai. Real usa minutos desde `POSITION_TIME`, não `g_vt.bars`.

**Para análise.** Capital parado. Muitas saídas `TEMPO` com MFE > 1R = o
preço foi e voltou — o tempo não é o vilão, o retorno é. BE desliga este
stop de propósito.

### `InpTimeStopMinR`

- **Tipo / default:** `double` = `0.5`
- **Rótulo:** Stop de tempo: sai se lucro < X R
- **Onde:** `VirtualTrades.mqh`, `RealOrders.mqh`
- **Motivo CSV:** — (saída `TEMPO`)

**O que faz.** Só sai por tempo se o lucro atual (fecha vs. entrada) < X R.
Trade que já fez 0.5R+ fica vivo (até trail, alvo, reversão ou zeragem).

**Para análise.** Subir para 1.0 mata mais “quase lá”. Descer para 0 só sai
se estiver negativo ou zerado após N barras.

### `InpReversalExit`

- **Tipo / default:** `bool` = `true`
- **Rótulo:** Saida por reversao (desespero + corpo cheio)
- **Onde:** `VirtualTrades.mqh` (`ReversalExitSignal`); `RealOrders.mqh`
- **Motivo CSV:** — (saída `REVERSAO`)

**O que faz.** Overlay nos dois modos de saída. Barra anterior: pavio
contrário ≥ `InpDespWickMult` × corpo. Barra atual: corpo ≥
`InpFullBodyFrac` da amplitude **e** fecha contra a posição.

**Para análise.** Não espera o trail. Falso positivo = estopar tendência
num pavio. Compare `REVERSAO` vs. MFE: se MFE já era grande, o trail talvez
bastasse; se MAE explode no mesmo minuto, a reversão salvou.

### `InpDespWickMult`

- **Tipo / default:** `double` = `2.0`
- **Rótulo:** Desespero: pavio >= X vezes o corpo
- **Onde:** `VirtualTrades.mqh` (`ReversalExitSignal`); `OnInit` exige `> 0`
- **Motivo CSV:** —

**O que faz.** Primeira perna do sinal de reversão (pavio de rejeição).

**Para análise.** Mult maior = menos sinais (só pavio extremo). Corpo da
barra de desespero precisa ser ≥ 1 tick.

### `InpFullBodyFrac`

- **Tipo / default:** `double` = `0.60`
- **Rótulo:** Corpo cheio: corpo >= X da amplitude
- **Onde:** `VirtualTrades.mqh`; `OnInit` exige `0 < x <= 1`
- **Motivo CSV:** —

**O que faz.** Segunda perna: candle seguinte “cheio” contra a posição.

**Para análise.** 0.60 = corpo domina 60% do range. Apertar (0.8) exige
marubozu; afrouxar pega doji com fechamento contra.

### `InpMaxTradesDay`

- **Tipo / default:** `int` = `3`
- **Rótulo:** Maximo de operacoes por dia
- **Onde:** `Analysis/Trigger.mqh`; incrementa só se `taken`; zera em `StartDay`
- **Motivo CSV:** `limite de operacoes do dia`

**O que faz.** Conta `EXECUTADO`, não rejeitado nem `ESTUDO_EXECUTADO`.
Virtuais rejeitadas continuam nascendo para o CSV.

**Para análise.** Vale no Baseline. Os rejeitados *depois* do limite ainda
aparecem — úteis para ver o que o teto deixou na mesa. `HasOpenTrade` já
impede sobreposição; o teto é extra.

### `InpMaxLossesDay`

- **Tipo / default:** `int` = `2`
- **Rótulo:** Para apos X perdas no dia
- **Onde:** `Trigger.mqh`; incrementa em `CloseVirtual` se `taken` e `pts < 0`
- **Motivo CSV:** `limite de perdas do dia`

**O que faz.** Perda = resultado em pontos < 0 de operação *tomada*
(inclui `ZERO_A_ZERO`? não — `pts` no BE de +1 tick é ≥ 0). `TEMPO` /
`REVERSAO` / `FIM_DIA` negativos contam.

**Para análise.** Não conta rejeitado virtual que teria perdido. `ERRO_ORDEM`
não incrementa. Dois stops reais no dia calam as entradas seguintes; o CSV
ainda registra os gatilhos com este motivo.

### `InpMaxLossDayBRL`

- **Tipo / default:** `double` = `0`
- **Rótulo:** Prejuizo maximo do dia (R$, 0 = off)
- **Onde:** `Core/Utils.mqh` (`DayPnlBRL`, `DailyLossBreached`);
  `Execution/RealOrders.mqh` (`EnforceDailyLossLimit`); `Analysis/Trigger.mqh`;
  `ICS_Modular.mq5` (`OnTick`, `OnInit`)
- **Motivo CSV:** `limite de prejuizo do dia`
- **Saída real:** `CLOSE` com o mesmo texto se houver posição aberta

**O que faz.** `0` desliga. Caso contrário, compara
`AccountEquity − g_dayStartEquity` com `−InpMaxLossDayBRL`. O snapshot de
equity é feito no `OnInit` (depois do replay) e de novo em cada `StartDay`
fora de replay. Estourou: `g_dayLossHalt` fica verdadeiro até o próximo
`StartDay`, novas entradas são rejeitadas e a posição real é zerada **no
tick** (não espera o M1 fechar). `InpExecuteAll` também respeita o teto.

É o PnL **da conta**, não só do mágico — qualquer outro débito no mesmo
login conta. Depósito no meio do dia afasta o teto; saque aproxima.

**Para análise.** Vale no Baseline. Não é filtro de setup: é orçamento.
Rejeitados com este motivo ainda viram virtual. Folga intra-barra ainda
existe (slip / gap até o `PositionClose` retornar). A rede da corretora
precisa ficar **acima** deste valor. Default `0` deixa o backtest antigo
igual.

---

## Validações em `OnInit`

[`ICS_Modular.mq5`](../ICS_Modular.mq5) recusa o EA com
`INIT_PARAMETERS_INCORRECT` se:

| Condição | Mensagem |
|---|---|
| `InpSessionStart` / `InpLastEntry` / `InpFlatTime` inválidos | Horario invalido nos parametros (use HH:MM) |
| `InpAcceptMin > InpAcceptBars` | Aceitacao: o minimo nao pode ser maior que o numero de barras |
| `InpHoldBars < 1` | Manter: o numero de candles deve ser >= 1 |
| `InpRejectMaxBars < 1` | Reteste falho: o prazo em barras deve ser >= 1 |
| `InpRejectMinRetr` fora de `(0, 1]` | Reteste falho: a retracao minima deve estar em (0, 1] |
| `InpDespWickMult <= 0` ou `InpFullBodyFrac` fora de `(0, 1]` | Reversao: pavio/corpo deve ser > 0 e a fracao de corpo cheio entre 0 e 1 |
| `InpMaxLossDayBRL < 0` | Prejuizo maximo do dia nao pode ser negativo (0 = desligado) |

Aviso (não aborta): símbolo com `WIN$` no nome.

Outros limites silenciosos:

- `InpVolDays` é limitado a 1..60 em `g_volCap`
- `InpTrailTpMult` efetivo é `max(valor, 1.0)`
- `InpMinStopATR = 0` desliga o piso de stop
- `InpBrkMaxVolMult = 0` desliga o teto climático
- `InpMinScore = 0` desliga o piso de score
- `InpMaxLossDayBRL = 0` desliga o teto de prejuízo em R$

Não há validação de `InpZoneMinBars <= InpZoneMaxBars` nem de
`InpPbMinRetr <= InpPbGoodRetr <= InpPbMaxRetr`. Combinação invertida
compila e produz comportamento degenerado — trate como erro de preset.

---

## Motivos de rejeição (coluna `motivos`)

Ordem em que `AddReason` acrescenta (vários podem coexistir):

| Motivo | Parâmetro / condição |
|---|---|
| `reprocessamento` | `g_replay` (carga de histórico) |
| `posicao aberta` | `HasOpenTrade()` |
| `horario` | `InpSessionStart` + `InpNoEntryFirstMin` / `InpLastEntry` |
| `limite de operacoes do dia` | `InpMaxTradesDay` |
| `limite de perdas do dia` | `InpMaxLossesDay` |
| `limite de prejuizo do dia` | `InpMaxLossDayBRL` |
| `contra o contexto` | `InpCtxFilter = BLOCK` |
| `sem contexto a favor` | `InpCtxFilter = REQUIRE` |
| `rompimento climatico` | `InpBrkMaxVolMult` |
| `pullback com volume alto` | `InpPbMaxVolRatio` (não Baseline; só pullback) |
| `delta contrario forte no pullback` | `InpPbMaxDeltaRatio` (idem) |
| `gatilho sem volume` | `InpTrigVolMult` (não hold; não Baseline) |
| `gatilho sem delta` | `InpTrigMinDeltaPct` (não hold; não Baseline) |
| `sem absorcao` | `InpReqAbsorption` (não Baseline) |
| `sem teste` | `InpReqTest` (não Baseline) |
| `stop largo` | `InpMaxStopATR` |
| `stop curto` | risco < 2 ticks (sem input) |
| `RR insuficiente (...)` | `InpMinRR` |
| `score baixo` | `InpMinScore` |
| `falha no envio da ordem` | status `ERRO_ORDEM` (substitui os outros) |

---

## Manutenção

Ao criar, renomear ou mudar o significado de um `input`:

1. `Config/Inputs.mqh` no grupo certo, rótulo para quem opera
2. Validação em `OnInit` se puder invalidar outro
3. Se for volume/fluxo, respeitar `InpBaseline`
4. Atualizar **esta ficha** na mesma mudança (default, onde, motivo CSV,
   nota de análise). A regra `000-projeto` trata entrega sem ficha como
   trabalho incompleto.
5. Se mudar modo de operação, uma linha no `README.md`

Não declare `input` fora de `Inputs.mqh` — a ordem dos grupos é a ordem da
janela do MetaTrader.

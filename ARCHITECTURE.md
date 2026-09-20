# ICS_Modular — Arquitetura

> **Este arquivo é o contexto do projeto.** Ao pedir ajuda em um módulo isolado,
> cole este arquivo + o `.mqh` em questão. Isso dá todo o contexto necessário sem
> precisar colar as ~2000 linhas do EA inteiro.

---

## 1. Como o MQL5 compila este projeto

MQL5 **não tem linker**. `#include` é inclusão textual do pré-processador: os 24
arquivos viram **uma única unidade de compilação** e um único `.ex5`.

Consequências que governam todo o desenho abaixo:

| Fato | Consequência prática |
|---|---|
| Inclusão é textual | A ordem em `ICS_Modular.mq5` importa |
| Não há compilação separada | Compile sempre `ICS_Modular.mq5` (F7), nunca um `.mqh` |
| Variável global precisa existir antes do uso | `Core/Globals.mqh` vem antes de tudo |
| Funções globais podem ser chamadas antes de definidas | Ainda assim usamos `Core/Prototypes.mqh` para documentar o acoplamento |
| Dependência circular não existe | A hierarquia é estritamente em camadas |

Todo `.mqh` tem include guard (`#ifndef __ICSM_<NOME>_MQH__`).

---

## 2. Camadas

Cada camada só pode usar o que está **acima** dela. Nunca o contrário.

```
camada 0  Config/      contratos de dados e parâmetros    (não depende de nada)
camada 1  Core/        estado global + utilitários puros
camada 2  Data/        leitura e derivação de dados de mercado
camada 3  UI/ Exec/    saída: desenho e arquivos
camada 4  Data/        construção de barras
camada 5  Execution/   ordens virtuais e reais
camada 6  Analysis/    a inteligência do setup
camada 7  Runtime/     orquestração
          ICS_Modular.mq5   eventos do MetaTrader
```

---

## 3. Mapa dos módulos

### Config/ — camada 0

| Arquivo | Responsabilidade | Mexer quando |
|---|---|---|
| `Defines.mqh` | `PROF_SIZE`, estados `ST_*`, enums de parâmetro, structs `IcsBar` `IcsZone` `IcsSetup` `IcsAbs` `IcsVTrade` | acrescentar um campo novo a uma struct |
| `Inputs.mqh` | todos os `input`, agrupados | acrescentar/renomear um parâmetro |

> A ordem dos grupos em `Inputs.mqh` é a ordem exibida na janela de propriedades
> do MetaTrader. Manter tudo centralizado aqui é o que dá esse controle.

### Core/ — camada 1

| Arquivo | Responsabilidade |
|---|---|
| `Globals.mqh` | todo o estado compartilhado (prefixo `g_`) + `CTrade` |
| `Prototypes.mqh` | declarações antecipadas dos 10 pontos de acoplamento cruzado |
| `Utils.mqh` | `DayStart` `MinOfDay` `Clamp01` `RoundDn/Up` `TS` `B` `F` `ParseHM` `AddReason` `IdxOf` `WriteLine` `OrdersAllowed` `ATRArr` |
| `Stats.mqh` | `CountIn` `CountOf` `CountReasons` — contadores nomeados |

### Data/ — camadas 2 e 4

| Arquivo | Responsabilidade | Funções públicas |
|---|---|---|
| `VolumeNormals.mqh` | volume "normal" por minuto do dia, dos últimos N dias | `ComputeNormals` `NormalVol` `NormalVol5` |
| `VolumeProfile.mqh` | histograma do dia, POC, Value Area 70%, HVNs | `ProfReset` `ProfAdd` `ProfAddRange` `ProfValueArea` `ProfHVN` |
| `Flow.mqh` | lado agressor de cada negócio (delta) | `QuoteSide` `TickSide` |
| `BarBuilder.mqh` | monta M1 com fluxo, agrega M5 | `FillFromRates` `LoadBarTicks` `UpdateM5` `PushM5` |

### UI/ — camadas 3 e 7

| Arquivo | Responsabilidade |
|---|---|
| `Draw.mqh` | `DrawMark` `DrawLevel` `DrawZone` — objetos com prefixo `ICSM_` |
| `Panel.mqh` | `UpdatePanel` — o `Comment` no canto do gráfico |

### Execution/ — camadas 3 e 5

| Arquivo | Responsabilidade | Funções públicas |
|---|---|---|
| `Logger.mqh` | abre os CSV, registra eventos do setup | `OpenFiles` `LogEvent` |
| `VirtualTrades.mqh` | operações simuladas (executadas **e** rejeitadas) | `CloseVirtual` `CloseAllVirtual` `TrailStop` `ReversalExitSignal` `UpdateVirtualTrades` |
| `RealOrders.mqh` | posição real no MetaTrader | `HasRealPosition` `HasOpenTrade` `SendOrder` `CloseRealPosition` `ManageRealPosition` |

### Analysis/ — camada 6 (o núcleo do setup)

| Arquivo | Responsabilidade | Mexer quando |
|---|---|---|
| **`ZoneDetector.mqh`** | **marcação da área** no M5 | mudar como a zona institucional é identificada |
| `Zone.mqh` | ciclo de vida da zona: POC próprio, encerramento, consulta de absorção | mudar quando a zona morre ou como o POC dela é calculado |
| `Absorption.mqh` | detecção de absorção no M1 | mudar a definição operacional de absorção |
| `Levels.mqh` | níveis candidatos a alvo | acrescentar um tipo novo de obstáculo |
| `StateMachine.mqh` | rompimento → aceitação → impulso → pullback → gatilho | mudar a sequência de confirmação |
| **`Reject.mqh`** | vazamento sem fluxo → bounce que não reconquista | mudar o reteste falho (kind=3) |
| **`Trigger.mqh`** | entrada, stop, alvo, score, filtros, registro | mudar critérios de entrada, pesos do score, regras de risco |

### Runtime/ — camada 7

| Arquivo | Responsabilidade | Funções públicas |
|---|---|---|
| `Session.mqh` | abertura/encerramento do pregão, virada de dia | `StartDay` `EndDay` `CheckDay` |
| `BarProcessor.mqh` | pipeline por barra, carga de histórico, diagnóstico de dados | `UpdateContext` `ProcessBar` `ProcessPending` `LoadHistory` `DataLooksBad` `PrintDataDiag` |
| `Summary.mqh` | funil e resumo estatístico | `PrintFunnel` `PrintSummary` |

---

## 4. Os 10 pontos de acoplamento cruzado

Declarados em `Core/Prototypes.mqh`. São as únicas chamadas que apontam "para
frente" na ordem de include:

```
StateMachine.mqh  →  EvaluateTrigger()    (Analysis/Trigger.mqh)
StateMachine.mqh  →  UpdateRejectWatch()  (Analysis/Reject.mqh)
StateMachine.mqh  →  CancelRejectWatch()  (Analysis/Reject.mqh)
Zone.mqh          →  LogEvent()           (Execution/Logger.mqh)
Zone.mqh          →  DrawZone()           (UI/Draw.mqh)
Zone.mqh          →  CountIn()            (Core/Stats.mqh)
Session.mqh       →  CloseAllVirtual()    (Execution/VirtualTrades.mqh)
Session.mqh       →  CloseRealPosition()  (Execution/RealOrders.mqh)
Session.mqh       →  RetireZone()         (Analysis/Zone.mqh)
BarProcessor.mqh  →  OnM5Close()          (Analysis/ZoneDetector.mqh)
```

**Se você criar uma chamada nova entre módulos, acrescente o protótipo lá.**

---

## 5. A ordem de execução por barra M1

Definida em `ProcessBar()` (`Runtime/BarProcessor.mqh`). Mudar essa ordem muda o
comportamento do EA:

```
1. máxima/mínima/VWAP do dia + volume por minuto
2. numera a barra (seq) e guarda em g_m1
3. agrega no M5
   ── daqui em diante, só quando live = true ──
4. UpdateContext        contexto pela VWAP
5. UpdateVirtualTrades  avança as operações simuladas
6. ManageRealPosition   breakeven / trailing / stop de tempo
7. DetectAbsorption     registra absorção
8. RunStateMachine      ZoneBar / BreakoutBar / ImpulseBar
9. OnM5Close            redetecta a zona (só se um M5 fechou)
10. UpdatePanel
```

`live = false` durante `LoadHistory()`: as barras alimentam os acumuladores mas
não geram sinais.

---

## 6. Máquina de estados

```
                  ZoneDetector achou congestão
      ST_IDLE ──────────────────────────────────► ST_ZONE
         ▲                                            │
         │                 ┌── vazamento sem fluxo ──► kind=3 RETESTE_FALHO
         │                 │
         │                 │ fechou fora COM volume e delta
         │                 ▼
         │                                       ST_BREAKOUT
         │                                            │
         │                                            │ InpHoldEntry: X candles
         │                                            │ sem fechar contra o nível
         │                                            │ → EvaluateTrigger(kind=2)
         │                                            │   (não encerra a zona)
         │                                            │
         │  RetireZone()                              │ avançou
         │  (qualquer estado)                         │ InpContMult × altura
         │                                            ▼
         └────────────────────────────────────── ST_IMPULSE
                                                      │
                                       pullback qualificado
                                       + retomada do micro-extremo
                                                      ▼
                                              EvaluateTrigger(kind=0)
```

Quatro gatilhos, populações separadas no CSV (`PULLBACK` / `ROMPIMENTO` /
`ACEITACAO` / `RETESTE_FALHO`):

- `kind=1` no candle do rompimento (`InpEntryMode`)
- `kind=2` após `InpHoldBars` fechamentos sem cruzar `brkLevel` (`InpHoldEntry`)
- `kind=0` no pullback clássico
- `kind=3` no reteste falho após vazamento (`InpRejectEntry`)

Transições de volta para `ST_ZONE`: rompimento devolvido dentro do prazo
(armadilha) ou rompimento falho. Fechar contra `brkLevel` invalida o hold.

---

## 7. O princípio do estudo

**Todo gatilho avaliado vira uma operação simulada, executado ou rejeitado.** As
rejeitadas continuam sendo acompanhadas até o desfecho.

É isso que permite responder, no CSV, à pergunta que importa: *este filtro está
me protegendo ou me custando dinheiro?* Se a população de REJEITADOS tiver R
médio parecido ou melhor que a de EXECUTADOS, o filtro está errado.

Implementado em `Execution/VirtualTrades.mqh` + o registro em
`Analysis/Trigger.mqh`, que **nunca aborta** — mesmo rejeitando, monta e grava a
operação virtual.

---

## 8. Saídas

Pasta comum do MetaTrader (`Common\Files`), o que permite abrir no Excel com o
teste ainda rodando:

| Arquivo | Conteúdo |
|---|---|
| `ICS_Modular_sinais_<símbolo>_<modo>.csv` | uma linha por gatilho, 37 colunas, do contexto ao resultado em R$ |
| `ICS_Modular_eventos_<símbolo>_<modo>.csv` | trilha do setup: zonas, absorções, testes, armadilhas, rompimentos |

`<modo>` é `completo` ou `baseline`, mais o `InpRunTag` se preenchido.

---

## 9. Convenções

- `g_` prefixa toda variável global
- `Inp` prefixa todo parâmetro de entrada
- `ST_` prefixa estado da máquina
- `ICSM_` prefixa todo objeto gráfico
- Include guard: `__ICSM_<NOME>_MQH__`
- Código e comentários sem acentuação (compatibilidade com o MetaEditor)
- Cabeçalho de cada `.mqh` declara **do que ele depende**

---

## 10. Próximos passos naturais de modularização

`Analysis/StateMachine.mqh` é o maior arquivo (335 linhas, ~250 de código). Se
crescer mais, o corte natural é por estado:

```
Analysis/States/ZoneState.mqh       ZoneBar
Analysis/States/BreakoutState.mqh   BreakoutBar
Analysis/States/ImpulseState.mqh    ImpulseBar + PullbackTrigger
Analysis/StateMachine.mqh           RecalcImpulse, RecalcPullback,
                                    MicroExtreme, StartBreakout,
                                    RunStateMachine
```

Meta: manter cada módulo entre 150 e 300 linhas.

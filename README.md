# ICS_Modular — Institutional Continuation Setup

Expert Advisor para MetaTrader 5, mini índice (WIN), gráfico M1.

**v1.213** — regra de versão: mudança de regra do projeto ou de comportamento
do EA sobe `ICSM_VERSION` na mesma alteração.

**v1.212** — parcial do trilho em conta netting. Cada fatia sai como ordem
oposta de `InpLots / 3` (compra de 3 vira três vendas de 1, e o inverso).

**v1.211** — trilho de saída em três fatias (`InpTrilhoSaida`, default
desligado). Branch `v1.211-trilho-saida`, fora do main até o teste.

**v1.210** — teto de prejuízo do dia em R$ (`InpMaxLossDayBRL`). Default `0`
(desligado). Estourou: sem entrada nova e zera a posição real no tick.
Preset ao vivo: `presets/ICS_Modular_v1210-live-winv26.set.example`.
A 1.200 era a governança live × Testador.

---

## Instalação

1. No MetaEditor: **Arquivo → Abrir pasta de dados**
2. Copie a pasta `ICS_Modular` inteira para `MQL5\Experts\`

```
MQL5\Experts\ICS_Modular\
├── ICS_Modular.mq5          ← compile ESTE arquivo (F7)
├── ARCHITECTURE.md
├── README.md
├── Config\
├── Core\
├── Data\
├── UI\
├── Execution\
├── Analysis\
└── Runtime\
```

3. Abra `ICS_Modular.mq5` e compile com **F7**

> **Compile sempre o `.mq5`.** Abrir um `.mqh` e apertar F7 só faz checagem de
> sintaxe — não gera o `.ex5`. Isso é esperado: MQL5 não tem compilação separada
> por módulo.

---

## Convivência com o `ICS_EA` antigo

Este EA foi renomeado para conviver com a versão monolítica sem colisão. O nome
do arquivo é só uma das **quatro identidades** que precisavam mudar:

| Identidade | `ICS_EA` (antigo) | `ICS_Modular` (este) | O que colidia |
|---|---|---|---|
| Arquivo / pasta | `ICS_EA.mq5` | `ICS_Modular.mq5` | duas entradas iguais no Navegador |
| Número mágico | `26091601` | `20260918` | **os dois EAs disputariam a mesma posição** |
| Prefixo do CSV | `ICS_sinais_*` | `ICS_Modular_sinais_*` | escrita simultânea no mesmo arquivo |
| Objetos do gráfico | `ICS_Z*`, `ICS_M*` | `ICSM_Z*`, `ICSM_M*` | um apagaria os desenhos do outro |

O número mágico é o mais perigoso dos quatro. É por ele que o EA reconhece a
posição como sua — em `HasRealPosition`, `ManageRealPosition` e
`CloseRealPosition`. Com os dois rodando ao vivo no mesmo símbolo e o mesmo
mágico, cada um enxergaria a posição do outro como própria e tentaria gerenciá-la:
trailing concorrente, zeragem cruzada, stop sobrescrito.

**Não rode os dois ao mesmo tempo no mesmo símbolo**, mesmo com identidades
separadas. O filtro `HasOpenTrade()` só enxerga as operações do próprio EA, então
você acabaria com duas posições abertas simultâneas e risco dobrado sem perceber.

O comentário da ordem é `ICS|{id}` (id do sinal no CSV). Junto com o mágico,
deixa a posição distinguível na aba Negociação e junta com `ordens.csv`.

---

## Antes de rodar: os dados

O setup inteiro depende de **delta** (lado agressor de cada negócio). Sem dados
de fluxo válidos, os resultados não significam nada.

- **Não use `WIN$`** — o contínuo não tem lado agressor nem bid/ask. O EA avisa.
- Use o contrato cheio (`WINV26`, `WINZ26`…) ou o símbolo arquivado `WIN_ICS`.
- No testador, se aparecer `real ticks discarded` no Diário, os ticks reais foram
  descartados e o delta ficou inválido.

O EA imprime um diagnóstico automático:

```
Dados: 12480 barras | 98.2% com negócios | 1847221 negócios |
       91.4% com lado agressor | 0.1% sem volume
```

Se `% com lado agressor` estiver abaixo de 50%, o aviso aparece sozinho.

---

## Modos de uso

### Estudo (recomendado para começar)

| Parâmetro | Valor |
|---|---|
| `InpTradeEnabled` | `true` |
| `InpLiveOrders` | `false` |
| `InpBaseline` | `false` |

Rode no testador. Todos os gatilhos, executados e rejeitados, vão para o CSV.

### Baseline (medir o valor dos filtros)

Rode o mesmo período com `InpBaseline = true`. Isso desliga os filtros de volume
e fluxo. Compare os dois CSV: se o baseline for igual ou melhor, os filtros não
estão agregando.

### Ao vivo

Requer **as duas** travas abertas:

| Parâmetro | Valor |
|---|---|
| `InpTradeEnabled` | `true` |
| `InpLiveOrders` | `true` |
| `InpMaxLossDayBRL` | orçamento do dia em R$ (`0` = off) |

Com `InpLiveOrders = false` o EA roda normalmente mas só emite alertas — nenhuma
ordem é enviada. É proposital.

O teto em R$ mede a **equity da conta** desde o snapshot do dia, não o P&L
virtual. Folga intra-barra até o `PositionClose` voltar ainda existe — a
rede da corretora precisa ficar acima do valor do input.

---

## Onde saem os resultados

Pasta comum do MetaTrader (`Common\Files`) — dá para abrir no Excel com o teste
ainda rodando.

| Arquivo | Conteúdo |
|---|---|
| `ICS_Modular_sinais_*_{live\|tester}_{data}.csv` | uma linha por gatilho |
| `ICS_Modular_eventos_*` | trilha do setup |
| `ICS_Modular_barras_*` | uma linha por M1 live |
| `ICS_Modular_ordens_*` | envio / modify / close / fail reais |
| `ICS_Modular_run_*` | identidade da run + snapshot dos inputs |
| `ICS_Modular_funil_*` | funil do dia (antes só no Diário) |

Como cruzar live × Testador no Excel: [`docs/COMPARATIVO.md`](docs/COMPARATIVO.md).

`InpCommaDecimal = true` grava com vírgula decimal (Excel pt-BR).

Ao fim do teste, o Diário mostra o **funil** — em que etapa os candidatos estão
morrendo:

```
--- Funil do setup ---
Zonas criadas: 47 | ajustes: 112 | absorções: 23 | testes: 31
Rompimentos com fluxo: 18 | armadilhas: 9 | rompimentos falhos: 4
Deslocamentos confirmados: 11 | pullbacks sem gatilho: 6 | gatilhos: 7
```

Se há 47 zonas e zero rompimentos, o problema está no filtro de rompimento — não
na marcação de área.

---

## Onde mexer para cada coisa

| Quero mudar… | Arquivo |
|---|---|
| como a área é marcada | `Analysis/ZoneDetector.mqh` |
| quando a zona morre | `Analysis/Zone.mqh` |
| o que conta como absorção | `Analysis/Absorption.mqh` |
| a sequência de confirmação | `Analysis/StateMachine.mqh` |
| critérios de entrada, score, risco | `Analysis/Trigger.mqh` |
| níveis candidatos a alvo | `Analysis/Levels.mqh` |
| breakeven / trailing | `Execution/VirtualTrades.mqh` (`TrailStop`) |
| saída por reversão | `Execution/VirtualTrades.mqh` (`ReversalExitSignal`) |
| um parâmetro novo | `Config/Inputs.mqh` + ficha em `docs/PARAMETROS.md` |
| o que um parâmetro faz | `docs/PARAMETROS.md` |
| o que um objeto no gráfico significa | `docs/GRAFICO.md` |
| um campo novo numa struct | `Config/Defines.mqh` |
| colunas do CSV | `Execution/Logger.mqh` + `Analysis/Trigger.mqh` |
| comparar real vs tester | `docs/COMPARATIVO.md` |

---

## Trabalhando em um módulo isolado

Foi para isso que o projeto foi modularizado. Para pedir ajuda em uma regra
específica, mande:

1. `ARCHITECTURE.md` (o contexto do projeto inteiro)
2. O `.mqh` que você quer evoluir

Isso é ~600 linhas em vez de ~2000, e o `ARCHITECTURE.md` supre o contexto do
resto sem precisar colar código.

---

## Regras ao editar

- **Respeite as camadas.** Um módulo só pode usar o que vem antes dele na ordem
  de include em `ICS_Modular.mq5`. `Analysis/` pode usar `Core/`; `Core/` nunca pode
  usar `Analysis/`.
- **Chamada nova entre módulos?** Acrescente o protótipo em
  `Core/Prototypes.mqh`.
- **Módulo passou de ~300 linhas?** Quebre de novo. Veja a seção 10 do
  `ARCHITECTURE.md`.
- **Sem acentuação** no código e nos comentários `.mqh` (compatibilidade com o
  MetaEditor). Os `.md` podem ter acento à vontade.
- `#property` só no `.mq5`. Em `.mqh` é ignorado.

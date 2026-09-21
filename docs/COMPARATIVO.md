# Comparativo conta real × Testador

Protocolo para medir a divergência entre o EA na conta real e o mesmo EA no
Testador, no dia já encerrado. Não compara saldo: compara **dado, decisão e
execução**.

A fonte da verdade do que cada coluna significa é o código
([`Execution/Logger.mqh`](../Execution/Logger.mqh),
[`Analysis/Trigger.mqh`](../Analysis/Trigger.mqh),
[`Execution/RealOrders.mqh`](../Execution/RealOrders.mqh)). Este arquivo é o
roteiro de análise.

---

## Por que existe

O Testador não reproduz latência, fill, catch-up nem a chegada real dos ticks.
O backtest em `WIN_ICS` ainda pode divergir do contrato da corretora. Sem
`run_id`, ambiente no nome do arquivo e chave de negócio, os CSVs antigos não
davam para juntar — e o Testador **apagava** a run live se o nome coincidisse.

---

## Dois ciclos (não misturar no mesmo dia)

1. **Fase ambiente.** Live no contrato da corretora (ex. `WINV26`) × Testador
   no **mesmo símbolo**, ticks reais, dia já fechado. Isola latência, fill,
   catch-up e chegada de ticks.
2. **Fase arquivo local.** O CSV **live** do mesmo dia × Testador em `WIN_ICS`.
   Isola a qualidade do arquivo que alimenta os backtests.

**Dia 0 (recomendado, sem dinheiro):** `InpTradeEnabled = true`,
`InpLiveOrders = false`. Live gera os mesmos sinais e virtuais, sem ordem.
Meça divergência de **inteligência**. Só então ligue `InpLiveOrders` com lote
mínimo e saldo limitado.

**Testador:** modelo **todos os ticks**. Se o Diário disser `real ticks
discarded`, o comparativo de fluxo é inválido.

---

## Arquivos

Pasta comum: `TerminalInfoString(TERMINAL_COMMONDATA_PATH)\Files`.

```
ICS_Modular_{tipo}_{SIMBOLO}_{modo}_{ambiente}_{YYYYMMDD}[_tag].csv
```

`ambiente` = `live` | `tester`. A data é a de `TimeCurrent()` no `OnInit`
(início da run). Uma segunda run tester no mesmo dia sem `InpRunTag`
sobrescreve só os arquivos `*_tester_*`.

| tipo | Uma linha por | Join no Excel |
|---|---|---|
| `run` | início e fim da run | — (leia primeiro) |
| `barras` | M1 com `live = true` | `t` |
| `eventos` | evento do setup | `chave` |
| `sinais` | gatilho avaliado | `chave` |
| `ordens` | tentativa real | `sinal_id` → `sinais.id` |
| `funil` | dia (`fase=dia`) e encerramento (`fase=fim`) | `data` + `ambiente` |

Toda linha (exceto o cabeçalho) carrega `run_id` e `ambiente`.

### Chaves de negócio

Não junte por `id` nem `zona_id` — são contadores da run. Se uma zona a mais
nascer num ambiente, todos os IDs seguintes desalinham.

| Arquivo | `chave` |
|---|---|
| `sinais` | `{hora_entrada com data}\|{setup}\|{COMPRA\|VENDA}` |
| `eventos` de zona | `Z\|{t0}\|{lo}\|{hi}` |
| demais eventos | `{hora}\|{evento}\|{C\|V\|}` |
| `barras` | `t` (abertura do M1) |

---

## Ordem de investigação

Quando o saldo divergir, percorra nesta ordem. Cada pergunta aponta o arquivo.

### A. Foi a mesma run? — `run.csv`

- Mesma `versao`, mesmos `inputs` (`k=v\|k=v`), mesmo `simbolo`.
- `is_tester`, `trade_enabled`, `live_orders`.
- No `fase=fim`: `pct_barras_tick`, `pct_tick_flag`, `pct_vol_zero`.
  Abaixo de 90% de barras com negócio, ou abaixo de 50% de ticks com flag
  (exceto `InpDeltaMode = QUOTE`), o fluxo é inválido.

### B. Viram o mesmo mercado? — `barras.csv`

- Mesmo OHLC / `vol` / `delta` / `vwap` em cada `t`.
- Mesmo `ticks` e `ticks_flag`.
- Mesmo `normal_vol` daquele minuto (histórico carregado diferente = zona
  diferente).
- `proc_lag_s = TimeCurrent() - (t+60)`. No Testador barra-a-barra fica ~0.
  No live após restart, explode: nessas linhas **bid/ask não são do minuto**.
  OHLCV, delta e ticks ainda são comparáveis.

O primeiro M1 em que `delta` ou `vol` diverge acima de ~10% **antes** do
primeiro evento divergente é o minuto culpado.

### C. A máquina andou igual? — `eventos.csv`

Outer join por `chave`:

- `so_live` / `so_tester` / `match`.
- Mesma `ZONA_CRIADA` / `ZONA_AJUSTADA` no mesmo M5, mesmas bordas?
- Mesmo `ROMPIMENTO` / `ARMADILHA` / `DESLOCAMENTO` / `VAZAMENTO` / `ABSORCAO`?
- Mesmo motivo e hora de `ZONA_ENCERRADA`?

### D. A decisão foi a mesma? — `sinais.csv`

Join por `chave`:

- Mesmo `status` e mesmos `motivos`?
- Mesmos `score`, `romp_vol_x`, `retracao_pct`, `gatilho_delta_pct`, stop,
  alvo, `fonte_alvo`?
- Motivo `posicao aberta` / `limite de operacoes do dia` / `horario` só num
  lado = divergência de **estado de conta**, não de setup.

### E. A execução estragou um sinal que o estudo acertou? — `ordens.csv`

Só relevante com `InpLiveOrders = true` (ou Testador com `InpTradeEnabled`).

- `SEND` saiu? Qual `retcode`?
- `preco_fill - sinais.entrada` versus `slip_modelo` (`InpSlipPts`).
- `MODIFY` / `CLOSE` no mesmo minuto que `saida_hora` da virtual?
- Comment da ordem no terminal: `ICS|{id}` (limite de 31 caracteres do MT5).
  O `run_id` completo está no CSV, não no comment.

### F. O filtro protege nos dois ambientes? — `sinais.csv` + `funil.csv`

R médio de `EXECUTADO` versus `REJEITADO` nos dois CSVs. Se os rejeitados
tiverem R igual ou melhor, o filtro está errado — **nesse ambiente**. Um
motivo que só aparece num lado (ex. `falha no envio da ordem` só no live)
é execução, não filtro.

---

## Views no Excel

1. Abrir o par irmão (`*_live_*` e `*_tester_*`) do mesmo tipo.
2. Criar coluna auxiliar com a `chave` (já vem pronta em sinais/eventos).
3. `XLOOKUP` / `PROCV` do tester na chave live.
4. Classificar: `match` / `so_live` / `so_tester`.
5. No `match` de sinais, comparar `status`, `motivos`, `score`, `zona_min/max`.
6. No primeiro evento órfão, voltar a `barras.csv` no mesmo `t` e olhar
   `delta`, `vol`, `ticks`.

Listas úteis:

- Sinais divergentes + coluna de o que diferiu (`status` / `motivos` / feature).
- Ordens aprovadas (`status = EXECUTADO`) em cada ambiente, com `motivos` vazio.
- Ordens reprovadas (`REJEITADO` / `ERRO_ORDEM`) + `motivos`.
- Eventos órfãos no mesmo minuto.
- Fill vs estudo: `ordens.preco_fill - sinais.entrada`.

---

## Hipóteses a ter no bolso

- **Saldo diverge, sinais idênticos** → execução / custo / slip, não o setup.
- **Zona ou evento diverge antes do gatilho** → dado (tick, volume, normal),
  não “o EA mudou”.
- **`posicao aberta` só no live** → a conta já estava posicionada; o Testador
  começa limpo.
- **`WIN$` ou ticks descartados** → comparativo de fluxo inválido; `run.csv`
  (`data_diag`) denuncia.

---

## O que esta versão não grava

- Tick a tick.
- Snapshot de Volume Profile / HVN por barra.
- Objetos `ICSM_*` do gráfico.
- Transições silenciosas (`insideCount`, `CancelRejectWatch`, espera do hold).
  Se A–C não fecharem um caso, aí sim acrescentar um evento desses.

`LoadHistory()` continua sem ticks: isso só molda o volume normal dos **dias
anteriores**. O dia corrente já passa por `LoadBarTicks`.

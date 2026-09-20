# Glossário — ICS_Modular

Referência de consulta. Cite com `@GLOSSARY.md` no Cursor quando precisar do
vocabulário completo; não é indexado automaticamente.

---

## Instrumento

**WIN** — mini contrato futuro do Ibovespa, negociado na B3. Tick de 5 pontos.
Valor do ponto em torno de R$ 0,20 por contrato — o código lê do símbolo via
`SYMBOL_TRADE_TICK_VALUE / SYMBOL_TRADE_TICK_SIZE`, não usa constante.

**Contrato cheio** — `WINV26`, `WINZ26`. Letra do mês + ano.

**`WIN$`** — série contínua. **Não serve para este EA:** não tem lado agressor
nem bid/ask, então o delta fica inválido. O EA avisa no Diário.

**`WIN_ICS`** — símbolo arquivado localmente pelo desenvolvedor, com os ticks
reais preservados. É o símbolo recomendado para backtest.

---

## Fases do ciclo de mercado

A metodologia parte do princípio de que movimentos relevantes passam por:

| Fase | O que é |
|---|---|
| **Absorção** | volume alto com preço parado — alguém está segurando a ponta |
| **Acumulação / Distribuição** | construção de posição dentro de uma faixa |
| **Teste de oferta / demanda** | toque na extremidade com volume baixo, confirmando ausência do outro lado |
| **Spike** | deslocamento rápido, direcional |
| **Spike channel** | movimento já maduro, escadinha — tarde demais para entrar |

O ICS busca as fases iniciais, onde a assimetria risco-retorno é maior.
`InpMaxPullbacks = 1` existe para não entrar em spike channel.

---

## Conceitos do setup

**Zona institucional** — congestão no M5 com amplitude estreita, baixa eficiência
direcional e volume acima do normal. O "acampamento dos grandes players".
Struct `IcsZone`, detectada em `Analysis/ZoneDetector.mqh`.

**ER (eficiência direcional)** — `|fechamento − abertura| / caminho percorrido`.
Perto de 1 = tendência limpa. Perto de 0 = vai e volta, congestão. O ICS quer
ER **baixo** para marcar a zona.

**Volume relativo** — volume da janela dividido pelo volume normal do mesmo
horário. Acima de 1 significa participação acima do típico.

**Absorção** — volume muito acima do normal produzindo deslocamento mínimo.
Detectada em janelas de 1 a 3 barras M1. `Analysis/Absorption.mqh`.

**Teste de demanda** — toca o fundo da zona com volume **baixo** e fecha dentro.
Volume baixo no toque significa que não há vendedor ali. Evento `TESTE_FUNDO`.

**Teste de oferta** — o espelho, no topo. Evento `TESTE_TOPO`.

**Padrão V / armadilha** — saída fraca da zona rapidamente devolvida. Pegou os
participantes atrasados, e a liquidez deles alimenta o movimento contrário.
Campos `sweptHigh` / `sweptLow`, evento `ARMADILHA`.

**Rompimento com fluxo** — fecha fora da zona com volume acima do normal **e**
delta a favor. Sem as duas condições não é rompimento, é vazamento.

**Aceitação** — o preço permanece fora da zona por N barras. Distingue rompimento
real de pavio. `InpAcceptBars`, `InpAcceptMin`.

**Deslocamento** — avanço de pelo menos `InpContMult` vezes a altura da zona após
o rompimento. Confirma continuidade. Evento `DESLOCAMENTO`.

**Pullback fraco** — retração com volume médio abaixo do impulso e delta
contrário fraco. Fraqueza aqui é sinal de que o movimento continua.

**Micro-extremo** — extremo da perna de pullback. Rompê-lo é o **gatilho** de
entrada. Função `MicroExtreme()`.

**Retração** — `|extremo do impulso − extremo do pullback| / tamanho da perna`.
Válida entre `InpPbMinRetr` e `InpPbMaxRetr`.

---

## Volume e perfil

**Delta** — volume agressor comprador menos vendedor. Requer identificar o lado
agressor de cada negócio. `Data/Flow.mqh`.

**Lado agressor** — quem pagou o preço do outro. Vem das flags
`TICK_FLAG_BUY`/`TICK_FLAG_SELL` da corretora ou, na falta delas, da regra de
cotação (negócio no ask = comprador agressor).

**Volume normal** — volume típico daquele minuto do dia, média dos últimos N
dias com janela de ±2 minutos. **Não é média móvel** — o volume do WIN não é
comparável entre horários. `Data/VolumeNormals.mqh`.

**POC (Point of Control)** — nível de preço com maior volume negociado no
período. O EA calcula dois: o do dia (`ProfValueArea`) e o da zona (`ZonePoc`).

**Value Area** — faixa que concentra 70% do volume do dia. `VAH` é o topo, `VAL`
o fundo.

**HVN (High Volume Node)** — pico local do histograma de volume. Age como
obstáculo e vira candidato a alvo. `ProfHVN`.

**VWAP** — preço médio ponderado por volume, acumulado no dia. Define o contexto:
preço acima da VWAP com VWAP subindo = contexto de alta. `UpdateContext`.

---

## Gestão

**R** — múltiplo de risco. `1R` é a distância entre entrada e stop. Resultado em
R é a métrica principal do estudo, mais que reais.

**R:R líquido** — retorno dividido por risco, já descontados slippage e custos.

**MAE / MFE** — Maximum Adverse / Favorable Excursion. O quanto a operação andou
contra e a favor antes de encerrar. Colunas do CSV, úteis para calibrar stop e
alvo.

**Breakeven (zero a zero)** — mover o stop para o preço de entrada após o trade
andar `InpBEAtR` vezes o risco.

**Trailing** — seguir o preço a `InpTrailATR` × ATR(M5) de distância, começando
após `InpTrailStartR`.

**Stop de tempo** — encerrar após `InpTimeStopBars` barras se o lucro não
atingiu `InpTimeStopMinR`. Capital parado em trade que não anda é capital
desperdiçado.

**Zeragem** — fechamento obrigatório no horário `InpFlatTime`. Day trade não
carrega posição.

---

## Modos de operação do EA

**Completo** — todos os filtros ligados. `InpBaseline = false`.

**Baseline** — filtros de volume e fluxo desligados. Serve para medir quanto eles
agregam: se o baseline for igual ou melhor, os filtros não estão funcionando.

**Estudo** (`InpExecuteAll = true`, só no Testador) — executa também os gatilhos
rejeitados, para medir o custo real dos filtros.

**Executado × Rejeitado** — toda operação simulada é classificada assim. A
comparação entre as duas populações é o produto principal do CSV.

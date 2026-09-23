# Legenda gráfica — ICS_Modular

O que cada objeto no gráfico significa. Fonte da verdade:
[`UI/Draw.mqh`](../UI/Draw.mqh), [`Execution/Logger.mqh`](../Execution/Logger.mqh)
(`LogEvent`) e [`Analysis/Trigger.mqh`](../Analysis/Trigger.mqh).

Nada aqui altera o setup — é só visualização. O CSV e o funil continuam
iguais com o desenho desligado.

Vocabulário do setup: [`GLOSSARY.md`](GLOSSARY.md). Parâmetros:
[`PARAMETROS.md`](PARAMETROS.md) (`InpDraw`).

---

## Quando aparece

`g_draw = InpDraw && (!testador || modo visual)`.

| Situação | Desenha? |
|---|---|
| Ao vivo, `InpDraw = true` | sim |
| Testador em modo visual | sim |
| Testador sem visual / otimização | não |
| `InpDraw = false` | não |

O painel (`Comment`) segue a mesma trava. Tooltip de cada objeto tem o texto
completo — passe o mouse em vez de decifrar a cor.

Prefixo de todo objeto: `ICSM_`. Não colide com o `ICS_EA` antigo (`ICS_Z*`,
`ICS_M*`). `OnDeinit` limpa o `Comment`; os retângulos, setas e linhas
**ficam no gráfico** até você apagar (lista de objetos do MetaTrader ou
remover o EA e limpar).

---

## Zona (retângulo)

Objeto `ICSM_Z<id>` — `OBJ_RECTANGLE` preenchido, atrás das velas
(`DrawZone`). Recriado a cada ajuste porque a janela cresce.

| Cor | Estado | Quando |
|---|---|---|
| **azul-aço** (`clrSteelBlue`) | zona viva | `ST_ZONE` / `ST_BREAKOUT` / `ST_IMPULSE` |
| **cinza** (`clrDimGray`) | zona encerrada | `RetireZone` (`isFinal = true`) |

Bordas do retângulo = `g_zone.hi` / `g_zone.lo`. Tempo = `t0` → `t1`
(mínimo 5 min se `t1` ainda não avançou).

**Tooltip:** `Zona Z<id>  lo - hi  POC  ER  VolRel`.

Uma zona cinza no caminho **não** é obstáculo desenhado — os níveis
candidatos a alvo (`Levels.mqh`) não são pintados. Só a faixa da congestão.

---

## Marcadores (setas / símbolos)

`OBJ_ARROW`, nome `ICSM_M<n>`, Wingdings, largura 2. Âncora: compra em geral
abaixo da mínima da barra; venda acima da máxima (`below` em `DrawMark`).

### Eventos do setup (`LogEvent`)

| Símbolo (Wingdings) | Cor | Evento | Significado |
|---|---|---|---|
| seta para cima **233** | azul (`clrDodgerBlue`) | `ROMPIMENTO` compra | fechou acima da zona com volume e delta (ou Baseline) |
| seta para baixo **234** | laranja (`clrOrange`) | `ROMPIMENTO` venda | o espelho, abaixo da zona |
| estrela **251** | amarelo (`clrYellow`) | `ARMADILHA` | saiu fraco e voltou dentro de `InpTrapBars` (padrão V) |
| círculo **108** | magenta (`clrMagenta`) | `ABSORCAO` | volume alto com deslocamento mínimo (1–3 M1) |
| traço **159** | aqua (`clrAqua`), abaixo | `TESTE_FUNDO` | toque no fundo com volume baixo e fecha dentro |
| traço **159** | aqua (`clrAqua`), acima | `TESTE_TOPO` | o espelho, no topo |

Preço do marcador: extremo relevante da barra (não o fecha), passado por
`LogEvent`.

Eventos **sem** marcador próprio — só CSV de eventos / funil:

- `DESLOCAMENTO` (vira `ST_IMPULSE`; a zona azul continua)
- `ROMPIMENTO_FALHOU`
- `PULLBACK_SEM_GATILHO`
- `VAZAMENTO` (saiu sem fluxo; watch do reteste falho)
- `RETESTE_SEM_GATILHO`
- `ZONA_AJUSTADA` / `ZONA_ENCERRADA` (a zona muda de cor ou some o azul)
- `GATILHO` / `ACEITACAO` / `ENTRADA_ROMPIMENTO` / `RETESTE_FALHO` — o
  marcador vem do bloco abaixo, não de `LogEvent`

### Gatilho (`EvaluateTrigger`)

Um marcador por gatilho avaliado — **inclusive rejeitado**.

| Símbolo | Cor | Status | Lado |
|---|---|---|---|
| seta **241** | lima (`clrLime`) | `EXECUTADO` | compra |
| seta **242** | vermelho (`clrRed`) | `EXECUTADO` | venda |
| seta **241** / **242** | cinza (`clrGray`) | `REJEITADO` / `ESTUDO_EXECUTADO` / `ERRO_ORDEM` | mesmo código de lado |

Posição: mínima da barra (compra) ou máxima (venda).

**Tooltip:** `PULLBACK|ROMPIMENTO|ACEITACAO|RETESTE_FALHO` + lado + status +
score + R:R + motivos (ou `todos os filtros ok`).

Cinza no gráfico **não** significa “sem setup”. Significa que o gatilho foi
avaliado e barrado — a virtual ainda corre até o desfecho. É o equivalente
visual da linha `REJEITADO` no CSV.

`ESTUDO_EXECUTADO` também é cinza: a cor segue `taken`, e o estudo não marca
`taken = true`.

---

## Linhas de operação

Só no gatilho **tomado** (`taken`). Duração visual = `InpTimeStopBars`
minutos a partir da barra do gatilho — o trade real/virtual pode durar
mais (trail, zeragem). Nomes `ICSM_L<n>` (`OBJ_TREND` horizontal, sem raio).

| Linha | Cor | Estilo | Tooltip |
|---|---|---|---|
| entrada | branco (`clrWhite`) | pontilhado | `entrada` |
| stop | vermelho (`clrRed`) | sólido | `stop` |
| alvo | lima (`clrLime`) | sólido | `alvo: <fonte>` |
| trilho 110 | dourado (`clrGold`) | tracejado | `trilho 110` |
| trilho 50 | laranja (`clrOrange`) | tracejado | `trilho 50` |

Níveis são os da **avaliação** (entrada com slippage, stop com buffer,
alvo já no modo FIXED ou no TP de segurança do TRAIL). O stop que o
`TrailStop` move **não** redesenha a linha — o gráfico congela o stop
inicial. Para o stop efetivo, use a aba Negociação / o CSV
(`saida_motivo` = `TRAILING` / `ZERO_A_ZERO`).

`trilho 110` aparece quando a primeira fatia sai. `trilho 50` aparece
quando o recuo é armado e de novo se o máximo anda. Só no gatilho tomado,
e só com `InpTrilhoSaida`.

Gatilho cinza: sem linhas. A virtual existe, mas não ganha régua no
gráfico.

---

## Painel (canto do gráfico)

`Comment` em [`UI/Panel.mqh`](../UI/Panel.mqh), atualizado a cada M1 com
`g_draw`. Some no `OnDeinit`.

```
ICS Modular v1.213 [BASELINE]
Estado: ...
Contexto: alta | baixa | neutro
Zona Z<id>: lo - hi
Retracao: N% | pullback valido: sim|nao
Gatilhos: N | executados: N
PnL dia: R$ x | limite: R$ y | PARADO
```

| Campo | O que é |
|---|---|
| `[BASELINE]` | só aparece com `InpBaseline = true` |
| **Estado** | `sem zona` / `zona ativa` / `rompimento (aguardando aceitacao)` / `deslocamento / pullback` |
| **Contexto** | VWAP do dia (`UpdateContext`) — o mesmo de `InpCtxFilter` |
| **Zona** | id e bordas; vazio em `ST_IDLE` |
| **Retracao** | só em `ST_IMPULSE`; `pullback valido` = já passou `InpPbMinRetr` |
| **Gatilhos** | `g_signals` — todos os avaliados no dia/sessão corrente do EA |
| **executados** | `g_tkN` — só `taken` (não inclui `ESTUDO_EXECUTADO`) |
| **PnL dia** | só se `InpMaxLossDayBRL > 0`. `PARADO` = `g_dayLossHalt` |

O painel é estado **agora**, não histórico. Para a trilha completa use o
CSV de eventos.

---

## Como ler uma sequência no gráfico

Ordem típica do ICS clássico (kind=0), da esquerda para a direita:

1. retângulo **azul** — congestão M5
2. círculo **magenta** (opcional) — absorção perto da zona
3. traço **aqua** (opcional) — teste de borda
4. estrela **amarela** (opcional) — armadilha / padrão V
5. seta **azul ou laranja** — rompimento com fluxo
6. retângulo segue azul durante aceitação / deslocamento / pullback
7. seta **lima ou vermelha** + três linhas — gatilho executado  
   ou seta **cinza** — gatilho rejeitado (ainda assim no CSV)
8. retângulo vira **cinza** — zona encerrada (`RetireZone`)

Hold (`ACEITACAO`), entrada no rompimento (`ROMPIMENTO`) e reteste falho
(`RETESTE_FALHO`) usam o mesmo marcador de gatilho (241/242); o tooltip e
a coluna `setup` do CSV separam as quatro populações.

Painel em `ST_ZONE` com watch ligado: `zona ativa (reteste falho)`.

---

## Manutenção

Ao mudar um símbolo, cor ou o que um evento desenha:

1. `LogEvent` em `Execution/Logger.mqh` (eventos do setup)
2. bloco final de `EvaluateTrigger` (gatilho + linhas)
3. `DrawZone` em `UI/Draw.mqh` (zona)
4. atualizar **esta** legenda na mesma mudança. A regra `000-projeto`
   trata entrega sem a ficha como trabalho incompleto.

Código Wingdings novo: anote o número e o significado visual — o MetaTrader
não mostra o nome do caractere na lista de objetos.

# AGENTS.md — ICS_Modular

Instruções para agentes de IA trabalhando neste repositório. Lido pelo Cursor,
Claude Code, Codex e outras ferramentas que seguem a convenção `AGENTS.md`.

As regras detalhadas por contexto estão em `.cursor/rules/`. Este arquivo é o
resumo operacional.

---

## O projeto em uma frase

Expert Advisor MQL5 para MetaTrader 5 que opera mini índice Bovespa (WIN) em M1,
detectando zonas institucionais por volume e entrando na continuação após o
primeiro pullback fraco.

---

## Comandos

Não há build system, gerenciador de pacotes, linter ou suíte de testes. MQL5 é
compilado dentro do MetaEditor.

| Ação | Como |
|---|---|
| Compilar | MetaEditor → abrir `ICS_Modular.mq5` → **F7** |
| Testar | MetaTrader → Testador de Estratégia → símbolo `WINV26` ou `WIN_ICS`, M1 |
| Verificar ASCII | `grep -rlP '[^\x00-\x7F]' --include='*.mqh' --include='*.mq5' .` |

**Compile sempre o `.mq5`.** Abrir um `.mqh` e apertar F7 faz só checagem de
sintaxe e não gera o `.ex5` — isso é esperado, não é erro.

Não proponha `make`, `cmake`, `npm`, CI ou qualquer pipeline. Não existe
compilador MQL5 fora do MetaEditor.

---

## Regras que não se negociam

1. **MQL5 não tem linker.** `#include` é inclusão textual; tudo vira uma unidade
   de compilação. A ordem em `ICS_Modular.mq5` importa e segue camadas.

2. **Camada baixa nunca depende de camada alta.** `Analysis/` pode usar `Core/`;
   `Core/` nunca pode usar `Analysis/`.

3. **`EvaluateTrigger` nunca aborta.** Gatilho rejeitado também vira operação
   simulada e vai para o CSV. É o propósito do projeto — sem isso não dá para
   medir se um filtro protege ou custa dinheiro.

4. **Nenhum caractere acentuado em `.mq5` / `.mqh`.** O MetaEditor grava em ANSI.
   Arquivos `.md` podem acentuar.

5. **As duas travas de ordem real.** `InpTradeEnabled` **e** `InpLiveOrders`
   precisam estar ligadas ao vivo. Nunca simplifique ou contorne `OrdersAllowed()`.
   Nenhuma ordem sai com `g_replay = true`.

6. **`TrailStop()` é compartilhada** entre operações virtuais e posição real. Se
   mudar só um lado, o backtest deixa de descrever o EA.

---

## Onde mexer

| Quero mudar… | Arquivo |
|---|---|
| como a área é marcada | `Analysis/ZoneDetector.mqh` |
| quando a zona morre | `Analysis/Zone.mqh` |
| o que conta como absorção | `Analysis/Absorption.mqh` |
| a sequência de confirmação | `Analysis/StateMachine.mqh` |
| reteste falho / vazamento sem fluxo | `Analysis/Reject.mqh` |
| critérios de entrada, score, risco | `Analysis/Trigger.mqh` |
| níveis candidatos a alvo | `Analysis/Levels.mqh` |
| breakeven / trailing | `Execution/VirtualTrades.mqh` (`TrailStop`) |
| saída por reversão | `Execution/VirtualTrades.mqh` (`ReversalExitSignal`) |
| um parâmetro novo | `Config/Inputs.mqh` **e** `docs/PARAMETROS.md` |
| o que um parâmetro faz / analisar filtro | `docs/PARAMETROS.md` (obrigatório) |
| o que um objeto no gráfico significa | `docs/GRAFICO.md` |
| um campo novo em struct | `Config/Defines.mqh` |
| colunas do CSV | `Execution/Logger.mqh` **e** `Analysis/Trigger.mqh` **e** `Execution/VirtualTrades.mqh` |

---

## Estilo

- Indentação **3 espaços**, nunca tab
- Chave em linha própria (Allman)
- Prefixos: `g_` global, `Inp` parâmetro, `ST_` estado, `ICSM_` objeto gráfico
- Declarações relacionadas alinhadas em coluna
- Todo `.mqh` começa com cabeçalho declarando de que depende
- Comentários explicam **por que**, não **o quê**

**Não reformate código que você não precisou tocar.** Sem testes automatizados, a
revisão é visual — diffs limpos importam mais aqui do que no normal.

---

## Comunicação

- Responda em **português do Brasil**
- O desenvolvedor é engenheiro sênior: vá direto ao ponto, sem explicar o básico
- Ao analisar resultados de backtest, separe **fato observável** de **hipótese**
  e apresente o argumento contrário. Consulte `docs/PARAMETROS.md` (efeito de
  cada input) e `docs/GRAFICO.md` (marcadores) — não chute significado.
- "Não operar" é uma decisão válida. O EA rejeitar muitos sinais não é bug

---

## Antes de dizer que terminou

Percorra `.cursor/rules/080-checklist.mdc`. O resumo:

- compila com 0 erros e 0 avisos
- ASCII puro nos `.mqh` / `.mq5`
- funil do Testador ainda faz sentido
- `ARCHITECTURE.md` atualizado se a estrutura mudou
- `docs/PARAMETROS.md` / `docs/GRAFICO.md` atualizados se a mudança tocou
  input, filtro, motivo CSV ou desenho
- nenhum arquivo irrelevante no diff

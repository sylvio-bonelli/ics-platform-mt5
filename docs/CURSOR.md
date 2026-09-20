# Trabalhando neste projeto no Cursor

O que foi configurado, por que, e como usar no dia a dia.

---

## O que tem na pasta

```
.cursor/rules/
├── 000-projeto.mdc      sempre ativa   contexto do projeto
├── 010-mql5.mdc         em .mq5/.mqh   MQL5 não é C++
├── 020-camadas.mdc      sempre ativa   arquitetura e ordem de include
├── 030-estilo.mdc       em .mq5/.mqh   nomes, formatação, ASCII
├── 040-analysis.mdc     em Analysis/   regras do núcleo do setup
├── 050-config.mdc       em Config/     parâmetros e structs
├── 060-execucao.mdc     em Execution/  ordens, CSV, travas de segurança
├── 070-dominio.mdc      sob demanda    vocabulário de volume institucional
└── 080-checklist.mdc    sob demanda    verificação antes de fechar

AGENTS.md                resumo operacional, lido por várias ferramentas
.cursorignore            binários e CSV fora do contexto
.cursorindexingignore    fora do índice, mas acessível com @
.editorconfig            3 espaços, ANSI nos .mqh
.gitignore
docs/GLOSSARY.md         vocabulário completo, consulta sob demanda
docs/CURSOR.md           este arquivo
```

---

## Como as regras entram no contexto

Cada `.mdc` tem frontmatter que decide quando ela é carregada:

| Tipo | Frontmatter | Quando entra |
|---|---|---|
| **Always** | `alwaysApply: true` | toda requisição |
| **Auto Attached** | `globs: [...]` | quando um arquivo que casa com o glob está no contexto |
| **Agent Requested** | só `description` | quando o modelo julga relevante pela descrição |
| **Manual** | nada | só com `@nome-da-regra` |

Aqui: `000` e `020` são sempre ativas — o contexto do projeto e a arquitetura
valem para qualquer mudança. `010`, `030`, `040`, `050`, `060` entram sozinhas
conforme o arquivo aberto. `070` e `080` são Agent Requested: o modelo as puxa
pela descrição — `070` quando a conversa fala de absorção, POC ou delta, `080` ao
fechar uma alteração. Você também pode forçar as duas com `@070-dominio` e
`@080-checklist`.

---

## Uso no dia a dia

**Evoluir a marcação de área**

Abra `Analysis/ZoneDetector.mqh` e trabalhe normalmente. As regras `000`, `020`,
`010`, `030` e `040` entram sozinhas — o modelo já sabe as camadas, os três
critérios da zona e que não pode usar STL.

**Fechar uma alteração**

```
@080-checklist confere essa mudança
```

**Pedir contexto de domínio**

```
@GLOSSARY.md o que é padrão V e onde está no código?
```

**Refatorar um módulo grande**

```
@ARCHITECTURE.md quebra o StateMachine conforme a seção 10
```

---

## Ajustes que valem a pena no Cursor

**Codebase indexing** — Settings → Features → Codebase Indexing. Ligue. São 24
arquivos, indexa em segundos e melhora muito as buscas semânticas.

**Auto-run / YOLO mode** — deixe **desligado**. Não há comando de build ou teste
que o agente possa rodar sozinho neste projeto; a compilação é no MetaEditor.
Auto-run aqui só cria risco sem benefício.

**Model** — use o modelo mais forte disponível para `Analysis/`. Os módulos de
`Config/` e `UI/` toleram modelo mais rápido.

**Formatação automática** — deixe desligada para `.mq5`/`.mqh`. Não existe
formatador que conheça o estilo do projeto, e um reformat automático polui o
diff, que é a única revisão que este projeto tem.

---

## Editando fora do Cursor

O MetaEditor continua funcionando normalmente — ele lê os mesmos arquivos. O
fluxo prático é:

1. Editar no Cursor
2. Alternar para o MetaEditor e apertar **F7**
3. Ver os erros no MetaEditor
4. Voltar para o Cursor com a mensagem de erro, se houver

O MetaEditor detecta arquivos alterados em disco e recarrega. Se ele reclamar de
conflito, salve no Cursor primeiro e escolha "recarregar" no MetaEditor.

> **Cuidado com o charset.** O `.editorconfig` define `latin1` para `.mq5`/`.mqh`
> exatamente para não brigar com o MetaEditor. Se o Cursor gravar UTF-8 e você
> tiver acento no arquivo, o MetaEditor mostra lixo. Por isso a regra de ASCII
> puro no código — ela resolve o problema na origem.

---

## Git

Repositório: [sylvio-bonelli/ics-platform-mt5](https://github.com/sylvio-bonelli/ics-platform-mt5.git).
O `git init` fica **só** em `MQL5/Experts/ICS_Modular` — nunca em `Terminal\` ou
`MQL5\`, que são o data dir do MetaTrader.

O `.gitignore` exclui `.ex5`, CSV, presets `.set`, `.env` e dados de mercado.
Preset de estudo versionável: `*.set.example` (com `InpLiveOrders=false`).

O `.gitattributes` marca `.mq5`/`.mqh` como texto com `eol=crlf`, alinhado ao
`.editorconfig`. Sem `working-tree-encoding`: o código é ASCII; conversão
latin1↔UTF-8 no checkout briga com o MetaEditor.

Versionar permite comparar backtests por commit: "qual mudança piorou o funil?"
vira uma pergunta respondível.

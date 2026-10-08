# Protocolo A2A — coordenação entre agentes via GitHub

Complemento de [AGENT_COORDINATION.md](AGENT_COORDINATION.md). Define como
agentes heterogêneos (Devin local, Codex cloud via `chatgpt-codex-connector`,
Cursor) cooperam na mesma fila sem canal direto agente↔agente. **O GitHub é o
barramento**: issues, labels, comentários e PRs carregam todo o estado —
não existe protocolo A2A fora dele.

## 1. Papéis e capacidades

| Executor | Onde roda | Pode | Não pode |
|---|---|---|---|
| Devin | Máquina local do mantenedor (`avellaria`) | Tudo na fila: código, testes de dispositivo, acesso tailnet/Zotero local, merge **quando autorizado por sessão** | Decidir gates humanos |
| Codex | Nuvem OpenAI (connector) | Docs, revisão, análise de literatura pública, código em PR | Hardware, tailnet, VPS, secrets locais; push pode falhar → relay §3 |
| Cursor | IDE do mantenedor | Conforme sessão humana | — |

Tarefa para Codex usa label `agent:executor:codex`. Tarefa compartilhável usa
`agent:executor:any` — primeiro claim válido vence (regra de concorrência do
AGENT_COORDINATION §Claim).

## 2. Expor tarefa ao Codex

Uma issue executável por Codex precisa, além do contrato normal:

1. `agent:ready` + `agent:executor:codex` (ou `agent:executor:any`).
2. Escopo **auto-contido**: tudo que ele precisa está no repo ou em fonte
   pública. Nunca depender de tailnet, hardware, VPS ou arquivos locais.
3. Entrega esperada explícita: PR ou diff+relatório.

Invocação: comentário `@codex` na issue descrevendo a tarefa, ou designação
via interface do conector. O conector responde com `### Summary` e entrega
commits em branch `agent/<slug>` + PR quando consegue autenticar o push.

## 3. Relay de entrega (Codex → repo)

**Comportamento observado (2026-10-08):** o Codex produziu commits em ambiente
próprio (`9e8edf5`, `7ad2343` na nuvem) que **não chegaram ao origin** — o push
não estava autorizado no conector. Sem relay, o trabalho fica preso na nuvem.

Protocolo de relay:

1. Codex entrega um de: (a) PR aberto; (b) branch pushed; (c) diff unificado
   ou `git format-patch` colado na issue/comentário; (d) apenas relatório.
2. (a)/(b): revisão normal, CI roda, merge conforme autorização.
3. (c): **Devin aplica o patch** em `agent/issue-N-<slug>`, preserva autoria
   (`Co-Authored-By`), valida (`git apply --check`, docs-integrity), abre o PR
   citando a tarefa Codex de origem.
4. (d): o mantenedor ou outro agente transforma o relatório em tarefa com
   escopo próprio; ninguém "implementa" implicitamente análise de outro
   agente sem issue.

O relay é do executor que tem acesso de escrita, não do Codex — ele nunca
precisa de credencial além da do conector.

## 4. Handoff inter-agente

Além do HANDOFF padrão (AGENT_COORDINATION §85), quando a entrega cruza
agentes, acrescentar:

```text
ORIGIN=<executor que produziu> (<ref da tarefa/commit se externa>)
RELAY=<executor que transportou | nenhum>
ATTRIBUTION=<commits preservados | squash com crédito no corpo>
```

## 5. Divisão de trabalho recomendada

- **Codex:** fundamentação/ADR, revisão de PR, análise de literatura,
  rascunhos de contrato, código puro (sem hardware/env).
- **Devin:** tarefas com hardware, tailnet, VPS, secrets, E2E de tablet,
  relay e integração.
- **Nunca simultâneos no mesmo arquivo** (regra de claim exclusivo).

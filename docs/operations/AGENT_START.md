# Iniciar uma execução em Devin ou Cursor

Este roteiro entrega uma única tarefa ao executor. O contrato completo está em [AGENTS.md](../../AGENTS.md) e a fila está na [issue #1](https://github.com/rafaloct/jalapao-monitor-v2/issues/1).

## Prompt inicial

```text
Trabalhe exclusivamente em rafaloct/jalapao-monitor-v2.
GitHub é a fonte de verdade. Confirme o estado live antes de agir.

Leia AGENTS.md, docs/operations/AGENT_COORDINATION.md,
docs/operations/REPOSITORY_BASELINE.md, docs/operations/CI_PLAN.md
e a Issue #17 completa, incluindo comentários e dependências.

Se AGENTS.md ainda não estiver em main, leia a preparação da Issue #16
e seu PR como proposta. Para executar #17, siga o contrato completo da
própria issue e CLAUDE.md; não presuma o PR de governança integrado.

Verifique PRs abertos, arquivos sobrepostos, assignees, claims e
worktrees antes de assumir trabalho. Só execute #17 se continuar
agent:ready e HUMAN_GATE=NO. Se já houver outro executor, pare e informe.

Objetivo: reproduzir o baseline de desenvolvimento e os testes unitários
de modelos em checkout isolado. Editar somente
docs/evidence/BASELINE_EXECUTION.md, conforme a issue.

Registre claim, abra branch isolada a partir de main e entregue um draft
PR com SHA, versões, comandos, exit codes, resultados e bloqueios.
Não execute integration_test, scripts de captura ou backend real.
Não altere código/dependências para esconder falhas do baseline.

MERGE_ALLOWED=NO
PRODUCTION_ALLOWED=NO
Não usar bypass, force-push, credenciais de produção ou dispositivo de
campo. Ao entregar o PR e o handoff, encerre sem assumir outra tarefa.
```

## Preparação da ferramenta

No Devin, prefira `Open PRs as: Devin`. No Cursor, confirme a identidade GitHub utilizada pelo terminal e o checkout aberto. O uso de uma conta administrativa não concede ao agente permissão operacional para integrar ou mudar políticas.

As tarefas seguintes são #18, #19 e #20, mas só o estado da fila e suas dependências podem liberá-las. Não pedir ao agente para “implementar todos os milestones” em uma única sessão.

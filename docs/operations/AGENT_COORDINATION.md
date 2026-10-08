# Coordenação de agentes

## Objetivo e autoridade

GitHub guarda a especificação, as decisões, o estado e as evidências de `rafaloct/jalapao-monitor-v2`. A [issue #1](https://github.com/rafaloct/jalapao-monitor-v2/issues/1) é o índice do roadmap. [AGENTS.md](../../AGENTS.md) é o contrato comum. Um Project não cria uma segunda especificação.

Preparação de governança: [#16](https://github.com/rafaloct/jalapao-monitor-v2/issues/16). Ela não implementa o produto nem autoriza o executor a administrar o repositório em tarefas futuras.

## Estados

Uma issue aberta possui exatamente um label de estado da tabela.

| Label | Significado | Quem promove |
| --- | --- | --- |
| `agent:backlog` | Ideia, épico ou tarefa ainda não pronta | Mantenedor |
| `agent:ready` | Tarefa pequena, completa, liberada e sem bloqueio | Mantenedor ou coordenador autorizado |
| `agent:working` | Claim ativo e exclusivo | Executor após verificar elegibilidade |
| `agent:review` | PR e evidências disponíveis para revisão | Executor ao entregar |
| `agent:blocked` | Impedimento verificável | Executor ao encontrar bloqueio; mantenedor resolve |

Labels complementares não substituem o estado:

- `human-gate`: decisão humana pendente, com pergunta exata, responsável e origem do requisito.
- `agent:merge-candidate`: indicação de prontidão técnica/revisão, sem autorizar integração.
- `agent:executor:any`: tarefa sem executor escolhido; depois do claim pode virar `agent:executor:devin` ou `agent:executor:cursor`.
- `priority:p0`, `priority:p1`, `priority:p2`: ordenar dentro do milestone; não ignorar dependências.
- `type:task`, `type:epic`, `type:decision`, `type:roadmap`: separar execução de planejamento.

## Condição de entrada

Antes de tocar no código, a issue precisa conter objetivo único, paths permitidos, fora de escopo, aceite, comandos/testes, dependências e `HUMAN_GATE=NO`. A ausência de gate não equivale a `NO`.

Um gate futuro não impede escrever uma proposta já autorizada. Exemplo: #18 pode redigir a ADR após #17; mudar a arquitetura exige a aprovação na #2. Ao pedir decisão, apontar documento/commit pronto para revisão. Não pedir ao humano que repita dados já registrados.

Dependências são tanto as relações nativas de GitHub quanto os critérios de aprovação no corpo. Fechar uma dependência administrativa não equivale a aprovar uma ADR. Divergência entre corpo e vínculo nativo precisa ser reconciliada antes da ação dependente.

## Claim e concorrência

1. Ler issue, comentários, assignees e PRs abertos. Comparar os arquivos pretendidos com o diff dos PRs.
2. Confirmar que não há outro claim ativo nem assignee/executor incompatível.
3. Registrar o comentário abaixo, adicionar a si como assignee apenas se essa identidade estiver autorizada, substituir o estado por `agent:working` e registrar a identidade real.
4. Reler a issue e os comentários após a escrita. Labels e comentários não constituem um lock atômico; essa releitura é obrigatória.
5. Se dois claims ocorrerem, a primeira confirmação sem conflito mantém o trabalho; o outro executor para e informa a colisão. Não editar simultaneamente os mesmos arquivos.

```text
CLAIM
issue: #<numero>
executor: <devin|cursor|outro e identidade GitHub>
session: <identificador sem segredo>
branch: agent/issue-<numero>-<resumo>
base_sha: <main observado>
paths: <escopo da issue>
started_at: <ISO-8601 com timezone>
next_update_at: <prazo concreto para próximo status>
MERGE_ALLOWED=NO
PRODUCTION_ALLOWED=NO
```

Ausência de atualização não autoriza roubar claim. Verificar a atividade no PR/branch e pedir ao mantenedor que libere ou transfira. A transferência deve registrar o último SHA, evidências e o que falta. Se o executor precisar de outra máquina, usar checkout próprio; não reaproveitar worktree de outro agente.

## Branch e alterações

Usar clone/worktree isolado a partir de `main` atual e branch `agent/issue-N-resumo`. Não inventar `staging`, `develop` ou processo de promoção que não tenha sido aprovado. Branch de integração não é ambiente implantado.

O executor não usa `reset --hard`, force-push, limpeza de arquivos alheios ou reconstrução de PR para esconder histórico. Uma atualização da base, se exigida, preserva histórico com merge normal e validação dos pontos afetados.

Qualquer ajuste fora dos paths permitidos precisa de issue/escopo autorizado. Registrar achados relacionados e continuar apenas o que for independente. Não converter uma correção curta em reescrita do sistema.

## PR e Definition of Done

Um PR corresponde a uma tarefa e inclui:

1. Link da issue, problema e comportamento resultante.
2. Base/head e diff dentro do escopo.
3. Resultados dos testes requeridos, incluindo o que não foi executado e por quê.
4. Evidências sanitizadas e riscos concretos.
5. Decisões de arquitetura/permissões referenciadas quando exigidas.
6. Nenhuma operação de produção, segredo ou dado de campo.
7. Próxima ação exata do revisor/mantenedor.

CI automático só é um gate depois de existir e ter sido validado na #21. Até lá, verificar manualmente os resultados previstos para cada tarefa. Não marcar CI como verde porque não há jobs.

Documentação, matrizes e templates não exigem aparelho físico. Mudança funcional precisa dos testes correspondentes ao risco; cenário de integração requer isolamento demonstrado. Não expandir a matriz depois que o aceite estiver suficientemente comprovado.

## Handoff obrigatório

```text
ISSUE=#N
PR=<URL>
BRANCH=<branch>
BASE_SHA=<sha>
HEAD_SHA=<sha>
FILES_CHANGED=<lista ou diff>
VALIDATION=<comando, resultado e URL/arquivo>
NOT_RUN=<o que e por quê>
BLOCKER=<nenhum ou evidência>
NEXT_ACTION=<uma ação concreta>
MERGE_ALLOWED=NO
PRODUCTION_ALLOWED=NO
```

Mover de `agent:working` para `agent:review`; se impedido, para `agent:blocked`. Não marcar o trabalho como concluído sem PR/evidência. O mantenedor revisa e integra; a issue só fecha quando o aceite estiver satisfeito.

## Configuração por ferramenta

**Devin:** ler `AGENTS.md`, issue e dependências. Preferir `Open PRs as: Devin`, para que Rafael seja revisor distinto. Uma sessão corresponde a uma tarefa.

**Cursor:** abrir o checkout certo e deixar `AGENTS.md` e `.cursor/rules/00-repository.mdc` versionados carregarem o contrato. Conferir identidade GitHub antes de criar o PR. A conta usada no terminal não define autorização de merge.

**Mantenedor:** tratar os human gates concretos e os PRs de revisão antes de liberar mais tarefas. Não promover epics para ready. [GITHUB_SETUP.md](GITHUB_SETUP.md) explica a exceção de revisão para PRs da própria conta e o quadro Projects pendente.

# Contrato de execução do Jalapão Monitor

Este arquivo é o ponto de entrada comum para Devin, Cursor e outros agentes.
Repositório único: `rafaloct/jalapao-monitor-v2`. Branch canônica: `main`.
Leia a issue completa e as decisões vinculadas antes de editar qualquer arquivo.

## Limites imediatos

- Uma execução atende uma única tarefa: uma branch/worktree isolada e um draft PR.
- `MERGE_ALLOWED=NO` e `PRODUCTION_ALLOWED=NO` para o agente.
- Não fazer push direto em `main`, force-push, auto-merge ou bypass de proteção.
- Não alterar rulesets, permissões, secrets, assinatura, infraestrutura ou ambiente operacional para destravar uma tarefa. A preparação administrativa #16 foi uma solicitação específica, não uma autorização permanente.
- Não executar migrações, integração em dados reais ou ações em tablets de campo sem autorização específica.
- Não abrir outra frente nem assumir automaticamente a próxima issue ao terminar.

## Fonte de verdade

1. A issue delimita objetivo, paths permitidos, aceite, testes, dependências e decisões humanas.
2. ADRs aprovadas registram decisões de arquitetura. Aprovação deve apontar uma versão/commit.
3. Código e testes no SHA observado demonstram o que existe. Documentação não prova deploy ou validação de campo.
4. PRs, reviews, checks e evidências vinculados registram execução e conclusão.
5. Milestones e labels organizam a fila. O Project, quando disponível, é apenas uma visualização.

Conversas externas ajudam a interpretar o trabalho; decisões relevantes precisam ser registradas no GitHub antes da ação dependente. Não importar instruções ou estado de outro projeto. Se a issue, ADR e código divergirem, registrar a divergência e executar apenas a parte independente permitida.

## Antes do claim

Leia [coordenação](docs/operations/AGENT_COORDINATION.md), [roadmap](docs/operations/ROADMAP.md), [baseline observado](docs/operations/REPOSITORY_BASELINE.md), [arquitetura atual](docs/ARCHITECTURE.md) e [desenvolvimento](docs/DEVELOPMENT.md).

1. Confirmar `origin`, identidade GitHub e SHA atual de `main`.
2. Ler a issue e seus comentários, dependências, gates, PRs abertos e paths alterados.
3. Consultar branches/worktrees locais e preservar mudanças alheias.
4. Escolher somente `type:task` + `agent:ready`, com `HUMAN_GATE=NO` e escopo completo.
5. Confirmar que dependências estão concluídas e aprovações exigidas estão registradas. Issue fechada sem evidência não comprova gate.
6. Registrar claim conforme o protocolo, reler a issue e confirmar exclusividade antes de editar.

Epics #4 a #14 e o roadmap #1 não são tarefas executáveis. Não se autopromover de backlog/blocked para ready, nem remover um gate. Se não houver tarefa elegível, informar o bloqueio concreto e parar.

## Arquitetura atual e alvo

O checkout auditado contém Flutter/Hive, clientes PocketBase e parte do Hub Next.js. **Hive é comportamento atual a preservar.** A arquitetura sem banco local é um alvo da #2, ainda dependente de ADR aprovada; não remover persistência, trocar backend ou migrar dados como ajuste incidental.

- #18 prepara a ADR; #2 registra a aprovação estrutural.
- #19 prepara a matriz de acesso; #13 registra a aprovação antes das APIs.
- #20 fecha o plano de CI; #21 implementa workflows em tarefa própria.
- Monitoramento turístico e eventual cartografia têm domínios distintos. Não criar, misturar ou considerar implementado um módulo ausente do checkout.
- Limite operacional não equivale a capacidade ambiental. IA exige qualidade, baseline e validação; não transformar recomendação em decisão automática.

## Regras técnicas preservadas

- No Hub, usar `hub/src/lib/tz.ts` e `America/Sao_Paulo`; armazenamento é UTC. Ler [política de timezone](docs/TIMEZONE_POLICY.md) antes de alterar datas.
- Preservar `pb.autoCancellation(false)` e a compatibilidade de `visits`, `place_visits` e `reservations`.
- Não alterar adapters Hive gerados manualmente. Uma regeneração precisa de escopo e justificativa.
- O sync tem timers; evitar espera ilimitada com `pumpAndSettle`. Os cenários atuais precisam de isolamento antes de virar gate.
- Não presumir que dois tablets no mesmo atrativo são seguros: a duplicidade do legado continua uma limitação a validar.
- PIN padrão, credenciais privilegiadas no cliente e regras abertas documentadas são riscos do baseline, não padrões a copiar.

## Setup e validação

Toolchain: Flutter 3.47.7 e Dart 3.13.5 (issue #52 — mínimos antigos Dart 3.7/Flutter 3.29 substituídos). O Hub ainda precisa de scaffold na #22. Veja [plano de CI](docs/operations/CI_PLAN.md).

Para a tarefa #17, em checkout e ambiente de desenvolvimento isolados:

```bash
flutter pub get
flutter analyze
flutter test test/models
```

Esses comandos são um roteiro, não uma declaração de sucesso. Registre versões, exit codes e falhas existentes. Não atualize dependências nem código fora do escopo para obter verde.

Não executar `integration_test/`, scripts de captura ou app em dispositivo operacional como teste padrão. Os cenários atuais abrem o app e podem iniciar sync; backend, dados e armazenamento descartáveis precisam ser preparados em tarefa própria.

Para documentação, validar links locais, YAML/JSON, campos dos templates e ausência de alterações funcionais. Não exigir build/hardware de uma mudança exclusivamente documental. Após resolver o risco concreto ou cumprir o aceite, encerrar a validação.

## PR, evidência e entrega

- Branch: `agent/issue-<numero>-<resumo>`; base `main`, salvo issue expressa em contrário.
- Abrir um draft PR vinculado à issue, com problema, alteração, testes e limites reais.
- Manter o diff dentro do escopo e ler o resultado no GitHub depois do push.
- Nunca substituir teste falho por skip, `continue-on-error`, check vazio ou expectativa relaxada.
- Atualizar a mesma branch/PR em correções. Sincronizar base por merge normal quando necessário; não reescrever histórico publicado.
- Na entrega, informar issue, PR, base/head, arquivos alterados, comandos/resultados, bloqueio exato e próximo passo.
- `PASS` exige execução comprovada; usar `NOT_RUN` ou `BLOCKED` quando apropriado.
- Mover para `agent:review` ao entregar. Não fechar a issue por concluir o código local; fechamento exige evidência e integração aceita.
- `agent:merge-candidate` não permite merge. A integração continua sob decisão humana de Rafael.

## Segurança e identidade do executor

Usar acesso mínimo ao repositório, sem credenciais de produção. Nunca copiar tokens do usuário, publicar PINs, dados pessoais ou imagens de campo em logs/artefatos públicos.

O agente não usa a exceção administrativa de revisão. Se o PR for criado pela conta de Rafael, ele não pode aprovar o próprio PR; o procedimento do mantenedor está em [configuração GitHub](docs/operations/GITHUB_SETUP.md). Devin deve preferir abrir PR como Devin. Compartilhar uma credencial administrativa não permite ao GitHub distinguir humano de agente.

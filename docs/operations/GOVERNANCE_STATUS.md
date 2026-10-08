# Evidência da preparação de governança

Data: 06/10/2026. Repositório: `rafaloct/jalapao-monitor-v2`.
Tarefa: [#16](https://github.com/rafaloct/jalapao-monitor-v2/issues/16).
Base observada: `main@a6d9bfe1507f9d75e6d4a872c17501c435204634`.
Branch de documentação: `agent/issue-16-repository-governance-20261006`.

Este arquivo é uma evidência datada. O estado atual deve ser relido nas URLs abaixo. O PR da #16 entrega os arquivos; sua existência não significa que foram integrados em main.

## Configuração aplicada e confirmada

| Item | Resultado confirmado |
| --- | --- |
| Milestones | Sete, M0 a M6, sem datas artificiais |
| Issues | 25 abertas após a preparação: #1 a #25 |
| Organização | #2 a #15 com milestones; tarefas #16 a #25 com milestones próprios; #1 agregador |
| Subissues nativas | 24 vínculos: roadmap, epics/decisões e tarefas |
| Dependências nativas | 12 vínculos entre as primeiras tarefas |
| Estados de execução | Exatamente um label de estado por issue aberta |
| Primeira tarefa pronta | Somente #17, com escopo documental e unidade isolada |
| Branch main | Protegida; SHA original preservado |
| Auto-merge do repositório | Desabilitado no estado observado |
| Workflows GitHub Actions | Zero; a #21 implementará CI após os gates |
| Checks obrigatórios | Nenhum nome fictício cadastrado |

[Milestones](https://github.com/rafaloct/jalapao-monitor-v2/milestones), [roadmap #1](https://github.com/rafaloct/jalapao-monitor-v2/issues/1) e [fila pronta](https://github.com/rafaloct/jalapao-monitor-v2/issues?q=is%3Aissue%20is%3Aopen%20label%3Aagent%3Aready).

## Proteção lida de volta

| Ruleset | ID e link | Estado e regras |
| --- | --- | --- |
| `main-core-protection` | [24594797](https://github.com/rafaloct/jalapao-monitor-v2/rules/24594797) | Active; main; PR obrigatório; conversas resolvidas; sem exclusão, force-push ou bypass; merge normal/squash |
| `main-human-review` | [24594847](https://github.com/rafaloct/jalapao-monitor-v2/rules/24594847) | Active; uma aprovação; CODEOWNERS; descarta aprovação após mudanças; exceção de administrador somente por PR |

A comparação por GET confirmou todos os parâmetros administrados de [github-rulesets.json](github-rulesets.json), inclusive lista de bypass e branch alvo. O GitHub acrescentou os padrões `required_reviewers=[]` e `require_extra_approval_for_unattributed_changes=true`; esses campos adicionais não foram alterados. O endpoint de regras efetivas de main retornou ambos os rulesets.

A regra de CODEOWNERS está configurada, mas o arquivo `.github/CODEOWNERS` desta entrega só passa a existir em main depois do merge. O mantenedor verificado é `rafaloct`, com permissão administrativa. Agentes não usam a exceção de revisão; ver [GITHUB_SETUP.md](GITHUB_SETUP.md).

## Verificação dos arquivos

O PR contém documentação, contrato de agentes, templates e manifest de configuração. Não altera fontes em `lib/`, `hub/src/`, `android/`, testes, dependências ou workflows.

Foram verificados parser YAML/JSON, campos e IDs dos templates, sintaxe Bash dos exemplos, links locais contra a árvore canônica mais os arquivos propostos, ausência de espaços finais e tamanho do AGENTS.md abaixo de 16 KiB. Uma revisão independente não identificou bloqueio documental.

Build, análise Flutter, testes de runtime, backend, integração e dispositivos permanecem `NOT_RUN`. Esta evidência não declara segurança integral, prontidão de produção ou aprovação da arquitetura.

## Pendências explícitas

1. Revisão e integração do PR da #16 pelo mantenedor, preservando os gates do repositório.
2. [#25](https://github.com/rafaloct/jalapao-monitor-v2/issues/25): Projects v2 não criado. A sessão GitHub CLI não dispõe de `read:project`/`project`; autorização adicional opcional descrita na issue. Issues e milestones já funcionam como fila.
3. [#17](https://github.com/rafaloct/jalapao-monitor-v2/issues/17): reproduzir o ambiente e resultados unitários; depois liberar propostas #18/#19/#20 conforme suas dependências.
4. [#21](https://github.com/rafaloct/jalapao-monitor-v2/issues/21): implementar e comprovar CI antes de configurar checks obrigatórios reais.

Nenhum agente Devin/Cursor foi iniciado automaticamente e nenhum merge ou deploy foi executado nesta preparação.

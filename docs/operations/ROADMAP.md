# Roadmap operacional

O [roadmap #1](https://github.com/rafaloct/jalapao-monitor-v2/issues/1), as issues e seus milestones guardam o estado atual. Este documento explica a organização e a sequência; consultar labels/PRs ao iniciar uma execução.

## Marcos de entrega

| Marco | Escopo | Gate de saída |
| --- | --- | --- |
| [M0](https://github.com/rafaloct/jalapao-monitor-v2/milestone/1) Arquitetura, governança e qualidade | #2, #3; baseline, ADR, acesso e CI | Baseline reproduzível, decisões/gates aprovados e qualidade verificável |
| [M1](https://github.com/rafaloct/jalapao-monitor-v2/milestone/2) Backend, identidade e contratos | #13; filhos iniciais de #11/#14 | Autorização, contratos versionados, idempotência e ambiente sintético |
| [M2](https://github.com/rafaloct/jalapao-monitor-v2/milestone/3) Operação e dispositivos | #4, #5, #6 | Sessão, QR/fila, entrada/saída, recibo e displays validados |
| [M3](https://github.com/rafaloct/jalapao-monitor-v2/milestone/4) Turista, agência e gestão | #7, #8 | Informação pública adequada, acesso limitado e gestão operacional útil |
| [M4](https://github.com/rafaloct/jalapao-monitor-v2/milestone/5) Ambiente, pesquisa e mídia | #9, #10, #11 | Fonte/responsável/validade, dados científicos reproduzíveis e protocolo de mídia |
| [M5](https://github.com/rafaloct/jalapao-monitor-v2/milestone/6) Dados e IA assistiva | #12 | Qualidade, baseline e validação antes de recomendação |
| [M6](https://github.com/rafaloct/jalapao-monitor-v2/milestone/7) Piloto e produção limitada | #14, #15 | Piloto, restore, observabilidade, rollback e go/no-go humano |

Não foram definidas datas sem estimativa de capacidade. O marco de um épico representa seu fechamento completo: contratos de dados e infraestrutura básica começam em M1, mesmo que #11 e #14 fechem depois. O escopo concreto do piloto deve ser aprovado na #15; um milestone não autoriza publicação.

## Primeira sequência

| Issue | Entrega | Pré-condições |
| --- | --- | --- |
| [#16](https://github.com/rafaloct/jalapao-monitor-v2/issues/16) | Preparação de governança | Solicitação atual; somente documentação/configuração |
| [#17](https://github.com/rafaloct/jalapao-monitor-v2/issues/17) | Baseline de SDK/testes e lacunas do checkout | Sem dependência; tarefa inicial elegível |
| [#18](https://github.com/rafaloct/jalapao-monitor-v2/issues/18) | Proposta de ADR sem banco local | #17 |
| [#19](https://github.com/rafaloct/jalapao-monitor-v2/issues/19) | Matriz de acesso e ameaças | #17; reconciliar #18 antes da aprovação |
| [#20](https://github.com/rafaloct/jalapao-monitor-v2/issues/20) | Plano de CI fechado pelo baseline | #17 |
| [#21](https://github.com/rafaloct/jalapao-monitor-v2/issues/21) | CI mínimo real | #18/#20 e aprovações exigidas |
| [#22](https://github.com/rafaloct/jalapao-monitor-v2/issues/22) | Recuperar scaffold do Hub | #17/#18, gates e origem dos arquivos |
| [#23](https://github.com/rafaloct/jalapao-monitor-v2/issues/23) | Contrato de sessão de monitoramento | #18/#19 aprovadas |
| [#24](https://github.com/rafaloct/jalapao-monitor-v2/issues/24) | Remover fallback de credencial | #18/#19/#21 e transição aprovada |
| [#25](https://github.com/rafaloct/jalapao-monitor-v2/issues/25) | Visualização opcional Projects | Escopo de autenticação `project`; não bloqueia a fila |

#18, #19 e #20 podem ser propostas em paralelo depois do baseline, em arquivos diferentes e por executores distintos. Implementações continuam bloqueadas até os gates específicos. Nenhum épico inteiro está liberado.

## Consultas de trabalho

- [Tarefas prontas](https://github.com/rafaloct/jalapao-monitor-v2/issues?q=is%3Aissue%20is%3Aopen%20label%3Atype%3Atask%20label%3Aagent%3Aready)
- [Em execução](https://github.com/rafaloct/jalapao-monitor-v2/issues?q=is%3Aissue%20is%3Aopen%20label%3Aagent%3Aworking)
- [Em revisão](https://github.com/rafaloct/jalapao-monitor-v2/issues?q=is%3Aissue%20is%3Aopen%20label%3Aagent%3Areview)
- [Decisões humanas pendentes](https://github.com/rafaloct/jalapao-monitor-v2/issues?q=is%3Aissue%20is%3Aopen%20label%3Ahuman-gate)
- [Milestones](https://github.com/rafaloct/jalapao-monitor-v2/milestones)

O bootstrap criou a #17 como `agent:ready`; a seleção futura depende do estado live e do claim exclusivo. Não usar este snapshot para ignorar alterações posteriores.

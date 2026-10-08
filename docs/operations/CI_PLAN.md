# Plano de CI e gates de contribuição

## 1. Objetivo e limites

Este documento atende ao planejamento da [Issue #3](https://github.com/rafaloct/jalapao-monitor-v2/issues/3), preparado na [Issue #16](https://github.com/rafaloct/jalapao-monitor-v2/issues/16). Define a sequência para obter verificações reproduzíveis sem apresentar checks planejados como existentes.

**Nenhum workflow é criado por este plano.** O fechamento do plano pertence à [Issue #20](https://github.com/rafaloct/jalapao-monitor-v2/issues/20); a implementação pertence à [Issue #21](https://github.com/rafaloct/jalapao-monitor-v2/issues/21), após os gates registrados.

Fonte técnica inicial: [REPOSITORY_BASELINE.md](REPOSITORY_BASELINE.md), commit `a6d9bfe1507f9d75e6d4a872c17501c435204634`. A inspeção foi estática e os comandos de runtime permanecem `NOT_RUN`.

A preparação documental pode prosseguir. Merge, deploy, contratação, alteração de secrets e acesso ao backend real não são autorizados por este plano.

## 2. Dependências da fila

| Issue | Entrega | Dependência para executar ou avançar |
|---|---|---|
| #16 | Governança, templates, baseline e plano inicial | Documentação e configuração dentro do escopo autorizado |
| #17 | Baseline de SDK e testes unitários | Ambiente isolado e SDK compatível; registrar resultados reais |
| #18 | ADR da arquitetura autoritativa | Inventário atual; aprovação antes de implementação estrutural |
| #19 | Matriz papel × recurso × ação | Decisões propostas de arquitetura; aprovação antes das APIs |
| #20 | Fechar plano de CI | Resultado da #17 e limites explícitos dos componentes bloqueados |
| #21 | Implementar CI | Plano/gates aprovados; checks baseados em comandos reproduzidos |
| #22 | Recuperar scaffold do Hub | Origem legítima dos arquivos ou escopo explícito de reconstrução |
| #23 | Contrato de sessão | Decisões de arquitetura e acesso aprovadas para avançar à implementação |
| #24 | Remover fallback de PIN | Política de acesso aprovada; testes sem credenciais reais |
| #25 | GitHub Projects | Capacidade/permissão própria pendente; não bloqueia trabalho independente |

Epics não são unidades prontas de execução. Cada agente trabalha em uma tarefa atômica, uma branch isolada e um draft PR; registra evidências antes de devolver a tarefa para revisão.

## 3. Princípios dos gates

- Usar comandos que funcionem a partir de checkout limpo e dependências declaradas.
- Fixar versões somente após validá-las e registrá-las na #17 ou #22.
- Diferenciar falha de código, falha de ambiente e verificação não executada.
- Não transformar requisito planejado em sucesso automático, job vazio ou `continue-on-error`.
- Não mudar runtime Flutter/Hive para contornar limitações desta preparação.
- Preservar a separação entre monitoramento e cartografia.
- Manter segredos, dados reais e endpoints operacionais fora de fixtures e logs.
- Exigir evidência proporcional ao risco e aos arquivos alterados.
- Reexecutar ou ampliar testes para resolver risco concreto, sem expandir indefinidamente o escopo.
- Registrar dependência e próxima ação precisa quando a tarefa ficar bloqueada.

## 4. Matriz inicial de verificações

Os comandos abaixo são **candidatos**, sujeitos à reprodução e ao ajuste de escopo nas issues correspondentes.

| Camada | Verificação candidata | Condição para adoção |
|---|---|---|
| Documentação | Links locais, existência de caminhos e consistência de templates | Definir ferramenta/comando na #20; não há checker comprovado |
| Integridade do diff | `git diff --check` | Executar no diff real do PR e registrar resultado |
| Flutter, formato | `dart format --output=none --set-exit-if-changed lib test integration_test` | #17 identifica baseline; resolver dívida em tarefa delimitada, sem formatar tudo neste PR |
| Flutter, análise | `flutter analyze` | SDK/dependências reproduzidos; registrar achados preexistentes |
| Flutter, unidade | `flutter test test/models` | Prioridade inicial da #17; 35 testes existentes, ainda `NOT_RUN` |
| Android, build | Build de validação definido após bootstrap | Wrapper, SDK, Java e configuração de rede reproduzidos |
| Hub, instalação | Comando do gerenciador correspondente ao lock recuperado | #22 concluída; `npm ci` somente se houver lock npm válido |
| Hub, qualidade | Lint, typecheck, testes e build realmente declarados | Manifest e scripts recuperados; não inventar `npm run` inexistente |
| Contratos | Validação de schema/OpenAPI e exemplos de sessão | #18/#19/#23 aprovadas no que condiciona a implementação |
| Segurança | Varredura de secrets e dependências aplicável à stack | Ferramenta e política de saída definidas; descoberta sensível com valores removidos |
| Integração | Fluxos críticos contra ambiente efêmero e dados sintéticos | Isolamento de rede/Hive/backend e assertions funcionais |
| Hardware | Adapters simulados para QR, impressora e displays | Contratos definidos; teste físico permanece evidência separada |
| Mídia/privacidade | Acesso, retenção e isolamento de stream/snapshot | Protocolo aprovado antes de ativar captura |
| Release | Artefato, identidade do build e promoção controlada | Assinatura, rollback, restore e autorização de promoção |
| Execução periódica | Carga e regressão longa | Necessidade concreta e agendamento explicitamente aprovado |

Build debug ou release com chave debug serve apenas ao objetivo de validação declarado. Não comprova assinatura de distribuição nem prontidão de produção.

## 5. Integração: bloqueio atual e caminho para habilitar

Os quatro cenários atuais de `integration_test/` iniciam o aplicativo com Hive e providers reais. Há sincronização ao iniciar, chamadas a `pumpAndSettle` e poucos resultados verificados por assertions. Os scripts e guias também referenciam backend existente.

Antes de habilitar esse gate:

1. Disponibilizar backend efêmero ou simulador com contrato verificável, sem credenciais operacionais.
2. Isolar armazenamento do aplicativo, dados sintéticos e ciclo de setup/teardown.
3. Impedir que configuração ausente provoque fallback para serviço real.
4. Confirmar que falhas de conexão não apareçam como operação salva no fluxo alvo.
5. Substituir espera indefinida por sincronização e limites coerentes com o cenário.
6. Verificar transições e resultados relevantes, inclusive casos negativos, sem pular silenciosamente caminhos.
7. Registrar duração, dispositivo/ambiente, resultados e evidências sanitizadas.

Não executar o walkthrough atual contra backend real para “obter um verde”. Hardware físico, acesso a serviço existente e dados de campo requerem tarefa e autorização próprias.

## 6. Aplicação da proteção de branch

A política desejada é contribuição por PR, histórico verificável, resolução de conversas e revisão compatível com o risco. Force-push e exclusão da branch canônica devem permanecer impedidos quando a capacidade administrativa permitir.

Checks obrigatórios serão configurados somente quando:

1. O workflow correspondente existir e rodar para o evento correto.
2. O nome efetivo do check for observado no GitHub.
3. Uma execução no SHA relevante comprovar que o gate funciona.
4. A configuração não deixar alterações válidas presas em check ausente ou eternamente pendente.
5. A configuração aplicada for lida novamente e comparada com o plano.

Não declarar proteção ativa somente porque este documento existe. Permissões insuficientes ou limitações do plano GitHub devem ser registradas como bloqueio técnico específico, mantendo disponíveis as tarefas independentes.

## 7. Revisão humana e evidências do PR

A #3 exige revisão humana em mudanças de dados, segurança, IA, privacidade, limites operacionais e produção. A #2 condiciona implementação estrutural à ADR; a #13 exige matriz de acesso aprovada antes das APIs.

`HUMAN_GATE=NO` em uma tarefa significa que o trabalho autorizado pode ser executado. Não substitui revisão requerida, aprovação de decisões ou autorização de merge/deploy.

Todo PR deve informar:

- Issue atendida, objetivo e escopo efetivamente alterado.
- Base e HEAD relevantes, sem confundir evidência de outro commit.
- Comandos executados, versões necessárias e resultados `PASS`, `FAIL`, `BLOCKED` ou `NOT_RUN`.
- Comportamento resultante, casos negativos relevantes e limites da validação.
- Risco remanescente, rollback aplicável e gate humano exato, quando existir.
- Próximo passo ou handoff suficiente para evitar repetição de investigação.

Nunca registrar PINs, tokens, senhas, dumps reais ou logs integrais com dados pessoais. Evidência de segurança deve identificar presença, arquivo, impacto e correção proposta sem revelar valores.

## 8. Critério de conclusão do planejamento

A #20 pode fechar quando o baseline executado da #17 estiver registrado, os comandos iniciais e seus triggers estiverem definidos, os bloqueios do Hub/Android/integração estiverem explícitos e a #21 tiver escopo e aceite executáveis.

A #21 só pode declarar CI entregue com workflows reais, execuções comprovadas e resultado verificado no GitHub. Proteção de branch, Projects, aprovação arquitetural e prontidão de produção são estados distintos e devem ser reportados separadamente.

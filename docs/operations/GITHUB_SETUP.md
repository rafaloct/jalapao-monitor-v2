# Configuração operacional do GitHub

Repositório: `rafaloct/jalapao-monitor-v2`. Preparação: Issues [#16](https://github.com/rafaloct/jalapao-monitor-v2/issues/16) e [#3](https://github.com/rafaloct/jalapao-monitor-v2/issues/3).

Este documento descreve a configuração desejada e sua verificação. A presença do arquivo não comprova que regras ou Project foram aplicados. Registrar as evidências reais na Issue correspondente, com data, URLs e IDs retornados pelo GitHub.

## 1. Fonte de verdade e limites

- `AGENTS.md` define o contrato do agente; cada Issue define objetivo, escopo, dependências e critérios de conclusão.
- Issues, labels e milestones constituem a fila funcional, inclusive enquanto o Project estiver pendente.
- O Project apresenta essa fila; não substitui as Issues nem autoriza ampliar seu escopo.
- A preparação #16/#3 não cria workflows, implementa funcionalidades ou executa deploy.
- Agentes não fazem merge, bypass, auto-merge ou alterações administrativas. Essas ações cabem ao mantenedor, conforme autorização específica.

## 2. Dois rulesets para `main`

Ambos devem ter `target=branch`, `enforcement=active` e incluir `refs/heads/main`, sem exclusões. O [manifest dos campos administrados](github-rulesets.json) registra os parâmetros solicitados; [GOVERNANCE_STATUS.md](GOVERNANCE_STATUS.md) registra IDs e confirmação da preparação. O GitHub pode acrescentar campos padrão na resposta; comparar todos os campos administrados e registrar os adicionais, sem ignorar divergências nesses campos.

| Configuração | Núcleo de proteção | Revisão humana |
| --- | --- | --- |
| Exigir PR | Sim | Sim |
| Aprovações obrigatórias | 0 | 1 |
| Resolver conversas de revisão | Sim | Sim, o mesmo requisito |
| Exigir CODEOWNERS | Não | Sim |
| Descartar aprovações após mudanças | Não | Sim |
| Aprovação por pessoa diferente do último push | Não | Não |
| Bloquear exclusão | Sim, regra `deletion` | Sem regra adicional |
| Bloquear force push | Sim, regra `non_fast_forward` | Sem regra adicional |
| Bypass | Nenhum, `bypass_actors=[]` | Somente administrador do repositório, via PR |
| Checks obrigatórios nesta preparação | Nenhum | Nenhum |

Na regra de revisão, a exceção é `actor_type=RepositoryRole`, `actor_id=5`, `bypass_mode=pull_request`. O valor 5 identifica o papel de administrador; não é um ID de usuário ou de ruleset. Não conceder bypass a aplicações, agentes ou ao papel geral de escrita.

O núcleo permanece sem exceção: o bypass da revisão não libera push direto, exclusão, force push ou futuras exigências de CI incluídas no núcleo. O GitHub combina as regras aplicáveis. Manter a exceção exclusivamente no ruleset de revisão.

### Identidade do autor e responsabilidade do mantenedor

O GitHub não permite que o autor aprove o próprio PR. No Devin, preferir **Settings > Devin > Pull requests > Open PRs as: Devin**, para que Rafael possa revisar como pessoa distinta do autor.

Se o Cursor abrir o PR como `rafaloct`, o mantenedor deve revisar o diff e as evidências, registrar a decisão para o HEAD examinado e realizar pessoalmente a integração pela exceção de administrador, quando necessária. O agente entrega o PR e aguarda; não usa a exceção nem interpreta um comentário próprio como aprovação humana.

Uma credencial compartilhada com o owner não permite ao GitHub distinguir uma ação humana de uma ação do agente. A regra de revisão fornece uma exigência técnica com uma exceção administrativa; o uso humano dessa exceção depende também do procedimento e da separação das credenciais.

### Como confirmar a proteção

Executar somente consultas; não testar bloqueios tentando alterar ou excluir `main`:

```bash
gh api repos/rafaloct/jalapao-monitor-v2 --jq '{default_branch,visibility}'
gh api --paginate repos/rafaloct/jalapao-monitor-v2/rulesets --jq '.[] | {id,name,target,enforcement}'
gh api repos/rafaloct/jalapao-monitor-v2/rules/branches/main
```

Para cada ID retornado, consultar `gh api repos/rafaloct/jalapao-monitor-v2/rulesets/ID` e comparar `conditions`, `rules` e `bypass_actors` com a tabela. Substituir `ID` pelo valor observado. Conferir também `.github/CODEOWNERS` em `main`, seus proprietários e suas permissões; a regra depende de um arquivo válido.

Registrar em #16 os dois IDs, links das regras e resultado da comparação. Não declarar `PASS` somente porque uma chamada de criação retornou sucesso.

## 3. Checks após baseline e plano de CI

A [baseline #17](https://github.com/rafaloct/jalapao-monitor-v2/issues/17) e o [plano #20](https://github.com/rafaloct/jalapao-monitor-v2/issues/20) precisam ser aprovados antes da [implementação de CI #21](https://github.com/rafaloct/jalapao-monitor-v2/issues/21).

Somente depois de #21 produzir execuções válidas, o mantenedor poderá adicionar checks ao núcleo. Usar nomes reais e exclusivos, verificar execução recente bem-sucedida e confirmar que rodam para PRs no SHA relevante. Não cadastrar nomes estimados, jobs inexistentes ou workflows que sejam inteiramente pulados por filtros de caminhos. Registrar os nomes e a origem esperada dos checks na própria Issue de CI.

## 4. Project: pendência de permissão em #25

A consulta realizada com `gh project list` foi negada por falta de `read:project`. A pendência está na [Issue #25](https://github.com/rafaloct/jalapao-monitor-v2/issues/25). Consultas exigem `read:project`; criação e edição exigem `project`.

Quando o mantenedor decidir habilitar o quadro, a autorização adicional é:

```bash
gh auth refresh -h github.com -s project
```

Concluir a autorização interativa na conta correta. Não incluir tokens, códigos de autenticação ou credenciais em arquivos, comandos versionados, comentários ou evidências. Se a autorização continuar indisponível, manter #25 pendente e trabalhar pela fila de Issues e milestones.

### Bootstrap verificável após autorização

Título proposto: **Jalapão Monitor | Desenvolvimento**. Owner: `rafaloct`. Executar uma única instância do roteiro abaixo, em Bash com GitHub CLI autenticado. Ele procura o título em todas as páginas antes de criar, interrompe em caso de duplicidade e reutiliza os itens existentes.

```bash
set -euo pipefail
JALAPAO_OWNER=rafaloct
JALAPAO_REPO=rafaloct/jalapao-monitor-v2
JALAPAO_TITLE='Jalapão Monitor | Desenvolvimento'
JALAPAO_QUERY='query($login:String!,$endCursor:String){
  user(login:$login){projectsV2(first:100,after:$endCursor){
    nodes{number title} pageInfo{hasNextPage endCursor}
  }}
}'
JALAPAO_NUMBER="$(gh api graphql --paginate -f query="$JALAPAO_QUERY" \
  -f login="$JALAPAO_OWNER" --jq '.data.user.projectsV2.nodes[] |
  select(.title == "Jalapão Monitor | Desenvolvimento") | .number')"
if [[ "$JALAPAO_NUMBER" == *$'\n'* ]]; then
  printf '%s\n' 'Há vários Projects com esse título. Resolver a ambiguidade em #25.' >&2
  exit 1
fi
if [[ -z "$JALAPAO_NUMBER" ]]; then
  JALAPAO_NUMBER="$(gh project create --owner "$JALAPAO_OWNER" \
    --title "$JALAPAO_TITLE" --format json --jq '.number')"
fi
JALAPAO_CLOSED="$(gh project view "$JALAPAO_NUMBER" --owner "$JALAPAO_OWNER" \
  --format json --jq '.closed')"
if [[ "$JALAPAO_CLOSED" != false ]]; then
  printf '%s\n' 'Project encerrado ou estado inesperado. Revisar #25 antes de alterar.' >&2
  exit 1
fi
gh project link "$JALAPAO_NUMBER" --owner "$JALAPAO_OWNER" --repo "$JALAPAO_REPO"
JALAPAO_ISSUES="$(gh api --paginate "repos/$JALAPAO_REPO/issues?state=all&per_page=100" \
  --jq '.[] | select(has("pull_request") | not) | .html_url')"
while IFS= read -r JALAPAO_ISSUE_URL; do
  [[ -z "$JALAPAO_ISSUE_URL" ]] && continue
  gh project item-add "$JALAPAO_NUMBER" --owner "$JALAPAO_OWNER" \
    --url "$JALAPAO_ISSUE_URL" >/dev/null
done <<< "$JALAPAO_ISSUES"
gh project view "$JALAPAO_NUMBER" --owner "$JALAPAO_OWNER" --format json
gh project item-list "$JALAPAO_NUMBER" --owner "$JALAPAO_OWNER" --limit 1000 --format json
```

A carga inclui Issues abertas e encerradas, sem adicionar os PRs como tarefas duplicadas. Repetir `item-add` para uma Issue já presente reutiliza o item. Conferir a contagem total no retorno; se a listagem exceder o limite, paginar a conferência antes de registrar conclusão.

Confirmar o vínculo na aba Projects do repositório. Configurar uma tabela com Issue, Status, labels, responsável, milestone e PR vinculado, além de um quadro por Status. Usar labels e milestones existentes; evitar campos duplicados de prioridade ou de escopo.

Para novos itens, pode-se configurar o auto-add nativo do Project para este repositório. Ele não importa retroativamente as Issues, por isso o roteiro faz a carga inicial. Nenhum workflow GitHub Actions é necessário para esse passo. Não ativar encerramento automático de Issues a partir de mudanças manuais no quadro.

Registrar em #25 a URL real, owner, vínculo, contagem conferida, campos e automações efetivamente configurados. O Project só estará concluído após essa leitura de confirmação.

## 5. Referências oficiais

- [GitHub: criação de rulesets e bypass somente por PR](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/creating-rulesets-for-a-repository).
- [GitHub: combinação de rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets).
- [GitHub: aprovação e impossibilidade de autoaprovação](https://docs.github.com/en/pull-requests/how-tos/review-pull-requests/approving-a-pull-request-with-required-reviews).
- [GitHub: checks obrigatórios e condições de execução](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-required-status-checks).
- [Devin: identidade de abertura de PRs](https://docs.devin.ai/integrations/gh).
- [Cursor: AGENTS.md e regras de projeto](https://cursor.com/docs/rules); [Devin: AGENTS.md](https://docs.devin.ai/onboard-devin/agents-md).
- [GitHub: Projects via API, scopes e reutilização de itens](https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/using-the-api-to-manage-projects).
- [GitHub: vínculo entre Project e repositório](https://docs.github.com/en/issues/planning-and-tracking-with-projects/managing-your-project/adding-your-project-to-a-repository).
- [GitHub: auto-add nativo](https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/adding-items-automatically); [CLI: autorização adicional](https://cli.github.com/manual/gh_auth_refresh).

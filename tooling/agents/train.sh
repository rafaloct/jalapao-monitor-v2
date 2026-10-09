#!/usr/bin/env bash
# train.sh — driver do merge-train (AGENT_ORCHESTRATOR §4).
#
#   train.sh --dry-run   (default) lista PRs elegíveis em ordem, sem integrar
#   train.sh --merge     integra os elegíveis em ordem; exige MERGE_ALLOWED=YES
#
# Ordem: dependências explícitas (`Depends on: #N` / `Depende de #N` no corpo
# da issue do PR) têm precedência sobre número do PR. PR cuja dependência está
# aberta e não integrada neste trem fica enfileirado até ela entrar — se ela
# reprovar, o trem para antes dele (fail-closed).
set -uo pipefail

MODE="${1:---dry-run}"
HERE="$(cd "$(dirname "$0")" && pwd)"

if [ "$MODE" = "--merge" ] && [ "${MERGE_ALLOWED:-NO}" != "YES" ]; then
  echo "abortado: --merge exige MERGE_ALLOWED=YES no ambiente" >&2
  exit 1
fi

echo "== Merge-train — PRs abertos de agente (base: main) =="

# Só PRs de agente com base main — alvo diferente viola o contrato do repo.
declare -A PR_ISSUE DEPENDS
PRS=$(gh pr list --state open --base main --json number,headRefName \
      --jq '[.[] | select(.headRefName | startswith("agent/")) | .number] | sort | .[]')
[ -z "$PRS" ] && { echo "nenhum PR de agente aberto."; exit 0; }

for PR in $PRS; do
  HEAD=$(gh pr view "$PR" --json headRefName --jq '.headRefName' 2>/dev/null)
  ISSUE=$(echo "$HEAD" | sed -n 's/^agent\/issue-\([0-9]*\)-.*/\1/p')
  [ -n "$ISSUE" ] || continue
  PR_ISSUE[$PR]=$ISSUE
  # Dependências: "Depends on: #N" (EN) ou "Depende de/da #N" (PT)
  DEPS=$(gh issue view "$ISSUE" --json body --jq '.body' 2>/dev/null \
    | grep -oiE '(depends on|depende d[ae]) ?:? *#[0-9]+' \
    | grep -oE '[0-9]+$' || true)
  DEPENDS[$PR]="$DEPS"
done

# Issue fechada só conta como dependência satisfeita se houver evidência de
# integração: PR que a fechou mergeado (closedByPullRequestsReferences) ou
# label agent:done. Fechamento administrativo não prova gate.
ISSUE_DONE() {
  local N="$1"
  [ "$(gh issue view "$N" --json state --jq '.state' 2>/dev/null)" = "CLOSED" ] || return 1
  gh issue view "$N" --json labels --jq '.labels[].name' 2>/dev/null \
    | grep -qx 'agent:done' && return 0
  local MERGED
  MERGED=$(gh api graphql -f query="
    {repository(owner:\"rafaloct\",name:\"jalapao-monitor-v2\"){
      issue(number:$N){closedByPullRequestsReferences(first:5){nodes{merged}}
    }}}" --jq '[.data.repository.issue.closedByPullRequestsReferences.nodes[] | select(.merged==true)] | length' 2>/dev/null)
  [ "${MERGED:-0}" -gt 0 ]
}

# Ordenação topológica simples: em cada rodada, pega PRs cujas dependências
# já foram integradas (neste trem) ou já estão fechadas com evidência.
ORDERED=""
PENDING_LIST="$PRS"
for pass in 1 2 3 4 5 6 7 8 9 10; do
  [ -z "$PENDING_LIST" ] && break
  PROGRESS=0
  for PR in $PENDING_LIST; do
    echo "$ORDERED" | grep -qw "$PR" && continue
    READY=1
    for DEP in ${DEPENDS[$PR]:-}; do
      ISSUE_DONE "$DEP" && continue
      DEP_PR=""
      for other in $PRS; do [ "${PR_ISSUE[$other]:-}" = "$DEP" ] && DEP_PR=$other; done
      if [ -n "$DEP_PR" ] && ! echo "$ORDERED" | grep -qw "$DEP_PR"; then READY=0; break; fi
      [ -z "$DEP_PR" ] && { echo "  [aviso] PR #$PR depende de #$DEP aberta sem PR de agente — fail-closed"; READY=0; break; }
    done
    if [ "$READY" = 1 ]; then ORDERED="$ORDERED $PR"; PROGRESS=1; fi
  done
  [ "$PROGRESS" = 0 ] && { echo "TREM PARADO: ciclo de dependências entre: $PENDING_LIST"; exit 1; }
  PENDING_LIST=$(for PR in $PENDING_LIST; do echo "$ORDERED" | grep -qw "$PR" || echo "$PR"; done)
done

for PR in $ORDERED; do
  ISSUE="${PR_ISSUE[$PR]:-?}"
  echo "── PR #$PR (issue #$ISSUE) ──────────────────────────"

  # O gate é reexecutado para CADA PR na hora do merge — após integrações
  # anteriores do trem, CI/threads podem ter mudado de estado.
  "$HERE/claim_check.sh" "$PR" || {
    echo "TREM PARADO: PR #$PR reprovado no gate. Resolva antes de seguir."
    [ "$MODE" = "--dry-run" ] && continue
    exit 1
  }

  # mergeable cobre conflito; mergeStateStatus cobre head desatualizado
  # (BEHIND/DIRTY) — CI rodada na base antiga não vale como evidência.
  STATE=$(gh pr view "$PR" --json mergeable,mergeStateStatus \
          --jq '"\(.mergeable) \(.mergeStateStatus)"')
  case "$STATE" in
    *CONFLICTING*)
      echo "TREM PARADO: PR #$PR em conflito com a base — rebase antes."
      [ "$MODE" = "--dry-run" ] && continue
      exit 1 ;;
    *BEHIND*|*DIRTY*)
      echo "TREM PARADO: PR #$PR atrás da main ($STATE) — rebase e CI nova exigidos."
      [ "$MODE" = "--dry-run" ] && continue
      exit 1 ;;
  esac

  if [ "$MODE" = "--merge" ]; then
    echo "mergeando PR #$PR…"
    gh pr merge "$PR" --merge || { echo "merge do PR #$PR falhou — trem parado."; exit 1; }
    # Ciclo de vida da issue: fechar com referência ao merge commit +
    # label agent:done (evidência para dependências futuras).
    MERGE_SHA=$(gh pr view "$PR" --json mergeCommit --jq '.mergeCommit.oid[0:8]' 2>/dev/null)
    if [ "$ISSUE" != "?" ]; then
      gh label create agent:done --color 0e8a16 \
        --description "entrega integrada" 2>/dev/null || true
      gh issue edit "$ISSUE" --add-label agent:done 2>/dev/null || true
      gh issue close "$ISSUE" -c "DONE — integrado pelo merge-train no commit ${MERGE_SHA:-<merge>} (PR #$PR)." \
        2>/dev/null || true
    fi
  else
    echo "elegível: PR #$PR (dry-run — nada integrado)"
  fi
done

echo "== fim do trem ($MODE) =="

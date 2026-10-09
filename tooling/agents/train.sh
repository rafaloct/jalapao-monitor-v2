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

echo "== Merge-train — PRs abertos de agente =="

# Mapa PR -> issue (a partir do head ref agent/issue-N-*)
declare -A PR_ISSUE DEPENDS
PRS=$(gh pr list --state open --json number,headRefName \
      --jq '[.[] | select(.headRefName | startswith("agent/")) | .number] | sort | .[]')
[ -z "$PRS" ] && { echo "nenhum PR de agente aberto."; exit 0; }

for PR in $PRS; do
  HEAD=$(gh pr view "$PR" --json headRefName --jq '.headRefName' 2>/dev/null)
  ISSUE=$(echo "$HEAD" | sed -n 's/^agent\/issue-\([0-9]*\)-.*/\1/p')
  [ -n "$ISSUE" ] || continue
  PR_ISSUE[$PR]=$ISSUE
  # Dependências declaradas na issue: "Depends on: #N" ou "Depende de #N"
  DEPS=$(gh issue view "$ISSUE" --json body --jq '.body' 2>/dev/null \
    | grep -oiE 'depende?n?c?y? ?(on|de)?:? *#[0-9]+' | grep -oE '[0-9]+$' || true)
  DEPENDS[$PR]="$DEPS"
done

# Ordenação topológica simples: em cada rodada, pega PRs cujas dependências
# já foram integradas (neste trem) ou já estão fechadas/mergeadas na main.
ORDERED=""
PENDING_LIST="$PRS"
ISSUE_DONE() { # issue já satisfeita? (fechada no GitHub)
  [ "$(gh issue view "$1" --json state --jq '.state' 2>/dev/null)" = "CLOSED" ]
}
for pass in 1 2 3 4 5 6 7 8 9 10; do
  [ -z "$PENDING_LIST" ] && break
  PROGRESS=0
  for PR in $PENDING_LIST; do
    echo "$ORDERED" | grep -qw "$PR" && continue
    READY=1
    for DEP in ${DEPENDS[$PR]:-}; do
      # dependência satisfeita se a issue dep já fechou OU o PR da dep já saiu na fila
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
  echo "── PR #$PR (issue #${PR_ISSUE[$PR]:-?}) ──────────────────────────"
  "$HERE/claim_check.sh" "$PR" || {
    echo "TREM PARADO: PR #$PR reprovado no gate. Resolva antes de seguir."
    [ "$MODE" = "--dry-run" ] && continue
    exit 1
  }

  MERGEABLE=$(gh pr view "$PR" --json mergeable --jq '.mergeable')
  if [ "$MERGEABLE" = "CONFLICTING" ]; then
    echo "TREM PARADO: PR #$PR em conflito com a base — rebase antes."
    [ "$MODE" = "--dry-run" ] && continue
    exit 1
  fi

  if [ "$MODE" = "--merge" ]; then
    echo "mergeando PR #$PR…"
    gh pr merge "$PR" --merge || { echo "merge do PR #$PR falhou — trem parado."; exit 1; }
  else
    echo "elegível: PR #$PR (dry-run — nada integrado)"
  fi
done

echo "== fim do trem ($MODE) =="

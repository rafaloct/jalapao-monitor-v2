#!/usr/bin/env bash
# claim_check.sh <PR_NUMBER> — gate de sessão autorizada (AGENT_ORCHESTRATOR §2).
# Verifica S1–S8; reporta S9 como aviso (decisão humana).
# Exit 0 = sessão autorizada; exit 1 = violação ou incerteza (fail-closed).
set -uo pipefail

PR="${1:?uso: claim_check.sh <pr-number>}"
FAIL=0

say()  { printf '%s\n' "$*"; }
ok()   { say "  [OK]   $*"; }
fail() { say "  [FAIL] $*"; FAIL=1; }
warn() { say "  [WARN] $*"; }

REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null) || {
  say "erro: gh indisponível ou sem repo"; exit 1; }
say "claim_check: $REPO PR #$PR"

# ── Dados do PR ──────────────────────────────────────────────
PR_JSON=$(gh pr view "$PR" --json state,headRefName,mergeStateStatus,body \
          --jq '{state,head:.headRefName,merge:.mergeStateStatus,body}' 2>/dev/null) \
  || { fail "PR #$PR inacessível"; exit 1; }

[ "$(echo "$PR_JSON" | jq -r '.state')" = "OPEN" ] || fail "PR não está OPEN"
HEAD_BRANCH=$(echo "$PR_JSON" | jq -r '.head')
BODY=$(echo "$PR_JSON" | jq -r '.body')

# ── S5: branch segue o padrão e identifica a issue ───────────
ISSUE=$(echo "$HEAD_BRANCH" | sed -n 's/^agent\/issue-\([0-9]*\)-.*/\1/p')
if [ -z "$ISSUE" ]; then
  ISSUE=$(echo "$BODY" | grep -oiE 'closes #[0-9]+' | grep -oE '[0-9]+' | head -1 || true)
  [ -n "$ISSUE" ] && warn "S5: branch '$HEAD_BRANCH' fora do padrão; issue inferida do corpo: #$ISSUE" \
                 || fail "S5: branch '$HEAD_BRANCH' sem padrão agent/issue-N-* e sem 'Closes #N' no corpo"
else
  ok "S5: branch=$HEAD_BRANCH issue=#$ISSUE"
fi

[ -n "${ISSUE:-}" ] || exit 1

# ── S1+S4+S2: labels da issue ────────────────────────────────
LABELS=$(gh issue view "$ISSUE" --json labels --jq '[.labels[].name] | join(" ")' 2>/dev/null) \
  || { fail "issue #$ISSUE inacessível"; exit 1; }
say "  labels da issue #$ISSUE: ${LABELS:-<nenhuma>}"

echo "$LABELS" | grep -qw "agent:working" \
  && ok "S1: issue em agent:working" \
  || fail "S1: issue #$ISSUE não está em agent:working"

echo "$LABELS" | grep -qw "agent:blocked" \
  && fail "S4: issue ainda marcada agent:blocked" \
  || ok "S4: sem agent:blocked"

echo "$LABELS" | grep -qw "human-gate" \
  && fail "S4: human-gate ainda presente — precisa de liberação registrada" \
  || ok "S4: sem human-gate pendente"

EXECUTOR=$(echo "$LABELS" | grep -oE 'agent:executor:[a-z-]+' | head -1 | cut -d: -f3)
if [ -z "$EXECUTOR" ]; then
  fail "S2: issue sem label agent:executor:*"
else
  ok "S2: executor autorizado = $EXECUTOR"
fi

# ── S3: comentário CLAIM ─────────────────────────────────────
CLAIM=$(gh issue view "$ISSUE" --json comments \
  --jq '[.comments[].body | select(startswith("CLAIM"))] | last // empty' 2>/dev/null)
if [ -z "$CLAIM" ]; then
  fail "S3: nenhum comentário CLAIM na issue"
else
  ok "S3: CLAIM presente"
  CLAIM_BRANCH=$(echo "$CLAIM" | sed -n 's/^branch: *\([^ ]*\).*/\1/p' | head -1)
  if [ -n "$CLAIM_BRANCH" ] && [ "$CLAIM_BRANCH" != "$HEAD_BRANCH" ]; then
    fail "S3: branch do CLAIM ($CLAIM_BRANCH) ≠ head do PR ($HEAD_BRANCH)"
  fi
fi

# ── S6: paths do diff ⊆ paths declarados ─────────────────────
CLAIM_PATHS=$(echo "${CLAIM:-}" | sed -n 's/^paths: *//p' | head -1)
if [ -z "$CLAIM_PATHS" ]; then
  warn "S6: CLAIM não declara paths — conferência de escopo não executável"
else
  CHANGED=$(gh pr diff "$PR" --name-only 2>/dev/null | sort)
  OFFSCOPE=""
  IFS=',' read -ra ALLOWED <<< "$CLAIM_PATHS"
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    HIT=0
    for p in "${ALLOWED[@]}"; do
      p=$(echo "$p" | xargs) # trim
      case "$f" in "$p"|"$p"/*|*"$p"*) HIT=1;; esac
    done
    [ "$HIT" = 0 ] && OFFSCOPE="$OFFSCOPE $f"
  done <<< "$CHANGED"
  if [ -n "$OFFSCOPE" ]; then
    warn "S6: arquivos fora do escopo declarado:${OFFSCOPE} — exige justificativa"
  else
    ok "S6: diff dentro dos paths declarados"
  fi
fi

# ── S7: CI verde ─────────────────────────────────────────────
# statusCheckRollup: conclusion = SUCCESS|FAILURE|…, status = COMPLETED|…
CHECKS=$(gh pr view "$PR" --json statusCheckRollup --jq '.statusCheckRollup' 2>/dev/null)
TOTAL=$(echo "${CHECKS:-null}" | jq -r 'if type == "array" then length else 0 end' 2>/dev/null)
PENDING=$(echo "${CHECKS:-[]}" | jq -r '[.[] | select(.status != "COMPLETED")] | length' 2>/dev/null)
FAILED=$(echo "${CHECKS:-[]}" | jq -r '[.[] | select(.status == "COMPLETED" and .conclusion != "SUCCESS" and .conclusion != "NEUTRAL" and .conclusion != "SKIPPED")] | length' 2>/dev/null)
TOTAL=${TOTAL:-0}; PENDING=${PENDING:-0}; FAILED=${FAILED:-0}
if [ "$TOTAL" = 0 ]; then
  fail "S7: nenhum check reportado — pipeline ausente é incerteza, não verde"
elif [ "$FAILED" -gt 0 ]; then
  fail "S7: $FAILED check(s) reprovado(s)"
elif [ "$PENDING" -gt 0 ]; then
  fail "S7: $PENDING check(s) ainda pendentes"
else
  ok "S7: todos os checks verdes"
fi

# ── S8: threads de revisão ───────────────────────────────────
UNRESOLVED=$(gh api graphql -f query="
  {repository(owner:\"${REPO%%/*}\",name:\"${REPO##*/}\"){
    pullRequest(number:$PR){reviewThreads(first:100){nodes{isResolved}}
  }}}" --jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved==false)] | length' 2>/dev/null)
if [ -z "$UNRESOLVED" ]; then
  warn "S8: não foi possível consultar threads — verificar manualmente"
elif [ "$UNRESOLVED" -gt 0 ]; then
  fail "S8: $UNRESOLVED thread(s) de revisão não resolvidas"
else
  ok "S8: threads resolvidas"
fi

# ── S9: gates humanos (aviso, não decide) ────────────────────
warn "S9: gates humanos/decisões D-* exigem confirmação registrada na issue — conferir antes de mergear"

if [ "$FAIL" = 1 ]; then
  say "RESULTADO: PR #$PR NÃO está em sessão autorizada para merge."
  exit 1
fi
say "RESULTADO: PR #$PR em sessão autorizada (S9 requer conferência humana)."
exit 0

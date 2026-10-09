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

# Checks de CI que o contrato do repo exige (workflow ci.yml + tooling/ci/README.md).
EXPECTED_CHECKS="ci/flutter-unit ci/flutter-analyze ci/dart-format ci/docs-integrity ci/secrets-scan"

REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null) || {
  say "erro: gh indisponível ou sem repo"; exit 1; }
say "claim_check: $REPO PR #$PR"

# ── Dados do PR ──────────────────────────────────────────────
PR_JSON=$(gh pr view "$PR" --json state,headRefName,baseRefName,body \
          --jq '{state,head:.headRefName,base:.baseRefName,body}' 2>/dev/null) \
  || { fail "PR #$PR inacessível"; exit 1; }

[ "$(echo "$PR_JSON" | jq -r '.state')" = "OPEN" ] || fail "PR não está OPEN"
HEAD_BRANCH=$(echo "$PR_JSON" | jq -r '.head')
BASE_BRANCH=$(echo "$PR_JSON" | jq -r '.base')
BODY=$(echo "$PR_JSON" | jq -r '.body')

# Contrato do repo: PRs de agente integram em main salvo declaração explícita
# diferente na issue. Fora disso, o trem não toca.
if [ "$BASE_BRANCH" != "main" ]; then
  fail "S0: base do PR é '$BASE_BRANCH' — contrato exige main"
fi

# ── S5: branch segue o padrão e identifica a issue ───────────
# Sem fallback por 'Closes #N': a convenção de branch é mandatória —
# fora do padrão o gate reprova, não infere.
ISSUE=$(echo "$HEAD_BRANCH" | sed -n 's/^agent\/issue-\([0-9]*\)-.*/\1/p')
if [ -z "$ISSUE" ]; then
  fail "S5: branch '$HEAD_BRANCH' fora do padrão agent/issue-N-*"
  exit 1
fi
ok "S5: branch=$HEAD_BRANCH issue=#$ISSUE"

# ── S1+S4+S2: labels da issue ────────────────────────────────
LABELS=$(gh issue view "$ISSUE" --json labels --jq '[.labels[].name] | join(" ")' 2>/dev/null) \
  || { fail "issue #$ISSUE inacessível"; exit 1; }
say "  labels da issue #$ISSUE: ${LABELS:-<nenhuma>}"

# agent:working = em execução; agent:review = entregue, aguardando integração
# (handoff move a issue para review ANTES do merge — exigir working aqui
# reprovaria todo PR que seguiu o protocolo).
if echo "$LABELS" | grep -qw "agent:working" || echo "$LABELS" | grep -qw "agent:review"; then
  ok "S1: issue em agent:working/agent:review"
else
  fail "S1: issue #$ISSUE não está em agent:working nem agent:review"
fi

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
  # S2b: o executor que claimou precisa bater com o executor autorizado.
  CLAIM_EXEC=$(echo "$CLAIM" | sed -n 's/^executor: *\([^ ]*\).*/\1/p' | head -1)
  if [ -n "$EXECUTOR" ] && [ -n "$CLAIM_EXEC" ]; then
    if [ "$EXECUTOR" != "any" ] && [ "$CLAIM_EXEC" != "$EXECUTOR" ]; then
      fail "S2b: CLAIM é de '$CLAIM_EXEC' mas issue autoriza '$EXECUTOR'"
    else
      ok "S2b: claimant ($CLAIM_EXEC) confere com executor autorizado"
    fi
  elif [ -z "$CLAIM_EXEC" ]; then
    fail "S2b: CLAIM não declara executor — claimant não verificável"
  fi
fi

# ── S6: paths do diff ⊆ paths declarados ─────────────────────
CLAIM_PATHS=$(echo "${CLAIM:-}" | sed -n 's/^paths: *//p' | head -1)
if [ -z "$CLAIM_PATHS" ]; then
  fail "S6: CLAIM não declara paths — escopo não verificável"
else
  CHANGED=$(gh pr diff "$PR" --name-only 2>/dev/null | sort)
  OFFSCOPE=""
  IFS=',' read -ra ALLOWED <<< "$CLAIM_PATHS"
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    HIT=0
    for p in "${ALLOWED[@]}"; do
      p=$(echo "$p" | xargs) # trim
      # prefixo de diretório ('docs/') ou arquivo exato — não substring solta
      case "$p" in
        */) [ "${f#"$p"}" != "$f" ] && HIT=1 ;;
        *)  [ "$f" = "$p" ] && HIT=1 ;;
      esac
    done
    [ "$HIT" = 0 ] && OFFSCOPE="$OFFSCOPE $f"
  done <<< "$CHANGED"
  if [ -n "$OFFSCOPE" ]; then
    fail "S6: arquivos fora do escopo declarado:${OFFSCOPE}"
  else
    ok "S6: diff dentro dos paths declarados"
  fi
fi

# ── S7: CI verde — os checks esperados do repo, não qualquer rollup ──
# statusCheckRollup mistura CheckRun (status/conclusion) e StatusContext
# (state). Um check run conta como verde se COMPLETED+SUCCESS/NEUTRAL/
# SKIPPED; um status context conta se state==SUCCESS.
CHECKS=$(gh pr view "$PR" --json statusCheckRollup --jq '.statusCheckRollup' 2>/dev/null)
EVAL=$(echo "${CHECKS:-null}" | jq -r '
  if type != "array" then "0 0 0" else
    ([.[] | select(
       (.state // "" | ascii_upcase | IN("PENDING","EXPECTED","QUEUED"))
       or ((.state == null) and (.status != "COMPLETED"))
     )] | length) as $pending |
    ([.[] | select(
       (.state // "" | ascii_upcase | IN("FAILURE","ERROR"))
       or ((.state == null) and (.status == "COMPLETED")
           and ((.conclusion // "") | IN("SUCCESS","NEUTRAL","SKIPPED") | not))
     )] | length) as $failed |
    "\(length) \($pending) \($failed)"
  end' 2>/dev/null)
read -r TOTAL PENDING FAILED <<< "${EVAL:-0 0 0}"
TOTAL=${TOTAL:-0}; PENDING=${PENDING:-0}; FAILED=${FAILED:-0}
if [ "$TOTAL" = 0 ]; then
  fail "S7: nenhum check reportado — pipeline ausente é incerteza, não verde"
elif [ "$FAILED" -gt 0 ]; then
  fail "S7: $FAILED check(s) reprovado(s)"
elif [ "$PENDING" -gt 0 ]; then
  fail "S7: $PENDING check(s) ainda pendentes"
else
  ok "S7: todos os checks reportados verdes"
  # S7b: os checks esperados pelo contrato precisam estar presentes —
  # um rollup verde sem a pipeline do repo não prova nada.
  NAMES=$(echo "$CHECKS" | jq -r '.[].name // .[].context // empty' 2>/dev/null | sort -u)
  MISSING=""
  for want in $EXPECTED_CHECKS; do
    echo "$NAMES" | grep -qx "$want" || MISSING="$MISSING $want"
  done
  if [ -n "$MISSING" ]; then
    fail "S7b: checks esperados ausentes no rollup:${MISSING}"
  else
    ok "S7b: pipeline do repo completa (flutter/analyze/format/docs/secrets)"
  fi
fi

# ── S8: threads de revisão — ilegível reprova (fail-closed) ──
UNRESOLVED=$(gh api graphql -f query="
  {repository(owner:\"${REPO%%/*}\",name:\"${REPO##*/}\"){
    pullRequest(number:$PR){reviewThreads(first:100){nodes{isResolved}}
  }}}" --jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved==false)] | length' 2>/dev/null)
if [ -z "$UNRESOLVED" ]; then
  fail "S8: threads ilegíveis (erro de API/permissão) — incerteza não é autorização"
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

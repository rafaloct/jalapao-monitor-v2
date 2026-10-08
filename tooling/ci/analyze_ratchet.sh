#!/usr/bin/env bash
# Ratchet de `flutter analyze` (plano de CI §4.2):
# - falha se a contagem de achados exceder o baseline versionado;
# - falha se houver qualquer diagnostico de severidade `error`, mesmo dentro do limiar;
# - achados info/warning ate o baseline sao reportados sem reprovar (divida registrada).
# Nao e continue-on-error: e um limiar explicito, versionado e revisavel.
set -u

BASELINE_FILE="$(dirname "$0")/analyze_baseline.txt"
BASELINE=$(tr -d '[:space:]' < "$BASELINE_FILE")

OUT=$(flutter analyze 2>&1)
ANALYZE_EXIT=$?
echo "$OUT"

COUNT=$(echo "$OUT" | grep -oE '[0-9]+ issues? found' | grep -oE '^[0-9]+' | head -1)
COUNT=${COUNT:-0}
ERRORS=$(echo "$OUT" | grep -cE '^\s*error\s' || true)

echo "ratchet: achados=$COUNT baseline=$BASELINE erros=$ERRORS analyze_exit=$ANALYZE_EXIT"

if [ "$ERRORS" -gt 0 ]; then
  echo "RATCHET FAIL: diagnosticos de erro presentes" >&2
  exit 1
fi
if [ "$COUNT" -gt "$BASELINE" ]; then
  echo "RATCHET FAIL: $COUNT achados excedem baseline $BASELINE" >&2
  exit 1
fi
exit 0

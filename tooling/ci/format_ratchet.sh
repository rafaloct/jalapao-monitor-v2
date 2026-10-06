#!/usr/bin/env bash
# Ratchet de `dart format` (plano de CI §4.2):
# - falha se algum arquivo FORA do baseline versionado precisar de formatacao;
# - arquivos do baseline que forem formatados sao progresso, nunca falha.
# Nao e continue-on-error: e um limiar explicito, versionado e revisavel.
set -u

BASELINE_FILE="$(dirname "$0")/format_baseline.txt"

CURRENT=$(dart format --output=none --set-exit-if-changed lib test integration_test 2>&1 \
  | grep '^Changed ' | sed 's/^Changed //' | sort)
NEW_FILES=$(comm -23 <(echo "$CURRENT") <(sort "$BASELINE_FILE") | sed '/^$/d')

echo "ratchet: arquivos nao formatados fora do baseline:"
echo "${NEW_FILES:-<nenhum>}"

if [ -n "$NEW_FILES" ]; then
  echo "RATCHET FAIL: novos arquivos sem formatacao" >&2
  exit 1
fi
exit 0

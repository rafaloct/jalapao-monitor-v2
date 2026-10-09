#!/usr/bin/env bash
# Sobe um PocketBase EFÊMERO com o schema real (ops/pocketbase/pb_migrations)
# + dados sintéticos, para rodar a baseline E2E sem device físico e sem
# tocar no backend de produção.
#
# Uso:
#   PB_BIN=/caminho/pocketbase ./ops/pocketbase/seed_ci.sh
#
# Depois:  flutter test integration_test/baseline_operational_walkthrough.dart \
#            -d emulator-5554 \
#            --dart-define=PB_URL=http://10.0.2.2:8090 \
#            --dart-define=TEST_GESTOR_EMAIL=gestor-e2e@example.invalid \
#            --dart-define=TEST_GESTOR_PASSWORD=e2e-gestor-sintetico
set -euo pipefail

PB_BIN=${PB_BIN:-pocketbase}
PB_DIR=${PB_DIR:-/tmp/jalapao-e2e-pbdata}
PB_ADDR=${PB_ADDR:-127.0.0.1:8090}
MIGRATIONS_DIR="$(cd "$(dirname "$0")" && pwd)/pb_migrations"
LOG=${PB_LOG:-/tmp/jalapao-e2e-pb.log}

ADMIN_EMAIL="ci-admin@example.invalid"
ADMIN_PASS="ci-superuser-not-secret"
TEST_EMAIL="gestor-e2e@example.invalid"
TEST_PASS="e2e-gestor-sintetico"

rm -rf "$PB_DIR"
mkdir -p "$PB_DIR"

echo "[seed] aplicando migrations ($MIGRATIONS_DIR)"
"$PB_BIN" migrate up --dir="$PB_DIR" --migrationsDir="$MIGRATIONS_DIR"

echo "[seed] criando superuser sintético"
"$PB_BIN" superuser create "$ADMIN_EMAIL" "$ADMIN_PASS" --dir="$PB_DIR" >/dev/null

echo "[seed] subindo PocketBase em $PB_ADDR (log: $LOG)"
"$PB_BIN" serve --http="$PB_ADDR" --dir="$PB_DIR" --migrationsDir="$MIGRATIONS_DIR" \
  >"$LOG" 2>&1 &
echo $! > /tmp/jalapao-e2e-pb.pid

for i in $(seq 1 30); do
  curl -sf "http://$PB_ADDR/api/health" >/dev/null 2>&1 && break
  sleep 1
  [ "$i" = 30 ] && { echo "[seed] ERRO: PB não subiu"; cat "$LOG"; exit 1; }
done

TOKEN=$(curl -sf -X POST "http://$PB_ADDR/api/collections/_superusers/auth-with-password" \
  -H 'Content-Type: application/json' \
  -d "{\"identity\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASS\"}" | python3 -c 'import json,sys;print(json.load(sys.stdin)["token"])')

echo "[seed] usuário gestor sintético"
curl -sf -X POST "http://$PB_ADDR/api/collections/users/records" \
  -H "Authorization: $TOKEN" -H 'Content-Type: application/json' \
  -d "{\"email\":\"$TEST_EMAIL\",\"password\":\"$TEST_PASS\",\"passwordConfirm\":\"$TEST_PASS\",\"role\":\"coordenador\",\"name\":\"Gestor E2E\"}" >/dev/null

echo "[seed] locais sintéticos (status=active)"
seed_place() {
  curl -sf -X POST "http://$PB_ADDR/api/collections/places/records" \
    -H "Authorization: $TOKEN" -H 'Content-Type: application/json' \
    -d "{\"name\":\"$1\",\"type\":\"$2\",\"latitude\":-10.4,\"longitude\":-46.6,\"capacity_total\":$3,\"owner_name\":\"E2E CI\",\"status\":\"active\",\"created_at_v2\":\"2026-01-01 12:00:00.000Z\"}" >/dev/null
}
seed_place "Fervedouro da Ceiça"    fervedouro 10
seed_place "Cachoeira da Formiga"   cachoeira  100
seed_place "Pousada E2E"            pousada    30

echo "[seed] OK — PB efêmero no ar em http://$PB_ADDR (pid $(cat /tmp/jalapao-e2e-pb.pid))"
echo "[seed] credenciais sintéticas: $TEST_EMAIL / $TEST_PASS"

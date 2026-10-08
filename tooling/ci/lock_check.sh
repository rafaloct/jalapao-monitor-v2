#!/usr/bin/env bash
# Verifica que `flutter pub get` não reescreve pubspec.lock.
# Via A do plano de CI (§4.5): reproduzibilidade comprovada sob Flutter 3.29.3.
set -euo pipefail

flutter pub get
git diff --exit-code pubspec.lock
echo "lock_check: pubspec.lock imutavel sob o SDK pinado"

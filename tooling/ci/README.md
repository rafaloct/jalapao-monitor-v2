# CI — jobs, origem e read-back

Implementação da [Issue #21](https://github.com/rafaloct/jalapao-monitor-v2/issues/21),
conforme plano de CI aprovado pelo mantenedor na
[Issue #3](https://github.com/rafaloct/jalapao-monitor-v2/issues/3#issuecomment-6025431674)
(`CI_PLAN.md`/`CI_BASELINE.md`, HEAD `300223c` do PR #30, `PROPOSED` integrado).

## SDK pinado — Via A comprovada

`flutter-version: '3.29.3'` (stable). Evidência executada neste checkout:

- `flutter pub get` sob 3.29.3 → `pubspec.lock` **imutável** (`git diff` vazio).
- Sob Flutter 3.44.9/Dart 3.12.2, o mesmo comando re-resolve 10 pins de pacotes
  bundleados do SDK — combinação não reproduzível, por isso não pinada.
- `flutter test test/models` sob 3.29.3 → **35/35 PASS**.

## Jobs (o nome do check é o do job)

| Check | Job | Conteúdo | Regime |
| --- | --- | --- | --- |
| `ci/flutter-unit` | flutter-unit | `lock_check.sh` (pub get + diff do lock) + `flutter test test/models` | Gate real — falha reprova |
| `ci/flutter-analyze` | flutter-analyze | `flutter analyze` via `analyze_ratchet.sh` | Ratchet: falha se achados > 103 ou qualquer `error` |
| `ci/dart-format` | dart-format | `dart format` via `format_ratchet.sh` | Ratchet: falha se arquivo fora do baseline precisar de formato |
| `ci/docs-integrity` | docs-integrity | `git diff --check origin/main...HEAD` | Gate real |
| `ci/secrets-scan` | secrets-scan | `gitleaks/gitleaks-action` | Gate real |

Baselines medidos sob 3.29.3 neste SHA: analyze **103 achados**
(`analyze_baseline.txt`), formato **24 arquivos** (`format_baseline.txt`).
São dívidas pré-existentes registradas — zerá-las é tarefa própria, não desta issue.

## Fora de qualquer gate (componentes bloqueados)

- **Android build:** sem wrapper `gradlew`/SDK reproduzível (B3).
- **Hub:** scaffold ainda não recuperado/reconstruído (B4, #22).
- **Integração:** exige backend efêmero e isolamento (B5, CI_PLAN §5).
- **Contratos:** aguardam implementação da arquitetura aprovada.

Nenhum destes aparece como validado.

## Read-back para o mantenedor

- Workflow: `.github/workflows/ci.yml` — triggers `pull_request`/`push` para `main`,
  `permissions: contents: read`, `concurrency` com cancel-in-progress, timeouts por job.
- Nenhum secret de produção é usado; `pull_request` (não `pull_request_target`).
- Os nomes acima são os checks que aparecerão nos PRs. A exigência de status
  obrigatório na proteção de branch é ato administrativo do mantenedor — este
  documento é o read-back de nomes/origem exigido pelo aceite da #21.

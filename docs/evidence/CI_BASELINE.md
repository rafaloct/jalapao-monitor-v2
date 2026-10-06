# Evidência de baseline para o plano de CI — Issue #20

Consolida os resultados **executados** que fundamentam cada verificação proposta
em [`docs/operations/CI_PLAN.md`](../operations/CI_PLAN.md). Fonte primária:
`docs/evidence/BASELINE_EXECUTION.md` entregue pela #17 no
[PR #27](https://github.com/rafaloct/jalapao-monitor-v2/pull/27) (em revisão;
valores reproduzidos aqui sem presumir integração).

Base observada: `main @ a6d9bfe1507f9d75e6d4a872c17501c435204634`.

## 1. Comandos com resultado real

| Comando | Exit | Resultado | Implicação para CI |
|---|---|---|---|
| `flutter pub get` | 0 | PASS | Executável em runner; lock re-resolve 10 pins transitivos sob Dart 3.12.2 — ver §3 |
| `flutter test test/models` | 0 | PASS — 35/35 | Candidato a **primeiro gate obrigatório** (`ci/flutter-unit`) |
| `flutter analyze` | 1 | 0 erros, 1 warning, 103 info — pré-existentes | Não pode ser gate "verde" hoje; política de ratchet em CI_PLAN §4.2 |
| `dart format --set-exit-if-changed` | — | NOT_RUN (dívida de formato presumida) | Mesmo tratamento do analyze |
| `git diff --check` | 0 | PASS nos PRs observados | Gate de integridade documental simples |

## 2. Ambiente de referência

| Ferramenta | Versão testada (observada) | Mínimo compatível (lock) |
|---|---|---|
| Flutter | 3.44.9 stable | >=3.29.0 |
| Dart | 3.12.2 | >=3.7.0 <4.0.0 |
| Java | OpenJDK 17.0.19 | Java 17 (`app/build.gradle.kts`) |
| Node.js | v24.19.0 | >=18 (doc; Hub sem scaffold) |
| Android SDK | **ausente** | AGP 8.11.1 / Gradle 8.14 / NDK 27.0.12077973 |

Versão **testada** é a pin proposta para o runner; mínimo do lock é compatibilidade
declarada, não validação. Distinção exigida pelo aceite da #20.

## 3. Falhas e bloqueios que o plano não ignora

| # | Item | Tipo | Tratamento proposto no plano |
|---|---|---|---|
| B1 | `flutter analyze` exit 1 (104 achados) | Falha pré-existente | Job executa e reporta; ratchet falha se contagem **aumentar**; gate obrigatório só após dívida zerada em tarefa delimitada — sem `continue-on-error` |
| B2 | `pubspec.lock` re-resolve sob SDK divergente | Reprodutibilidade | Pin do SDK testado; verificação de lock imutável (`pub get` + diff) vira gate **após** tarefa de reconciliação lock×SDK — hoje falharia legitimamente |
| B3 | Android SDK + wrappers `gradlew*` ausentes | Bloqueio ambiente/checkout | Android fora do gate até bootstrap versionado |
| B4 | Hub sem `package.json`/lockfile/tsconfig | Lacuna checkout | Hub fora do gate até #22 |
| B5 | `integration_test/` sem isolamento | Risco de falso verde | Só com backend/armazenamento efêmero, assertions e limites (CI_PLAN §5) |
| B6 | Sem `.github/workflows/` | Lacuna | Toda verificação é proposta; nenhum check existe hoje |

## 4. Triggers e ambiente propostos

- `pull_request` → `main` e `push` → `main` (nunca `pull_request_target` para
  código de PR; ver política de segurança em CI_PLAN §4.3).
- Runner `ubuntu-latest` + `subosito/flutter-action` com versão pinada da §2.
- Limites de tempo por job (docs ≤5 min, unit ≤15 min) e `concurrency` com
  cancel-in-progress por ref de PR.

## 5. O que ainda depende de aprovação ou tarefa externa

- Aprovação humana do plano (pré-condição da #21).
- Tarefa de dívida de analyze/format (B1) e reconciliação do lock (B2).
- #22 (scaffold do Hub), bootstrap Android, ADR #18 e matriz #19 (contratos),
  backend efêmero para integração (B5).

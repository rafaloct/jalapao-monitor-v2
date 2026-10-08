# Evidência de execução do baseline — Issue #17

Reprodução do checkout `main` em ambiente isolado e descartável.
Executor: Devin (`devin-ai-integration`), sessão `devin-cd1ba99c483b4c708c9e6e813f40db66`.
Claim registrado em [#17](https://github.com/rafaloct/jalapao-monitor-v2/issues/17).

Esta evidência distingue inspeção estática, execução real, bloqueio de ambiente e falha de código.
`PASS` indica execução observada nesta sessão; não é declaração de prontidão de produção.

## 1. Referência do checkout

| Item | Valor |
|---|---|
| Repositório | `rafaloct/jalapao-monitor-v2` |
| Base observada (`main`) | `a6d9bfe1507f9d75e6d4a872c17501c435204634` |
| Branch de trabalho | `agent/issue-17-baseline-flutter` |
| Escopo alterado | somente `docs/evidence/BASELINE_EXECUTION.md` |
| `pubspec.lock` versionado (blob em HEAD) | `598b6375e611a38192451bad064fa29d137c9dc4` |

## 2. Ambiente real de execução

Versões instaladas e observadas nesta sessão (Linux x86_64, VM descartável):

| Ferramenta | Versão observada | Fonte |
|---|---|---|
| Flutter | `3.44.9` (stable, revision `6b182d2c75`, engine `b9499e4c25212536ba3a4eec4f5c1905fb3214fe`) | `flutter --version` |
| Dart | `3.12.2` (stable) | `dart --version` |
| DevTools | `2.57.0` | `flutter --version` |
| Java | OpenJDK `17.0.19` | `java --version` |
| Node.js | `v24.19.0` | `node --version` |
| npm | `10.8.3` | `npm --version` |
| Android SDK | **ausente** (`ANDROID_HOME`/`ANDROID_SDK_ROOT` vazios) | inspeção do ambiente |

Os mínimos do `pubspec.lock`/`pubspec.yaml` — Dart `>=3.7.0 <4.0.0`, Flutter `>=3.29.0` — foram atendidos pelo ambiente acima. São constraints do lock, **não** uma versão validada de referência; a combinação exata a fixar permanece decisão posterior.

## 3. Comandos executados e resultados

Ordem real, no checkout isolado:

| # | Comando | Exit code | Resultado |
|---|---|---|---|
| 1 | `flutter pub get` | `0` | **PASS** — dependências resolvidas dentro das constraints |
| 2 | `flutter analyze` | `1` | **Achados pré-existentes** — 104 ocorrências: 0 erros, 1 warning, 103 info |
| 3 | `flutter test test/models` | `0` | **PASS** — 35/35 testes executados e aprovados |

### 3.1 `flutter pub get`

Exit `0`. Observação de reprodutibilidade: sob Dart `3.12.2`, o resolvedor atualizou
10 pins transitivos no `pubspec.lock` da worktree (ex.: `characters 1.4.0→1.4.1`,
`leak_tracker 10.0.8→11.0.2`, `vector_math 2.1.4→2.2.0`; 21 linhas alteradas).
As versões novas respeitam as constraints declaradas, mas o lock **não é estável
entre versões de SDK**: o blob versionado (`598b637…`) diverge do resolvido
(`187df5e4…`). O arquivo foi restaurado antes do commit — nenhum manifest ou
dependência foi alterado neste PR.

### 3.2 `flutter analyze`

Exit `1` com 104 ocorrências, todas pré-existentes no SHA observado:

- `error`: **0**
- `warning`: **1** — `unused_field`: `_longitude` em `lib/screens/place_form_screen.dart:30`
- `info`: **103** — majoritariamente `deprecated_member_use` (`withOpacity` em várias
  telas, `background` em `lib/theme/jalapao_theme.dart`), `use_build_context_synchronously`
  e `no_leading_underscores_for_local_identifiers` nos testes

Classificação: **falha de lint/estilo existente, não erro de compilação.** Exit `1`
reflete a política do analyzer (info conta para o exit code), não um código quebrado.
Nenhum achado foi corrigido — fora do escopo desta issue.

### 3.3 `flutter test test/models`

Exit `0`, saída final `All tests passed!`. Execução real observada: **35 testes**.

Conferência estática das chamadas `test(` no SHA base:

| Arquivo | test() estáticos | Executados |
|---|---:|---:|
| `test/models/place_test.dart` | 10 | 10 |
| `test/models/place_visit_test.dart` | 10 | 10 |
| `test/models/reservation_test.dart` | 9 | 9 |
| `test/models/visit_test.dart` | 6 | 6 |
| **Total** | **35** | **35** |

## 4. Inventário confirmado nesta execução

### Hub (`hub/`) — scaffold ausente, execução não reproduzível

Presentes: `hub/README.md`, `hub/src/app/page.tsx`, `hub/src/components/PlacesTab.tsx`,
`hub/src/lib/{pb,places-service,types,tz}.ts`.

Ausentes (verificado nesta execução): `package.json`, qualquer lockfile
(`package-lock.json`/`yarn.lock`/`pnpm-lock.yaml`), `tsconfig.json`,
`next.config.*`, `tailwind.config.*`, `postcss.config.*`, `src/app/layout.tsx`.

Resultado: **NOT_RUN** — `npm install`/`build` não são reproduzíveis neste checkout;
recuperação de scaffold pertence à #22. Nada foi inferido ou gerado.

### Bootstrap Android — wrappers não versionados

Ausentes: `android/gradlew`, `android/gradlew.bat`,
`android/gradle/wrapper/gradle-wrapper.jar` — os três ignorados por `android/.gitignore`.

Presentes: `gradle-wrapper.properties` (Gradle 8.14), `settings.gradle.kts`
(AGP 8.11.1, Kotlin 2.2.20), `app/build.gradle.kts` (Java 17, NDK 27.0.12077973).

Resultado: **BLOCKED (ambiente)** — sem Android SDK instalado e sem wrapper
versionado, `./gradlew` não pode ser invocado a partir do checkout. A geração do
wrapper pelo SDK Flutter não foi demonstrada nesta sessão e não foi presumida.

### Backend e infraestrutura

Não existem `pb_migrations/`, `pb_hooks/`, compose ou provisionamento versionados
(verificado na árvore). Estado do serviço PocketBase existente: **NOT_VERIFIED** —
nenhum backend real foi contatado, conforme escopo.

### CI

`.github/workflows/` ausente — nenhum workflow existe no SHA observado.
Não há check marcado como verde por ausência de jobs; implementação pertence à #21.

### Cartografia

Nenhum módulo de cartografia existe no checkout. Registrado como limite do
checkout, sem inferir implementação.

## 5. Não executado nesta tarefa (por escopo)

| Item | Estado | Motivo |
|---|---|---|
| `integration_test/` (4 cenários) | `NOT_RUN` | Escopo da issue: cenários abrem o app, usam `pumpAndSettle` e podem iniciar sync; não demonstram isolamento |
| `run_baseline_only.ps1`, `capture_screens.ps1` | `NOT_RUN` | Scripts de captura em dispositivo; fora de escopo e dependentes de hardware |
| App em dispositivo/emulador | `NOT_RUN` | Sem Android SDK; proibido pelo escopo |
| Build Android (debug/release) | `NOT_RUN` | Wrapper e SDK ausentes; assinatura debug não prova distribuição |
| Hub (`npm install`/`build`) | `NOT_RUN` | Scaffold ausente (#22) |
| PocketBase real | `NOT_RUN` | Sem provisionamento versionado; backend real fora de escopo |

## 6. Falhas e bloqueios registrados

| Tipo | Item | Descrição |
|---|---|---|
| Falha de código (pré-existente) | `flutter analyze` exit 1 | 104 achados de lint (0 erros); correção fora do escopo |
| Bloqueio de ambiente | Android SDK | Ausente na VM; impede validar bootstrap Gradle |
| Lacuna do checkout | Hub sem scaffold | Sem manifest/lockfile; build irreproduzível (#22) |
| Lacuna do checkout | Wrappers Android | `gradlew*`/jar ignorados pelo `.gitignore`; bootstrap não demonstrado |
| Reprodutibilidade | `pubspec.lock` | Pins transitivos re-resolvem sob SDK distinto; registrar versão de SDK ao fixar baseline |

## 7. Conclusão

Em `main @ a6d9bfe`, com Flutter 3.44.9 / Dart 3.12.2: `pub get` **PASS**,
`flutter test test/models` **PASS** (35/35, confere com a contagem estática),
`flutter analyze` reporta achados pré-existentes sem erro de compilação.
Hub, Android e backend permanecem **NOT_RUN/BLOCKED** pelas lacunas registradas.

Esta evidência não autoriza merge, deploy, nem o uso das versões observadas como
pin oficial de CI (#20/#21). `MERGE_ALLOWED=NO`. `PRODUCTION_ALLOWED=NO`.

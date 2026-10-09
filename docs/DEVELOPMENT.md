# Desenvolvimento do Jalapão Monitor

## Começar pelo estado real

Leia [AGENTS.md](../AGENTS.md), a issue escolhida e o [baseline do checkout](operations/REPOSITORY_BASELINE.md).
A preparação #16 altera documentação e governança. A reprodução do ambiente é a [#17](https://github.com/rafaloct/jalapao-monitor-v2/issues/17); a arquitetura futura é proposta na #18 e aprovada na #2.

Não usar exemplos históricos de VPS, scripts de captura ou credenciais de campo para preparar um agente.

## Ferramentas

| Componente | Requisito observado | Estado |
| --- | --- | --- |
| Dart | `>=3.7.0 <4.0.0` em pubspec/lock | Mínimo declarado; versão exata a comprovar |
| Flutter | `>=3.29.0` em pubspec.lock | Mínimo declarado; versão exata a comprovar |
| Java | 17 no build Android | Ambiente a reproduzir |
| Android | SDKs derivados do Flutter; NDK 27.0.12077973 | Bootstrap a validar; não fixar API por suposição |
| Gradle | 8.14 no wrapper properties | Scripts/JAR não versionados no baseline |
| Hub | Next.js 14.2.3 / React 18 / TS5 | Scaffold recuperado (#22); `npm ci` reproduzível |

Os mínimos acima não são uma combinação já testada. Não atualizar dependências para a versão mais recente sem escopo próprio.

## Baseline inicial sem backend

Em checkout/worktree isolado, registrar o SHA e as versões das ferramentas. Para a #17:

```bash
flutter --version
dart --version
flutter pub get
flutter analyze
flutter test test/models
```

Existem 35 declarações de teste de modelos. Registrar a quantidade realmente executada, comandos, exit codes e falhas. A execução ainda não está comprovada por este guia.
A #17 só pode escrever `docs/evidence/BASELINE_EXECUTION.md`; não alterar código ou manifests para esconder falhas.

## Configuração e integração

A URL do PocketBase é definida por `PB_URL` em `lib/config/app_config.dart`. O default de código no baseline é loopback HTTP, e regras de rede Android/documentação histórica divergem. Usar uma URL explícita de ambiente sintético e preparar o encaminhamento de rede apropriado antes de executar app ou integração.

Para builds por ambiente (staging/produção), use `--dart-define-from-file` com `env/<ambiente>.local.json` — ver [operations/ENVIRONMENTS.md](operations/ENVIRONMENTS.md). Nenhuma credencial entra no build (modelo da #24).

Os cenários em `integration_test/` abrem o app/Hive e podem iniciar sincronização. Eles não são o comando padrão de setup: primeiro é necessário isolar armazenamento, backend, dados e assertions em tarefa autorizada. Os scripts `run_baseline_only.ps1` e `capture_screens.ps1` também contêm configuração específica de máquina e não são bootstrap portátil.

`pumpAndSettle` pode conflitar com timers de sync. Novos cenários devem esperar condições observáveis e usar limites de tempo; ausência de exceção ou screenshot não substitui assertion funcional.

## Build Android

Os arquivos Gradle e o manifest principal estão presentes, mas os scripts/JAR do wrapper não estão versionados. A #17 deve verificar como o ambiente Flutter prepara esse bootstrap; não declarar o build aprovado sem executá-lo.

O bloco release atual usa configuração de assinatura debug. Um APK técnico gerado assim não é uma release de distribuição. Configurar assinatura, instalar em tablet de campo e publicar exigem tarefa e autorização específicas.

Existem flavors `staging`/`production` (#39): staging instala como pacote `.staging` com estado isolado. Build por ambiente via `--flavor` + `--dart-define-from-file` — ver [operations/ENVIRONMENTS.md](operations/ENVIRONMENTS.md).

## Hub

O scaffold foi recuperado na [#22](https://github.com/rafaloct/jalapao-monitor-v2/issues/22) — `npm ci`, `npm run lint` e `npm run build` são reproduzíveis (proveniência em `docs/evidence/HUB_SCAFFOLD_PROVENANCE.md`):

```bash
cd hub && cp .env.example .env.local && npm ci && npm run dev
```

Separar variáveis públicas de credenciais. Nunca usar uma variável `NEXT_PUBLIC_*` para senha ou token secreto, pois ela pertence à configuração entregue ao cliente. `NEXT_PUBLIC_PB_URL` carrega somente a URL pública do backend.

## Backend

O schema está descrito em [POCKETBASE_SCHEMA.md](POCKETBASE_SCHEMA.md), mas o checkout não contém provisionamento/migrations suficientes para reproduzir ou atestar o serviço existente.

Nenhum guia local autoriza alterar regras de collection, usar superuser em cliente, consultar dados de campo ou fazer deploy. A matriz da #19 está aprovada (ata na #13, 2026-10-06) — implementações de API devem segui-la.

O fallback literal de PIN de `lib/services/auth_service.dart` foi removido na [#24](https://github.com/rafaloct/jalapao-monitor-v2/issues/24) (PR #38) — autenticação exclusiva por conta PocketBase, com transição/rotação documentada em `docs/security/CREDENTIAL_TRANSITION.md`.

## Paths técnicos reais

| Área | Caminhos |
| --- | --- |
| Entrada do app | `lib/main.dart` |
| Modelos | `lib/models/place.dart`, `place_visit.dart`, `reservation.dart`, `visit.dart` |
| Estado e sync | `lib/providers/`, `lib/services/sync_service.dart` |
| Autenticação | `lib/services/auth_service.dart`, `lib/screens/gestor_login_screen.dart` |
| Hub | `hub/src/app/page.tsx`, `hub/src/components/PlacesTab.tsx`, `hub/src/lib/` |

Para datas, leia [TIMEZONE_POLICY.md](TIMEZONE_POLICY.md) e use `hub/src/lib/tz.ts`. Preserve UTC no armazenamento, exibição em `America/Sao_Paulo`, `pb.autoCancellation(false)` e compatibilidade entre `visits`, `place_visits` e `reservations`.

## Entrega

Seguir o [protocolo de coordenação](operations/AGENT_COORDINATION.md) e o [plano de CI](operations/CI_PLAN.md).
A issue é a especificação da tarefa, o PR é a entrega revisável e as evidências demonstram o resultado. Merge e produção não são autorizados pelo comando de build nem pelo label ready.

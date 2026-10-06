# Baseline versionado do repositório

## 1. Fonte, alcance e estado da verificação

Repositório: [rafaloct/jalapao-monitor-v2](https://github.com/rafaloct/jalapao-monitor-v2).
Commit observado da `main`: [`a6d9bfe1507f9d75e6d4a872c17501c435204634`](https://github.com/rafaloct/jalapao-monitor-v2/commit/a6d9bfe1507f9d75e6d4a872c17501c435204634).
Este documento integra a [Issue #16](https://github.com/rafaloct/jalapao-monitor-v2/issues/16); a reprodução de SDK e testes pertence à [Issue #17](https://github.com/rafaloct/jalapao-monitor-v2/issues/17).

A inspeção leu a árvore completa do commit e os arquivos focais de configuração, documentação, código e testes. A árvore retornou sem truncamento. Nenhum build, teste, script de captura, dispositivo ou serviço PocketBase foi executado.

As divergências documentais abaixo descrevem esse SHA anterior à preparação #16. Correções nos guias deste PR não resolvem as pendências de runtime nem mudam o resultado `NOT_RUN`.

| Verificação | Estado |
|---|---|
| Inventário de arquivos e leitura dos arquivos focais | Inspeção estática concluída |
| Instalação de dependências e compatibilidade do ambiente | `NOT_RUN` |
| Format, análise, testes e build Flutter | `NOT_RUN` |
| Instalação, typecheck, testes e build do Hub | `NOT_RUN` |
| Testes Android, integração e dispositivos | `NOT_RUN` |
| Estado do backend, permissões reais, backup e restore | `NOT_VERIFIED` |

Contagens abaixo descrevem código existente, não testes aprovados. A existência de documentação ou de um comando não comprova sua execução.

## 2. Produto atual e arquitetura proposta

O código atual usa Flutter, Hive, Provider e PocketBase; o Hub contém fontes de uma aplicação Next.js. O alvo descrito nas issues #1 e #2 é backend autoritativo, sem banco local no cliente, com confirmação explícita das operações.

A arquitetura alvo permanece sujeita à [ADR #18](https://github.com/rafaloct/jalapao-monitor-v2/issues/18). Esta preparação não autoriza remover Hive, migrar dados ou reescrever o aplicativo. Monitoramento e cartografia são escopos separados; este inventário não autoriza integrar seus fluxos ou dados.

| Componente | Evidência versionada | Situação observada |
|---|---|---|
| Aplicativo | `lib/`, `pubspec.yaml`, `pubspec.lock` | Fontes, modelos e dependências presentes |
| Persistência local | `lib/main.dart`, `lib/models/*.g.dart` | Inicializa Hive e abre caixas de visitas, locais, reservas e configuração |
| Sincronização | `lib/services/sync_service.dart`, `lib/providers/place_provider.dart` | Tentativa inicial; upload periódico de 30 segundos; sync-down de locais de 60 segundos |
| Android | `android/app/src/main/AndroidManifest.xml`, arquivos Gradle | Estrutura principal presente; bootstrap e assinatura têm pendências |
| Hub | `hub/src/`, `hub/README.md` | Fontes presentes, scaffold de execução incompleto |
| Backend | `docs/POCKETBASE_SCHEMA.md` | Schema documentado; sem provisionamento ou migrations PocketBase versionados |
| Automação | Árvore do commit observado | Nenhum workflow em `.github/workflows/` |

## 3. Reprodutibilidade e configuração

### Flutter e Android

- `pubspec.yaml` e `pubspec.lock`: Dart `>=3.7.0 <4.0.0`.
- `pubspec.lock`: Flutter `>=3.29.0`; nenhuma versão exata do SDK foi validada.
- `docs/DEVELOPMENT.md` informa Flutter ≥3.19 e Dart ≥3.3; esses mínimos estão desatualizados em relação ao lock.
- `android/settings.gradle.kts`: Android Gradle Plugin 8.11.1 e Kotlin 2.2.20.
- `android/app/build.gradle.kts`: Java 17 e NDK 27.0.12077973; SDKs Android derivados do Flutter.
- `android/gradle/wrapper/gradle-wrapper.properties`: distribuição Gradle 8.14.
- `android/gradlew`, `android/gradlew.bat` e `android/gradle/wrapper/gradle-wrapper.jar` não estão versionados; `android/.gitignore` os ignora explicitamente.
- A eventual geração do wrapper pelo ambiente Flutter ainda precisa ser demonstrada. Não assumir que `./gradlew` existe após clone.
- O manifest principal existe e declara Internet, estado de rede, localização, câmera e acesso a imagens.
- O bloco `release` utiliza a configuração de assinatura `debug`. Um APK release assim gerado não comprova preparação para distribuição de produção.

A Issue #17 deve registrar versões realmente instaladas e resultados. Atualizar mínimos documentais não substitui validar uma combinação de ferramentas.

### Hub

Não estão presentes `hub/package.json`, lockfile npm/yarn/pnpm, `tsconfig.json`, configuração Next/Tailwind/PostCSS, `src/app/layout.tsx` ou CSS global. Os comandos `npm install`, `npm run dev` e `npm run build` documentados não são reproduzíveis apenas com esse checkout.

A [Issue #22](https://github.com/rafaloct/jalapao-monitor-v2/issues/22) deve recuperar o scaffold da origem legítima e comparar as fontes. Inferir dependências e gerar um novo manifest requer escopo explícito de reconstrução. As versões Next.js 14 e Node ≥18 citadas em documentos não constituem ambiente validado.

### Backend e rede

O repositório não contém `pb_migrations`, `pb_hooks`, compose ou provisionamento equivalente. O schema documentado não comprova o estado do serviço existente.

`lib/config/app_config.dart` usa HTTP em loopback como default de `PB_URL`. A exceção de cleartext em `android/app/src/main/res/xml/network_security_config.xml` cobre outro host. Documentação e scripts também referenciam um backend existente. O setup precisa definir explicitamente o ambiente sintético e o encaminhamento de rede do emulador/tablet.

## 4. Testes existentes

### Testes de modelos

| Arquivo | Chamadas `test(...)` |
|---|---:|
| `test/models/place_test.dart` | 10 |
| `test/models/place_visit_test.dart` | 10 |
| `test/models/reservation_test.dart` | 9 |
| `test/models/visit_test.dart` | 6 |
| Total | 35 |

Esses arquivos importam modelos e `flutter_test`, com assertions reais. São o primeiro candidato à reprodução na Issue #17 após preparar SDK compatível. Seu resultado permanece `NOT_RUN`.

### Cenários de integração

| Arquivo em `integration_test/` | Cenários `testWidgets(...)` | Chamadas `expect(...)` | Chamadas `pumpAndSettle(...)` |
|---|---:|---:|---:|
| `app_test.dart` | 1 | 0 | 12 |
| `baseline_operational_walkthrough.dart` | 1 | 0 | 33 |
| `edge_cases_test.dart` | 1 | 0 | 4 |
| `peak_flow_test.dart` | 1 | 1 | 5 |

Os quatro cenários iniciam o aplicativo e não estabelecem armazenamento Hive descartável nem setup/teardown de isolamento. Providers podem sincronizar dados ao iniciar. Vários caminhos são condicionais à presença dos widgets, permitindo pular etapas sem verificar o resultado funcional.

A documentação orienta evitar `pumpAndSettle`, mas todos os cenários o utilizam. Capturas de tela e ausência de exceção não equivalem à comprovação de E2E. Não executar esses cenários contra backend real nem adicioná-los ao CI antes de isolar dados, rede, armazenamento e assertions.

## 5. Segurança e documentação divergente

| Evidência | Risco ou correção necessária |
|---|---|
| `lib/services/auth_service.dart` | PIN padrão literal não vazio como fallback de configuração; login local ocorre antes da autenticação PocketBase |
| `integration_test/baseline_operational_walkthrough.dart` | Repete o mesmo PIN padrão do aplicativo; valores não devem ser copiados para issues, evidências ou logs |
| `docs/DEVELOPMENT.md` | A afirmação de que credenciais nunca estão no código não descreve o fallback atual |
| `lib/config/app_config.dart` | Referência a `.env.example`, ausente na árvore observada |
| `hub/README.md` | Referência a `hub/src/app/docs/page.tsx`, ausente |
| `docs/DEVELOPMENT.md` | Referência a `lib/models/visit_record.dart`, ausente; existe `lib/models/visit.dart` |
| `run_baseline_only.ps1`, `capture_screens.ps1` | Configuração de máquina/PATH e URL default; não constituem bootstrap portátil |

A remoção do fallback pertence à [Issue #24](https://github.com/rafaloct/jalapao-monitor-v2/issues/24), condicionada à decisão de acesso aprovada. Esta inspeção não verifica a validade operacional do PIN nem realiza rotação. Não houve auditoria exaustiva do histórico Git ou consulta de secrets.

## 6. Ordem de avanço e evidências

1. #17: reproduzir SDK e os 35 testes de modelos, registrando SHA, versões, comandos, resultados e bloqueios.
2. #18 e #19: produzir ADR e matriz de acesso; implementar decisões somente após os gates aplicáveis.
3. #22: recuperar scaffold do Hub; registrar origem e diferenças antes de declarar build reproduzível.
4. #20: fechar o plano de CI usando resultados reais; #21 implementa workflows após os gates.
5. #23: contrato de sessão e eventos após decisões de arquitetura/acesso; #24 trata o fallback PIN aprovado.
6. #25: configuração de GitHub Projects permanece vinculada à capacidade/permissão própria, sem bloquear documentação ou tarefas independentes.

As próximas evidências devem distinguir `PASS`, `FAIL`, `BLOCKED` e `NOT_RUN`, registrar o comando exato com dados sensíveis removidos e evitar endpoints reais nos exemplos. Merge, deploy e promoção de ambiente não estão autorizados por este inventário.

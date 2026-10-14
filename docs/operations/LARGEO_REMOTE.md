# LARGEO — execução remota de trabalho pesado (build/teste/emulador)

- **Complementa:** [AGENT_COORDINATION.md](AGENT_COORDINATION.md) (contrato de
  execução), [AGENT_A2A.md](AGENT_A2A.md) (interoperabilidade entre agentes) e
  [ENVIRONMENTS.md](ENVIRONMENTS.md) (modelo de builds por ambiente).
- **Natureza:** este documento descreve um **recurso de execução**, não uma
  autorização nova. Nenhuma tarefa passa a existir por causa deste contrato —
  todo trabalho continua exigindo issue `type:task` + `agent:ready` com claim
  registrado (AGENT_COORDINATION §Condição de entrada e §Claim).
- **Fonte autoritativa:** o kit instalado na máquina
  (`D:\AI-Shared\largeo-performance\...`) é a única referência de versão,
  comportamento e estado em tempo real. Esta página é um espelho de contexto
  (versão 14/10/2026); em divergência, **o kit vence** e a divergência deve
  ser registrada na issue da tarefa.

## 1. Identidade da máquina

| Item | Valor |
|---|---|
| Hostname | `LARGEO` (jobs em outro host são rejeitados) |
| CPU | i7-12700 · 12 cores / 20 threads |
| RAM | 16 GiB |
| C: | NVMe 238 GiB — **quase cheio (~1,6 GiB livre)** |
| D: | HDD 931 GiB — ~590 GiB livre |
| OS | Windows 11 25H2 (build 26200) |

## 2. Toolchain (caminhos reais — não assumir o PATH)

| Ferramenta | Caminho |
|---|---|
| Flutter SDK | `D:\flutter-3.44.9` (Dart 3.12.2) |
| Android SDK | `D:\DevTools\AndroidSDK` |
| JDK de build (Flutter/Gradle) | `D:\adroid\jbr` (JBR OpenJDK 21.0.8) — **não** é o JDK 25 do PATH |
| Gradle user home | `D:\DevTools\gradle` |
| Pub cache | `D:\DevTools\pub-cache` |
| AVDs | `D:\DevTools\android-user\avd\` (junction `~\.android`) |
| WHPX | instalado e utilizável |

### 2.1 Divergência de toolchain — RESTRIÇÃO para este repositório

A toolchain canônica do repo é **Flutter 3.47.7 / Dart 3.13.5** (issue #52;
ver [CI_PLAN.md](CI_PLAN.md) §4.5 e `.github/workflows/ci.yml`). O LARGEO roda
**Flutter 3.44.9 / Dart 3.12.2**. Consequências:

- `flutter pub get` sob 3.44.9 **re-resolve ~10 pins transitivos** do
  `pubspec.lock` versionado (evidência da #17/CI_BASELINE) — resultado de
  build/analyze no LARGEO não substitui o gate de CI nem comprova
  reprodutibilidade do lock.
- Uso legítimo hoje: **offload de trabalho pesado** (builds Android longos,
  análises exploratórias, ciclos de depuração, emulador) cujo resultado é
  evidência de apoio, não gate.
- Build oficial de validação/release exige toolchain alinhada à canônica —
  ou upgrade do Flutter no LARGEO (tarefa própria, autorizada), ou execução
  em ambiente com 3.47.7.
- **Proibido** regenerar/commitar `pubspec.lock` a partir do LARGEO 3.44.9;
  reconciliação de lock segue a Via A/B do CI_PLAN §4.5 em tarefa delimitada.

## 3. Como executar trabalho (único caminho suportado)

Kit v2: `D:\AI-Shared\largeo-performance\20261014-131851-v2`

```powershell
# 1. preflight (somente leitura) — saiba se a máquina aceita carga
powershell -NoProfile -ExecutionPolicy Bypass -File `
  D:\AI-Shared\largeo-performance\20261014-131851-v2\Test-LARGeoPreflight.ps1
#    exit 0 = PASS/PASS_WITH_WARNINGS · exit 2 = BLOCKED

# 2. dry-run: mostra gate/fila sem efeito colateral
powershell -NoProfile -ExecutionPolicy Bypass -File `
  D:\AI-Shared\largeo-performance\20261014-131851-v2\Invoke-LARGeoTask.ps1 `
  -Profile <Build|Interactive|EmulatorQA> -ProjectRoot <sua-pasta> -Command "<cmd>" -WhatIf

# 3. execução real (admissão atômica, lock, logs limitados, Job Object)
powershell -NoProfile -ExecutionPolicy Bypass -File `
  D:\AI-Shared\largeo-performance\20261014-131851-v2\Invoke-LARGeoTask.ps1 `
  -Profile Interactive -ProjectRoot <worktree> -WorkingDirectory <subdir> `
  -Command "<comando>" -TimeoutMin 30 -QueueTimeoutMin 10
```

O checkout canônico `D:\AI-Shared\Codex\Tutor-TDS\repo` é **read-only para
este kit** (rejeitado como `ProjectRoot`); sempre use worktree/cópia própria
da tarefa — coerente com a regra de checkout isolado do AGENT_COORDINATION
(§Branch e alterações).

### 3.1 Perfis

| Perfil | Classe | Concorrência | Uso |
|---|---|---|---|
| `Interactive` | interactive | máx 2 simultâneos | comandos curtos/leves |
| `Build` | heavy | máx 1 | builds Gradle/Flutter pesados |
| `EmulatorQA` | heavy | máx 1 | `-Command builtin:start-emulator` (AVD explícito via `-AvdName`) |

`Build` e `EmulatorQA` **não coexistem** (mesma classe `heavy`).

### 3.2 Retorno (o que o chamador recebe)

- **Exit code**: `0` ok · `2` validação · `3` recurso insuficiente · `4` lock/
  concorrência/estado não verificável · `5` seção crítica ocupada · `7` comando
  falhou · `124/125` timeout comando/AVD · `98` erro interno.
- **Console/log por job**: `<kit>\logs\<jobid>.stdout.log` + `.stderr.log`
  (limitados; `[TRUNCATED]` marca corte), stdout do wrapper com linhas
  `LOCK=`, `RESOURCE_GATE=`, `DONE result=... duration_s=...`.
- **`benchmarks.csv`** no kit: linha por execução (job, perfil, exit, duração,
  RAM/commit observados). Linhas com `mock-resources` em `notes` são de teste.
- **Restore**: `Restore-LARGeoState.ps1` — `0` ok · `10` conflito (edição
  externa preservada) · `11` incompleto. Ver também `-ReleaseLeases` para AVDs
  `KeepAvd`.

### 3.3 Evidência mínima ao usar LARGEO em uma tarefa deste repo

Registrar no PR/handoff (AGENT_COORDINATION §Handoff):

1. `jobid` e perfil utilizados, comando exato e `ProjectRoot` (worktree).
2. Exit code do wrapper **e** do comando; linhas `LOCK=`/`RESOURCE_GATE=`/`DONE`.
3. Versão do SDK Flutter usado (hoje 3.44.9 — ver §2.1) e duração.
4. Estado de restore (`0/10/11`) quando houver patch aplicado.
5. Resultado classificado como evidência de apoio — nunca como gate de CI
   nem como `PASS` de aceite que exija toolchain canônica.

## 4. Estado compartilhado (coordenador)

`D:\AI-Shared\largeo-performance\_shared\coordinator\`

| Subpasta | Conteúdo |
|---|---|
| `locks\` | um diretório `<base>-<jobid>.lock\lock.json` por job ativo (hostname+pid+start) |
| `manifests\` | transações de patch `patch-<jobid>.json` (pendentes de restore) |
| `leases\` | AVDs mantidos ativos (`avd-*.lease`) — um AVD com lease bloqueia EmulatorQA |
| `projects\` | lock por projeto durante patch de `gradle.properties` |
| `admission.lock\` | seção crítica interna — **não tocar** |

Regras: **inspeção somente leitura**. Não criar/apagar arquivos diretamente —
o kit é a única escritora. Lock sem JSON/corrompido/estrangeiro é conservador:
nunca removido por suposição. PID sozinho não prova dono (StartTime é
comparado).

## 5. Estado conhecido (14/10 ~14:05 — verificar preflight antes de usar)

- **Emulador ativo por pedido do usuário**: `Pixel_8_Pro` em `emulator-5554`,
  lease `avd-Pixel_8_Pro.lease` — **não encerrar**; EmulatorQA ficará bloqueado
  enquanto ele existir.
- Aparelho físico `ce11182bc340760e017e` conectado — **não usar** (apenas
  emulador).
- Gates pesados **BLOCKED** no caminho real: C: < reserva de 30 GiB; RAM livre
  ~5,7 GiB com o AVD ativo.

Este estado é transitório: `Test-LARGeoPreflight.ps1` é a verificação válida
no momento da execução.

## 6. Proibido

Matar processos por nome global (`java`, `dart`, `emulator`),
`adb kill-server`, tocar AVD/lease alheio, apagar locks/manifestos
manualmente, usar `MockResourceFile` fora de teste, modificar o checkout
canônico, iniciar segundo emulador, aceitar licenças automaticamente, alterar
pagefiles/BIOS/clock/tensão/hibernação, e usar chaves de assinatura ou gerar
AAB oficial.

## 7. Limites de autorização (inalteráveis por este documento)

- Build remoto **não é** build de release: assinatura, promoção
  staging→produção e AAB seguem [ENVIRONMENTS.md](ENVIRONMENTS.md) §5 e
  exigem tarefa/autorização próprias.
- `MERGE_ALLOWED=NO` e `PRODUCTION_ALLOWED=NO` permanecem para o agente,
  independentemente de onde o trabalho pesado rodou.
- Acesso ao LARGEO (RDP/extensão/Tailscale) é infraestrutura do mantenedor:
  nenhuma credencial, hostname tailnet ou caminho sensível além dos já
  declarados aqui entra no repo (AGENTS.md §Segurança).

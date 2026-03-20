# Guia de Desenvolvimento — Jalapão Monitor

## Pré-requisitos

- Flutter SDK ≥ 3.19 (canal stable)
- Dart SDK ≥ 3.3
- Android SDK (API 26+)
- Node.js ≥ 18 (para o Hub)
- ADB (para deploy no tablet)

## App Flutter

### Rodar em modo debug

```bash
# Conectar tablet via USB, habilitar depuração USB
adb devices

# Passar a URL do PocketBase via dart-define
flutter run --dart-define=PB_URL=http://92.112.179.111:8090
```

### Build APK para instalação

```bash
flutter build apk --release \
  --dart-define=PB_URL=http://92.112.179.111:8090

# Instalar no tablet conectado
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Testes de integração (38 screenshots)

```bash
# Requer tablet físico conectado via ADB
flutter test integration_test/baseline_operational_walkthrough.dart \
  -d <device-id> \
  --dart-define=PB_URL=http://92.112.179.111:8090
```

> **Atenção:** O teste usa `pump(500ms × 4)` em vez de `pumpAndSettle` para evitar
> loop infinito causado pelo timer de sync de 30s do PlaceProvider.

### Estrutura de diretórios Flutter

```
lib/
  main.dart                     # HomeRouter — roteamento por tipo de local
  models/
    place.dart                  # Place, PlaceVisit (Hive)
    visit_record.dart           # VisitRecord legado (fervedouro)
    reservation.dart            # Reservation
  providers/
    place_provider.dart         # Estado dos locais + sync timer 30s
  screens/
    onboarding_screen.dart      # Configuração inicial do tablet
    session_selector_screen.dart # Seleção de local de monitoramento
    dashboard_screen.dart       # Fervedouro: fila/água/concluído
    counter_screen.dart         # Cachoeira/atrativo: contador entrada/saída
    place_reservation_screen.dart # Pousada/restaurante: reservas
    gestor_screen.dart          # Gestão de locais (PIN protegido)
    place_form_screen.dart      # Formulário de cadastro de novo local
  services/
    sync_service.dart           # Upload/download PocketBase a cada 30s
  theme/
    jalapao_theme.dart          # Cores e estilos do sistema
  widgets/                      # Componentes reutilizáveis
```

### Variáveis de configuração

| Variável dart-define | Padrão | Descrição |
|---|---|---|
| `PB_URL` | `http://92.112.179.111:8090` | URL do PocketBase |

Credenciais (PIN do gestor, token PocketBase) são armazenadas em `flutter_secure_storage`, nunca em código.

---

## Hub Next.js

### Setup local

```bash
cd hub
npm install

# Criar arquivo de configuração local
cat > .env.local << 'EOF'
NEXT_PUBLIC_PB_URL=http://92.112.179.111:8090
NEXT_PUBLIC_HUB_PASSWORD=sua_senha_aqui
EOF

npm run dev
# Acesse http://localhost:3000
```

### Deploy no VPS

```bash
# No VPS via SSH
cd /root/jalapao-hub   # ou caminho configurado
git pull
npm install --production
npm run build
pm2 restart hub
```

### Variáveis de ambiente do Hub

| Variável | Descrição |
|---|---|
| `NEXT_PUBLIC_PB_URL` | URL do PocketBase |
| `NEXT_PUBLIC_HUB_PASSWORD` | Senha de acesso ao Hub |

---

## PocketBase

### Acesso admin

```
URL: http://<VPS_IP>:8090/_/
Usuário: configurado no primeiro setup
```

### Backup manual de dados

Via Hub: botão "Backup CSV" na página principal.
Via PocketBase admin: Settings → Backups.

---

## Regras gerais de código

1. **Timezone:** nunca use `getHours()`, `toLocaleDateString()` sem `timeZone`, ou `split('T')[0]` para datas. Use sempre `src/lib/tz.ts` no Hub e `DateTime.now()` com offset no Flutter.
2. **Queries paralelas ao PocketBase:** `pb.autoCancellation(false)` está setado — não remova.
3. **IDs de PlaceVisit no fervedouro:** derivados do `groupId` local — idempotentes para partial moves.
4. **Sync timer:** o `PlaceProvider` tem um timer de 30s. Em testes de integração, use `pump()` em vez de `pumpAndSettle()`.

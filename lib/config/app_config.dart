/// Configurações centralizadas via --dart-define (build-time).
///
/// Uso em desenvolvimento (PocketBase local):
///   flutter run --dart-define=PB_URL=http://localhost:8090
///
/// Uso em produção (VPS):
///   flutter build apk \
///     --dart-define=PB_URL=http://SEU_VPS_IP:8090 \
///     --dart-define=GESTOR_PIN=suasenha
///
/// Ver: .env.example para lista completa de variáveis.
class AppConfig {
  AppConfig._();

  static const String pbUrl = String.fromEnvironment(
    'PB_URL',
    defaultValue: 'http://localhost:8090',
  );
}

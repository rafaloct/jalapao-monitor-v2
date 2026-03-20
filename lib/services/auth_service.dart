import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:pocketbase/pocketbase.dart';
import '../config/app_config.dart';

/// Gerencia autenticação do Gestor.
///
/// Suporta dois modos:
/// 1. **PocketBase Auth**: Usa conta de usuário criada no PocketBase admin.
///    Requer: criar usuário em ${AppConfig.pbUrl}/_/ → Collections → users
///
/// 2. **PIN Local** (fallback): Usa PIN armazenado em FlutterSecureStorage.
///    PIN padrão configurável via --dart-define=GESTOR_PIN=suasenha
///    Alterável via app (fica gravado em secure storage no dispositivo).
class AuthService extends ChangeNotifier {
  static const _tokenKey = 'gestor_auth_token';
  static const _nameKey = 'gestor_auth_name';
  static const _pinKey = 'gestor_pin';

  // PIN padrão de primeiro uso — alterável via build-time ou pelo app.
  // Configure via: flutter run --dart-define=GESTOR_PIN=suasenha
  static const _defaultPin = String.fromEnvironment(
    'GESTOR_PIN',
    defaultValue: 'trocar-na-primeira-vez',
  );

  final PocketBase pb = PocketBase(AppConfig.pbUrl);
  final Box _configBox;

  final _ss = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  bool _isLoggedIn = false;
  String? _gestorName;
  bool _usesPinAuth = false;
  String _cachedPin = _defaultPin; // atualizado no _initAsync

  AuthService(this._configBox) {
    _initAsync();
  }

  bool get isLoggedIn => _isLoggedIn;
  String? get gestorName => _gestorName;
  bool get usesPinAuth => _usesPinAuth;

  /// PIN atual em memória (carregado do secure storage ao inicializar)
  String get gestorPin => _cachedPin;

  Future<void> _initAsync() async {
    _cachedPin = await _ss.read(key: _pinKey) ?? _defaultPin;
    await _restoreSession();
  }

  /// Tenta restaurar sessão PocketBase salva no secure storage
  Future<void> _restoreSession() async {
    final token = await _ss.read(key: _tokenKey);
    if (token != null && token.isNotEmpty) {
      pb.authStore.save(token, null);
      if (pb.authStore.isValid) {
        _isLoggedIn = true;
        _gestorName = _configBox.get(_nameKey) as String?;
        _usesPinAuth = false;
        notifyListeners();
      }
    }
  }

  /// Login do gestor.
  /// Tenta PIN primeiro; se não for PIN, tenta PocketBase.
  ///
  /// Retorna `null` em sucesso ou mensagem de erro.
  Future<String?> login(String emailOrPin, String password) async {
    // ── Modo PIN local ──────────────────────────────────
    if (emailOrPin == _cachedPin || password == _cachedPin) {
      _isLoggedIn = true;
      _gestorName = 'Gestor (PIN)';
      _usesPinAuth = true;
      notifyListeners();
      return null;
    }

    // ── Modo PocketBase Auth ────────────────────────────
    try {
      await pb.collection('users').authWithPassword(emailOrPin, password);
      await _ss.write(key: _tokenKey, value: pb.authStore.token);
      await _configBox.put(_nameKey, emailOrPin); // nome não é sensível
      _isLoggedIn = true;
      _gestorName = emailOrPin;
      _usesPinAuth = false;
      notifyListeners();
      return null;
    } on ClientException catch (e) {
      debugPrint('[AuthService] PB Login error: ${e.statusCode}');
      if (e.statusCode == 400) {
        return 'Credenciais inválidas.\n'
            'Use o PIN do gestor ou crie um usuário em:\n'
            '${AppConfig.pbUrl}/_/';
      }
      return 'Servidor indisponível. Use o PIN local.';
    } catch (e) {
      debugPrint('[AuthService] Login error: $e');
      return 'Erro de conexão. Tente o PIN local.';
    }
  }

  /// Logout do gestor — limpa token do secure storage
  Future<void> logout() async {
    pb.authStore.clear();
    await _ss.delete(key: _tokenKey);
    await _configBox.delete(_nameKey);
    _isLoggedIn = false;
    _gestorName = null;
    _usesPinAuth = false;
    notifyListeners();
  }

  /// Salva novo PIN do gestor no secure storage
  Future<void> setPin(String newPin) async {
    await _ss.write(key: _pinKey, value: newPin);
    _cachedPin = newPin;
  }

  /// Aprova um place no PocketBase.
  /// Retorna [true] se enviado ao servidor, [false] se somente local (PIN mode).
  Future<bool> approvePlace(String placeId) async {
    if (!_isLoggedIn) return false;
    try {
      await pb.collection('places').update(placeId, body: {
        'status': 'active',
        'approved_at': DateTime.now().toIso8601String(),
      });
      return true;
    } on ClientException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403 || e.statusCode == 404) {
        debugPrint('[AuthService] Approve requires PocketBase auth. '
            'Configure usuário gestor em ${AppConfig.pbUrl}/_/');
        return false;
      }
      debugPrint('[AuthService] Approve error: ${e.statusCode}');
      return false;
    } catch (e) {
      debugPrint('[AuthService] Approve place error: $e');
      return false;
    }
  }

  /// Rejeita um place no PocketBase.
  Future<bool> rejectPlace(String placeId) async {
    if (!_isLoggedIn) return false;
    try {
      await pb.collection('places').update(placeId, body: {
        'status': 'rejected',
      });
      return true;
    } on ClientException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403 || e.statusCode == 404) {
        debugPrint('[AuthService] Reject requires PocketBase auth.');
        return false;
      }
      return false;
    } catch (e) {
      debugPrint('[AuthService] Reject place error: $e');
      return false;
    }
  }

  /// Busca places pendentes do PocketBase (para gestor revisar)
  Future<List<Map<String, dynamic>>> fetchPendingPlaces() async {
    if (!_isLoggedIn) return [];
    try {
      final records = await pb.collection('places').getFullList(
        filter: 'status = "pending"',
        sort: '-created',
      );
      return records
          .map((r) => <String, dynamic>{'id': r.id, ...r.data})
          .toList();
    } catch (e) {
      debugPrint('[AuthService] Fetch pending places error: $e');
      return [];
    }
  }

  /// Busca places ativos do PocketBase (para sync-down em operadores)
  Future<List<Map<String, dynamic>>> fetchActivePlaces() async {
    try {
      final records = await pb.collection('places').getFullList(
        filter: 'status = "active"',
        sort: 'name',
      );
      return records
          .map((r) => <String, dynamic>{'id': r.id, ...r.data})
          .toList();
    } catch (e) {
      debugPrint('[AuthService] Fetch active places error: $e');
      return [];
    }
  }
}

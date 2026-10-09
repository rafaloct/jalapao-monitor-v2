import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:pocketbase/pocketbase.dart';
import '../config/app_config.dart';

/// Gerencia autenticação do Gestor.
///
/// Autenticação exclusiva via **PocketBase Auth** (collection `users`), conforme
/// modelo de provisionamento aprovado na Issue #13
/// (docs/security/ACCESS_MATRIX.md §5):
///
/// - Contas pessoais individuais no backend — sem conta compartilhada e sem
///   credencial válida embarcada no cliente.
/// - Configuração ausente ou servidor inacessível falha de forma explícita:
///   **nenhum privilégio local é concedido**.
/// - Transição/rotação do modelo anterior (PIN local): ver
///   `docs/security/CREDENTIAL_TRANSITION.md`.
class AuthService extends ChangeNotifier {
  static const _tokenKey = 'gestor_auth_token';
  static const _nameKey = 'gestor_auth_name';

  /// Chave legada do PIN local (modelo removido na #24) — mantida apenas para
  /// purgar o valor de instalações antigas no init.
  static const _legacyPinKey = 'gestor_pin';

  final PocketBase pb;
  final Box _configBox;

  final _ss = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  bool _isLoggedIn = false;
  String? _gestorName;

  /// Futuro da inicialização (purge de PIN legado + restauração de sessão).
  /// `login()` aguarda isso — evita race entre um login interativo e um
  /// auth-refresh de token antigo operando sobre o mesmo authStore.
  late final Future<void> ready;

  AuthService(this._configBox, {PocketBase? client})
    : pb = client ?? PocketBase(AppConfig.pbUrl) {
    ready = _initAsync();
  }

  bool get isLoggedIn => _isLoggedIn;
  String? get gestorName => _gestorName;

  Future<void> _initAsync() async {
    // Purga o PIN local de instalações anteriores (fallback removido na #24).
    await _ss.delete(key: _legacyPinKey);
    await _restoreSession();
  }

  /// Tenta restaurar sessão PocketBase salva no secure storage.
  /// O token é emitido pelo servidor e revogável — não é credencial embutida.
  /// A validade local (exp do JWT) não basta: o token é revalidado no servidor
  /// via auth-refresh antes de conceder acesso.
  Future<void> _restoreSession() async {
    final token = await _ss.read(key: _tokenKey);
    if (token == null || token.isEmpty) return;

    pb.authStore.save(token, null);
    // isValid decodifica o payload do JWT e pode lançar (não apenas
    // retornar false) em token malformado — isso fora do try travaria
    // o init e bloquearia até o login interativo. Valor corrompido é
    // descartado e a inicialização segue sem sessão.
    bool tokenOk;
    try {
      tokenOk = pb.authStore.isValid;
    } catch (_) {
      tokenOk = false;
    }
    if (!tokenOk) {
      pb.authStore.clear();
      await _ss.delete(key: _tokenKey);
      return;
    }

    try {
      // Revalida server-side: token revogado ou conta rotacionada falha aqui.
      await pb.collection('users').authRefresh();
      await _ss.write(key: _tokenKey, value: pb.authStore.token);
      _isLoggedIn = true;
      _gestorName = _configBox.get(_nameKey) as String?;
      notifyListeners();
    } on ClientException catch (e) {
      // Somente 401/403 estabelece revogação — aí o token é descartado.
      if (e.statusCode == 401 || e.statusCode == 403) {
        pb.authStore.clear();
        await _ss.delete(key: _tokenKey);
        return;
      }
      // Erro transitório (429/5xx/4xx genérico): não concede acesso, mas
      // preserva o token persistido para nova tentativa no próximo init.
      pb.authStore.clear();
    } catch (_) {
      // Falha de transporte: não concede acesso, mas mantém o token
      // para nova tentativa no próximo init.
      pb.authStore.clear();
    }
  }

  /// Login do gestor via conta PocketBase.
  ///
  /// Não existe credencial local de fallback: credencial inválida ou servidor
  /// indisponível retornam erro e **não** concedem acesso.
  ///
  /// Retorna `null` em sucesso ou mensagem de erro.
  Future<String?> login(String email, String password) async {
    // Serializa com a restauração de sessão em voo — um refresh de token
    // antigo não pode sobrescrever nem apagar o resultado deste login.
    await ready;
    try {
      await pb.collection('users').authWithPassword(email, password);
      await _ss.write(key: _tokenKey, value: pb.authStore.token);
      await _configBox.put(_nameKey, email); // nome não é sensível
      _isLoggedIn = true;
      _gestorName = email;
      notifyListeners();
      return null;
    } on ClientException catch (e) {
      debugPrint('[AuthService] PB Login error: ${e.statusCode}');
      if (e.statusCode == 400) {
        return 'Credenciais inválidas.\n'
            'Peça a conta ao coordenador responsável.';
      }
      return 'Servidor indisponível.\n'
          'O painel do gestor exige conexão com o servidor.';
    } catch (e) {
      debugPrint('[AuthService] Login error: $e');
      return 'Servidor indisponível.\n'
          'O painel do gestor exige conexão com o servidor.';
    }
  }

  /// Logout do gestor — limpa token do secure storage
  Future<void> logout() async {
    pb.authStore.clear();
    await _ss.delete(key: _tokenKey);
    await _configBox.delete(_nameKey);
    _isLoggedIn = false;
    _gestorName = null;
    notifyListeners();
  }

  /// Aprova um place no PocketBase.
  /// Retorna [true] somente se confirmado pelo servidor — sem login válido,
  /// nenhuma aprovação é concedida.
  Future<bool> approvePlace(String placeId) async {
    if (!_isLoggedIn) return false;
    try {
      await pb
          .collection('places')
          .update(
            placeId,
            body: {
              'status': 'active',
              'approved_at': DateTime.now().toIso8601String(),
            },
          );
      return true;
    } on ClientException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403 || e.statusCode == 404) {
        debugPrint(
          '[AuthService] Approve requires PocketBase auth. '
          'Configure usuário gestor em ${AppConfig.pbUrl}/_/',
        );
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
      await pb
          .collection('places')
          .update(placeId, body: {'status': 'rejected'});
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

  /// Cria ou atualiza um place completo no PocketBase (upsert por id —
  /// mesmo padrão do SyncService). Necessário quando o registro ainda só
  /// existe no Hive (`isSynced: false`): um update de status retornaria 404.
  /// Requer gestor autenticado — retorna false sem grant local.
  Future<bool> upsertPlace(Map<String, dynamic> placeJson) async {
    if (!_isLoggedIn) return false;
    final placeId = placeJson['id'] as String;
    try {
      try {
        await pb.collection('places').update(placeId, body: placeJson);
      } on ClientException catch (e) {
        if (e.statusCode != 404) rethrow;
        await pb.collection('places').create(body: placeJson);
      }
      return true;
    } catch (e) {
      debugPrint('[AuthService] Upsert place error: $e');
      return false;
    }
  }

  /// Busca places pendentes do PocketBase (para gestor revisar)
  Future<List<Map<String, dynamic>>> fetchPendingPlaces() async {
    if (!_isLoggedIn) return [];
    try {
      final records = await pb
          .collection('places')
          .getFullList(filter: 'status = "pending"', sort: '-created');
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
      final records = await pb
          .collection('places')
          .getFullList(filter: 'status = "active"', sort: 'name');
      return records
          .map((r) => <String, dynamic>{'id': r.id, ...r.data})
          .toList();
    } catch (e) {
      debugPrint('[AuthService] Fetch active places error: $e');
      return [];
    }
  }
}

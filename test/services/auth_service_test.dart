import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:jalapao_monitor/services/auth_service.dart';

/// Testes do AuthService após a remoção do fallback de PIN (Issue #24).
///
/// Fixture sintética: servidor PocketBase falso em localhost via HttpServer.
/// Nenhuma credencial aqui é reutilizada em operação.

const _ssChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

/// Armazenamento em memória simulando o secure storage.
late Map<String, String> _fakeSecureStorage;

void _mockSecureStorage() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_ssChannel, (call) async {
        final args = (call.arguments as Map?)?.cast<String, dynamic>() ?? {};
        switch (call.method) {
          case 'write':
            _fakeSecureStorage[args['key'] as String] = args['value'] as String;
            return null;
          case 'read':
            return _fakeSecureStorage[args['key']];
          case 'delete':
            _fakeSecureStorage.remove(args['key']);
            return null;
          case 'deleteAll':
            _fakeSecureStorage.clear();
            return null;
          case 'readAll':
            return Map<String, String>.from(_fakeSecureStorage);
          case 'containsKey':
            return _fakeSecureStorage.containsKey(args['key']);
          default:
            return null;
        }
      });
}

/// JWT sintético estruturalmente válido com expiração futura, para testar
/// restauração de sessão sem emitir credencial real.
String _fakeJwt({String id = 'u1'}) {
  String b64(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${b64({'alg': 'HS256', 'typ': 'JWT'})}.'
      '${b64({'id': id, 'type': 'auth', 'exp': 9999999999})}.assinatura';
}

/// Servidor PocketBase falso: responde ao endpoint de auth com sucesso ou 400
/// conforme a credencial sintética recebida.
class FakePocketBaseServer {
  HttpServer? _server;
  int get port => _server!.port;

  /// Quando definido, o auth-refresh responde com este status (ex.: 429/503)
  /// para simular erro transitório no lugar de validar o token.
  int? refreshErrorStatus;

  static const okEmail = 'gestor.teste@example.invalid';
  static const okPassword = 'senha-sintetica-de-teste';

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen((req) async {
      if (req.uri.path == '/api/collections/users/auth-refresh') {
        if (refreshErrorStatus != null) {
          req.response
            ..statusCode = refreshErrorStatus!
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({'message': 'transient error'}));
          await req.response.close();
          return;
        }
        // Revalida o token recebido (SDK envia com ou sem prefixo Bearer):
        // só o token do usuário sintético 'u1' continua válido — qualquer
        // outro simula token revogado/rotacionado.
        final authz = req.headers.value('authorization') ?? '';
        final presented =
            authz.startsWith('Bearer ') ? authz.substring(7) : authz;
        if (presented == _fakeJwt(id: 'u1')) {
          req.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'token': _fakeJwt(),
                'record': {'id': 'u1', 'email': okEmail},
              }),
            );
        } else {
          req.response
            ..statusCode = 401
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({'message': 'Invalid auth token.'}));
        }
      } else if (req.method == 'POST' &&
          req.uri.path == '/api/collections/users/auth-with-password') {
        final body =
            jsonDecode(await utf8.decoder.bind(req).join())
                as Map<String, dynamic>;
        if (body['identity'] == okEmail && body['password'] == okPassword) {
          req.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'token': _fakeJwt(),
                'record': {'id': 'u1', 'email': okEmail},
              }),
            );
        } else {
          req.response
            ..statusCode = 400
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({'message': 'Failed to authenticate.'}));
        }
      } else {
        req.response
          ..statusCode = 404
          ..write('not found');
      }
      await req.response.close();
    });
  }

  Future<void> stop() => _server!.close(force: true);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;
  late Box configBox;
  late FakePocketBaseServer fakePb;

  AuthService buildService(String url) =>
      AuthService(configBox, client: PocketBase(url));

  setUpAll(() async {
    // TestWidgetsFlutterBinding instala um HttpClient falso que retorna 400
    // para qualquer requisição. Anular o override devolve o HttpClient real,
    // permitindo falar com o servidor PocketBase falso em localhost.
    HttpOverrides.global = null;
    hiveDir = await Directory.systemTemp.createTemp('hive_auth_test');
    Hive.init(hiveDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDir.delete(recursive: true);
  });

  setUp(() async {
    _fakeSecureStorage = {};
    _mockSecureStorage();
    configBox = await Hive.openBox('config_${DateTime.now().microsecond}');
    fakePb = FakePocketBaseServer();
    await fakePb.start();
  });

  tearDown(() async {
    await fakePb.stop();
    await configBox.close();
  });

  group('sem credencial local de fallback', () {
    test(
      'login com credencial sintética válida autentica via servidor',
      () async {
        final auth = buildService('http://127.0.0.1:${fakePb.port}');
        final error = await auth.login(
          FakePocketBaseServer.okEmail,
          FakePocketBaseServer.okPassword,
        );
        expect(error, isNull);
        expect(auth.isLoggedIn, isTrue);
        expect(auth.gestorName, FakePocketBaseServer.okEmail);
        expect(_fakeSecureStorage['gestor_auth_token'], isNotEmpty);
      },
    );

    test('credencial inválida é recusada — sem grant local', () async {
      final auth = buildService('http://127.0.0.1:${fakePb.port}');
      final error = await auth.login('ninguem@example.invalid', 'errada');
      expect(error, contains('Credenciais inválidas'));
      expect(auth.isLoggedIn, isFalse);
      expect(await auth.approvePlace('place-qualquer'), isFalse);
    });

    test('valor do antigo PIN padrão não concede acesso', () async {
      // O literal 'trocar-na-primeira-vez' era o fallback embutido antes da #24.
      // Agora ele é tratado como credencial comum e rejeitado pelo servidor.
      final auth = buildService('http://127.0.0.1:${fakePb.port}');
      final error = await auth.login(
        'trocar-na-primeira-vez',
        'trocar-na-primeira-vez',
      );
      expect(error, isNotNull);
      expect(auth.isLoggedIn, isFalse);
    });

    test('servidor indisponível falha explicitamente, sem grant', () async {
      // Porta garantidamente fechada: bind + close.
      final probe = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final deadPort = probe.port;
      await probe.close();

      final auth = buildService('http://127.0.0.1:$deadPort');
      final error = await auth.login(
        FakePocketBaseServer.okEmail,
        FakePocketBaseServer.okPassword,
      );
      expect(error, contains('Servidor indisponível'));
      expect(auth.isLoggedIn, isFalse);
      expect(await auth.approvePlace('place-qualquer'), isFalse);
    });

    test('logout limpa token persistido e estado', () async {
      final auth = buildService('http://127.0.0.1:${fakePb.port}');
      await auth.login(
        FakePocketBaseServer.okEmail,
        FakePocketBaseServer.okPassword,
      );
      expect(auth.isLoggedIn, isTrue);

      await auth.logout();
      expect(auth.isLoggedIn, isFalse);
      expect(auth.gestorName, isNull);
      expect(_fakeSecureStorage.containsKey('gestor_auth_token'), isFalse);
    });
  });

  group('restauração de sessão', () {
    test(
      'token válido persistido restaura sessão após revalidar no servidor',
      () async {
        _fakeSecureStorage['gestor_auth_token'] = _fakeJwt();
        final auth = buildService('http://127.0.0.1:${fakePb.port}');
        await auth.ready;
        expect(auth.isLoggedIn, isTrue);
      },
    );

    test(
      'token revogado pelo servidor é descartado — sem grant local',
      () async {
        // Token de outro "usuário": o servidor falso rejeita no auth-refresh.
        _fakeSecureStorage['gestor_auth_token'] = _fakeJwt(id: 'u-revogado');
        final auth = buildService('http://127.0.0.1:${fakePb.port}');
        await auth.ready;
        expect(auth.isLoggedIn, isFalse);
        expect(_fakeSecureStorage.containsKey('gestor_auth_token'), isFalse);
      },
    );

    test('token inválido persistido não restaura sessão', () async {
      _fakeSecureStorage['gestor_auth_token'] = 'lixo-nao-jwt';
      final auth = buildService('http://127.0.0.1:${fakePb.port}');
      await auth.ready;
      expect(auth.isLoggedIn, isFalse);
    });

    test(
      'erro transitório (429) na revalidação preserva o token persistido',
      () async {
        fakePb.refreshErrorStatus = 429;
        _fakeSecureStorage['gestor_auth_token'] = _fakeJwt();
        final auth = buildService('http://127.0.0.1:${fakePb.port}');
        await auth.ready;
        // Sem grant local, mas o token não é apagado — nova tentativa no
        // próximo init ainda pode restaurar a sessão.
        expect(auth.isLoggedIn, isFalse);
        expect(_fakeSecureStorage['gestor_auth_token'], isNotNull);
      },
    );

    test('servidor indisponível na restauração não concede acesso', () async {
      final probe = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final deadPort = probe.port;
      await probe.close();

      _fakeSecureStorage['gestor_auth_token'] = _fakeJwt();
      final auth = buildService('http://127.0.0.1:$deadPort');
      await auth.ready;
      expect(auth.isLoggedIn, isFalse);
    });
  });
}

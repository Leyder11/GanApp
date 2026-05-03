import 'dart:convert';

import 'package:flutter_application_1/core/storage/session_local_store.dart';
import 'package:flutter_application_1/features/auth/domain/user_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Helpers ────────────────────────────────────────────────────────────────

UserSession makeSession({
  String uid = 'user-42',
  String email = 'test@ganapp.com',
  String displayName = 'Usuario Test',
  String accessToken = 'test-access-token',
}) =>
    UserSession(
      uid: uid,
      email: email,
      displayName: displayName,
      accessToken: accessToken,
    );

void main() {
  late SessionLocalStore sut;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    sut = SessionLocalStore();
  });

  // ─── save ─────────────────────────────────────────────────────────────────

  group('save', () {
    test('guarda la sesión serializada en SharedPreferences', () async {
      final session = makeSession();

      await sut.save(session);

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('ganapp.session');
      expect(raw, isNotNull);

      final decoded = jsonDecode(raw!) as Map<String, dynamic>;
      expect(decoded['accessToken'], session.accessToken);
      expect(decoded['uid'], session.uid);
      expect(decoded['email'], session.email);
      expect(decoded['displayName'], session.displayName);
    });

    test('sobreescribe la sesión anterior cuando se llama dos veces', () async {
      final first = makeSession(accessToken: 'token-1');
      final second = makeSession(accessToken: 'token-2');

      await sut.save(first);
      await sut.save(second);

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('ganapp.session')!;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      expect(decoded['accessToken'], 'token-2');
    });
  });

  // ─── read ─────────────────────────────────────────────────────────────────

  group('read', () {
    test('retorna null cuando no hay sesión guardada', () async {
      final result = await sut.read();
      expect(result, isNull);
    });

    test('retorna null cuando el valor guardado es una cadena vacía', () async {
      SharedPreferences.setMockInitialValues({'ganapp.session': ''});

      final result = await sut.read();

      expect(result, isNull);
    });

    test('retorna null cuando el valor guardado no es un JSON de tipo Map',
        () async {
      SharedPreferences.setMockInitialValues(
          {'ganapp.session': jsonEncode([1, 2, 3])});

      final result = await sut.read();

      expect(result, isNull);
    });

    test('retorna la UserSession correctamente cuando existe una sesión guardada',
        () async {
      final original = makeSession(
        accessToken: 'recovered-token',
        uid: 'user-99',
        email: 'user99@ganapp.com',
        displayName: 'Usuario 99',
      );
      await sut.save(original);

      final result = await sut.read();

      expect(result, isNotNull);
      expect(result!.accessToken, 'recovered-token');
      expect(result.uid, 'user-99');
      expect(result.email, 'user99@ganapp.com');
      expect(result.displayName, 'Usuario 99');
    });

    test('puede leer la sesión guardada por save en la misma instancia',
        () async {
      final session = makeSession();
      await sut.save(session);

      final result = await sut.read();

      expect(result, isNotNull);
      expect(result!.accessToken, session.accessToken);
      expect(result.uid, session.uid);
    });
  });

  // ─── clear ────────────────────────────────────────────────────────────────

  group('clear', () {
    test('elimina la sesión guardada', () async {
      await sut.save(makeSession());

      await sut.clear();

      final result = await sut.read();
      expect(result, isNull);
    });

    test('no lanza excepción si no hay sesión guardada al limpiar', () async {
      expect(() => sut.clear(), returnsNormally);
    });

    test('elimina solo la clave de sesión, no otras claves', () async {
      SharedPreferences.setMockInitialValues({
        'ganapp.session': jsonEncode(makeSession().toJson()),
        'otra.clave': 'valor',
      });

      await sut.clear();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ganapp.session'), isNull);
      expect(prefs.getString('otra.clave'), 'valor');
    });
  });

  // ─── flujo completo ───────────────────────────────────────────────────────

  group('flujo completo', () {
    test('save → read → clear → read retorna null al final', () async {
      final session = makeSession();

      await sut.save(session);
      final recovered = await sut.read();
      expect(recovered, isNotNull);

      await sut.clear();
      final afterClear = await sut.read();
      expect(afterClear, isNull);
    });
  });
}
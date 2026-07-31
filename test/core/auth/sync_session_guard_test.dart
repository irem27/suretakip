import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:suretakip/core/auth/sync_session_guard.dart';
import 'package:suretakip/core/sync/models/sync_enums.dart';

/// `dart_jsonwebtoken` doğrulaması olmadan sadece `exp` claim'ini taşıyan,
/// imzası önemsenmeyen (gotrue yalnız payload'u decode eder) sahte bir JWT
/// üretir.
String _fakeJwt({required DateTime expiresAt}) {
  String segment(Map<String, Object?> value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');

  final header = segment({'alg': 'HS256', 'typ': 'JWT'});
  final payload = segment({
    'exp': expiresAt.millisecondsSinceEpoch ~/ 1000,
    'sub': 'user-1',
  });
  return '$header.$payload.signature';
}

Session _sessionExpiringAt(DateTime expiresAt) {
  final token = _fakeJwt(expiresAt: expiresAt);
  return Session.fromJson({
    'access_token': token,
    'token_type': 'bearer',
    'refresh_token': 'refresh-token',
    'user': {
      'id': 'user-1',
      'aud': 'authenticated',
      'created_at': DateTime.utc(2026).toIso8601String(),
      'app_metadata': <String, Object?>{},
      'user_metadata': <String, Object?>{},
    },
  })!;
}

void main() {
  group('SupabaseSessionGuard', () {
    late SupabaseClient client;

    setUp(() {
      client = SupabaseClient(
        'https://example.supabase.co',
        'anon-key',
        httpClient: null,
      );
    });

    test('oturum yoksa authRequired döner', () async {
      final guard = SupabaseSessionGuard(client);

      final result = await guard.ensureValidSession();

      expect(result, SyncResultType.authRequired);
    });

    test(
      'eşik dışında geçerli bir oturum varsa hiç dokunmadan null döner',
      () async {
        final farFuture = DateTime.now().toUtc().add(const Duration(hours: 1));
        await client.auth.recoverSession(
          jsonEncode(_sessionExpiringAt(farFuture).toJson()),
        );
        final guard = SupabaseSessionGuard(
          client,
          refreshThreshold: const Duration(minutes: 2),
        );

        final result = await guard.ensureValidSession();

        expect(result, isNull);
        expect(client.auth.currentSession, isNotNull);
      },
    );
  });
}

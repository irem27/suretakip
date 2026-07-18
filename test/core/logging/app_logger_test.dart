import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/logging/console_app_logger.dart';

void main() {
  test(
    'token ve kişisel verileri hata, bağlam ve stack trace içinde maskeler',
    () {
      final output = <String>[];
      final logger = ConsoleAppLogger(output: output.add);

      logger.error(
        StateError(
          'Bearer bearer-secret '
          'eyJhbGciOiJIUzI1NiJ9.payload.signature '
          'user@example.com +905551112233 password=plain-secret',
        ),
        context: 'token=context-secret owner@example.com',
        stackTrace: StackTrace.fromString(
          'refresh_token=stack-secret backup@example.com +905559998877',
        ),
      );

      final logged = output.join('\n');
      for (final sensitive in <String>[
        'bearer-secret',
        'eyJhbGciOiJIUzI1NiJ9',
        'user@example.com',
        '+905551112233',
        'plain-secret',
        'context-secret',
        'owner@example.com',
        'stack-secret',
        'backup@example.com',
        '+905559998877',
      ]) {
        expect(logged, isNot(contains(sensitive)), reason: sensitive);
      }
      expect(logged, contains('[MASKELENDİ]'));
    },
  );

  test('ham Postgres ayrıntısının tamamını maskeler', () {
    final output = <String>[];
    final logger = ConsoleAppLogger(output: output.add);

    logger.warn(
      StateError(
        'Postgres DETAIL: duplicate key value violates users_email_key',
      ),
    );

    final logged = output.single;
    expect(logged, isNot(contains('users_email_key')));
    expect(logged, contains('VERİTABANI AYRINTISI MASKELENDİ'));
  });

  test('JSON ve yaygın telefon biçimlerindeki hassas verileri maskeler', () {
    final output = <String>[];
    final logger = ConsoleAppLogger(output: output.add);

    logger.error(
      StateError(
        '{"password": "iki kelimeli parola", '
        '"api_key": "sb_publishable_ham-anahtar", '
        '"authorization": "Basic ham-kimlik", '
        '"phone": "+90 (555) 111 22 33"}',
      ),
    );

    final logged = output.single;
    for (final sensitive in <String>[
      'iki kelimeli parola',
      'sb_publishable_ham-anahtar',
      'Basic ham-kimlik',
      '+90 (555) 111 22 33',
    ]) {
      expect(logged, isNot(contains(sensitive)), reason: sensitive);
    }
  });
}

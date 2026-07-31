import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/core/errors/postgres_error_mapper.dart';

void main() {
  group('ödeme RPC hataları', () {
    final cases = <(String, Type)>[
      ('payment_amount_invalid', ValidationException),
      ('payment_idempotency_key_required', ValidationException),
      ('payment_idempotency_key_reused', ConflictException),
      ('payment_reason_required', ValidationException),
      ('payment_kind_not_voidable', ValidationException),
      ('payment_exceeds_balance', ConflictException),
      ('refund_exceeds_refundable', ConflictException),
      ('payment_already_voided', ConflictException),
      ('session_not_payable', ConflictException),
      ('payment_not_found', NotFoundException),
    ];

    for (final (code, expectedType) in cases) {
      test('$code doğru domain hatasına Türkçe mesajla eşlenir', () {
        final exception = PostgresErrorMapper.map(message: code, code: 'P0001');

        expect(exception.runtimeType, expectedType);
        expect(exception.code, code);
        expect(exception.message, isNot(code));
        expect(exception.message, matches(RegExp('[çğıöşüÇĞİÖŞÜ]')));
      });
    }
  });

  test(
    'yeniden kullanılan ödeme referansı yeni ödeme başlatmaya yönlendirir',
    () {
      final exception = PostgresErrorMapper.map(
        message: 'payment_idempotency_key_reused',
      );

      expect(exception, isA<ConflictException>());
      expect(exception.message, contains('başka bir işlem'));
      expect(exception.message, contains('yeni bir ödeme'));
    },
  );

  test('insufficient_stock hatasını conflict olarak eşler', () {
    final exception = PostgresErrorMapper.map(message: 'insufficient_stock');

    expect(exception, isA<ConflictException>());
    expect(exception.code, 'insufficient_stock');
  });

  test('not_a_member hatasını authorization olarak eşler', () {
    final exception = PostgresErrorMapper.map(message: 'not_a_member');

    expect(exception, isA<AuthorizationException>());
  });

  test('authentication_required hatasını authentication olarak eşler', () {
    final exception = PostgresErrorMapper.map(
      message: 'authentication_required',
    );

    expect(exception, isA<AuthenticationException>());
  });

  test('currency_mismatch hatasını validation olarak eşler', () {
    final exception = PostgresErrorMapper.map(message: 'currency_mismatch');

    expect(exception, isA<ValidationException>());
  });

  test('benzersizlik ihlalini conflict olarak eşler', () {
    final exception = PostgresErrorMapper.map(
      message: 'duplicate key value',
      code: '23505',
    );

    expect(exception, isA<ConflictException>());
  });

  test('ham hata ayrıntısını ve güvenli olmayan kodu maskeler', () {
    const sensitive =
        'Bearer eyJhbGciOiJIUzI1NiJ9.secret user@example.com +905551112233';
    final exception = PostgresErrorMapper.map(
      message: 'DETAIL: $sensitive on public.users',
      code: sensitive,
      cause: StateError(sensitive),
    );

    expect(exception, isA<DatabaseException>());
    expect(exception.code, isNull);
    expect(exception.message, isNot(contains('user@example.com')));
    expect(exception.toString(), isNot(contains('eyJhbGci')));
    expect(exception.cause.toString(), isNot(contains('+905551112233')));
    expect(exception.cause.toString(), 'Veritabanı hata ayrıntısı maskelendi.');
  });

  group('PostgresErrorMapper.map — ek RPC anahtarları', () {
    test('doğrulama hataları ValidationException', () {
      for (final key in [
        'business_name_required',
        'invalid_amount',
        'payment_reason_required',
        'user_id_required',
        'cannot_transfer_to_self',
      ]) {
        expect(
          PostgresErrorMapper.map(message: key),
          isA<ValidationException>(),
          reason: key,
        );
      }
    });

    test('çakışma hataları ConflictException', () {
      for (final key in [
        'session_not_payable',
        'refund_exceeds_refundable',
        'last_owner_protected',
        'member_already_exists',
        'session_already_cancelled',
      ]) {
        expect(
          PostgresErrorMapper.map(message: key),
          isA<ConflictException>(),
          reason: key,
        );
      }
    });

    test('bulunamadı hataları NotFoundException', () {
      for (final key in [
        'payment_not_found',
        'member_not_found',
        'user_not_found',
        'service_not_available',
      ]) {
        expect(
          PostgresErrorMapper.map(message: key),
          isA<NotFoundException>(),
          reason: key,
        );
      }
    });

    test('stok doğrudan yazma denemesi AuthorizationException', () {
      expect(
        PostgresErrorMapper.map(message: 'stock_quantity_direct_write_denied'),
        isA<AuthorizationException>(),
      );
    });

    test('anahtar kelime ortasında geçerse iş-hatasına eşlenmez', () {
      // 'not_a_member' harf komşularıyla çevrili → token sınırı yok, döngü
      // taramayı sürdürüp eşleşme bulmamalı (_containsToken/_isWordChar).
      final mapped = PostgresErrorMapper.map(
        message: 'xnot_a_memberx bir hata detayı not_a_membery',
        code: '99999',
      );
      expect(mapped, isA<DatabaseException>());
    });

    test('anahtar tekrar geçtiğinde ikinci konumda sınır bulur', () {
      // İlk geçiş kelime-parçası (eşleşmez), ikinci geçiş token-sınırlı.
      final mapped = PostgresErrorMapper.map(
        message: 'prefixnot_authorized ve ardından not_authorized',
      );
      expect(mapped, isA<AuthorizationException>());
    });
  });
}

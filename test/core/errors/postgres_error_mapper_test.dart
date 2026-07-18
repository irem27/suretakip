import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/core/errors/postgres_error_mapper.dart';

void main() {
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
}

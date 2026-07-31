import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/core/errors/supabase_error_guard.dart';
import 'package:suretakip/core/logging/console_app_logger.dart';

void main() {
  test(
    'PostgREST hatasını kullanıcı dostu domain exceptiona çevirir',
    () async {
      final future = SupabaseErrorGuard.run<void>(
        () => throw const PostgrestException(
          message: 'business_name_required',
          code: 'P0001',
        ),
      );

      await expectLater(
        future,
        throwsA(
          isA<ValidationException>().having(
            (error) => error.message,
            'message',
            'İşletme adı boş bırakılamaz.',
          ),
        ),
      );
    },
  );

  test('PostgREST içindeki token ve kişisel verileri maskeler', () async {
    const sensitive =
        'Bearer eyJhbGciOiJIUzI1NiJ9.secret user@example.com +905551112233';
    final future = SupabaseErrorGuard.run<void>(
      () => throw const PostgrestException(
        message: 'raw postgres detail: $sensitive',
        code: sensitive,
        details: 'public.users email column',
        hint: sensitive,
      ),
    );

    await expectLater(
      future,
      throwsA(
        isA<DatabaseException>()
            .having((error) => error.code, 'code', isNull)
            .having(
              (error) => error.message,
              'message',
              'Veritabanı işlemi tamamlanamadı. Lütfen tekrar deneyin.',
            )
            .having(
              (error) => error.cause.toString(),
              'cause',
              'Veritabanı hata ayrıntısı maskelendi.',
            ),
      ),
    );
  });

  test('beklenmeyen hata ayrıntısını log için güvenli tutar', () async {
    const sensitive = 'user@example.com eyJhbGciOiJIUzI1NiJ9.secret';
    final future = SupabaseErrorGuard.run<void>(
      () => throw StateError(sensitive),
    );

    await expectLater(
      future,
      throwsA(
        isA<UnknownException>().having(
          (error) => error.cause.toString(),
          'cause',
          'İşlem hata ayrıntısı maskelendi.',
        ),
      ),
    );
  });

  test('taşıma hatalarını NetworkException olarak eşler', () async {
    final errors = <Object>[
      const SocketException('user@example.com bağlantı yok'),
      TimeoutException('token=secret-token'),
      http.ClientException('Bearer secret-client-token'),
      AuthRetryableFetchException(message: 'password=very-secret'),
      AuthUnknownException(
        message: 'fetch failed',
        originalError: const SocketException('ağ yok'),
      ),
    ];

    for (final error in errors) {
      final future = SupabaseErrorGuard.run<void>(() => throw error);

      await expectLater(
        future,
        throwsA(
          isA<NetworkException>()
              .having(
                (exception) => exception.message,
                'message',
                'Çevrimdışı moddasınız.',
              )
              .having(
                (exception) => exception.cause.toString(),
                'cause',
                'İşlem hata ayrıntısı maskelendi.',
              ),
        ),
      );
    }
  });

  test('PostgREST ayrıntısını güvenli logger çıktısında maskeler', () async {
    final output = <String>[];
    final logger = ConsoleAppLogger(output: output.add);
    const sensitive =
        'Postgres DETAIL: user@example.com token=secret-token +905551112233';

    final future = SupabaseErrorGuard.run<void>(
      () => throw const PostgrestException(
        message: sensitive,
        details: sensitive,
        hint: sensitive,
      ),
      logger: logger,
      context: 'email=owner@example.com',
    );

    await expectLater(future, throwsA(isA<DatabaseException>()));
    final logged = output.join('\n');
    expect(logged, isNot(contains('user@example.com')));
    expect(logged, isNot(contains('owner@example.com')));
    expect(logged, isNot(contains('secret-token')));
    expect(logged, isNot(contains('+905551112233')));
    expect(logged, contains('VERİTABANI AYRINTISI MASKELENDİ'));
  });
}

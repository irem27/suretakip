import 'dart:async';
import 'dart:io';

// Supabase'in HTTP taşıma katmanında kullandığı mevcut geçişli paket.
// Yeni bağımlılık eklemeden somut ClientException tipini ayırt ediyoruz.
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/core/errors/postgres_error_mapper.dart';
import 'package:suretakip/core/errors/sensitive_data_sanitizer.dart';
import 'package:suretakip/core/logging/app_logger.dart';
import 'package:suretakip/core/logging/noop_app_logger.dart';

abstract final class SupabaseErrorGuard {
  static Future<T> run<T>(
    Future<T> Function() operation, {
    AppLogger logger = const NoopAppLogger(),
    String? context,
  }) async {
    try {
      return await operation();
    } on PostgrestException catch (error, stackTrace) {
      logger.error(error, stackTrace: stackTrace, context: context);
      throw PostgresErrorMapper.map(
        message: error.message,
        code: error.code,
        cause: SensitiveDataSanitizer.sanitizedCause(),
      );
    } catch (error, stackTrace) {
      logger.error(error, stackTrace: stackTrace, context: context);
      if (error is DomainException) rethrow;
      final networkException = mapNetworkError(error);
      if (networkException != null) throw networkException;
      throw UnknownException(
        'İşlem tamamlanamadı. Lütfen tekrar deneyin.',
        cause: SensitiveDataSanitizer.sanitizedCause(),
      );
    }
  }

  static NetworkException? mapNetworkError(Object error) {
    if (!_isNetworkError(error)) return null;
    return NetworkException(
      'İnternet bağlantısı yok gibi görünüyor. '
      'Bağlantınızı kontrol edip tekrar deneyin.',
      cause: SensitiveDataSanitizer.sanitizedCause(),
    );
  }

  static bool _isNetworkError(Object error) =>
      error is SocketException ||
      error is TimeoutException ||
      error is http.ClientException ||
      error is AuthRetryableFetchException ||
      (error is AuthUnknownException && _isNetworkError(error.originalError));
}

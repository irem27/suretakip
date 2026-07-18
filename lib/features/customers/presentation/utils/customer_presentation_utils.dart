import 'package:suretakip/core/errors/domain_exception.dart';

String customerErrorMessage(Object? error, String fallback) =>
    error is DomainException ? error.message : fallback;

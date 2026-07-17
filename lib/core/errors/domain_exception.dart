sealed class DomainException implements Exception {
  const DomainException(this.message, {this.code, this.cause});

  final String message;
  final String? code;
  final Object? cause;

  @override
  String toString() => message;
}

final class NetworkException extends DomainException {
  const NetworkException(super.message, {super.code, super.cause});
}

final class AuthenticationException extends DomainException {
  const AuthenticationException(super.message, {super.code, super.cause});
}

final class AuthorizationException extends DomainException {
  const AuthorizationException(super.message, {super.code, super.cause});
}

final class ValidationException extends DomainException {
  const ValidationException(super.message, {super.code, super.cause});
}

final class DatabaseException extends DomainException {
  const DatabaseException(super.message, {super.code, super.cause});
}

final class NotFoundException extends DomainException {
  const NotFoundException(super.message, {super.code, super.cause});
}

final class ConflictException extends DomainException {
  const ConflictException(super.message, {super.code, super.cause});
}

final class UnknownException extends DomainException {
  const UnknownException(super.message, {super.code, super.cause});
}

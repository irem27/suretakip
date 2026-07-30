import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/features/auth/domain/entities/auth_session_state.dart';

void main() {
  group('AuthSessionState', () {
    test('two instances with same field values are equal', () {
      // Arrange
      const first = AuthSessionState(userId: 'user-1');
      const second = AuthSessionState(userId: 'user-1');

      // Act & Assert
      expect(first, equals(second));
      expect(first.hashCode, equals(second.hashCode));
    });

    test('instances with different userId are not equal', () {
      // Arrange
      const first = AuthSessionState(userId: 'user-1');
      const second = AuthSessionState(userId: 'user-2');

      // Act & Assert
      expect(first, isNot(equals(second)));
    });

    test('instances with different isPasswordRecovery are not equal', () {
      // Arrange
      const first = AuthSessionState(userId: 'user-1');
      const second =
          AuthSessionState(userId: 'user-1', isPasswordRecovery: true);

      // Act & Assert
      expect(first, isNot(equals(second)));
    });

    test('null userId instances with same recovery flag are equal', () {
      // Arrange
      const first = AuthSessionState(userId: null);
      const second = AuthSessionState(userId: null);

      // Act & Assert
      expect(first, equals(second));
      expect(first.hashCode, equals(second.hashCode));
    });
  });
}

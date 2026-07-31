import 'package:suretakip/core/constants/app_constants.dart';

abstract final class FormValidators {
  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'E-posta zorunlu.';
    final valid = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
    return valid ? null : 'Geçerli bir e-posta adresi girin.';
  }

  static String? password(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Şifre zorunlu.';
    if (password.length < AppConstants.minimumPasswordLength) {
      return 'Şifre en az ${AppConstants.minimumPasswordLength} karakter olmalı.';
    }
    return null;
  }

  static String? requiredName(String? value, String label) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return '$label zorunlu.';
    if (name.length > AppConstants.maximumNameLength) {
      return '$label en fazla ${AppConstants.maximumNameLength} karakter olabilir.';
    }
    return null;
  }

  static String? nonNegativeMoney(String? value, String label) {
    final normalized = (value ?? '').trim().replaceAll(',', '.');
    if (normalized.isEmpty) return '$label zorunlu.';
    final amount = double.tryParse(normalized);
    if (amount == null || !amount.isFinite || amount < 0) {
      return 'Geçerli bir $label girin.';
    }
    final decimalPart = normalized.split('.');
    if (decimalPart.length > 1 && decimalPart.last.length > 2) {
      return '$label en fazla iki ondalık basamak içerebilir.';
    }
    return null;
  }

  static String? positiveMoney(String? value, String label) {
    final error = nonNegativeMoney(value, label);
    if (error != null) return error;
    if (moneyToMinor(value!) <= 0) return '$label sıfırdan büyük olmalı.';
    return null;
  }

  /// Kullanıcı girdisini kuruş (minor unit) tam sayısına çevirir.
  /// Float aritmetiği KULLANMAZ — "12,07" gibi girdilerde `12.07 * 100`
  /// yuvarlama hatası yaşanmaması için tam/kesir kısmı ayrı ayrı işlenir.
  /// `nonNegativeMoney` doğrulamasından geçmiş bir değer beklenir.
  static int moneyToMinor(String value) {
    final parts = value.trim().replaceAll(',', '.').split('.');
    final whole = parts.first.isEmpty ? 0 : int.parse(parts.first);
    final fraction = parts.length > 1 && parts[1].isNotEmpty
        ? int.parse(parts[1].padRight(2, '0').substring(0, 2))
        : 0;
    return whole * 100 + fraction;
  }
}

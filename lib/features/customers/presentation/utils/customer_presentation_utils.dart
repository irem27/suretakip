import 'package:flutter/widgets.dart';
import 'package:suretakip/core/errors/domain_exception.dart';

String customerErrorMessage(Object? error, String fallback) =>
    error is DomainException ? error.message : fallback;

/// Müşteri avatarı için baş harfi güvenli üretir.
///
/// Boş/whitespace isim (legacy/migrate/manuel kayıt) build'i çökertmesin:
/// `characters.first` boş dizide StateError atar. Bu durumda '?' döner.
String customerAvatarInitial(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  return trimmed.characters.first.toUpperCase();
}

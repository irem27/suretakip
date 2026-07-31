import 'package:suretakip/core/domain/domain_enums.dart';

/// Arayüzü role göre uyarlamak için kullanılan istemci tarafı yetki ipuçları.
///
/// Gerçek yetkilendirme sınırı sunucu tarafındaki RLS ve RPC kontrolleridir.
final class BusinessCapabilities {
  const BusinessCapabilities({
    required this.canManageCatalog,
    required this.canManageMembers,
    required this.canEditBusinessSettings,
    required this.canCancelCompletedSession,
  });

  const BusinessCapabilities.none()
    : canManageCatalog = false,
      canManageMembers = false,
      canEditBusinessSettings = false,
      canCancelCompletedSession = false;

  final bool canManageCatalog;
  final bool canManageMembers;
  final bool canEditBusinessSettings;
  final bool canCancelCompletedSession;

  factory BusinessCapabilities.forRole(MemberRole? role) => switch (role) {
    MemberRole.owner || MemberRole.admin => const BusinessCapabilities(
      canManageCatalog: true,
      canManageMembers: true,
      canEditBusinessSettings: true,
      canCancelCompletedSession: true,
    ),
    MemberRole.staff || null => const BusinessCapabilities.none(),
  };

  /// Admin üyeleri yönetebilir ancak owner rolündeki bir satıra dokunamaz.
  static bool canManageMemberRow({
    required MemberRole actorRole,
    required MemberRole targetRole,
  }) => switch (actorRole) {
    MemberRole.owner => true,
    MemberRole.admin => targetRole != MemberRole.owner,
    MemberRole.staff => false,
  };
}

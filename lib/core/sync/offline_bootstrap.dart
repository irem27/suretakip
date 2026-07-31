import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suretakip/app/providers/app_providers.dart';

/// Çevrimdışı önbellek ısıtıcı.
///
/// Online iken tüm referans verisini (müşteri, hizmet, ürün) yerel Drift
/// önbelleğine çeker ki KULLANICI ÇEVRİMDIŞIYKEN DE her fonksiyon çalışsın —
/// özellikle offline seans başlatma hizmet/ürün kataloğunun yerelde bulunmasına
/// bağlıdır. Her çekim bağımsızdır; biri (ör. offline) başarısız olursa diğerleri
/// etkilenmez ve mevcut önbellek olduğu gibi korunur (asla silinmez).
class OfflineBootstrap {
  const OfflineBootstrap(this._ref);

  final Ref _ref;

  /// Verilen işletme için üyelik + hizmet + ürün verisini paralel çeker.
  /// Müşteriler zaten kendi delta/liste senkronizasyonuyla geldiğinden burada
  /// tekrar çekilmez. Üyelik (getMembers) kritiktir: offline seans/müşteri
  /// başlatma `currentMemberProvider`'a bağlıdır ve o üyelik önbelleğini okur —
  /// önbellek boşsa çevrimdışı hata verir. Çevrimdışıysa sessizce geçer (mevcut
  /// önbellek korunur, ASLA silinmez).
  Future<void> warm(String businessId) async {
    await Future.wait([
      _guard(() async {
        await _ref.read(businessesRepositoryProvider).getMembers(businessId);
      }, 'members'),
      _guard(
        () => _ref
            .read(offlineServicesRepositoryProvider)
            .pullFromServer(businessId),
        'services',
      ),
      _guard(
        () => _ref
            .read(offlineProductsRepositoryProvider)
            .pullFromServer(businessId),
        'products',
      ),
    ]);
  }

  Future<void> _guard(Future<void> Function() op, String label) async {
    try {
      await op();
    } catch (error, stack) {
      // Çevrimdışı/hata: mevcut önbellek korunur, ısıtma sessizce atlanır.
      _ref
          .read(appLoggerProvider)
          .warn(error, stackTrace: stack, context: 'OfflineBootstrap.$label');
    }
  }
}

final offlineBootstrapProvider = Provider<OfflineBootstrap>(
  (ref) => OfflineBootstrap(ref),
);

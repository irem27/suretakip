import 'package:suretakip/features/services/domain/entities/service.dart';
import 'package:suretakip/features/services/domain/entities/service_input.dart';

abstract interface class ServicesRepository {
  Future<List<Service>> getServices({
    required String businessId,
    bool includeInactive = false,
  });

  Future<Service> getService(String serviceId);

  Future<Service> createService(ServiceInput input);

  /// Yalnızca düzenlenebilir alanları (ad, fiyat, yuvarlama, minimum) günceller.
  /// Aktiflik durumu ve arşiv damgası bu yolla DEĞİŞTİRİLMEZ; onlar için
  /// [setServiceActive] kullanılır — böylece eşzamanlı toggle ile düzenleme
  /// birbirini ezmez (kayıp güncelleme önlenir).
  Future<Service> updateService(Service service);

  /// Yalnızca `is_active` + `archived_at` alanlarını yazar (kısmi güncelleme).
  Future<Service> setServiceActive(String serviceId, {required bool isActive});
}

import 'package:suretakip/features/services/domain/entities/service.dart';

abstract interface class ServicesRepository {
  Future<List<Service>> getServices({
    required String businessId,
    bool includeInactive = false,
  });

  Future<Service> getService(String serviceId);

  Future<Service> createService(Service service);

  Future<Service> updateService(Service service);
}

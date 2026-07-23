import 'dart:async';

import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/core/logging/app_logger.dart';
import 'package:suretakip/core/logging/noop_app_logger.dart';
import 'package:suretakip/features/products/data/local/products_local_data_source.dart';
import 'package:suretakip/features/products/domain/entities/inventory_movement.dart';
import 'package:suretakip/features/products/domain/entities/product.dart';
import 'package:suretakip/features/products/domain/entities/product_input.dart';
import 'package:suretakip/features/products/domain/repositories/products_repository.dart';

/// Ürün okumalarını local-first stale-while-revalidate önbellekle sarar.
/// Önbellek doluysa UI hemen açılır, sunucu yenilemesi arka planda çalışır.
/// Yazma ve envanter hareketleri internet ister.
class CachedProductsRepository implements ProductsRepository {
  CachedProductsRepository({
    required ProductsRepository remote,
    required ProductsLocalDataSource local,
    AppLogger logger = const NoopAppLogger(),
  }) : _remote = remote,
       _local = local,
       _logger = logger;

  final ProductsRepository _remote;
  final ProductsLocalDataSource _local;
  final AppLogger _logger;

  @override
  Future<List<Product>> getProducts({
    required String businessId,
    bool includeInactive = false,
  }) async {
    final cached = await _local.getProducts(
      businessId: businessId,
      includeInactive: includeInactive,
    );
    if (cached.isNotEmpty) {
      unawaited(_refreshProducts(businessId));
      return cached;
    }
    try {
      // Önbellek boş: tam katalog (pasif dahil) çekilir ki yönetim görünümü de
      // çevrimdışı doğru çalışsın; istenen filtre burada uygulanır.
      final all = await _remote.getProducts(
        businessId: businessId,
        includeInactive: true,
      );
      await _cache(() => _local.replaceProducts(businessId, all));
      return includeInactive
          ? all
          : all.where((p) => p.isActive).toList(growable: false);
    } on NetworkException {
      return cached;
    }
  }

  @override
  Future<Product> getProduct(String productId) async {
    final cached = await _local.getProduct(productId);
    if (cached != null) {
      unawaited(_refreshProduct(productId));
      return cached;
    }
    try {
      final product = await _remote.getProduct(productId);
      await _cache(() => _local.upsertProduct(product));
      return product;
    } on NetworkException {
      rethrow;
    }
  }

  @override
  Future<Product> createProduct(ProductInput input) async {
    final created = await _remote.createProduct(input);
    await _cache(() => _local.upsertProduct(created));
    return created;
  }

  @override
  Future<Product> updateProduct(Product product) async {
    final updated = await _remote.updateProduct(product);
    await _cache(() => _local.upsertProduct(updated));
    return updated;
  }

  @override
  Future<Product> setProductActive(
    String productId, {
    required bool isActive,
  }) async {
    final updated = await _remote.setProductActive(
      productId,
      isActive: isActive,
    );
    await _cache(() => _local.upsertProduct(updated));
    return updated;
  }

  // Envanter hareketleri sunucu-otoriteli; önbelleklenmez.
  @override
  Future<List<InventoryMovement>> getInventoryMovements({
    required String businessId,
    String? productId,
  }) => _remote.getInventoryMovements(
    businessId: businessId,
    productId: productId,
  );

  @override
  Future<InventoryMovement> createInventoryMovement(
    InventoryMovement movement,
  ) => _remote.createInventoryMovement(movement);

  /// Arka plan yenilemesi her zaman TAM katalogu (pasif dahil) çeker; böylece
  /// aktif-only bir görünüm önbellekteki pasif kayıtları silmez.
  Future<void> _refreshProducts(String businessId) async {
    try {
      final all = await _remote.getProducts(
        businessId: businessId,
        includeInactive: true,
      );
      await _cache(() => _local.replaceProducts(businessId, all));
    } catch (error, stack) {
      _logRefreshError(error, stack, 'list');
    }
  }

  Future<void> _refreshProduct(String productId) async {
    try {
      final product = await _remote.getProduct(productId);
      await _cache(() => _local.upsertProduct(product));
    } catch (error, stack) {
      _logRefreshError(error, stack, 'detail');
    }
  }

  void _logRefreshError(Object error, StackTrace stack, String target) {
    _logger.warn(
      error,
      stackTrace: stack,
      context: 'CachedProductsRepository.refresh.$target',
    );
  }

  Future<void> _cache(Future<void> Function() write) async {
    try {
      await write();
    } catch (error, stack) {
      _logger.warn(
        error,
        stackTrace: stack,
        context: 'CachedProductsRepository.cache',
      );
    }
  }
}

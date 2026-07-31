import 'dart:async';

import 'package:uuid/uuid.dart';
import 'package:suretakip/core/database/app_database.dart';
import 'package:suretakip/core/logging/app_logger.dart';
import 'package:suretakip/core/logging/noop_app_logger.dart';
import 'package:suretakip/core/sync/device_identity.dart';
import 'package:suretakip/core/sync/sync_engine.dart';
import 'package:suretakip/features/products/data/local/products_local_data_source.dart';
import 'package:suretakip/features/products/domain/entities/inventory_movement.dart';
import 'package:suretakip/features/products/domain/entities/product.dart';
import 'package:suretakip/features/products/domain/entities/product_input.dart';
import 'package:suretakip/features/products/domain/repositories/products_repository.dart';

/// Offline-first ürün katalog yazımı (müşteri deseninin birebir aynısı,
/// Sprint 1). Ürün + outbox tek transaction'da yerelde yazılır, sonra push
/// denemesi tetiklenir. UI, dönüşü beklemeden yerel önbellek üzerinden
/// kaydı anında görür.
///
/// [ProductsRepository] sözleşmesini uygular; böylece mevcut controller/UI
/// katmanı hiç değişmeden `productsRepositoryProvider` bağlaması ile
/// çevrimdışı yazma yoluna geçer (bkz. `app_providers.dart`).
///
/// Envanter hareketleri (`getInventoryMovements`/`createInventoryMovement`)
/// sunucu-otoriteli kalır: ledger asla offline yazılmaz, bu iki metot internet
/// ister — mevcut `ProductsRepositoryImpl` davranışıyla aynıdır.
class OfflineProductsRepository implements ProductsRepository {
  OfflineProductsRepository({
    required ProductsLocalDataSource local,
    required ProductsRepository remote,
    required DeviceIdentity deviceIdentity,
    required SyncEngine syncEngine,
    // ProductsRepository sözleşmesi actorUserId almaz (mevcut controller/UI
    // katmanını değiştirmemek için); denetim izi (sync_processed_operations)
    // ve outbox aktör izolasyonu için oturumdaki kullanıcı buradan okunur —
    // SyncEngine.currentActorUserId ile AYNI kaynak.
    required String? Function() currentActorUserId,
    Uuid? uuid,
    DateTime Function()? clock,
    AppLogger logger = const NoopAppLogger(),
  }) : _local = local,
       _remote = remote,
       _deviceIdentity = deviceIdentity,
       _syncEngine = syncEngine,
       _currentActorUserId = currentActorUserId,
       _uuid = uuid ?? const Uuid(),
       _clock = clock ?? (() => DateTime.now().toUtc()),
       _logger = logger;

  final ProductsLocalDataSource _local;
  final ProductsRepository _remote;
  final DeviceIdentity _deviceIdentity;
  final SyncEngine _syncEngine;
  final String? Function() _currentActorUserId;
  final Uuid _uuid;
  final DateTime Function() _clock;
  final AppLogger _logger;

  /// Önbellek doluysa yerelden döner ve arka planda tam katalogu tazeler;
  /// boşsa sunucudan (tam katalog) çeker ve önbelleğe yazar.
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
    final all = await _remote.getProducts(
      businessId: businessId,
      includeInactive: true,
    );
    await _cache(() => _local.replaceProducts(businessId, all));
    return includeInactive
        ? all
        : all.where((p) => p.isActive).toList(growable: false);
  }

  /// Proaktif önbellek ısıtma: tam ürün katalogunu sunucudan çekip yerele yazar.
  /// Online iken (ör. giriş/dashboard) çağrılır ki çevrimdışıyken ürünler DAİMA
  /// mevcut olsun.
  Future<void> pullFromServer(String businessId) async {
    final all = await _remote.getProducts(
      businessId: businessId,
      includeInactive: true,
    );
    await _cache(() => _local.replaceProducts(businessId, all));
  }

  @override
  Future<Product> getProduct(String productId) async {
    final cached = await _local.getProduct(productId);
    if (cached != null) {
      unawaited(_refreshProduct(productId));
      return cached;
    }
    final product = await _remote.getProduct(productId);
    await _cache(() => _local.upsertProduct(product));
    return product;
  }

  /// Yeni ürünü yerelde kalıcı yazar ve arka planda senkronizasyonu tetikler.
  /// Push başarısız olsa bile kayıt cihazda korunur.
  @override
  Future<Product> createProduct(ProductInput input) async {
    final deviceId = await _deviceIdentity.getOrCreate();
    final row = await _local.enqueueCreateProduct(
      EnqueueCreateProduct(
        productId: _uuid.v4(),
        operationId: _uuid.v4(),
        businessId: input.businessId,
        actorUserId: _requireActorUserId(),
        deviceId: deviceId,
        name: input.name,
        sku: input.sku,
        unitPriceMinor: input.unitPrice.minorUnits,
        currencyCode: input.unitPrice.currencyCode,
        trackStock: input.trackStock,
        stockQuantity: input.stockQuantity,
        now: _clock(),
      ),
    );

    // Fire-and-forget: bağlantı yoksa kayıt pending kalır, sonra denenir.
    // Arka plan sync hatası (ör. offline) çağıranı asla düşürmemelidir.
    unawaited(_syncEngine.push().catchError(_handleBackgroundSyncError));
    return _fromRow(row);
  }

  /// Var olan ürünü yerelde günceller ve arka planda senkronizasyonu
  /// tetikler. Push başarısız olsa (ör. offline) da kayıt cihazda "bekliyor"
  /// olarak korunur; bağlantı gelince otomatik gönderilir.
  @override
  Future<Product> updateProduct(Product product) async {
    final deviceId = await _deviceIdentity.getOrCreate();
    final existing = await _local.findProductRow(product.id);
    if (existing == null) {
      throw StateError('Yerel ürün kaydı bulunamadı: ${product.id}');
    }
    final row = await _local.enqueueUpdateProduct(
      EnqueueUpdateProduct(
        productId: product.id,
        operationId: _uuid.v4(),
        businessId: product.businessId,
        actorUserId: _requireActorUserId(),
        deviceId: deviceId,
        name: product.name,
        sku: product.sku,
        unitPriceMinor: product.unitPriceMinor,
        trackStock: product.trackStock,
        expectedVersion: existing.serverVersion ?? 1,
        now: _clock(),
      ),
    );

    unawaited(_syncEngine.push().catchError(_handleBackgroundSyncError));
    return _fromRow(row);
  }

  /// Ürünü yerelde aktif/pasif yapar ve arka planda senkronizasyonu
  /// tetikler. Push başarısız olsa da kayıt cihazda "bekliyor" olarak korunur.
  @override
  Future<Product> setProductActive(
    String productId, {
    required bool isActive,
  }) async {
    final deviceId = await _deviceIdentity.getOrCreate();
    final existing = await _local.findProductRow(productId);
    if (existing == null) {
      throw StateError('Yerel ürün kaydı bulunamadı: $productId');
    }
    final row = await _local.enqueueSetProductActive(
      EnqueueSetProductActive(
        productId: productId,
        operationId: _uuid.v4(),
        businessId: existing.businessId,
        actorUserId: _requireActorUserId(),
        deviceId: deviceId,
        isActive: isActive,
        expectedVersion: existing.serverVersion ?? 1,
        now: _clock(),
      ),
    );

    unawaited(_syncEngine.push().catchError(_handleBackgroundSyncError));
    return _fromRow(row);
  }

  // Envanter hareketleri sunucu-otoriteli; asla offline yazılmaz.
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
      context: 'OfflineProductsRepository.refresh.$target',
    );
  }

  Future<void> _cache(Future<void> Function() write) async {
    try {
      await write();
    } catch (error, stack) {
      _logger.warn(
        error,
        stackTrace: stack,
        context: 'OfflineProductsRepository.cache',
      );
    }
  }

  SyncRunSummary _handleBackgroundSyncError(Object error, StackTrace stack) {
    _logger.warn(
      error,
      stackTrace: stack,
      context: 'OfflineProductBackgroundSync',
    );
    return const SyncRunSummary(
      pushed: 0,
      retried: 0,
      failed: 0,
      authRequired: false,
    );
  }

  /// Bekleyen tüm kayıtları göndermeyi dener (uygulama açılışı, foreground,
  /// "şimdi senkronize et" gibi tetikleyiciler için).
  Future<SyncRunSummary> sync() => _syncEngine.push();

  /// Oturumsuz offline yazma engellenir: outbox aktör izolasyonu (Bölüm 16.2)
  /// `originalActorUserId`'nin doğru kullanıcıya ait olmasını gerektirir.
  String _requireActorUserId() {
    final actorUserId = _currentActorUserId();
    if (actorUserId == null) {
      throw StateError('Ürün işlemi için oturum açık bir kullanıcı gerekir.');
    }
    return actorUserId;
  }

  Product _fromRow(LocalProductRow row) => Product(
    id: row.id,
    businessId: row.businessId,
    name: row.name,
    sku: row.sku,
    unitPriceMinor: row.unitPriceMinor,
    currencyCode: row.currencyCode,
    trackStock: row.trackStock,
    stockQuantity: row.stockQuantity,
    isActive: row.isActive,
    archivedAt: row.archivedAt,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );
}

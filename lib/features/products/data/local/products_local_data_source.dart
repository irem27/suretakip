import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:suretakip/core/database/app_database.dart';
import 'package:suretakip/core/sync/models/sync_enums.dart';
import 'package:suretakip/features/products/domain/entities/product.dart';

/// Yeni ürün oluşturma için gereken, senkronizasyondan bağımsız girdi.
final class EnqueueCreateProduct {
  const EnqueueCreateProduct({
    required this.productId,
    required this.operationId,
    required this.businessId,
    required this.actorUserId,
    required this.deviceId,
    required this.name,
    required this.unitPriceMinor,
    required this.currencyCode,
    required this.trackStock,
    required this.stockQuantity,
    required this.now,
    this.sku,
    this.payloadVersion = 1,
  });

  final String productId;
  final String operationId;
  final String businessId;
  final String actorUserId;
  final String deviceId;
  final String name;
  final String? sku;
  final int unitPriceMinor;
  final String currencyCode;
  final bool trackStock;
  final int stockQuantity;
  final DateTime now;
  final int payloadVersion;

  /// {business_id}:{device_id}:{operation_id} (Bölüm 7.2).
  String get idempotencyKey => '$businessId:$deviceId:$operationId';
}

/// Var olan ürünü güncelleme için gereken, senkronizasyondan bağımsız girdi.
/// Yalnızca sunucu tarafında düzenlenebilir kolonlar taşınır (stok/para birimi
/// hariç — bkz. `20260718090000_product_write_hardening.sql`).
final class EnqueueUpdateProduct {
  const EnqueueUpdateProduct({
    required this.productId,
    required this.operationId,
    required this.businessId,
    required this.actorUserId,
    required this.deviceId,
    required this.name,
    required this.unitPriceMinor,
    required this.trackStock,
    required this.expectedVersion,
    required this.now,
    this.sku,
    this.payloadVersion = 1,
  });

  final String productId;
  final String operationId;
  final String businessId;
  final String actorUserId;
  final String deviceId;
  final String name;
  final String? sku;
  final int unitPriceMinor;
  final bool trackStock;

  /// Optimistic concurrency için yerelde bilinen `server_version` (Bölüm 8).
  final int expectedVersion;
  final DateTime now;
  final int payloadVersion;

  /// {business_id}:{device_id}:{operation_id} (Bölüm 7.2).
  String get idempotencyKey => '$businessId:$deviceId:$operationId';
}

/// Ürünü aktif/pasif yapma için gereken, senkronizasyondan bağımsız girdi.
final class EnqueueSetProductActive {
  const EnqueueSetProductActive({
    required this.productId,
    required this.operationId,
    required this.businessId,
    required this.actorUserId,
    required this.deviceId,
    required this.isActive,
    required this.expectedVersion,
    required this.now,
    this.payloadVersion = 1,
  });

  final String productId;
  final String operationId;
  final String businessId;
  final String actorUserId;
  final String deviceId;
  final bool isActive;

  /// Optimistic concurrency için yerelde bilinen `server_version` (Bölüm 8).
  final int expectedVersion;
  final DateTime now;
  final int payloadVersion;

  /// {business_id}:{device_id}:{operation_id} (Bölüm 7.2).
  String get idempotencyKey => '$businessId:$deviceId:$operationId';
}

/// Ürün okuma ve "ürün + outbox" atomik yazımını yöneten Drift katmanı.
/// Stok her zaman sunucu-otoriteli kalır; yerelde yalnız ürünün diğer
/// alanları (ad, sku, fiyat, track_stock, aktiflik) offline yazılabilir.
class ProductsLocalDataSource {
  const ProductsLocalDataSource(this._db);

  final AppDatabase _db;

  /// Yalnız temiz (dirty olmayan) yerel kopyalar sunucu snapshot'ı ile
  /// ezilir; offline yazılmış bekleyen/çakışmalı kayıtlar korunur
  /// (`upsertServerCustomers` ile aynı desen).
  Future<void> replaceProducts(String businessId, List<Product> products) =>
      _db.transaction(() async {
        const dirtyStatuses = <String>{
          'localOnly',
          'pending',
          'processing',
          'retrying',
          'conflicted',
        };
        final existingRows = await (_db.select(
          _db.localProducts,
        )..where((t) => t.businessId.equals(businessId))).get();
        final dirtyIds = {
          for (final row in existingRows)
            if (dirtyStatuses.contains(row.syncStatus)) row.id,
        };
        for (final row in existingRows) {
          if (dirtyIds.contains(row.id)) continue;
          await (_db.delete(
            _db.localProducts,
          )..where((t) => t.id.equals(row.id))).go();
        }
        for (final product in products) {
          if (dirtyIds.contains(product.id)) continue;
          await _db
              .into(_db.localProducts)
              .insertOnConflictUpdate(_toCompanion(product));
        }
      });

  Future<List<Product>> getProducts({
    required String businessId,
    bool includeInactive = false,
  }) async {
    final query = _db.select(_db.localProducts)
      ..where(
        (t) => t.businessId.equals(businessId) & t.isDeleted.equals(false),
      )
      ..orderBy([(t) => OrderingTerm(expression: t.name)]);
    if (!includeInactive) query.where((t) => t.isActive.equals(true));
    final rows = await query.get();
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<Product?> getProduct(String id) async {
    final row = await findProductRow(id);
    return row == null ? null : _fromRow(row);
  }

  Future<LocalProductRow?> findProductRow(String id) => (_db.select(
    _db.localProducts,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> upsertProduct(Product product) => _db
      .into(_db.localProducts)
      .insertOnConflictUpdate(_toCompanion(product));

  /// Domain kaydı ve outbox kaydını TEK transaction'da yazar (Bölüm 6).
  /// Stok her zaman 0 ile açılır; ilk stok varsa sunucu tarafında
  /// `inventory_movements` ledger kaydı olarak eklenir — cache asla doğrudan
  /// yazılmaz (bkz. dosya başındaki not).
  Future<LocalProductRow> enqueueCreateProduct(
    EnqueueCreateProduct command,
  ) {
    return _db.transaction(() async {
      final product = LocalProductsCompanion.insert(
        id: command.productId,
        businessId: command.businessId,
        name: command.name,
        sku: Value(command.sku),
        unitPriceMinor: command.unitPriceMinor,
        currencyCode: command.currencyCode,
        trackStock: Value(command.trackStock),
        // Yerel önbellek de ledger kadar otoriteli değildir; başlangıç stoğu
        // iyimser biçimde gösterilir, sunucu senkronu gerçek değeri getirir.
        stockQuantity: Value(command.trackStock ? command.stockQuantity : 0),
        syncStatus: Value(SyncStatus.pending.wireName),
        createdAt: command.now,
        updatedAt: command.now,
      );
      await _db.into(_db.localProducts).insert(product);

      final payload = <String, Object?>{
        'id': command.productId,
        'name': command.name,
        'sku': command.sku,
        'unit_price_minor': command.unitPriceMinor,
        'currency_code': command.currencyCode,
        'track_stock': command.trackStock,
        'initial_stock': command.stockQuantity,
      };

      await _db
          .into(_db.syncOutbox)
          .insert(
            SyncOutboxCompanion.insert(
              id: command.operationId,
              operationId: command.operationId,
              businessId: command.businessId,
              originalActorUserId: command.actorUserId,
              deviceId: command.deviceId,
              aggregateType: 'product',
              aggregateId: command.productId,
              operationType: SyncOperationType.createProduct.wireName,
              sequenceNumber: await _nextSequence(
                'product',
                command.productId,
              ),
              payloadJson: jsonEncode(payload),
              payloadVersion: Value(command.payloadVersion),
              idempotencyKey: command.idempotencyKey,
              status: SyncStatus.pending.wireName,
              createdAt: command.now,
            ),
          );

      final inserted = await findProductRow(command.productId);
      if (inserted == null) {
        throw StateError('Yerel ürün kaydı oluşturulamadı.');
      }
      return inserted;
    });
  }

  /// Var olan ürünü ve outbox kaydını TEK transaction'da yazar
  /// (`enqueueCreateProduct` ile aynı desen). `server_version`, optimistic
  /// concurrency için yerel satırdan `expected_version` olarak okunur.
  Future<LocalProductRow> enqueueUpdateProduct(
    EnqueueUpdateProduct command,
  ) {
    return _db.transaction(() async {
      await (_db.update(
        _db.localProducts,
      )..where((t) => t.id.equals(command.productId))).write(
        LocalProductsCompanion(
          name: Value(command.name),
          sku: Value(command.sku),
          unitPriceMinor: Value(command.unitPriceMinor),
          trackStock: Value(command.trackStock),
          syncStatus: Value(SyncStatus.pending.wireName),
          updatedAt: Value(command.now),
        ),
      );

      final payload = <String, Object?>{
        'id': command.productId,
        'name': command.name,
        'sku': command.sku,
        'unit_price_minor': command.unitPriceMinor,
        'track_stock': command.trackStock,
      };

      await _db
          .into(_db.syncOutbox)
          .insert(
            SyncOutboxCompanion.insert(
              id: command.operationId,
              operationId: command.operationId,
              businessId: command.businessId,
              originalActorUserId: command.actorUserId,
              deviceId: command.deviceId,
              aggregateType: 'product',
              aggregateId: command.productId,
              operationType: SyncOperationType.updateProduct.wireName,
              sequenceNumber: await _nextSequence(
                'product',
                command.productId,
              ),
              payloadJson: jsonEncode(payload),
              payloadVersion: Value(command.payloadVersion),
              idempotencyKey: command.idempotencyKey,
              expectedServerVersion: Value(command.expectedVersion),
              status: SyncStatus.pending.wireName,
              createdAt: command.now,
            ),
          );

      final updated = await findProductRow(command.productId);
      if (updated == null) {
        throw StateError('Yerel ürün kaydı bulunamadı.');
      }
      return updated;
    });
  }

  /// Ürünü aktif/pasif yapar; yalnız `is_active` alanını değiştirir ve
  /// domain kaydı + outbox kaydını TEK transaction'da yazar.
  Future<LocalProductRow> enqueueSetProductActive(
    EnqueueSetProductActive command,
  ) {
    return _db.transaction(() async {
      await (_db.update(
        _db.localProducts,
      )..where((t) => t.id.equals(command.productId))).write(
        LocalProductsCompanion(
          isActive: Value(command.isActive),
          syncStatus: Value(SyncStatus.pending.wireName),
          updatedAt: Value(command.now),
        ),
      );

      final payload = <String, Object?>{
        'id': command.productId,
        'is_active': command.isActive,
      };

      await _db
          .into(_db.syncOutbox)
          .insert(
            SyncOutboxCompanion.insert(
              id: command.operationId,
              operationId: command.operationId,
              businessId: command.businessId,
              originalActorUserId: command.actorUserId,
              deviceId: command.deviceId,
              aggregateType: 'product',
              aggregateId: command.productId,
              operationType: SyncOperationType.setProductActive.wireName,
              sequenceNumber: await _nextSequence(
                'product',
                command.productId,
              ),
              payloadJson: jsonEncode(payload),
              payloadVersion: Value(command.payloadVersion),
              idempotencyKey: command.idempotencyKey,
              expectedServerVersion: Value(command.expectedVersion),
              status: SyncStatus.pending.wireName,
              createdAt: command.now,
            ),
          );

      final updated = await findProductRow(command.productId);
      if (updated == null) {
        throw StateError('Yerel ürün kaydı bulunamadı.');
      }
      return updated;
    });
  }

  Future<int> _nextSequence(String aggregateType, String aggregateId) async {
    final maxExpr = _db.syncOutbox.sequenceNumber.max();
    final query = _db.selectOnly(_db.syncOutbox)
      ..addColumns([maxExpr])
      ..where(
        _db.syncOutbox.aggregateType.equals(aggregateType) &
            _db.syncOutbox.aggregateId.equals(aggregateId),
      );
    final current = await query.map((row) => row.read(maxExpr)).getSingle();
    return (current ?? 0) + 1;
  }

  LocalProductsCompanion _toCompanion(Product p) => LocalProductsCompanion.insert(
    id: p.id,
    businessId: p.businessId,
    name: p.name,
    sku: Value(p.sku),
    unitPriceMinor: p.unitPriceMinor,
    currencyCode: p.currencyCode,
    trackStock: Value(p.trackStock),
    stockQuantity: Value(p.stockQuantity),
    isActive: Value(p.isActive),
    archivedAt: Value(p.archivedAt),
    createdAt: p.createdAt,
    updatedAt: p.updatedAt,
    syncStatus: const Value('synced'),
  );

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

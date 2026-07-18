import 'package:suretakip/core/errors/supabase_error_guard.dart';
import 'package:suretakip/core/logging/app_logger.dart';
import 'package:suretakip/core/logging/noop_app_logger.dart';
import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/features/products/data/datasources/products_remote_data_source.dart';
import 'package:suretakip/features/products/domain/entities/inventory_movement.dart';
import 'package:suretakip/features/products/domain/entities/product.dart';
import 'package:suretakip/features/products/domain/entities/product_input.dart';
import 'package:suretakip/features/products/domain/repositories/products_repository.dart';

class ProductsRepositoryImpl implements ProductsRepository {
  const ProductsRepositoryImpl(
    this._dataSource, {
    AppLogger logger = const NoopAppLogger(),
  }) : _logger = logger;
  final ProductsRemoteDataSource _dataSource;
  final AppLogger _logger;

  @override
  Future<List<Product>> getProducts({
    required String businessId,
    bool includeInactive = false,
  }) => _guard(() async {
    final rows = await _dataSource.getProducts(
      businessId: businessId,
      includeInactive: includeInactive,
    );
    return rows.map(_fromJson).toList(growable: false);
  });

  @override
  Future<Product> getProduct(String productId) =>
      _guard(() async => _fromJson(await _dataSource.getProduct(productId)));

  @override
  Future<Product> createProduct(ProductInput input) => _guard(() async {
    // İlk stok, cache'e doğrudan değil, RPC içinde 'initial' ledger kaydı
    // olarak yazılır (stok kaynağı = inventory_movements).
    final productId = await _dataSource.createProductWithStock({
      'p_business_id': input.businessId,
      'p_name': input.name,
      'p_sku': input.sku,
      'p_unit_price_minor': input.unitPrice.minorUnits,
      'p_currency_code': input.unitPrice.currencyCode,
      'p_track_stock': input.trackStock,
      'p_initial_stock': input.stockQuantity,
    });
    return _fromJson(await _dataSource.getProduct(productId));
  });

  @override
  Future<Product> updateProduct(Product product) => _guard(
    () async => _fromJson(await _dataSource.updateProduct(_values(product))),
  );

  @override
  Future<Product> setProductActive(
    String productId, {
    required bool isActive,
  }) => _guard(
    () async => _fromJson(
      await _dataSource.updateProduct({
        'id': productId,
        'is_active': isActive,
        'archived_at': isActive
            ? null
            : DateTime.now().toUtc().toIso8601String(),
      }),
    ),
  );

  @override
  Future<List<InventoryMovement>> getInventoryMovements({
    required String businessId,
    String? productId,
  }) => _guard(() async {
    final rows = await _dataSource.getInventoryMovements(
      businessId: businessId,
      productId: productId,
    );
    return rows.map(_movementFromJson).toList(growable: false);
  });

  @override
  Future<InventoryMovement> createInventoryMovement(
    InventoryMovement movement,
  ) => _guard(
    () async => _movementFromJson(
      await _dataSource.createInventoryMovement({
        'id': movement.id,
        'business_id': movement.businessId,
        'product_id': movement.productId,
        'session_item_id': movement.sessionItemId,
        'movement_type': _movementTypeToJson(movement.movementType),
        'quantity_delta': movement.quantityDelta,
        'note': movement.note,
        'created_by_member_id': movement.createdByMemberId,
      }),
    ),
  );

  // stock_quantity BİLİNÇLİ olarak yok: o bir cache'tir ve yalnızca
  // inventory_movements trigger'ı ile değişir. Düzenlemede yazılırsa
  // eşzamanlı satışları ezip ledger ile ayrışırdı.
  Map<String, Object?> _values(Product value) => {
    'id': value.id,
    'name': value.name,
    'sku': value.sku,
    'unit_price_minor': value.unitPriceMinor,
    'track_stock': value.trackStock,
  };

  Product _fromJson(Map<String, dynamic> json) => Product(
    id: json['id'] as String,
    businessId: json['business_id'] as String,
    name: json['name'] as String,
    sku: json['sku'] as String?,
    unitPriceMinor: json['unit_price_minor'] as int,
    currencyCode: json['currency_code'] as String,
    trackStock: json['track_stock'] as bool,
    stockQuantity: json['stock_quantity'] as int,
    isActive: json['is_active'] as bool,
    archivedAt: json['archived_at'] == null
        ? null
        : DateTime.parse(json['archived_at'] as String),
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  InventoryMovement _movementFromJson(Map<String, dynamic> json) =>
      InventoryMovement(
        id: json['id'] as String,
        businessId: json['business_id'] as String,
        productId: json['product_id'] as String,
        sessionItemId: json['session_item_id'] as String?,
        movementType: _movementTypeFromJson(json['movement_type'] as String),
        quantityDelta: json['quantity_delta'] as int,
        note: json['note'] as String?,
        createdByMemberId: json['created_by_member_id'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  String _movementTypeToJson(InventoryMovementType value) => switch (value) {
    InventoryMovementType.saleReversal => 'sale_reversal',
    InventoryMovementType.manualAdjustment => 'manual_adjustment',
    _ => value.name,
  };

  InventoryMovementType _movementTypeFromJson(String value) => switch (value) {
    'sale_reversal' => InventoryMovementType.saleReversal,
    'manual_adjustment' => InventoryMovementType.manualAdjustment,
    _ => InventoryMovementType.values.byName(value),
  };

  Future<T> _guard<T>(Future<T> Function() operation) => SupabaseErrorGuard.run(
    operation,
    logger: _logger,
    context: 'ProductsRepository',
  );
}

import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/value_objects/money.dart';
import 'package:suretakip/features/products/data/datasources/products_remote_data_source.dart';
import 'package:suretakip/features/products/data/repositories/products_repository_impl.dart';
import 'package:suretakip/features/products/domain/entities/product.dart';
import 'package:suretakip/features/products/domain/entities/product_input.dart';

/// Data katmanı sözleşme testleri: gönderilen kolon/RPC parametre adları
/// stringly-typed olduğu için burada kilitlenir.
void main() {
  test('updateProduct stok cache kolonunu ASLA göndermez', () async {
    final dataSource = _FakeProductsDataSource();
    final repository = ProductsRepositoryImpl(dataSource);

    await repository.updateProduct(_product());

    final values = dataSource.updatedValues!;
    // Kritik: stock_quantity bir cache'tir, yalnız inventory_movements
    // trigger'ı yazar. Düzenlemede gönderilirse eşzamanlı satış ezilir.
    expect(values.containsKey('stock_quantity'), isFalse);
    expect(values['id'], 'product-1');
    expect(values['name'], 'Kola');
    expect(values['unit_price_minor'], 3000);
    expect(values['track_stock'], isTrue);
  });

  test('setProductActive yalnızca durum kolonlarını gönderir', () async {
    final dataSource = _FakeProductsDataSource();
    final repository = ProductsRepositoryImpl(dataSource);

    await repository.setProductActive('product-1', isActive: false);

    final values = dataSource.updatedValues!;
    expect(values.keys.toSet(), {'id', 'is_active', 'archived_at'});
    expect(values['is_active'], isFalse);
    expect(values['archived_at'], isNotNull);
  });

  test('createProduct ilk stoğu RPC parametresi olarak iletir', () async {
    final dataSource = _FakeProductsDataSource();
    final repository = ProductsRepositoryImpl(dataSource);

    await repository.createProduct(
      ProductInput(
        businessId: 'business-1',
        name: 'Gofret',
        sku: 'GOF-1',
        unitPrice: Money(minorUnits: 2500, currencyCode: 'TRY'),
        trackStock: true,
        stockQuantity: 24,
      ),
    );

    expect(dataSource.rpcParams, {
      'p_business_id': 'business-1',
      'p_name': 'Gofret',
      'p_sku': 'GOF-1',
      'p_unit_price_minor': 2500,
      'p_currency_code': 'TRY',
      'p_track_stock': true,
      'p_initial_stock': 24,
    });
  });
}

Product _product() => Product(
  id: 'product-1',
  businessId: 'business-1',
  name: 'Kola',
  sku: 'KOLA-1',
  unitPriceMinor: 3000,
  currencyCode: 'TRY',
  trackStock: true,
  stockQuantity: 8,
  isActive: true,
  archivedAt: null,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

Map<String, dynamic> _row() => {
  'id': 'product-1',
  'business_id': 'business-1',
  'name': 'Kola',
  'sku': 'KOLA-1',
  'unit_price_minor': 3000,
  'currency_code': 'TRY',
  'track_stock': true,
  'stock_quantity': 8,
  'is_active': true,
  'archived_at': null,
  'created_at': '2026-01-01T00:00:00Z',
  'updated_at': '2026-01-01T00:00:00Z',
};

class _FakeProductsDataSource implements ProductsRemoteDataSource {
  Map<String, Object?>? updatedValues;
  Map<String, Object?>? rpcParams;

  @override
  Future<String> createProductWithStock(Map<String, Object?> params) async {
    rpcParams = params;
    return 'product-1';
  }

  @override
  Future<Map<String, dynamic>> updateProduct(
    Map<String, Object?> values,
  ) async {
    updatedValues = values;
    return _row();
  }

  @override
  Future<Map<String, dynamic>> getProduct(String id) async => _row();

  @override
  Future<List<Map<String, dynamic>>> getProducts({
    required String businessId,
    required bool includeInactive,
  }) async => [_row()];

  @override
  Future<List<Map<String, dynamic>>> getInventoryMovements({
    required String businessId,
    String? productId,
  }) async => const [];

  @override
  Future<Map<String, dynamic>> createInventoryMovement(
    Map<String, Object?> values,
  ) async => {
    'id': 'movement-1',
    'business_id': 'business-1',
    'product_id': 'product-1',
    'session_item_id': null,
    'movement_type': 'initial',
    'quantity_delta': 1,
    'note': null,
    'created_by_member_id': null,
    'created_at': '2026-01-01T00:00:00Z',
  };
}

import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/features/products/data/datasources/products_remote_data_source.dart';
import 'package:suretakip/features/products/data/repositories/products_repository_impl.dart';
import 'package:suretakip/features/products/domain/entities/inventory_movement.dart';

/// [ProductsRepositoryImpl]'ın ilk test dosyasında kapsanmayan yollarını
/// (okuma, envanter hareketi eşlemesi, saleReversal/manualAdjustment JSON
/// dönüşümü) kilitler.
void main() {
  test('getProducts satırları domain modeline eşler', () async {
    final dataSource = _FakeProductsDataSource();
    final repository = ProductsRepositoryImpl(dataSource);

    final products = await repository.getProducts(businessId: 'business-1');

    expect(products.single.id, 'product-1');
    expect(products.single.stockQuantity, 8);
  });

  test('getProduct tek satırı domain modeline eşler', () async {
    final repository = ProductsRepositoryImpl(_FakeProductsDataSource());

    final product = await repository.getProduct('product-1');

    expect(product.name, 'Kola');
  });

  test(
    'getInventoryMovements movement_type=sale_reversal doğru eşlenir',
    () async {
      final dataSource = _FakeProductsDataSource()
        ..movementRows = [_movementRow(movementType: 'sale_reversal')];
      final repository = ProductsRepositoryImpl(dataSource);

      final movements = await repository.getInventoryMovements(
        businessId: 'business-1',
      );

      expect(movements.single.movementType, InventoryMovementType.saleReversal);
    },
  );

  test(
    'getInventoryMovements movement_type=manual_adjustment doğru eşlenir',
    () async {
      final dataSource = _FakeProductsDataSource()
        ..movementRows = [_movementRow(movementType: 'manual_adjustment')];
      final repository = ProductsRepositoryImpl(dataSource);

      final movements = await repository.getInventoryMovements(
        businessId: 'business-1',
      );

      expect(
        movements.single.movementType,
        InventoryMovementType.manualAdjustment,
      );
    },
  );

  test(
    'createInventoryMovement, sale_reversal türünü JSON\'a doğru yazar',
    () async {
      final dataSource = _FakeProductsDataSource();
      final repository = ProductsRepositoryImpl(dataSource);

      await repository.createInventoryMovement(
        InventoryMovement(
          id: 'movement-1',
          businessId: 'business-1',
          productId: 'product-1',
          sessionItemId: null,
          movementType: InventoryMovementType.saleReversal,
          quantityDelta: -1,
          note: null,
          createdByMemberId: null,
          createdAt: DateTime.utc(2026),
        ),
      );

      expect(dataSource.insertedMovement?['movement_type'], 'sale_reversal');
    },
  );

  test(
    'createInventoryMovement, diğer türlerde enum adını olduğu gibi yazar',
    () async {
      final dataSource = _FakeProductsDataSource();
      final repository = ProductsRepositoryImpl(dataSource);

      await repository.createInventoryMovement(
        InventoryMovement(
          id: 'movement-1',
          businessId: 'business-1',
          productId: 'product-1',
          sessionItemId: 'session-item-1',
          movementType: InventoryMovementType.sale,
          quantityDelta: -2,
          note: 'not',
          createdByMemberId: 'member-1',
          createdAt: DateTime.utc(2026),
        ),
      );

      expect(dataSource.insertedMovement?['movement_type'], 'sale');
      expect(dataSource.insertedMovement?['session_item_id'], 'session-item-1');
    },
  );
}

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

Map<String, dynamic> _movementRow({required String movementType}) => {
  'id': 'movement-1',
  'business_id': 'business-1',
  'product_id': 'product-1',
  'session_item_id': null,
  'movement_type': movementType,
  'quantity_delta': -1,
  'note': null,
  'created_by_member_id': null,
  'created_at': '2026-01-01T00:00:00Z',
};

class _FakeProductsDataSource implements ProductsRemoteDataSource {
  List<Map<String, dynamic>> movementRows = [];
  Map<String, Object?>? insertedMovement;

  @override
  Future<String> createProductWithStock(Map<String, Object?> params) async =>
      'product-1';

  @override
  Future<Map<String, dynamic>> updateProduct(
    Map<String, Object?> values,
  ) async => {..._row(), ...values};

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
  }) async => movementRows;

  @override
  Future<Map<String, dynamic>> createInventoryMovement(
    Map<String, Object?> values,
  ) async {
    insertedMovement = values;
    return {
      'id': 'movement-1',
      'business_id': 'business-1',
      'product_id': 'product-1',
      'session_item_id': values['session_item_id'],
      'movement_type': values['movement_type'],
      'quantity_delta': values['quantity_delta'],
      'note': values['note'],
      'created_by_member_id': values['created_by_member_id'],
      'created_at': '2026-01-01T00:00:00Z',
    };
  }
}

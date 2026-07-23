import 'package:drift/drift.dart';
import 'package:suretakip/core/database/app_database.dart';
import 'package:suretakip/features/products/domain/entities/product.dart';

/// Ürün önbelleğini yöneten Drift katmanı (read-through). Yalnız okuma;
/// stok sunucu-otoriteli kalır.
class ProductsLocalDataSource {
  const ProductsLocalDataSource(this._db);

  final AppDatabase _db;

  Future<void> replaceProducts(String businessId, List<Product> products) =>
      _db.transaction(() async {
        await (_db.delete(
          _db.localProducts,
        )..where((t) => t.businessId.equals(businessId))).go();
        for (final product in products) {
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
      ..where((t) => t.businessId.equals(businessId))
      ..orderBy([(t) => OrderingTerm(expression: t.name)]);
    if (!includeInactive) query.where((t) => t.isActive.equals(true));
    final rows = await query.get();
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<Product?> getProduct(String id) async {
    final row = await (_db.select(
      _db.localProducts,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  Future<void> upsertProduct(Product product) => _db
      .into(_db.localProducts)
      .insertOnConflictUpdate(_toCompanion(product));

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

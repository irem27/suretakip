// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'product.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$Product {
  String get id => throw _privateConstructorUsedError;
  String get businessId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String? get sku => throw _privateConstructorUsedError;
  int get unitPriceMinor => throw _privateConstructorUsedError;
  String get currencyCode => throw _privateConstructorUsedError;
  bool get trackStock => throw _privateConstructorUsedError;
  int get stockQuantity => throw _privateConstructorUsedError;
  bool get isActive => throw _privateConstructorUsedError;
  DateTime? get archivedAt => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;

  /// Create a copy of Product
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ProductCopyWith<Product> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ProductCopyWith<$Res> {
  factory $ProductCopyWith(Product value, $Res Function(Product) then) =
      _$ProductCopyWithImpl<$Res, Product>;
  @useResult
  $Res call({
    String id,
    String businessId,
    String name,
    String? sku,
    int unitPriceMinor,
    String currencyCode,
    bool trackStock,
    int stockQuantity,
    bool isActive,
    DateTime? archivedAt,
    DateTime createdAt,
    DateTime updatedAt,
  });
}

/// @nodoc
class _$ProductCopyWithImpl<$Res, $Val extends Product>
    implements $ProductCopyWith<$Res> {
  _$ProductCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Product
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? businessId = null,
    Object? name = null,
    Object? sku = freezed,
    Object? unitPriceMinor = null,
    Object? currencyCode = null,
    Object? trackStock = null,
    Object? stockQuantity = null,
    Object? isActive = null,
    Object? archivedAt = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            businessId: null == businessId
                ? _value.businessId
                : businessId // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            sku: freezed == sku
                ? _value.sku
                : sku // ignore: cast_nullable_to_non_nullable
                      as String?,
            unitPriceMinor: null == unitPriceMinor
                ? _value.unitPriceMinor
                : unitPriceMinor // ignore: cast_nullable_to_non_nullable
                      as int,
            currencyCode: null == currencyCode
                ? _value.currencyCode
                : currencyCode // ignore: cast_nullable_to_non_nullable
                      as String,
            trackStock: null == trackStock
                ? _value.trackStock
                : trackStock // ignore: cast_nullable_to_non_nullable
                      as bool,
            stockQuantity: null == stockQuantity
                ? _value.stockQuantity
                : stockQuantity // ignore: cast_nullable_to_non_nullable
                      as int,
            isActive: null == isActive
                ? _value.isActive
                : isActive // ignore: cast_nullable_to_non_nullable
                      as bool,
            archivedAt: freezed == archivedAt
                ? _value.archivedAt
                : archivedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            updatedAt: null == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ProductImplCopyWith<$Res> implements $ProductCopyWith<$Res> {
  factory _$$ProductImplCopyWith(
    _$ProductImpl value,
    $Res Function(_$ProductImpl) then,
  ) = __$$ProductImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String businessId,
    String name,
    String? sku,
    int unitPriceMinor,
    String currencyCode,
    bool trackStock,
    int stockQuantity,
    bool isActive,
    DateTime? archivedAt,
    DateTime createdAt,
    DateTime updatedAt,
  });
}

/// @nodoc
class __$$ProductImplCopyWithImpl<$Res>
    extends _$ProductCopyWithImpl<$Res, _$ProductImpl>
    implements _$$ProductImplCopyWith<$Res> {
  __$$ProductImplCopyWithImpl(
    _$ProductImpl _value,
    $Res Function(_$ProductImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Product
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? businessId = null,
    Object? name = null,
    Object? sku = freezed,
    Object? unitPriceMinor = null,
    Object? currencyCode = null,
    Object? trackStock = null,
    Object? stockQuantity = null,
    Object? isActive = null,
    Object? archivedAt = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _$ProductImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        businessId: null == businessId
            ? _value.businessId
            : businessId // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        sku: freezed == sku
            ? _value.sku
            : sku // ignore: cast_nullable_to_non_nullable
                  as String?,
        unitPriceMinor: null == unitPriceMinor
            ? _value.unitPriceMinor
            : unitPriceMinor // ignore: cast_nullable_to_non_nullable
                  as int,
        currencyCode: null == currencyCode
            ? _value.currencyCode
            : currencyCode // ignore: cast_nullable_to_non_nullable
                  as String,
        trackStock: null == trackStock
            ? _value.trackStock
            : trackStock // ignore: cast_nullable_to_non_nullable
                  as bool,
        stockQuantity: null == stockQuantity
            ? _value.stockQuantity
            : stockQuantity // ignore: cast_nullable_to_non_nullable
                  as int,
        isActive: null == isActive
            ? _value.isActive
            : isActive // ignore: cast_nullable_to_non_nullable
                  as bool,
        archivedAt: freezed == archivedAt
            ? _value.archivedAt
            : archivedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        updatedAt: null == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc

class _$ProductImpl implements _Product {
  const _$ProductImpl({
    required this.id,
    required this.businessId,
    required this.name,
    required this.sku,
    required this.unitPriceMinor,
    required this.currencyCode,
    required this.trackStock,
    required this.stockQuantity,
    required this.isActive,
    required this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  final String id;
  @override
  final String businessId;
  @override
  final String name;
  @override
  final String? sku;
  @override
  final int unitPriceMinor;
  @override
  final String currencyCode;
  @override
  final bool trackStock;
  @override
  final int stockQuantity;
  @override
  final bool isActive;
  @override
  final DateTime? archivedAt;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  @override
  String toString() {
    return 'Product(id: $id, businessId: $businessId, name: $name, sku: $sku, unitPriceMinor: $unitPriceMinor, currencyCode: $currencyCode, trackStock: $trackStock, stockQuantity: $stockQuantity, isActive: $isActive, archivedAt: $archivedAt, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ProductImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.businessId, businessId) ||
                other.businessId == businessId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.sku, sku) || other.sku == sku) &&
            (identical(other.unitPriceMinor, unitPriceMinor) ||
                other.unitPriceMinor == unitPriceMinor) &&
            (identical(other.currencyCode, currencyCode) ||
                other.currencyCode == currencyCode) &&
            (identical(other.trackStock, trackStock) ||
                other.trackStock == trackStock) &&
            (identical(other.stockQuantity, stockQuantity) ||
                other.stockQuantity == stockQuantity) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.archivedAt, archivedAt) ||
                other.archivedAt == archivedAt) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    businessId,
    name,
    sku,
    unitPriceMinor,
    currencyCode,
    trackStock,
    stockQuantity,
    isActive,
    archivedAt,
    createdAt,
    updatedAt,
  );

  /// Create a copy of Product
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ProductImplCopyWith<_$ProductImpl> get copyWith =>
      __$$ProductImplCopyWithImpl<_$ProductImpl>(this, _$identity);
}

abstract class _Product implements Product {
  const factory _Product({
    required final String id,
    required final String businessId,
    required final String name,
    required final String? sku,
    required final int unitPriceMinor,
    required final String currencyCode,
    required final bool trackStock,
    required final int stockQuantity,
    required final bool isActive,
    required final DateTime? archivedAt,
    required final DateTime createdAt,
    required final DateTime updatedAt,
  }) = _$ProductImpl;

  @override
  String get id;
  @override
  String get businessId;
  @override
  String get name;
  @override
  String? get sku;
  @override
  int get unitPriceMinor;
  @override
  String get currencyCode;
  @override
  bool get trackStock;
  @override
  int get stockQuantity;
  @override
  bool get isActive;
  @override
  DateTime? get archivedAt;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;

  /// Create a copy of Product
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ProductImplCopyWith<_$ProductImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

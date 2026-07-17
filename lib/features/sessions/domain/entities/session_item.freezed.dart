// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$SessionItem {
  String get id => throw _privateConstructorUsedError;
  String get businessId => throw _privateConstructorUsedError;
  String get sessionId => throw _privateConstructorUsedError;
  String? get productId => throw _privateConstructorUsedError;
  String get productNameSnapshot => throw _privateConstructorUsedError;
  String? get skuSnapshot => throw _privateConstructorUsedError;
  int get unitPriceMinorSnapshot => throw _privateConstructorUsedError;
  String get currencyCodeSnapshot => throw _privateConstructorUsedError;
  int get quantity => throw _privateConstructorUsedError;
  int get discountMinor => throw _privateConstructorUsedError;
  int get taxMinor => throw _privateConstructorUsedError;
  int get lineTotalMinor => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;

  /// Create a copy of SessionItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SessionItemCopyWith<SessionItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SessionItemCopyWith<$Res> {
  factory $SessionItemCopyWith(
    SessionItem value,
    $Res Function(SessionItem) then,
  ) = _$SessionItemCopyWithImpl<$Res, SessionItem>;
  @useResult
  $Res call({
    String id,
    String businessId,
    String sessionId,
    String? productId,
    String productNameSnapshot,
    String? skuSnapshot,
    int unitPriceMinorSnapshot,
    String currencyCodeSnapshot,
    int quantity,
    int discountMinor,
    int taxMinor,
    int lineTotalMinor,
    DateTime createdAt,
    DateTime updatedAt,
  });
}

/// @nodoc
class _$SessionItemCopyWithImpl<$Res, $Val extends SessionItem>
    implements $SessionItemCopyWith<$Res> {
  _$SessionItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SessionItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? businessId = null,
    Object? sessionId = null,
    Object? productId = freezed,
    Object? productNameSnapshot = null,
    Object? skuSnapshot = freezed,
    Object? unitPriceMinorSnapshot = null,
    Object? currencyCodeSnapshot = null,
    Object? quantity = null,
    Object? discountMinor = null,
    Object? taxMinor = null,
    Object? lineTotalMinor = null,
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
            sessionId: null == sessionId
                ? _value.sessionId
                : sessionId // ignore: cast_nullable_to_non_nullable
                      as String,
            productId: freezed == productId
                ? _value.productId
                : productId // ignore: cast_nullable_to_non_nullable
                      as String?,
            productNameSnapshot: null == productNameSnapshot
                ? _value.productNameSnapshot
                : productNameSnapshot // ignore: cast_nullable_to_non_nullable
                      as String,
            skuSnapshot: freezed == skuSnapshot
                ? _value.skuSnapshot
                : skuSnapshot // ignore: cast_nullable_to_non_nullable
                      as String?,
            unitPriceMinorSnapshot: null == unitPriceMinorSnapshot
                ? _value.unitPriceMinorSnapshot
                : unitPriceMinorSnapshot // ignore: cast_nullable_to_non_nullable
                      as int,
            currencyCodeSnapshot: null == currencyCodeSnapshot
                ? _value.currencyCodeSnapshot
                : currencyCodeSnapshot // ignore: cast_nullable_to_non_nullable
                      as String,
            quantity: null == quantity
                ? _value.quantity
                : quantity // ignore: cast_nullable_to_non_nullable
                      as int,
            discountMinor: null == discountMinor
                ? _value.discountMinor
                : discountMinor // ignore: cast_nullable_to_non_nullable
                      as int,
            taxMinor: null == taxMinor
                ? _value.taxMinor
                : taxMinor // ignore: cast_nullable_to_non_nullable
                      as int,
            lineTotalMinor: null == lineTotalMinor
                ? _value.lineTotalMinor
                : lineTotalMinor // ignore: cast_nullable_to_non_nullable
                      as int,
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
abstract class _$$SessionItemImplCopyWith<$Res>
    implements $SessionItemCopyWith<$Res> {
  factory _$$SessionItemImplCopyWith(
    _$SessionItemImpl value,
    $Res Function(_$SessionItemImpl) then,
  ) = __$$SessionItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String businessId,
    String sessionId,
    String? productId,
    String productNameSnapshot,
    String? skuSnapshot,
    int unitPriceMinorSnapshot,
    String currencyCodeSnapshot,
    int quantity,
    int discountMinor,
    int taxMinor,
    int lineTotalMinor,
    DateTime createdAt,
    DateTime updatedAt,
  });
}

/// @nodoc
class __$$SessionItemImplCopyWithImpl<$Res>
    extends _$SessionItemCopyWithImpl<$Res, _$SessionItemImpl>
    implements _$$SessionItemImplCopyWith<$Res> {
  __$$SessionItemImplCopyWithImpl(
    _$SessionItemImpl _value,
    $Res Function(_$SessionItemImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SessionItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? businessId = null,
    Object? sessionId = null,
    Object? productId = freezed,
    Object? productNameSnapshot = null,
    Object? skuSnapshot = freezed,
    Object? unitPriceMinorSnapshot = null,
    Object? currencyCodeSnapshot = null,
    Object? quantity = null,
    Object? discountMinor = null,
    Object? taxMinor = null,
    Object? lineTotalMinor = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _$SessionItemImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        businessId: null == businessId
            ? _value.businessId
            : businessId // ignore: cast_nullable_to_non_nullable
                  as String,
        sessionId: null == sessionId
            ? _value.sessionId
            : sessionId // ignore: cast_nullable_to_non_nullable
                  as String,
        productId: freezed == productId
            ? _value.productId
            : productId // ignore: cast_nullable_to_non_nullable
                  as String?,
        productNameSnapshot: null == productNameSnapshot
            ? _value.productNameSnapshot
            : productNameSnapshot // ignore: cast_nullable_to_non_nullable
                  as String,
        skuSnapshot: freezed == skuSnapshot
            ? _value.skuSnapshot
            : skuSnapshot // ignore: cast_nullable_to_non_nullable
                  as String?,
        unitPriceMinorSnapshot: null == unitPriceMinorSnapshot
            ? _value.unitPriceMinorSnapshot
            : unitPriceMinorSnapshot // ignore: cast_nullable_to_non_nullable
                  as int,
        currencyCodeSnapshot: null == currencyCodeSnapshot
            ? _value.currencyCodeSnapshot
            : currencyCodeSnapshot // ignore: cast_nullable_to_non_nullable
                  as String,
        quantity: null == quantity
            ? _value.quantity
            : quantity // ignore: cast_nullable_to_non_nullable
                  as int,
        discountMinor: null == discountMinor
            ? _value.discountMinor
            : discountMinor // ignore: cast_nullable_to_non_nullable
                  as int,
        taxMinor: null == taxMinor
            ? _value.taxMinor
            : taxMinor // ignore: cast_nullable_to_non_nullable
                  as int,
        lineTotalMinor: null == lineTotalMinor
            ? _value.lineTotalMinor
            : lineTotalMinor // ignore: cast_nullable_to_non_nullable
                  as int,
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

class _$SessionItemImpl implements _SessionItem {
  const _$SessionItemImpl({
    required this.id,
    required this.businessId,
    required this.sessionId,
    required this.productId,
    required this.productNameSnapshot,
    required this.skuSnapshot,
    required this.unitPriceMinorSnapshot,
    required this.currencyCodeSnapshot,
    required this.quantity,
    required this.discountMinor,
    required this.taxMinor,
    required this.lineTotalMinor,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  final String id;
  @override
  final String businessId;
  @override
  final String sessionId;
  @override
  final String? productId;
  @override
  final String productNameSnapshot;
  @override
  final String? skuSnapshot;
  @override
  final int unitPriceMinorSnapshot;
  @override
  final String currencyCodeSnapshot;
  @override
  final int quantity;
  @override
  final int discountMinor;
  @override
  final int taxMinor;
  @override
  final int lineTotalMinor;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  @override
  String toString() {
    return 'SessionItem(id: $id, businessId: $businessId, sessionId: $sessionId, productId: $productId, productNameSnapshot: $productNameSnapshot, skuSnapshot: $skuSnapshot, unitPriceMinorSnapshot: $unitPriceMinorSnapshot, currencyCodeSnapshot: $currencyCodeSnapshot, quantity: $quantity, discountMinor: $discountMinor, taxMinor: $taxMinor, lineTotalMinor: $lineTotalMinor, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SessionItemImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.businessId, businessId) ||
                other.businessId == businessId) &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId) &&
            (identical(other.productId, productId) ||
                other.productId == productId) &&
            (identical(other.productNameSnapshot, productNameSnapshot) ||
                other.productNameSnapshot == productNameSnapshot) &&
            (identical(other.skuSnapshot, skuSnapshot) ||
                other.skuSnapshot == skuSnapshot) &&
            (identical(other.unitPriceMinorSnapshot, unitPriceMinorSnapshot) ||
                other.unitPriceMinorSnapshot == unitPriceMinorSnapshot) &&
            (identical(other.currencyCodeSnapshot, currencyCodeSnapshot) ||
                other.currencyCodeSnapshot == currencyCodeSnapshot) &&
            (identical(other.quantity, quantity) ||
                other.quantity == quantity) &&
            (identical(other.discountMinor, discountMinor) ||
                other.discountMinor == discountMinor) &&
            (identical(other.taxMinor, taxMinor) ||
                other.taxMinor == taxMinor) &&
            (identical(other.lineTotalMinor, lineTotalMinor) ||
                other.lineTotalMinor == lineTotalMinor) &&
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
    sessionId,
    productId,
    productNameSnapshot,
    skuSnapshot,
    unitPriceMinorSnapshot,
    currencyCodeSnapshot,
    quantity,
    discountMinor,
    taxMinor,
    lineTotalMinor,
    createdAt,
    updatedAt,
  );

  /// Create a copy of SessionItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SessionItemImplCopyWith<_$SessionItemImpl> get copyWith =>
      __$$SessionItemImplCopyWithImpl<_$SessionItemImpl>(this, _$identity);
}

abstract class _SessionItem implements SessionItem {
  const factory _SessionItem({
    required final String id,
    required final String businessId,
    required final String sessionId,
    required final String? productId,
    required final String productNameSnapshot,
    required final String? skuSnapshot,
    required final int unitPriceMinorSnapshot,
    required final String currencyCodeSnapshot,
    required final int quantity,
    required final int discountMinor,
    required final int taxMinor,
    required final int lineTotalMinor,
    required final DateTime createdAt,
    required final DateTime updatedAt,
  }) = _$SessionItemImpl;

  @override
  String get id;
  @override
  String get businessId;
  @override
  String get sessionId;
  @override
  String? get productId;
  @override
  String get productNameSnapshot;
  @override
  String? get skuSnapshot;
  @override
  int get unitPriceMinorSnapshot;
  @override
  String get currencyCodeSnapshot;
  @override
  int get quantity;
  @override
  int get discountMinor;
  @override
  int get taxMinor;
  @override
  int get lineTotalMinor;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;

  /// Create a copy of SessionItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SessionItemImplCopyWith<_$SessionItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

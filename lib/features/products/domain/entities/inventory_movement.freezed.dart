// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'inventory_movement.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$InventoryMovement {
  String get id => throw _privateConstructorUsedError;
  String get businessId => throw _privateConstructorUsedError;
  String get productId => throw _privateConstructorUsedError;
  String? get sessionItemId => throw _privateConstructorUsedError;
  InventoryMovementType get movementType => throw _privateConstructorUsedError;
  int get quantityDelta => throw _privateConstructorUsedError;
  String? get note => throw _privateConstructorUsedError;
  String? get createdByMemberId => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// Create a copy of InventoryMovement
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $InventoryMovementCopyWith<InventoryMovement> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $InventoryMovementCopyWith<$Res> {
  factory $InventoryMovementCopyWith(
    InventoryMovement value,
    $Res Function(InventoryMovement) then,
  ) = _$InventoryMovementCopyWithImpl<$Res, InventoryMovement>;
  @useResult
  $Res call({
    String id,
    String businessId,
    String productId,
    String? sessionItemId,
    InventoryMovementType movementType,
    int quantityDelta,
    String? note,
    String? createdByMemberId,
    DateTime createdAt,
  });
}

/// @nodoc
class _$InventoryMovementCopyWithImpl<$Res, $Val extends InventoryMovement>
    implements $InventoryMovementCopyWith<$Res> {
  _$InventoryMovementCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of InventoryMovement
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? businessId = null,
    Object? productId = null,
    Object? sessionItemId = freezed,
    Object? movementType = null,
    Object? quantityDelta = null,
    Object? note = freezed,
    Object? createdByMemberId = freezed,
    Object? createdAt = null,
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
            productId: null == productId
                ? _value.productId
                : productId // ignore: cast_nullable_to_non_nullable
                      as String,
            sessionItemId: freezed == sessionItemId
                ? _value.sessionItemId
                : sessionItemId // ignore: cast_nullable_to_non_nullable
                      as String?,
            movementType: null == movementType
                ? _value.movementType
                : movementType // ignore: cast_nullable_to_non_nullable
                      as InventoryMovementType,
            quantityDelta: null == quantityDelta
                ? _value.quantityDelta
                : quantityDelta // ignore: cast_nullable_to_non_nullable
                      as int,
            note: freezed == note
                ? _value.note
                : note // ignore: cast_nullable_to_non_nullable
                      as String?,
            createdByMemberId: freezed == createdByMemberId
                ? _value.createdByMemberId
                : createdByMemberId // ignore: cast_nullable_to_non_nullable
                      as String?,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$InventoryMovementImplCopyWith<$Res>
    implements $InventoryMovementCopyWith<$Res> {
  factory _$$InventoryMovementImplCopyWith(
    _$InventoryMovementImpl value,
    $Res Function(_$InventoryMovementImpl) then,
  ) = __$$InventoryMovementImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String businessId,
    String productId,
    String? sessionItemId,
    InventoryMovementType movementType,
    int quantityDelta,
    String? note,
    String? createdByMemberId,
    DateTime createdAt,
  });
}

/// @nodoc
class __$$InventoryMovementImplCopyWithImpl<$Res>
    extends _$InventoryMovementCopyWithImpl<$Res, _$InventoryMovementImpl>
    implements _$$InventoryMovementImplCopyWith<$Res> {
  __$$InventoryMovementImplCopyWithImpl(
    _$InventoryMovementImpl _value,
    $Res Function(_$InventoryMovementImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of InventoryMovement
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? businessId = null,
    Object? productId = null,
    Object? sessionItemId = freezed,
    Object? movementType = null,
    Object? quantityDelta = null,
    Object? note = freezed,
    Object? createdByMemberId = freezed,
    Object? createdAt = null,
  }) {
    return _then(
      _$InventoryMovementImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        businessId: null == businessId
            ? _value.businessId
            : businessId // ignore: cast_nullable_to_non_nullable
                  as String,
        productId: null == productId
            ? _value.productId
            : productId // ignore: cast_nullable_to_non_nullable
                  as String,
        sessionItemId: freezed == sessionItemId
            ? _value.sessionItemId
            : sessionItemId // ignore: cast_nullable_to_non_nullable
                  as String?,
        movementType: null == movementType
            ? _value.movementType
            : movementType // ignore: cast_nullable_to_non_nullable
                  as InventoryMovementType,
        quantityDelta: null == quantityDelta
            ? _value.quantityDelta
            : quantityDelta // ignore: cast_nullable_to_non_nullable
                  as int,
        note: freezed == note
            ? _value.note
            : note // ignore: cast_nullable_to_non_nullable
                  as String?,
        createdByMemberId: freezed == createdByMemberId
            ? _value.createdByMemberId
            : createdByMemberId // ignore: cast_nullable_to_non_nullable
                  as String?,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc

class _$InventoryMovementImpl implements _InventoryMovement {
  const _$InventoryMovementImpl({
    required this.id,
    required this.businessId,
    required this.productId,
    required this.sessionItemId,
    required this.movementType,
    required this.quantityDelta,
    required this.note,
    required this.createdByMemberId,
    required this.createdAt,
  });

  @override
  final String id;
  @override
  final String businessId;
  @override
  final String productId;
  @override
  final String? sessionItemId;
  @override
  final InventoryMovementType movementType;
  @override
  final int quantityDelta;
  @override
  final String? note;
  @override
  final String? createdByMemberId;
  @override
  final DateTime createdAt;

  @override
  String toString() {
    return 'InventoryMovement(id: $id, businessId: $businessId, productId: $productId, sessionItemId: $sessionItemId, movementType: $movementType, quantityDelta: $quantityDelta, note: $note, createdByMemberId: $createdByMemberId, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$InventoryMovementImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.businessId, businessId) ||
                other.businessId == businessId) &&
            (identical(other.productId, productId) ||
                other.productId == productId) &&
            (identical(other.sessionItemId, sessionItemId) ||
                other.sessionItemId == sessionItemId) &&
            (identical(other.movementType, movementType) ||
                other.movementType == movementType) &&
            (identical(other.quantityDelta, quantityDelta) ||
                other.quantityDelta == quantityDelta) &&
            (identical(other.note, note) || other.note == note) &&
            (identical(other.createdByMemberId, createdByMemberId) ||
                other.createdByMemberId == createdByMemberId) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    businessId,
    productId,
    sessionItemId,
    movementType,
    quantityDelta,
    note,
    createdByMemberId,
    createdAt,
  );

  /// Create a copy of InventoryMovement
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$InventoryMovementImplCopyWith<_$InventoryMovementImpl> get copyWith =>
      __$$InventoryMovementImplCopyWithImpl<_$InventoryMovementImpl>(
        this,
        _$identity,
      );
}

abstract class _InventoryMovement implements InventoryMovement {
  const factory _InventoryMovement({
    required final String id,
    required final String businessId,
    required final String productId,
    required final String? sessionItemId,
    required final InventoryMovementType movementType,
    required final int quantityDelta,
    required final String? note,
    required final String? createdByMemberId,
    required final DateTime createdAt,
  }) = _$InventoryMovementImpl;

  @override
  String get id;
  @override
  String get businessId;
  @override
  String get productId;
  @override
  String? get sessionItemId;
  @override
  InventoryMovementType get movementType;
  @override
  int get quantityDelta;
  @override
  String? get note;
  @override
  String? get createdByMemberId;
  @override
  DateTime get createdAt;

  /// Create a copy of InventoryMovement
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$InventoryMovementImplCopyWith<_$InventoryMovementImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

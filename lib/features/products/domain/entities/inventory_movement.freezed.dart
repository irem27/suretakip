// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'inventory_movement.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$InventoryMovement {

 String get id; String get businessId; String get productId; String? get sessionItemId; InventoryMovementType get movementType; int get quantityDelta; String? get note; String? get createdByMemberId; DateTime get createdAt;
/// Create a copy of InventoryMovement
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InventoryMovementCopyWith<InventoryMovement> get copyWith => _$InventoryMovementCopyWithImpl<InventoryMovement>(this as InventoryMovement, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InventoryMovement&&(identical(other.id, id) || other.id == id)&&(identical(other.businessId, businessId) || other.businessId == businessId)&&(identical(other.productId, productId) || other.productId == productId)&&(identical(other.sessionItemId, sessionItemId) || other.sessionItemId == sessionItemId)&&(identical(other.movementType, movementType) || other.movementType == movementType)&&(identical(other.quantityDelta, quantityDelta) || other.quantityDelta == quantityDelta)&&(identical(other.note, note) || other.note == note)&&(identical(other.createdByMemberId, createdByMemberId) || other.createdByMemberId == createdByMemberId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,businessId,productId,sessionItemId,movementType,quantityDelta,note,createdByMemberId,createdAt);

@override
String toString() {
  return 'InventoryMovement(id: $id, businessId: $businessId, productId: $productId, sessionItemId: $sessionItemId, movementType: $movementType, quantityDelta: $quantityDelta, note: $note, createdByMemberId: $createdByMemberId, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $InventoryMovementCopyWith<$Res>  {
  factory $InventoryMovementCopyWith(InventoryMovement value, $Res Function(InventoryMovement) _then) = _$InventoryMovementCopyWithImpl;
@useResult
$Res call({
 String id, String businessId, String productId, String? sessionItemId, InventoryMovementType movementType, int quantityDelta, String? note, String? createdByMemberId, DateTime createdAt
});




}
/// @nodoc
class _$InventoryMovementCopyWithImpl<$Res>
    implements $InventoryMovementCopyWith<$Res> {
  _$InventoryMovementCopyWithImpl(this._self, this._then);

  final InventoryMovement _self;
  final $Res Function(InventoryMovement) _then;

/// Create a copy of InventoryMovement
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? businessId = null,Object? productId = null,Object? sessionItemId = freezed,Object? movementType = null,Object? quantityDelta = null,Object? note = freezed,Object? createdByMemberId = freezed,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,businessId: null == businessId ? _self.businessId : businessId // ignore: cast_nullable_to_non_nullable
as String,productId: null == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as String,sessionItemId: freezed == sessionItemId ? _self.sessionItemId : sessionItemId // ignore: cast_nullable_to_non_nullable
as String?,movementType: null == movementType ? _self.movementType : movementType // ignore: cast_nullable_to_non_nullable
as InventoryMovementType,quantityDelta: null == quantityDelta ? _self.quantityDelta : quantityDelta // ignore: cast_nullable_to_non_nullable
as int,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,createdByMemberId: freezed == createdByMemberId ? _self.createdByMemberId : createdByMemberId // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [InventoryMovement].
extension InventoryMovementPatterns on InventoryMovement {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InventoryMovement value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InventoryMovement() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InventoryMovement value)  $default,){
final _that = this;
switch (_that) {
case _InventoryMovement():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InventoryMovement value)?  $default,){
final _that = this;
switch (_that) {
case _InventoryMovement() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String businessId,  String productId,  String? sessionItemId,  InventoryMovementType movementType,  int quantityDelta,  String? note,  String? createdByMemberId,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InventoryMovement() when $default != null:
return $default(_that.id,_that.businessId,_that.productId,_that.sessionItemId,_that.movementType,_that.quantityDelta,_that.note,_that.createdByMemberId,_that.createdAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String businessId,  String productId,  String? sessionItemId,  InventoryMovementType movementType,  int quantityDelta,  String? note,  String? createdByMemberId,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _InventoryMovement():
return $default(_that.id,_that.businessId,_that.productId,_that.sessionItemId,_that.movementType,_that.quantityDelta,_that.note,_that.createdByMemberId,_that.createdAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String businessId,  String productId,  String? sessionItemId,  InventoryMovementType movementType,  int quantityDelta,  String? note,  String? createdByMemberId,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _InventoryMovement() when $default != null:
return $default(_that.id,_that.businessId,_that.productId,_that.sessionItemId,_that.movementType,_that.quantityDelta,_that.note,_that.createdByMemberId,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc


class _InventoryMovement implements InventoryMovement {
  const _InventoryMovement({required this.id, required this.businessId, required this.productId, required this.sessionItemId, required this.movementType, required this.quantityDelta, required this.note, required this.createdByMemberId, required this.createdAt});


@override final  String id;
@override final  String businessId;
@override final  String productId;
@override final  String? sessionItemId;
@override final  InventoryMovementType movementType;
@override final  int quantityDelta;
@override final  String? note;
@override final  String? createdByMemberId;
@override final  DateTime createdAt;

/// Create a copy of InventoryMovement
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InventoryMovementCopyWith<_InventoryMovement> get copyWith => __$InventoryMovementCopyWithImpl<_InventoryMovement>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InventoryMovement&&(identical(other.id, id) || other.id == id)&&(identical(other.businessId, businessId) || other.businessId == businessId)&&(identical(other.productId, productId) || other.productId == productId)&&(identical(other.sessionItemId, sessionItemId) || other.sessionItemId == sessionItemId)&&(identical(other.movementType, movementType) || other.movementType == movementType)&&(identical(other.quantityDelta, quantityDelta) || other.quantityDelta == quantityDelta)&&(identical(other.note, note) || other.note == note)&&(identical(other.createdByMemberId, createdByMemberId) || other.createdByMemberId == createdByMemberId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,businessId,productId,sessionItemId,movementType,quantityDelta,note,createdByMemberId,createdAt);

@override
String toString() {
  return 'InventoryMovement(id: $id, businessId: $businessId, productId: $productId, sessionItemId: $sessionItemId, movementType: $movementType, quantityDelta: $quantityDelta, note: $note, createdByMemberId: $createdByMemberId, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$InventoryMovementCopyWith<$Res> implements $InventoryMovementCopyWith<$Res> {
  factory _$InventoryMovementCopyWith(_InventoryMovement value, $Res Function(_InventoryMovement) _then) = __$InventoryMovementCopyWithImpl;
@override @useResult
$Res call({
 String id, String businessId, String productId, String? sessionItemId, InventoryMovementType movementType, int quantityDelta, String? note, String? createdByMemberId, DateTime createdAt
});




}
/// @nodoc
class __$InventoryMovementCopyWithImpl<$Res>
    implements _$InventoryMovementCopyWith<$Res> {
  __$InventoryMovementCopyWithImpl(this._self, this._then);

  final _InventoryMovement _self;
  final $Res Function(_InventoryMovement) _then;

/// Create a copy of InventoryMovement
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? businessId = null,Object? productId = null,Object? sessionItemId = freezed,Object? movementType = null,Object? quantityDelta = null,Object? note = freezed,Object? createdByMemberId = freezed,Object? createdAt = null,}) {
  return _then(_InventoryMovement(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,businessId: null == businessId ? _self.businessId : businessId // ignore: cast_nullable_to_non_nullable
as String,productId: null == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as String,sessionItemId: freezed == sessionItemId ? _self.sessionItemId : sessionItemId // ignore: cast_nullable_to_non_nullable
as String?,movementType: null == movementType ? _self.movementType : movementType // ignore: cast_nullable_to_non_nullable
as InventoryMovementType,quantityDelta: null == quantityDelta ? _self.quantityDelta : quantityDelta // ignore: cast_nullable_to_non_nullable
as int,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,createdByMemberId: freezed == createdByMemberId ? _self.createdByMemberId : createdByMemberId // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on

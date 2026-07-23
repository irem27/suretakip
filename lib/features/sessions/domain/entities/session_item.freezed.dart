// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SessionItem {

 String get id; String get businessId; String get sessionId; String? get productId; String get productNameSnapshot; String? get skuSnapshot; int get unitPriceMinorSnapshot; String get currencyCodeSnapshot; int get quantity; int get discountMinor; int get taxMinor; int get lineTotalMinor; DateTime get createdAt; DateTime get updatedAt;
/// Create a copy of SessionItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionItemCopyWith<SessionItem> get copyWith => _$SessionItemCopyWithImpl<SessionItem>(this as SessionItem, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionItem&&(identical(other.id, id) || other.id == id)&&(identical(other.businessId, businessId) || other.businessId == businessId)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.productId, productId) || other.productId == productId)&&(identical(other.productNameSnapshot, productNameSnapshot) || other.productNameSnapshot == productNameSnapshot)&&(identical(other.skuSnapshot, skuSnapshot) || other.skuSnapshot == skuSnapshot)&&(identical(other.unitPriceMinorSnapshot, unitPriceMinorSnapshot) || other.unitPriceMinorSnapshot == unitPriceMinorSnapshot)&&(identical(other.currencyCodeSnapshot, currencyCodeSnapshot) || other.currencyCodeSnapshot == currencyCodeSnapshot)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.discountMinor, discountMinor) || other.discountMinor == discountMinor)&&(identical(other.taxMinor, taxMinor) || other.taxMinor == taxMinor)&&(identical(other.lineTotalMinor, lineTotalMinor) || other.lineTotalMinor == lineTotalMinor)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,businessId,sessionId,productId,productNameSnapshot,skuSnapshot,unitPriceMinorSnapshot,currencyCodeSnapshot,quantity,discountMinor,taxMinor,lineTotalMinor,createdAt,updatedAt);

@override
String toString() {
  return 'SessionItem(id: $id, businessId: $businessId, sessionId: $sessionId, productId: $productId, productNameSnapshot: $productNameSnapshot, skuSnapshot: $skuSnapshot, unitPriceMinorSnapshot: $unitPriceMinorSnapshot, currencyCodeSnapshot: $currencyCodeSnapshot, quantity: $quantity, discountMinor: $discountMinor, taxMinor: $taxMinor, lineTotalMinor: $lineTotalMinor, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $SessionItemCopyWith<$Res>  {
  factory $SessionItemCopyWith(SessionItem value, $Res Function(SessionItem) _then) = _$SessionItemCopyWithImpl;
@useResult
$Res call({
 String id, String businessId, String sessionId, String? productId, String productNameSnapshot, String? skuSnapshot, int unitPriceMinorSnapshot, String currencyCodeSnapshot, int quantity, int discountMinor, int taxMinor, int lineTotalMinor, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class _$SessionItemCopyWithImpl<$Res>
    implements $SessionItemCopyWith<$Res> {
  _$SessionItemCopyWithImpl(this._self, this._then);

  final SessionItem _self;
  final $Res Function(SessionItem) _then;

/// Create a copy of SessionItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? businessId = null,Object? sessionId = null,Object? productId = freezed,Object? productNameSnapshot = null,Object? skuSnapshot = freezed,Object? unitPriceMinorSnapshot = null,Object? currencyCodeSnapshot = null,Object? quantity = null,Object? discountMinor = null,Object? taxMinor = null,Object? lineTotalMinor = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,businessId: null == businessId ? _self.businessId : businessId // ignore: cast_nullable_to_non_nullable
as String,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,productId: freezed == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as String?,productNameSnapshot: null == productNameSnapshot ? _self.productNameSnapshot : productNameSnapshot // ignore: cast_nullable_to_non_nullable
as String,skuSnapshot: freezed == skuSnapshot ? _self.skuSnapshot : skuSnapshot // ignore: cast_nullable_to_non_nullable
as String?,unitPriceMinorSnapshot: null == unitPriceMinorSnapshot ? _self.unitPriceMinorSnapshot : unitPriceMinorSnapshot // ignore: cast_nullable_to_non_nullable
as int,currencyCodeSnapshot: null == currencyCodeSnapshot ? _self.currencyCodeSnapshot : currencyCodeSnapshot // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,discountMinor: null == discountMinor ? _self.discountMinor : discountMinor // ignore: cast_nullable_to_non_nullable
as int,taxMinor: null == taxMinor ? _self.taxMinor : taxMinor // ignore: cast_nullable_to_non_nullable
as int,lineTotalMinor: null == lineTotalMinor ? _self.lineTotalMinor : lineTotalMinor // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [SessionItem].
extension SessionItemPatterns on SessionItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SessionItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SessionItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SessionItem value)  $default,){
final _that = this;
switch (_that) {
case _SessionItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SessionItem value)?  $default,){
final _that = this;
switch (_that) {
case _SessionItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String businessId,  String sessionId,  String? productId,  String productNameSnapshot,  String? skuSnapshot,  int unitPriceMinorSnapshot,  String currencyCodeSnapshot,  int quantity,  int discountMinor,  int taxMinor,  int lineTotalMinor,  DateTime createdAt,  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SessionItem() when $default != null:
return $default(_that.id,_that.businessId,_that.sessionId,_that.productId,_that.productNameSnapshot,_that.skuSnapshot,_that.unitPriceMinorSnapshot,_that.currencyCodeSnapshot,_that.quantity,_that.discountMinor,_that.taxMinor,_that.lineTotalMinor,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String businessId,  String sessionId,  String? productId,  String productNameSnapshot,  String? skuSnapshot,  int unitPriceMinorSnapshot,  String currencyCodeSnapshot,  int quantity,  int discountMinor,  int taxMinor,  int lineTotalMinor,  DateTime createdAt,  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _SessionItem():
return $default(_that.id,_that.businessId,_that.sessionId,_that.productId,_that.productNameSnapshot,_that.skuSnapshot,_that.unitPriceMinorSnapshot,_that.currencyCodeSnapshot,_that.quantity,_that.discountMinor,_that.taxMinor,_that.lineTotalMinor,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String businessId,  String sessionId,  String? productId,  String productNameSnapshot,  String? skuSnapshot,  int unitPriceMinorSnapshot,  String currencyCodeSnapshot,  int quantity,  int discountMinor,  int taxMinor,  int lineTotalMinor,  DateTime createdAt,  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _SessionItem() when $default != null:
return $default(_that.id,_that.businessId,_that.sessionId,_that.productId,_that.productNameSnapshot,_that.skuSnapshot,_that.unitPriceMinorSnapshot,_that.currencyCodeSnapshot,_that.quantity,_that.discountMinor,_that.taxMinor,_that.lineTotalMinor,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc


class _SessionItem implements SessionItem {
  const _SessionItem({required this.id, required this.businessId, required this.sessionId, required this.productId, required this.productNameSnapshot, required this.skuSnapshot, required this.unitPriceMinorSnapshot, required this.currencyCodeSnapshot, required this.quantity, required this.discountMinor, required this.taxMinor, required this.lineTotalMinor, required this.createdAt, required this.updatedAt});


@override final  String id;
@override final  String businessId;
@override final  String sessionId;
@override final  String? productId;
@override final  String productNameSnapshot;
@override final  String? skuSnapshot;
@override final  int unitPriceMinorSnapshot;
@override final  String currencyCodeSnapshot;
@override final  int quantity;
@override final  int discountMinor;
@override final  int taxMinor;
@override final  int lineTotalMinor;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;

/// Create a copy of SessionItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionItemCopyWith<_SessionItem> get copyWith => __$SessionItemCopyWithImpl<_SessionItem>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionItem&&(identical(other.id, id) || other.id == id)&&(identical(other.businessId, businessId) || other.businessId == businessId)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.productId, productId) || other.productId == productId)&&(identical(other.productNameSnapshot, productNameSnapshot) || other.productNameSnapshot == productNameSnapshot)&&(identical(other.skuSnapshot, skuSnapshot) || other.skuSnapshot == skuSnapshot)&&(identical(other.unitPriceMinorSnapshot, unitPriceMinorSnapshot) || other.unitPriceMinorSnapshot == unitPriceMinorSnapshot)&&(identical(other.currencyCodeSnapshot, currencyCodeSnapshot) || other.currencyCodeSnapshot == currencyCodeSnapshot)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.discountMinor, discountMinor) || other.discountMinor == discountMinor)&&(identical(other.taxMinor, taxMinor) || other.taxMinor == taxMinor)&&(identical(other.lineTotalMinor, lineTotalMinor) || other.lineTotalMinor == lineTotalMinor)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,businessId,sessionId,productId,productNameSnapshot,skuSnapshot,unitPriceMinorSnapshot,currencyCodeSnapshot,quantity,discountMinor,taxMinor,lineTotalMinor,createdAt,updatedAt);

@override
String toString() {
  return 'SessionItem(id: $id, businessId: $businessId, sessionId: $sessionId, productId: $productId, productNameSnapshot: $productNameSnapshot, skuSnapshot: $skuSnapshot, unitPriceMinorSnapshot: $unitPriceMinorSnapshot, currencyCodeSnapshot: $currencyCodeSnapshot, quantity: $quantity, discountMinor: $discountMinor, taxMinor: $taxMinor, lineTotalMinor: $lineTotalMinor, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$SessionItemCopyWith<$Res> implements $SessionItemCopyWith<$Res> {
  factory _$SessionItemCopyWith(_SessionItem value, $Res Function(_SessionItem) _then) = __$SessionItemCopyWithImpl;
@override @useResult
$Res call({
 String id, String businessId, String sessionId, String? productId, String productNameSnapshot, String? skuSnapshot, int unitPriceMinorSnapshot, String currencyCodeSnapshot, int quantity, int discountMinor, int taxMinor, int lineTotalMinor, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class __$SessionItemCopyWithImpl<$Res>
    implements _$SessionItemCopyWith<$Res> {
  __$SessionItemCopyWithImpl(this._self, this._then);

  final _SessionItem _self;
  final $Res Function(_SessionItem) _then;

/// Create a copy of SessionItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? businessId = null,Object? sessionId = null,Object? productId = freezed,Object? productNameSnapshot = null,Object? skuSnapshot = freezed,Object? unitPriceMinorSnapshot = null,Object? currencyCodeSnapshot = null,Object? quantity = null,Object? discountMinor = null,Object? taxMinor = null,Object? lineTotalMinor = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_SessionItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,businessId: null == businessId ? _self.businessId : businessId // ignore: cast_nullable_to_non_nullable
as String,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,productId: freezed == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as String?,productNameSnapshot: null == productNameSnapshot ? _self.productNameSnapshot : productNameSnapshot // ignore: cast_nullable_to_non_nullable
as String,skuSnapshot: freezed == skuSnapshot ? _self.skuSnapshot : skuSnapshot // ignore: cast_nullable_to_non_nullable
as String?,unitPriceMinorSnapshot: null == unitPriceMinorSnapshot ? _self.unitPriceMinorSnapshot : unitPriceMinorSnapshot // ignore: cast_nullable_to_non_nullable
as int,currencyCodeSnapshot: null == currencyCodeSnapshot ? _self.currencyCodeSnapshot : currencyCodeSnapshot // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,discountMinor: null == discountMinor ? _self.discountMinor : discountMinor // ignore: cast_nullable_to_non_nullable
as int,taxMinor: null == taxMinor ? _self.taxMinor : taxMinor // ignore: cast_nullable_to_non_nullable
as int,lineTotalMinor: null == lineTotalMinor ? _self.lineTotalMinor : lineTotalMinor // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on

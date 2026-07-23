// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'service.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Service {

 String get id; String get businessId; String get name; int get pricePerMinuteMinor; int get roundingIntervalMinutes; int get minimumChargeMinutes; String get currencyCode; bool get isActive; DateTime? get archivedAt; DateTime get createdAt; DateTime get updatedAt;
/// Create a copy of Service
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ServiceCopyWith<Service> get copyWith => _$ServiceCopyWithImpl<Service>(this as Service, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Service&&(identical(other.id, id) || other.id == id)&&(identical(other.businessId, businessId) || other.businessId == businessId)&&(identical(other.name, name) || other.name == name)&&(identical(other.pricePerMinuteMinor, pricePerMinuteMinor) || other.pricePerMinuteMinor == pricePerMinuteMinor)&&(identical(other.roundingIntervalMinutes, roundingIntervalMinutes) || other.roundingIntervalMinutes == roundingIntervalMinutes)&&(identical(other.minimumChargeMinutes, minimumChargeMinutes) || other.minimumChargeMinutes == minimumChargeMinutes)&&(identical(other.currencyCode, currencyCode) || other.currencyCode == currencyCode)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,businessId,name,pricePerMinuteMinor,roundingIntervalMinutes,minimumChargeMinutes,currencyCode,isActive,archivedAt,createdAt,updatedAt);

@override
String toString() {
  return 'Service(id: $id, businessId: $businessId, name: $name, pricePerMinuteMinor: $pricePerMinuteMinor, roundingIntervalMinutes: $roundingIntervalMinutes, minimumChargeMinutes: $minimumChargeMinutes, currencyCode: $currencyCode, isActive: $isActive, archivedAt: $archivedAt, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $ServiceCopyWith<$Res>  {
  factory $ServiceCopyWith(Service value, $Res Function(Service) _then) = _$ServiceCopyWithImpl;
@useResult
$Res call({
 String id, String businessId, String name, int pricePerMinuteMinor, int roundingIntervalMinutes, int minimumChargeMinutes, String currencyCode, bool isActive, DateTime? archivedAt, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class _$ServiceCopyWithImpl<$Res>
    implements $ServiceCopyWith<$Res> {
  _$ServiceCopyWithImpl(this._self, this._then);

  final Service _self;
  final $Res Function(Service) _then;

/// Create a copy of Service
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? businessId = null,Object? name = null,Object? pricePerMinuteMinor = null,Object? roundingIntervalMinutes = null,Object? minimumChargeMinutes = null,Object? currencyCode = null,Object? isActive = null,Object? archivedAt = freezed,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,businessId: null == businessId ? _self.businessId : businessId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,pricePerMinuteMinor: null == pricePerMinuteMinor ? _self.pricePerMinuteMinor : pricePerMinuteMinor // ignore: cast_nullable_to_non_nullable
as int,roundingIntervalMinutes: null == roundingIntervalMinutes ? _self.roundingIntervalMinutes : roundingIntervalMinutes // ignore: cast_nullable_to_non_nullable
as int,minimumChargeMinutes: null == minimumChargeMinutes ? _self.minimumChargeMinutes : minimumChargeMinutes // ignore: cast_nullable_to_non_nullable
as int,currencyCode: null == currencyCode ? _self.currencyCode : currencyCode // ignore: cast_nullable_to_non_nullable
as String,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,archivedAt: freezed == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [Service].
extension ServicePatterns on Service {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Service value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Service() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Service value)  $default,){
final _that = this;
switch (_that) {
case _Service():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Service value)?  $default,){
final _that = this;
switch (_that) {
case _Service() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String businessId,  String name,  int pricePerMinuteMinor,  int roundingIntervalMinutes,  int minimumChargeMinutes,  String currencyCode,  bool isActive,  DateTime? archivedAt,  DateTime createdAt,  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Service() when $default != null:
return $default(_that.id,_that.businessId,_that.name,_that.pricePerMinuteMinor,_that.roundingIntervalMinutes,_that.minimumChargeMinutes,_that.currencyCode,_that.isActive,_that.archivedAt,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String businessId,  String name,  int pricePerMinuteMinor,  int roundingIntervalMinutes,  int minimumChargeMinutes,  String currencyCode,  bool isActive,  DateTime? archivedAt,  DateTime createdAt,  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _Service():
return $default(_that.id,_that.businessId,_that.name,_that.pricePerMinuteMinor,_that.roundingIntervalMinutes,_that.minimumChargeMinutes,_that.currencyCode,_that.isActive,_that.archivedAt,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String businessId,  String name,  int pricePerMinuteMinor,  int roundingIntervalMinutes,  int minimumChargeMinutes,  String currencyCode,  bool isActive,  DateTime? archivedAt,  DateTime createdAt,  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _Service() when $default != null:
return $default(_that.id,_that.businessId,_that.name,_that.pricePerMinuteMinor,_that.roundingIntervalMinutes,_that.minimumChargeMinutes,_that.currencyCode,_that.isActive,_that.archivedAt,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc


class _Service implements Service {
  const _Service({required this.id, required this.businessId, required this.name, required this.pricePerMinuteMinor, required this.roundingIntervalMinutes, required this.minimumChargeMinutes, required this.currencyCode, required this.isActive, required this.archivedAt, required this.createdAt, required this.updatedAt});


@override final  String id;
@override final  String businessId;
@override final  String name;
@override final  int pricePerMinuteMinor;
@override final  int roundingIntervalMinutes;
@override final  int minimumChargeMinutes;
@override final  String currencyCode;
@override final  bool isActive;
@override final  DateTime? archivedAt;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;

/// Create a copy of Service
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ServiceCopyWith<_Service> get copyWith => __$ServiceCopyWithImpl<_Service>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Service&&(identical(other.id, id) || other.id == id)&&(identical(other.businessId, businessId) || other.businessId == businessId)&&(identical(other.name, name) || other.name == name)&&(identical(other.pricePerMinuteMinor, pricePerMinuteMinor) || other.pricePerMinuteMinor == pricePerMinuteMinor)&&(identical(other.roundingIntervalMinutes, roundingIntervalMinutes) || other.roundingIntervalMinutes == roundingIntervalMinutes)&&(identical(other.minimumChargeMinutes, minimumChargeMinutes) || other.minimumChargeMinutes == minimumChargeMinutes)&&(identical(other.currencyCode, currencyCode) || other.currencyCode == currencyCode)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,businessId,name,pricePerMinuteMinor,roundingIntervalMinutes,minimumChargeMinutes,currencyCode,isActive,archivedAt,createdAt,updatedAt);

@override
String toString() {
  return 'Service(id: $id, businessId: $businessId, name: $name, pricePerMinuteMinor: $pricePerMinuteMinor, roundingIntervalMinutes: $roundingIntervalMinutes, minimumChargeMinutes: $minimumChargeMinutes, currencyCode: $currencyCode, isActive: $isActive, archivedAt: $archivedAt, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$ServiceCopyWith<$Res> implements $ServiceCopyWith<$Res> {
  factory _$ServiceCopyWith(_Service value, $Res Function(_Service) _then) = __$ServiceCopyWithImpl;
@override @useResult
$Res call({
 String id, String businessId, String name, int pricePerMinuteMinor, int roundingIntervalMinutes, int minimumChargeMinutes, String currencyCode, bool isActive, DateTime? archivedAt, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class __$ServiceCopyWithImpl<$Res>
    implements _$ServiceCopyWith<$Res> {
  __$ServiceCopyWithImpl(this._self, this._then);

  final _Service _self;
  final $Res Function(_Service) _then;

/// Create a copy of Service
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? businessId = null,Object? name = null,Object? pricePerMinuteMinor = null,Object? roundingIntervalMinutes = null,Object? minimumChargeMinutes = null,Object? currencyCode = null,Object? isActive = null,Object? archivedAt = freezed,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_Service(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,businessId: null == businessId ? _self.businessId : businessId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,pricePerMinuteMinor: null == pricePerMinuteMinor ? _self.pricePerMinuteMinor : pricePerMinuteMinor // ignore: cast_nullable_to_non_nullable
as int,roundingIntervalMinutes: null == roundingIntervalMinutes ? _self.roundingIntervalMinutes : roundingIntervalMinutes // ignore: cast_nullable_to_non_nullable
as int,minimumChargeMinutes: null == minimumChargeMinutes ? _self.minimumChargeMinutes : minimumChargeMinutes // ignore: cast_nullable_to_non_nullable
as int,currencyCode: null == currencyCode ? _self.currencyCode : currencyCode // ignore: cast_nullable_to_non_nullable
as String,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,archivedAt: freezed == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on

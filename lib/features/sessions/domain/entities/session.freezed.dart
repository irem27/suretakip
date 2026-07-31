// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Session {

 String get id; String get businessId; String? get customerId; String get serviceId; String get openedByMemberId; String? get closedByMemberId; SessionStatus get status; DateTime get startedAt; DateTime? get endedAt; int? get chargedMinutes; String get serviceNameSnapshot; int get pricePerMinuteMinorSnapshot; int get roundingIntervalMinutesSnapshot; int get minimumChargeMinutesSnapshot; String get currencyCodeSnapshot; int? get serviceSubtotalMinor; int? get productsSubtotalMinor; int get discountMinor; int get taxMinor; int? get grandTotalMinor; String? get notes; DateTime get createdAt; DateTime get updatedAt;
/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionCopyWith<Session> get copyWith => _$SessionCopyWithImpl<Session>(this as Session, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Session&&(identical(other.id, id) || other.id == id)&&(identical(other.businessId, businessId) || other.businessId == businessId)&&(identical(other.customerId, customerId) || other.customerId == customerId)&&(identical(other.serviceId, serviceId) || other.serviceId == serviceId)&&(identical(other.openedByMemberId, openedByMemberId) || other.openedByMemberId == openedByMemberId)&&(identical(other.closedByMemberId, closedByMemberId) || other.closedByMemberId == closedByMemberId)&&(identical(other.status, status) || other.status == status)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.endedAt, endedAt) || other.endedAt == endedAt)&&(identical(other.chargedMinutes, chargedMinutes) || other.chargedMinutes == chargedMinutes)&&(identical(other.serviceNameSnapshot, serviceNameSnapshot) || other.serviceNameSnapshot == serviceNameSnapshot)&&(identical(other.pricePerMinuteMinorSnapshot, pricePerMinuteMinorSnapshot) || other.pricePerMinuteMinorSnapshot == pricePerMinuteMinorSnapshot)&&(identical(other.roundingIntervalMinutesSnapshot, roundingIntervalMinutesSnapshot) || other.roundingIntervalMinutesSnapshot == roundingIntervalMinutesSnapshot)&&(identical(other.minimumChargeMinutesSnapshot, minimumChargeMinutesSnapshot) || other.minimumChargeMinutesSnapshot == minimumChargeMinutesSnapshot)&&(identical(other.currencyCodeSnapshot, currencyCodeSnapshot) || other.currencyCodeSnapshot == currencyCodeSnapshot)&&(identical(other.serviceSubtotalMinor, serviceSubtotalMinor) || other.serviceSubtotalMinor == serviceSubtotalMinor)&&(identical(other.productsSubtotalMinor, productsSubtotalMinor) || other.productsSubtotalMinor == productsSubtotalMinor)&&(identical(other.discountMinor, discountMinor) || other.discountMinor == discountMinor)&&(identical(other.taxMinor, taxMinor) || other.taxMinor == taxMinor)&&(identical(other.grandTotalMinor, grandTotalMinor) || other.grandTotalMinor == grandTotalMinor)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,businessId,customerId,serviceId,openedByMemberId,closedByMemberId,status,startedAt,endedAt,chargedMinutes,serviceNameSnapshot,pricePerMinuteMinorSnapshot,roundingIntervalMinutesSnapshot,minimumChargeMinutesSnapshot,currencyCodeSnapshot,serviceSubtotalMinor,productsSubtotalMinor,discountMinor,taxMinor,grandTotalMinor,notes,createdAt,updatedAt]);

@override
String toString() {
  return 'Session(id: $id, businessId: $businessId, customerId: $customerId, serviceId: $serviceId, openedByMemberId: $openedByMemberId, closedByMemberId: $closedByMemberId, status: $status, startedAt: $startedAt, endedAt: $endedAt, chargedMinutes: $chargedMinutes, serviceNameSnapshot: $serviceNameSnapshot, pricePerMinuteMinorSnapshot: $pricePerMinuteMinorSnapshot, roundingIntervalMinutesSnapshot: $roundingIntervalMinutesSnapshot, minimumChargeMinutesSnapshot: $minimumChargeMinutesSnapshot, currencyCodeSnapshot: $currencyCodeSnapshot, serviceSubtotalMinor: $serviceSubtotalMinor, productsSubtotalMinor: $productsSubtotalMinor, discountMinor: $discountMinor, taxMinor: $taxMinor, grandTotalMinor: $grandTotalMinor, notes: $notes, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $SessionCopyWith<$Res>  {
  factory $SessionCopyWith(Session value, $Res Function(Session) _then) = _$SessionCopyWithImpl;
@useResult
$Res call({
 String id, String businessId, String? customerId, String serviceId, String openedByMemberId, String? closedByMemberId, SessionStatus status, DateTime startedAt, DateTime? endedAt, int? chargedMinutes, String serviceNameSnapshot, int pricePerMinuteMinorSnapshot, int roundingIntervalMinutesSnapshot, int minimumChargeMinutesSnapshot, String currencyCodeSnapshot, int? serviceSubtotalMinor, int? productsSubtotalMinor, int discountMinor, int taxMinor, int? grandTotalMinor, String? notes, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class _$SessionCopyWithImpl<$Res>
    implements $SessionCopyWith<$Res> {
  _$SessionCopyWithImpl(this._self, this._then);

  final Session _self;
  final $Res Function(Session) _then;

/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? businessId = null,Object? customerId = freezed,Object? serviceId = null,Object? openedByMemberId = null,Object? closedByMemberId = freezed,Object? status = null,Object? startedAt = null,Object? endedAt = freezed,Object? chargedMinutes = freezed,Object? serviceNameSnapshot = null,Object? pricePerMinuteMinorSnapshot = null,Object? roundingIntervalMinutesSnapshot = null,Object? minimumChargeMinutesSnapshot = null,Object? currencyCodeSnapshot = null,Object? serviceSubtotalMinor = freezed,Object? productsSubtotalMinor = freezed,Object? discountMinor = null,Object? taxMinor = null,Object? grandTotalMinor = freezed,Object? notes = freezed,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,businessId: null == businessId ? _self.businessId : businessId // ignore: cast_nullable_to_non_nullable
as String,customerId: freezed == customerId ? _self.customerId : customerId // ignore: cast_nullable_to_non_nullable
as String?,serviceId: null == serviceId ? _self.serviceId : serviceId // ignore: cast_nullable_to_non_nullable
as String,openedByMemberId: null == openedByMemberId ? _self.openedByMemberId : openedByMemberId // ignore: cast_nullable_to_non_nullable
as String,closedByMemberId: freezed == closedByMemberId ? _self.closedByMemberId : closedByMemberId // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SessionStatus,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,endedAt: freezed == endedAt ? _self.endedAt : endedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,chargedMinutes: freezed == chargedMinutes ? _self.chargedMinutes : chargedMinutes // ignore: cast_nullable_to_non_nullable
as int?,serviceNameSnapshot: null == serviceNameSnapshot ? _self.serviceNameSnapshot : serviceNameSnapshot // ignore: cast_nullable_to_non_nullable
as String,pricePerMinuteMinorSnapshot: null == pricePerMinuteMinorSnapshot ? _self.pricePerMinuteMinorSnapshot : pricePerMinuteMinorSnapshot // ignore: cast_nullable_to_non_nullable
as int,roundingIntervalMinutesSnapshot: null == roundingIntervalMinutesSnapshot ? _self.roundingIntervalMinutesSnapshot : roundingIntervalMinutesSnapshot // ignore: cast_nullable_to_non_nullable
as int,minimumChargeMinutesSnapshot: null == minimumChargeMinutesSnapshot ? _self.minimumChargeMinutesSnapshot : minimumChargeMinutesSnapshot // ignore: cast_nullable_to_non_nullable
as int,currencyCodeSnapshot: null == currencyCodeSnapshot ? _self.currencyCodeSnapshot : currencyCodeSnapshot // ignore: cast_nullable_to_non_nullable
as String,serviceSubtotalMinor: freezed == serviceSubtotalMinor ? _self.serviceSubtotalMinor : serviceSubtotalMinor // ignore: cast_nullable_to_non_nullable
as int?,productsSubtotalMinor: freezed == productsSubtotalMinor ? _self.productsSubtotalMinor : productsSubtotalMinor // ignore: cast_nullable_to_non_nullable
as int?,discountMinor: null == discountMinor ? _self.discountMinor : discountMinor // ignore: cast_nullable_to_non_nullable
as int,taxMinor: null == taxMinor ? _self.taxMinor : taxMinor // ignore: cast_nullable_to_non_nullable
as int,grandTotalMinor: freezed == grandTotalMinor ? _self.grandTotalMinor : grandTotalMinor // ignore: cast_nullable_to_non_nullable
as int?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [Session].
extension SessionPatterns on Session {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Session value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Session() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Session value)  $default,){
final _that = this;
switch (_that) {
case _Session():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Session value)?  $default,){
final _that = this;
switch (_that) {
case _Session() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String businessId,  String? customerId,  String serviceId,  String openedByMemberId,  String? closedByMemberId,  SessionStatus status,  DateTime startedAt,  DateTime? endedAt,  int? chargedMinutes,  String serviceNameSnapshot,  int pricePerMinuteMinorSnapshot,  int roundingIntervalMinutesSnapshot,  int minimumChargeMinutesSnapshot,  String currencyCodeSnapshot,  int? serviceSubtotalMinor,  int? productsSubtotalMinor,  int discountMinor,  int taxMinor,  int? grandTotalMinor,  String? notes,  DateTime createdAt,  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Session() when $default != null:
return $default(_that.id,_that.businessId,_that.customerId,_that.serviceId,_that.openedByMemberId,_that.closedByMemberId,_that.status,_that.startedAt,_that.endedAt,_that.chargedMinutes,_that.serviceNameSnapshot,_that.pricePerMinuteMinorSnapshot,_that.roundingIntervalMinutesSnapshot,_that.minimumChargeMinutesSnapshot,_that.currencyCodeSnapshot,_that.serviceSubtotalMinor,_that.productsSubtotalMinor,_that.discountMinor,_that.taxMinor,_that.grandTotalMinor,_that.notes,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String businessId,  String? customerId,  String serviceId,  String openedByMemberId,  String? closedByMemberId,  SessionStatus status,  DateTime startedAt,  DateTime? endedAt,  int? chargedMinutes,  String serviceNameSnapshot,  int pricePerMinuteMinorSnapshot,  int roundingIntervalMinutesSnapshot,  int minimumChargeMinutesSnapshot,  String currencyCodeSnapshot,  int? serviceSubtotalMinor,  int? productsSubtotalMinor,  int discountMinor,  int taxMinor,  int? grandTotalMinor,  String? notes,  DateTime createdAt,  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _Session():
return $default(_that.id,_that.businessId,_that.customerId,_that.serviceId,_that.openedByMemberId,_that.closedByMemberId,_that.status,_that.startedAt,_that.endedAt,_that.chargedMinutes,_that.serviceNameSnapshot,_that.pricePerMinuteMinorSnapshot,_that.roundingIntervalMinutesSnapshot,_that.minimumChargeMinutesSnapshot,_that.currencyCodeSnapshot,_that.serviceSubtotalMinor,_that.productsSubtotalMinor,_that.discountMinor,_that.taxMinor,_that.grandTotalMinor,_that.notes,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String businessId,  String? customerId,  String serviceId,  String openedByMemberId,  String? closedByMemberId,  SessionStatus status,  DateTime startedAt,  DateTime? endedAt,  int? chargedMinutes,  String serviceNameSnapshot,  int pricePerMinuteMinorSnapshot,  int roundingIntervalMinutesSnapshot,  int minimumChargeMinutesSnapshot,  String currencyCodeSnapshot,  int? serviceSubtotalMinor,  int? productsSubtotalMinor,  int discountMinor,  int taxMinor,  int? grandTotalMinor,  String? notes,  DateTime createdAt,  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _Session() when $default != null:
return $default(_that.id,_that.businessId,_that.customerId,_that.serviceId,_that.openedByMemberId,_that.closedByMemberId,_that.status,_that.startedAt,_that.endedAt,_that.chargedMinutes,_that.serviceNameSnapshot,_that.pricePerMinuteMinorSnapshot,_that.roundingIntervalMinutesSnapshot,_that.minimumChargeMinutesSnapshot,_that.currencyCodeSnapshot,_that.serviceSubtotalMinor,_that.productsSubtotalMinor,_that.discountMinor,_that.taxMinor,_that.grandTotalMinor,_that.notes,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc


class _Session implements Session {
  const _Session({required this.id, required this.businessId, required this.customerId, required this.serviceId, required this.openedByMemberId, required this.closedByMemberId, required this.status, required this.startedAt, required this.endedAt, required this.chargedMinutes, required this.serviceNameSnapshot, required this.pricePerMinuteMinorSnapshot, required this.roundingIntervalMinutesSnapshot, required this.minimumChargeMinutesSnapshot, required this.currencyCodeSnapshot, required this.serviceSubtotalMinor, required this.productsSubtotalMinor, required this.discountMinor, required this.taxMinor, required this.grandTotalMinor, required this.notes, required this.createdAt, required this.updatedAt});


@override final  String id;
@override final  String businessId;
@override final  String? customerId;
@override final  String serviceId;
@override final  String openedByMemberId;
@override final  String? closedByMemberId;
@override final  SessionStatus status;
@override final  DateTime startedAt;
@override final  DateTime? endedAt;
@override final  int? chargedMinutes;
@override final  String serviceNameSnapshot;
@override final  int pricePerMinuteMinorSnapshot;
@override final  int roundingIntervalMinutesSnapshot;
@override final  int minimumChargeMinutesSnapshot;
@override final  String currencyCodeSnapshot;
@override final  int? serviceSubtotalMinor;
@override final  int? productsSubtotalMinor;
@override final  int discountMinor;
@override final  int taxMinor;
@override final  int? grandTotalMinor;
@override final  String? notes;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;

/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionCopyWith<_Session> get copyWith => __$SessionCopyWithImpl<_Session>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Session&&(identical(other.id, id) || other.id == id)&&(identical(other.businessId, businessId) || other.businessId == businessId)&&(identical(other.customerId, customerId) || other.customerId == customerId)&&(identical(other.serviceId, serviceId) || other.serviceId == serviceId)&&(identical(other.openedByMemberId, openedByMemberId) || other.openedByMemberId == openedByMemberId)&&(identical(other.closedByMemberId, closedByMemberId) || other.closedByMemberId == closedByMemberId)&&(identical(other.status, status) || other.status == status)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.endedAt, endedAt) || other.endedAt == endedAt)&&(identical(other.chargedMinutes, chargedMinutes) || other.chargedMinutes == chargedMinutes)&&(identical(other.serviceNameSnapshot, serviceNameSnapshot) || other.serviceNameSnapshot == serviceNameSnapshot)&&(identical(other.pricePerMinuteMinorSnapshot, pricePerMinuteMinorSnapshot) || other.pricePerMinuteMinorSnapshot == pricePerMinuteMinorSnapshot)&&(identical(other.roundingIntervalMinutesSnapshot, roundingIntervalMinutesSnapshot) || other.roundingIntervalMinutesSnapshot == roundingIntervalMinutesSnapshot)&&(identical(other.minimumChargeMinutesSnapshot, minimumChargeMinutesSnapshot) || other.minimumChargeMinutesSnapshot == minimumChargeMinutesSnapshot)&&(identical(other.currencyCodeSnapshot, currencyCodeSnapshot) || other.currencyCodeSnapshot == currencyCodeSnapshot)&&(identical(other.serviceSubtotalMinor, serviceSubtotalMinor) || other.serviceSubtotalMinor == serviceSubtotalMinor)&&(identical(other.productsSubtotalMinor, productsSubtotalMinor) || other.productsSubtotalMinor == productsSubtotalMinor)&&(identical(other.discountMinor, discountMinor) || other.discountMinor == discountMinor)&&(identical(other.taxMinor, taxMinor) || other.taxMinor == taxMinor)&&(identical(other.grandTotalMinor, grandTotalMinor) || other.grandTotalMinor == grandTotalMinor)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,businessId,customerId,serviceId,openedByMemberId,closedByMemberId,status,startedAt,endedAt,chargedMinutes,serviceNameSnapshot,pricePerMinuteMinorSnapshot,roundingIntervalMinutesSnapshot,minimumChargeMinutesSnapshot,currencyCodeSnapshot,serviceSubtotalMinor,productsSubtotalMinor,discountMinor,taxMinor,grandTotalMinor,notes,createdAt,updatedAt]);

@override
String toString() {
  return 'Session(id: $id, businessId: $businessId, customerId: $customerId, serviceId: $serviceId, openedByMemberId: $openedByMemberId, closedByMemberId: $closedByMemberId, status: $status, startedAt: $startedAt, endedAt: $endedAt, chargedMinutes: $chargedMinutes, serviceNameSnapshot: $serviceNameSnapshot, pricePerMinuteMinorSnapshot: $pricePerMinuteMinorSnapshot, roundingIntervalMinutesSnapshot: $roundingIntervalMinutesSnapshot, minimumChargeMinutesSnapshot: $minimumChargeMinutesSnapshot, currencyCodeSnapshot: $currencyCodeSnapshot, serviceSubtotalMinor: $serviceSubtotalMinor, productsSubtotalMinor: $productsSubtotalMinor, discountMinor: $discountMinor, taxMinor: $taxMinor, grandTotalMinor: $grandTotalMinor, notes: $notes, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$SessionCopyWith<$Res> implements $SessionCopyWith<$Res> {
  factory _$SessionCopyWith(_Session value, $Res Function(_Session) _then) = __$SessionCopyWithImpl;
@override @useResult
$Res call({
 String id, String businessId, String? customerId, String serviceId, String openedByMemberId, String? closedByMemberId, SessionStatus status, DateTime startedAt, DateTime? endedAt, int? chargedMinutes, String serviceNameSnapshot, int pricePerMinuteMinorSnapshot, int roundingIntervalMinutesSnapshot, int minimumChargeMinutesSnapshot, String currencyCodeSnapshot, int? serviceSubtotalMinor, int? productsSubtotalMinor, int discountMinor, int taxMinor, int? grandTotalMinor, String? notes, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class __$SessionCopyWithImpl<$Res>
    implements _$SessionCopyWith<$Res> {
  __$SessionCopyWithImpl(this._self, this._then);

  final _Session _self;
  final $Res Function(_Session) _then;

/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? businessId = null,Object? customerId = freezed,Object? serviceId = null,Object? openedByMemberId = null,Object? closedByMemberId = freezed,Object? status = null,Object? startedAt = null,Object? endedAt = freezed,Object? chargedMinutes = freezed,Object? serviceNameSnapshot = null,Object? pricePerMinuteMinorSnapshot = null,Object? roundingIntervalMinutesSnapshot = null,Object? minimumChargeMinutesSnapshot = null,Object? currencyCodeSnapshot = null,Object? serviceSubtotalMinor = freezed,Object? productsSubtotalMinor = freezed,Object? discountMinor = null,Object? taxMinor = null,Object? grandTotalMinor = freezed,Object? notes = freezed,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_Session(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,businessId: null == businessId ? _self.businessId : businessId // ignore: cast_nullable_to_non_nullable
as String,customerId: freezed == customerId ? _self.customerId : customerId // ignore: cast_nullable_to_non_nullable
as String?,serviceId: null == serviceId ? _self.serviceId : serviceId // ignore: cast_nullable_to_non_nullable
as String,openedByMemberId: null == openedByMemberId ? _self.openedByMemberId : openedByMemberId // ignore: cast_nullable_to_non_nullable
as String,closedByMemberId: freezed == closedByMemberId ? _self.closedByMemberId : closedByMemberId // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SessionStatus,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,endedAt: freezed == endedAt ? _self.endedAt : endedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,chargedMinutes: freezed == chargedMinutes ? _self.chargedMinutes : chargedMinutes // ignore: cast_nullable_to_non_nullable
as int?,serviceNameSnapshot: null == serviceNameSnapshot ? _self.serviceNameSnapshot : serviceNameSnapshot // ignore: cast_nullable_to_non_nullable
as String,pricePerMinuteMinorSnapshot: null == pricePerMinuteMinorSnapshot ? _self.pricePerMinuteMinorSnapshot : pricePerMinuteMinorSnapshot // ignore: cast_nullable_to_non_nullable
as int,roundingIntervalMinutesSnapshot: null == roundingIntervalMinutesSnapshot ? _self.roundingIntervalMinutesSnapshot : roundingIntervalMinutesSnapshot // ignore: cast_nullable_to_non_nullable
as int,minimumChargeMinutesSnapshot: null == minimumChargeMinutesSnapshot ? _self.minimumChargeMinutesSnapshot : minimumChargeMinutesSnapshot // ignore: cast_nullable_to_non_nullable
as int,currencyCodeSnapshot: null == currencyCodeSnapshot ? _self.currencyCodeSnapshot : currencyCodeSnapshot // ignore: cast_nullable_to_non_nullable
as String,serviceSubtotalMinor: freezed == serviceSubtotalMinor ? _self.serviceSubtotalMinor : serviceSubtotalMinor // ignore: cast_nullable_to_non_nullable
as int?,productsSubtotalMinor: freezed == productsSubtotalMinor ? _self.productsSubtotalMinor : productsSubtotalMinor // ignore: cast_nullable_to_non_nullable
as int?,discountMinor: null == discountMinor ? _self.discountMinor : discountMinor // ignore: cast_nullable_to_non_nullable
as int,taxMinor: null == taxMinor ? _self.taxMinor : taxMinor // ignore: cast_nullable_to_non_nullable
as int,grandTotalMinor: freezed == grandTotalMinor ? _self.grandTotalMinor : grandTotalMinor // ignore: cast_nullable_to_non_nullable
as int?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on

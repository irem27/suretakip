// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'payment.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Payment {

 String get id; PaymentKind get kind; PaymentMethod get method; PaymentRecordStatus get status; int get amountMinor; String get currencyCode; String? get originalPaymentId; String? get externalReference; String? get note; String get receivedByMemberId; bool get receivedByMe; DateTime get receivedAt; String? get voidedByMemberId; DateTime? get voidedAt; String? get voidReason;
/// Create a copy of Payment
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PaymentCopyWith<Payment> get copyWith => _$PaymentCopyWithImpl<Payment>(this as Payment, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Payment&&(identical(other.id, id) || other.id == id)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.method, method) || other.method == method)&&(identical(other.status, status) || other.status == status)&&(identical(other.amountMinor, amountMinor) || other.amountMinor == amountMinor)&&(identical(other.currencyCode, currencyCode) || other.currencyCode == currencyCode)&&(identical(other.originalPaymentId, originalPaymentId) || other.originalPaymentId == originalPaymentId)&&(identical(other.externalReference, externalReference) || other.externalReference == externalReference)&&(identical(other.note, note) || other.note == note)&&(identical(other.receivedByMemberId, receivedByMemberId) || other.receivedByMemberId == receivedByMemberId)&&(identical(other.receivedByMe, receivedByMe) || other.receivedByMe == receivedByMe)&&(identical(other.receivedAt, receivedAt) || other.receivedAt == receivedAt)&&(identical(other.voidedByMemberId, voidedByMemberId) || other.voidedByMemberId == voidedByMemberId)&&(identical(other.voidedAt, voidedAt) || other.voidedAt == voidedAt)&&(identical(other.voidReason, voidReason) || other.voidReason == voidReason));
}


@override
int get hashCode => Object.hash(runtimeType,id,kind,method,status,amountMinor,currencyCode,originalPaymentId,externalReference,note,receivedByMemberId,receivedByMe,receivedAt,voidedByMemberId,voidedAt,voidReason);

@override
String toString() {
  return 'Payment(id: $id, kind: $kind, method: $method, status: $status, amountMinor: $amountMinor, currencyCode: $currencyCode, originalPaymentId: $originalPaymentId, externalReference: $externalReference, note: $note, receivedByMemberId: $receivedByMemberId, receivedByMe: $receivedByMe, receivedAt: $receivedAt, voidedByMemberId: $voidedByMemberId, voidedAt: $voidedAt, voidReason: $voidReason)';
}


}

/// @nodoc
abstract mixin class $PaymentCopyWith<$Res>  {
  factory $PaymentCopyWith(Payment value, $Res Function(Payment) _then) = _$PaymentCopyWithImpl;
@useResult
$Res call({
 String id, PaymentKind kind, PaymentMethod method, PaymentRecordStatus status, int amountMinor, String currencyCode, String? originalPaymentId, String? externalReference, String? note, String receivedByMemberId, bool receivedByMe, DateTime receivedAt, String? voidedByMemberId, DateTime? voidedAt, String? voidReason
});




}
/// @nodoc
class _$PaymentCopyWithImpl<$Res>
    implements $PaymentCopyWith<$Res> {
  _$PaymentCopyWithImpl(this._self, this._then);

  final Payment _self;
  final $Res Function(Payment) _then;

/// Create a copy of Payment
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? kind = null,Object? method = null,Object? status = null,Object? amountMinor = null,Object? currencyCode = null,Object? originalPaymentId = freezed,Object? externalReference = freezed,Object? note = freezed,Object? receivedByMemberId = null,Object? receivedByMe = null,Object? receivedAt = null,Object? voidedByMemberId = freezed,Object? voidedAt = freezed,Object? voidReason = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as PaymentKind,method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as PaymentMethod,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as PaymentRecordStatus,amountMinor: null == amountMinor ? _self.amountMinor : amountMinor // ignore: cast_nullable_to_non_nullable
as int,currencyCode: null == currencyCode ? _self.currencyCode : currencyCode // ignore: cast_nullable_to_non_nullable
as String,originalPaymentId: freezed == originalPaymentId ? _self.originalPaymentId : originalPaymentId // ignore: cast_nullable_to_non_nullable
as String?,externalReference: freezed == externalReference ? _self.externalReference : externalReference // ignore: cast_nullable_to_non_nullable
as String?,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,receivedByMemberId: null == receivedByMemberId ? _self.receivedByMemberId : receivedByMemberId // ignore: cast_nullable_to_non_nullable
as String,receivedByMe: null == receivedByMe ? _self.receivedByMe : receivedByMe // ignore: cast_nullable_to_non_nullable
as bool,receivedAt: null == receivedAt ? _self.receivedAt : receivedAt // ignore: cast_nullable_to_non_nullable
as DateTime,voidedByMemberId: freezed == voidedByMemberId ? _self.voidedByMemberId : voidedByMemberId // ignore: cast_nullable_to_non_nullable
as String?,voidedAt: freezed == voidedAt ? _self.voidedAt : voidedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,voidReason: freezed == voidReason ? _self.voidReason : voidReason // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Payment].
extension PaymentPatterns on Payment {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Payment value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Payment() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Payment value)  $default,){
final _that = this;
switch (_that) {
case _Payment():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Payment value)?  $default,){
final _that = this;
switch (_that) {
case _Payment() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  PaymentKind kind,  PaymentMethod method,  PaymentRecordStatus status,  int amountMinor,  String currencyCode,  String? originalPaymentId,  String? externalReference,  String? note,  String receivedByMemberId,  bool receivedByMe,  DateTime receivedAt,  String? voidedByMemberId,  DateTime? voidedAt,  String? voidReason)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Payment() when $default != null:
return $default(_that.id,_that.kind,_that.method,_that.status,_that.amountMinor,_that.currencyCode,_that.originalPaymentId,_that.externalReference,_that.note,_that.receivedByMemberId,_that.receivedByMe,_that.receivedAt,_that.voidedByMemberId,_that.voidedAt,_that.voidReason);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  PaymentKind kind,  PaymentMethod method,  PaymentRecordStatus status,  int amountMinor,  String currencyCode,  String? originalPaymentId,  String? externalReference,  String? note,  String receivedByMemberId,  bool receivedByMe,  DateTime receivedAt,  String? voidedByMemberId,  DateTime? voidedAt,  String? voidReason)  $default,) {final _that = this;
switch (_that) {
case _Payment():
return $default(_that.id,_that.kind,_that.method,_that.status,_that.amountMinor,_that.currencyCode,_that.originalPaymentId,_that.externalReference,_that.note,_that.receivedByMemberId,_that.receivedByMe,_that.receivedAt,_that.voidedByMemberId,_that.voidedAt,_that.voidReason);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  PaymentKind kind,  PaymentMethod method,  PaymentRecordStatus status,  int amountMinor,  String currencyCode,  String? originalPaymentId,  String? externalReference,  String? note,  String receivedByMemberId,  bool receivedByMe,  DateTime receivedAt,  String? voidedByMemberId,  DateTime? voidedAt,  String? voidReason)?  $default,) {final _that = this;
switch (_that) {
case _Payment() when $default != null:
return $default(_that.id,_that.kind,_that.method,_that.status,_that.amountMinor,_that.currencyCode,_that.originalPaymentId,_that.externalReference,_that.note,_that.receivedByMemberId,_that.receivedByMe,_that.receivedAt,_that.voidedByMemberId,_that.voidedAt,_that.voidReason);case _:
  return null;

}
}

}

/// @nodoc


class _Payment extends Payment {
  const _Payment({required this.id, required this.kind, required this.method, required this.status, required this.amountMinor, required this.currencyCode, required this.originalPaymentId, required this.externalReference, required this.note, required this.receivedByMemberId, required this.receivedByMe, required this.receivedAt, required this.voidedByMemberId, required this.voidedAt, required this.voidReason}): super._();


@override final  String id;
@override final  PaymentKind kind;
@override final  PaymentMethod method;
@override final  PaymentRecordStatus status;
@override final  int amountMinor;
@override final  String currencyCode;
@override final  String? originalPaymentId;
@override final  String? externalReference;
@override final  String? note;
@override final  String receivedByMemberId;
@override final  bool receivedByMe;
@override final  DateTime receivedAt;
@override final  String? voidedByMemberId;
@override final  DateTime? voidedAt;
@override final  String? voidReason;

/// Create a copy of Payment
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PaymentCopyWith<_Payment> get copyWith => __$PaymentCopyWithImpl<_Payment>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Payment&&(identical(other.id, id) || other.id == id)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.method, method) || other.method == method)&&(identical(other.status, status) || other.status == status)&&(identical(other.amountMinor, amountMinor) || other.amountMinor == amountMinor)&&(identical(other.currencyCode, currencyCode) || other.currencyCode == currencyCode)&&(identical(other.originalPaymentId, originalPaymentId) || other.originalPaymentId == originalPaymentId)&&(identical(other.externalReference, externalReference) || other.externalReference == externalReference)&&(identical(other.note, note) || other.note == note)&&(identical(other.receivedByMemberId, receivedByMemberId) || other.receivedByMemberId == receivedByMemberId)&&(identical(other.receivedByMe, receivedByMe) || other.receivedByMe == receivedByMe)&&(identical(other.receivedAt, receivedAt) || other.receivedAt == receivedAt)&&(identical(other.voidedByMemberId, voidedByMemberId) || other.voidedByMemberId == voidedByMemberId)&&(identical(other.voidedAt, voidedAt) || other.voidedAt == voidedAt)&&(identical(other.voidReason, voidReason) || other.voidReason == voidReason));
}


@override
int get hashCode => Object.hash(runtimeType,id,kind,method,status,amountMinor,currencyCode,originalPaymentId,externalReference,note,receivedByMemberId,receivedByMe,receivedAt,voidedByMemberId,voidedAt,voidReason);

@override
String toString() {
  return 'Payment(id: $id, kind: $kind, method: $method, status: $status, amountMinor: $amountMinor, currencyCode: $currencyCode, originalPaymentId: $originalPaymentId, externalReference: $externalReference, note: $note, receivedByMemberId: $receivedByMemberId, receivedByMe: $receivedByMe, receivedAt: $receivedAt, voidedByMemberId: $voidedByMemberId, voidedAt: $voidedAt, voidReason: $voidReason)';
}


}

/// @nodoc
abstract mixin class _$PaymentCopyWith<$Res> implements $PaymentCopyWith<$Res> {
  factory _$PaymentCopyWith(_Payment value, $Res Function(_Payment) _then) = __$PaymentCopyWithImpl;
@override @useResult
$Res call({
 String id, PaymentKind kind, PaymentMethod method, PaymentRecordStatus status, int amountMinor, String currencyCode, String? originalPaymentId, String? externalReference, String? note, String receivedByMemberId, bool receivedByMe, DateTime receivedAt, String? voidedByMemberId, DateTime? voidedAt, String? voidReason
});




}
/// @nodoc
class __$PaymentCopyWithImpl<$Res>
    implements _$PaymentCopyWith<$Res> {
  __$PaymentCopyWithImpl(this._self, this._then);

  final _Payment _self;
  final $Res Function(_Payment) _then;

/// Create a copy of Payment
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? kind = null,Object? method = null,Object? status = null,Object? amountMinor = null,Object? currencyCode = null,Object? originalPaymentId = freezed,Object? externalReference = freezed,Object? note = freezed,Object? receivedByMemberId = null,Object? receivedByMe = null,Object? receivedAt = null,Object? voidedByMemberId = freezed,Object? voidedAt = freezed,Object? voidReason = freezed,}) {
  return _then(_Payment(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as PaymentKind,method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as PaymentMethod,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as PaymentRecordStatus,amountMinor: null == amountMinor ? _self.amountMinor : amountMinor // ignore: cast_nullable_to_non_nullable
as int,currencyCode: null == currencyCode ? _self.currencyCode : currencyCode // ignore: cast_nullable_to_non_nullable
as String,originalPaymentId: freezed == originalPaymentId ? _self.originalPaymentId : originalPaymentId // ignore: cast_nullable_to_non_nullable
as String?,externalReference: freezed == externalReference ? _self.externalReference : externalReference // ignore: cast_nullable_to_non_nullable
as String?,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,receivedByMemberId: null == receivedByMemberId ? _self.receivedByMemberId : receivedByMemberId // ignore: cast_nullable_to_non_nullable
as String,receivedByMe: null == receivedByMe ? _self.receivedByMe : receivedByMe // ignore: cast_nullable_to_non_nullable
as bool,receivedAt: null == receivedAt ? _self.receivedAt : receivedAt // ignore: cast_nullable_to_non_nullable
as DateTime,voidedByMemberId: freezed == voidedByMemberId ? _self.voidedByMemberId : voidedByMemberId // ignore: cast_nullable_to_non_nullable
as String?,voidedAt: freezed == voidedAt ? _self.voidedAt : voidedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,voidReason: freezed == voidReason ? _self.voidReason : voidReason // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on

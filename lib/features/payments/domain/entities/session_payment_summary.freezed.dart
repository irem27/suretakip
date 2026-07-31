// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_payment_summary.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SessionPaymentSummary {

 String get sessionId; Money get sessionTotal; Money get collected; Money get refunded; Money get netPaid; Money get remaining; SessionPaymentStatus get paymentStatus; String get currencyCode; List<Payment> get payments;
/// Create a copy of SessionPaymentSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionPaymentSummaryCopyWith<SessionPaymentSummary> get copyWith => _$SessionPaymentSummaryCopyWithImpl<SessionPaymentSummary>(this as SessionPaymentSummary, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionPaymentSummary&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.sessionTotal, sessionTotal) || other.sessionTotal == sessionTotal)&&(identical(other.collected, collected) || other.collected == collected)&&(identical(other.refunded, refunded) || other.refunded == refunded)&&(identical(other.netPaid, netPaid) || other.netPaid == netPaid)&&(identical(other.remaining, remaining) || other.remaining == remaining)&&(identical(other.paymentStatus, paymentStatus) || other.paymentStatus == paymentStatus)&&(identical(other.currencyCode, currencyCode) || other.currencyCode == currencyCode)&&const DeepCollectionEquality().equals(other.payments, payments));
}


@override
int get hashCode => Object.hash(runtimeType,sessionId,sessionTotal,collected,refunded,netPaid,remaining,paymentStatus,currencyCode,const DeepCollectionEquality().hash(payments));

@override
String toString() {
  return 'SessionPaymentSummary(sessionId: $sessionId, sessionTotal: $sessionTotal, collected: $collected, refunded: $refunded, netPaid: $netPaid, remaining: $remaining, paymentStatus: $paymentStatus, currencyCode: $currencyCode, payments: $payments)';
}


}

/// @nodoc
abstract mixin class $SessionPaymentSummaryCopyWith<$Res>  {
  factory $SessionPaymentSummaryCopyWith(SessionPaymentSummary value, $Res Function(SessionPaymentSummary) _then) = _$SessionPaymentSummaryCopyWithImpl;
@useResult
$Res call({
 String sessionId, Money sessionTotal, Money collected, Money refunded, Money netPaid, Money remaining, SessionPaymentStatus paymentStatus, String currencyCode, List<Payment> payments
});




}
/// @nodoc
class _$SessionPaymentSummaryCopyWithImpl<$Res>
    implements $SessionPaymentSummaryCopyWith<$Res> {
  _$SessionPaymentSummaryCopyWithImpl(this._self, this._then);

  final SessionPaymentSummary _self;
  final $Res Function(SessionPaymentSummary) _then;

/// Create a copy of SessionPaymentSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = null,Object? sessionTotal = null,Object? collected = null,Object? refunded = null,Object? netPaid = null,Object? remaining = null,Object? paymentStatus = null,Object? currencyCode = null,Object? payments = null,}) {
  return _then(_self.copyWith(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,sessionTotal: null == sessionTotal ? _self.sessionTotal : sessionTotal // ignore: cast_nullable_to_non_nullable
as Money,collected: null == collected ? _self.collected : collected // ignore: cast_nullable_to_non_nullable
as Money,refunded: null == refunded ? _self.refunded : refunded // ignore: cast_nullable_to_non_nullable
as Money,netPaid: null == netPaid ? _self.netPaid : netPaid // ignore: cast_nullable_to_non_nullable
as Money,remaining: null == remaining ? _self.remaining : remaining // ignore: cast_nullable_to_non_nullable
as Money,paymentStatus: null == paymentStatus ? _self.paymentStatus : paymentStatus // ignore: cast_nullable_to_non_nullable
as SessionPaymentStatus,currencyCode: null == currencyCode ? _self.currencyCode : currencyCode // ignore: cast_nullable_to_non_nullable
as String,payments: null == payments ? _self.payments : payments // ignore: cast_nullable_to_non_nullable
as List<Payment>,
  ));
}

}


/// Adds pattern-matching-related methods to [SessionPaymentSummary].
extension SessionPaymentSummaryPatterns on SessionPaymentSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SessionPaymentSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SessionPaymentSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SessionPaymentSummary value)  $default,){
final _that = this;
switch (_that) {
case _SessionPaymentSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SessionPaymentSummary value)?  $default,){
final _that = this;
switch (_that) {
case _SessionPaymentSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String sessionId,  Money sessionTotal,  Money collected,  Money refunded,  Money netPaid,  Money remaining,  SessionPaymentStatus paymentStatus,  String currencyCode,  List<Payment> payments)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SessionPaymentSummary() when $default != null:
return $default(_that.sessionId,_that.sessionTotal,_that.collected,_that.refunded,_that.netPaid,_that.remaining,_that.paymentStatus,_that.currencyCode,_that.payments);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String sessionId,  Money sessionTotal,  Money collected,  Money refunded,  Money netPaid,  Money remaining,  SessionPaymentStatus paymentStatus,  String currencyCode,  List<Payment> payments)  $default,) {final _that = this;
switch (_that) {
case _SessionPaymentSummary():
return $default(_that.sessionId,_that.sessionTotal,_that.collected,_that.refunded,_that.netPaid,_that.remaining,_that.paymentStatus,_that.currencyCode,_that.payments);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String sessionId,  Money sessionTotal,  Money collected,  Money refunded,  Money netPaid,  Money remaining,  SessionPaymentStatus paymentStatus,  String currencyCode,  List<Payment> payments)?  $default,) {final _that = this;
switch (_that) {
case _SessionPaymentSummary() when $default != null:
return $default(_that.sessionId,_that.sessionTotal,_that.collected,_that.refunded,_that.netPaid,_that.remaining,_that.paymentStatus,_that.currencyCode,_that.payments);case _:
  return null;

}
}

}

/// @nodoc


class _SessionPaymentSummary implements SessionPaymentSummary {
  const _SessionPaymentSummary({required this.sessionId, required this.sessionTotal, required this.collected, required this.refunded, required this.netPaid, required this.remaining, required this.paymentStatus, required this.currencyCode, required final  List<Payment> payments}): _payments = payments;


@override final  String sessionId;
@override final  Money sessionTotal;
@override final  Money collected;
@override final  Money refunded;
@override final  Money netPaid;
@override final  Money remaining;
@override final  SessionPaymentStatus paymentStatus;
@override final  String currencyCode;
 final  List<Payment> _payments;
@override List<Payment> get payments {
  if (_payments is EqualUnmodifiableListView) return _payments;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_payments);
}


/// Create a copy of SessionPaymentSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionPaymentSummaryCopyWith<_SessionPaymentSummary> get copyWith => __$SessionPaymentSummaryCopyWithImpl<_SessionPaymentSummary>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionPaymentSummary&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.sessionTotal, sessionTotal) || other.sessionTotal == sessionTotal)&&(identical(other.collected, collected) || other.collected == collected)&&(identical(other.refunded, refunded) || other.refunded == refunded)&&(identical(other.netPaid, netPaid) || other.netPaid == netPaid)&&(identical(other.remaining, remaining) || other.remaining == remaining)&&(identical(other.paymentStatus, paymentStatus) || other.paymentStatus == paymentStatus)&&(identical(other.currencyCode, currencyCode) || other.currencyCode == currencyCode)&&const DeepCollectionEquality().equals(other._payments, _payments));
}


@override
int get hashCode => Object.hash(runtimeType,sessionId,sessionTotal,collected,refunded,netPaid,remaining,paymentStatus,currencyCode,const DeepCollectionEquality().hash(_payments));

@override
String toString() {
  return 'SessionPaymentSummary(sessionId: $sessionId, sessionTotal: $sessionTotal, collected: $collected, refunded: $refunded, netPaid: $netPaid, remaining: $remaining, paymentStatus: $paymentStatus, currencyCode: $currencyCode, payments: $payments)';
}


}

/// @nodoc
abstract mixin class _$SessionPaymentSummaryCopyWith<$Res> implements $SessionPaymentSummaryCopyWith<$Res> {
  factory _$SessionPaymentSummaryCopyWith(_SessionPaymentSummary value, $Res Function(_SessionPaymentSummary) _then) = __$SessionPaymentSummaryCopyWithImpl;
@override @useResult
$Res call({
 String sessionId, Money sessionTotal, Money collected, Money refunded, Money netPaid, Money remaining, SessionPaymentStatus paymentStatus, String currencyCode, List<Payment> payments
});




}
/// @nodoc
class __$SessionPaymentSummaryCopyWithImpl<$Res>
    implements _$SessionPaymentSummaryCopyWith<$Res> {
  __$SessionPaymentSummaryCopyWithImpl(this._self, this._then);

  final _SessionPaymentSummary _self;
  final $Res Function(_SessionPaymentSummary) _then;

/// Create a copy of SessionPaymentSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? sessionTotal = null,Object? collected = null,Object? refunded = null,Object? netPaid = null,Object? remaining = null,Object? paymentStatus = null,Object? currencyCode = null,Object? payments = null,}) {
  return _then(_SessionPaymentSummary(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,sessionTotal: null == sessionTotal ? _self.sessionTotal : sessionTotal // ignore: cast_nullable_to_non_nullable
as Money,collected: null == collected ? _self.collected : collected // ignore: cast_nullable_to_non_nullable
as Money,refunded: null == refunded ? _self.refunded : refunded // ignore: cast_nullable_to_non_nullable
as Money,netPaid: null == netPaid ? _self.netPaid : netPaid // ignore: cast_nullable_to_non_nullable
as Money,remaining: null == remaining ? _self.remaining : remaining // ignore: cast_nullable_to_non_nullable
as Money,paymentStatus: null == paymentStatus ? _self.paymentStatus : paymentStatus // ignore: cast_nullable_to_non_nullable
as SessionPaymentStatus,currencyCode: null == currencyCode ? _self.currencyCode : currencyCode // ignore: cast_nullable_to_non_nullable
as String,payments: null == payments ? _self._payments : payments // ignore: cast_nullable_to_non_nullable
as List<Payment>,
  ));
}


}

// dart format on

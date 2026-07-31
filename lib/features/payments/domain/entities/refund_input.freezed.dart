// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'refund_input.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$RefundInput {

 String get paymentId; Money get amount; String get idempotencyKey; String get reason;
/// Create a copy of RefundInput
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RefundInputCopyWith<RefundInput> get copyWith => _$RefundInputCopyWithImpl<RefundInput>(this as RefundInput, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RefundInput&&(identical(other.paymentId, paymentId) || other.paymentId == paymentId)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.idempotencyKey, idempotencyKey) || other.idempotencyKey == idempotencyKey)&&(identical(other.reason, reason) || other.reason == reason));
}


@override
int get hashCode => Object.hash(runtimeType,paymentId,amount,idempotencyKey,reason);

@override
String toString() {
  return 'RefundInput(paymentId: $paymentId, amount: $amount, idempotencyKey: $idempotencyKey, reason: $reason)';
}


}

/// @nodoc
abstract mixin class $RefundInputCopyWith<$Res>  {
  factory $RefundInputCopyWith(RefundInput value, $Res Function(RefundInput) _then) = _$RefundInputCopyWithImpl;
@useResult
$Res call({
 String paymentId, Money amount, String idempotencyKey, String reason
});




}
/// @nodoc
class _$RefundInputCopyWithImpl<$Res>
    implements $RefundInputCopyWith<$Res> {
  _$RefundInputCopyWithImpl(this._self, this._then);

  final RefundInput _self;
  final $Res Function(RefundInput) _then;

/// Create a copy of RefundInput
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? paymentId = null,Object? amount = null,Object? idempotencyKey = null,Object? reason = null,}) {
  return _then(_self.copyWith(
paymentId: null == paymentId ? _self.paymentId : paymentId // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as Money,idempotencyKey: null == idempotencyKey ? _self.idempotencyKey : idempotencyKey // ignore: cast_nullable_to_non_nullable
as String,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [RefundInput].
extension RefundInputPatterns on RefundInput {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RefundInput value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RefundInput() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RefundInput value)  $default,){
final _that = this;
switch (_that) {
case _RefundInput():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RefundInput value)?  $default,){
final _that = this;
switch (_that) {
case _RefundInput() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String paymentId,  Money amount,  String idempotencyKey,  String reason)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RefundInput() when $default != null:
return $default(_that.paymentId,_that.amount,_that.idempotencyKey,_that.reason);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String paymentId,  Money amount,  String idempotencyKey,  String reason)  $default,) {final _that = this;
switch (_that) {
case _RefundInput():
return $default(_that.paymentId,_that.amount,_that.idempotencyKey,_that.reason);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String paymentId,  Money amount,  String idempotencyKey,  String reason)?  $default,) {final _that = this;
switch (_that) {
case _RefundInput() when $default != null:
return $default(_that.paymentId,_that.amount,_that.idempotencyKey,_that.reason);case _:
  return null;

}
}

}

/// @nodoc


class _RefundInput implements RefundInput {
  const _RefundInput({required this.paymentId, required this.amount, required this.idempotencyKey, required this.reason});


@override final  String paymentId;
@override final  Money amount;
@override final  String idempotencyKey;
@override final  String reason;

/// Create a copy of RefundInput
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RefundInputCopyWith<_RefundInput> get copyWith => __$RefundInputCopyWithImpl<_RefundInput>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RefundInput&&(identical(other.paymentId, paymentId) || other.paymentId == paymentId)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.idempotencyKey, idempotencyKey) || other.idempotencyKey == idempotencyKey)&&(identical(other.reason, reason) || other.reason == reason));
}


@override
int get hashCode => Object.hash(runtimeType,paymentId,amount,idempotencyKey,reason);

@override
String toString() {
  return 'RefundInput(paymentId: $paymentId, amount: $amount, idempotencyKey: $idempotencyKey, reason: $reason)';
}


}

/// @nodoc
abstract mixin class _$RefundInputCopyWith<$Res> implements $RefundInputCopyWith<$Res> {
  factory _$RefundInputCopyWith(_RefundInput value, $Res Function(_RefundInput) _then) = __$RefundInputCopyWithImpl;
@override @useResult
$Res call({
 String paymentId, Money amount, String idempotencyKey, String reason
});




}
/// @nodoc
class __$RefundInputCopyWithImpl<$Res>
    implements _$RefundInputCopyWith<$Res> {
  __$RefundInputCopyWithImpl(this._self, this._then);

  final _RefundInput _self;
  final $Res Function(_RefundInput) _then;

/// Create a copy of RefundInput
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? paymentId = null,Object? amount = null,Object? idempotencyKey = null,Object? reason = null,}) {
  return _then(_RefundInput(
paymentId: null == paymentId ? _self.paymentId : paymentId // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as Money,idempotencyKey: null == idempotencyKey ? _self.idempotencyKey : idempotencyKey // ignore: cast_nullable_to_non_nullable
as String,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on

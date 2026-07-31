// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'payment_input.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PaymentInput {

 String get sessionId; PaymentMethod get method; Money get amount; String get idempotencyKey; String? get externalReference; String? get note;
/// Create a copy of PaymentInput
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PaymentInputCopyWith<PaymentInput> get copyWith => _$PaymentInputCopyWithImpl<PaymentInput>(this as PaymentInput, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PaymentInput&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.method, method) || other.method == method)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.idempotencyKey, idempotencyKey) || other.idempotencyKey == idempotencyKey)&&(identical(other.externalReference, externalReference) || other.externalReference == externalReference)&&(identical(other.note, note) || other.note == note));
}


@override
int get hashCode => Object.hash(runtimeType,sessionId,method,amount,idempotencyKey,externalReference,note);

@override
String toString() {
  return 'PaymentInput(sessionId: $sessionId, method: $method, amount: $amount, idempotencyKey: $idempotencyKey, externalReference: $externalReference, note: $note)';
}


}

/// @nodoc
abstract mixin class $PaymentInputCopyWith<$Res>  {
  factory $PaymentInputCopyWith(PaymentInput value, $Res Function(PaymentInput) _then) = _$PaymentInputCopyWithImpl;
@useResult
$Res call({
 String sessionId, PaymentMethod method, Money amount, String idempotencyKey, String? externalReference, String? note
});




}
/// @nodoc
class _$PaymentInputCopyWithImpl<$Res>
    implements $PaymentInputCopyWith<$Res> {
  _$PaymentInputCopyWithImpl(this._self, this._then);

  final PaymentInput _self;
  final $Res Function(PaymentInput) _then;

/// Create a copy of PaymentInput
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = null,Object? method = null,Object? amount = null,Object? idempotencyKey = null,Object? externalReference = freezed,Object? note = freezed,}) {
  return _then(_self.copyWith(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as PaymentMethod,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as Money,idempotencyKey: null == idempotencyKey ? _self.idempotencyKey : idempotencyKey // ignore: cast_nullable_to_non_nullable
as String,externalReference: freezed == externalReference ? _self.externalReference : externalReference // ignore: cast_nullable_to_non_nullable
as String?,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [PaymentInput].
extension PaymentInputPatterns on PaymentInput {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PaymentInput value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PaymentInput() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PaymentInput value)  $default,){
final _that = this;
switch (_that) {
case _PaymentInput():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PaymentInput value)?  $default,){
final _that = this;
switch (_that) {
case _PaymentInput() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String sessionId,  PaymentMethod method,  Money amount,  String idempotencyKey,  String? externalReference,  String? note)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PaymentInput() when $default != null:
return $default(_that.sessionId,_that.method,_that.amount,_that.idempotencyKey,_that.externalReference,_that.note);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String sessionId,  PaymentMethod method,  Money amount,  String idempotencyKey,  String? externalReference,  String? note)  $default,) {final _that = this;
switch (_that) {
case _PaymentInput():
return $default(_that.sessionId,_that.method,_that.amount,_that.idempotencyKey,_that.externalReference,_that.note);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String sessionId,  PaymentMethod method,  Money amount,  String idempotencyKey,  String? externalReference,  String? note)?  $default,) {final _that = this;
switch (_that) {
case _PaymentInput() when $default != null:
return $default(_that.sessionId,_that.method,_that.amount,_that.idempotencyKey,_that.externalReference,_that.note);case _:
  return null;

}
}

}

/// @nodoc


class _PaymentInput implements PaymentInput {
  const _PaymentInput({required this.sessionId, required this.method, required this.amount, required this.idempotencyKey, this.externalReference, this.note});


@override final  String sessionId;
@override final  PaymentMethod method;
@override final  Money amount;
@override final  String idempotencyKey;
@override final  String? externalReference;
@override final  String? note;

/// Create a copy of PaymentInput
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PaymentInputCopyWith<_PaymentInput> get copyWith => __$PaymentInputCopyWithImpl<_PaymentInput>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PaymentInput&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.method, method) || other.method == method)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.idempotencyKey, idempotencyKey) || other.idempotencyKey == idempotencyKey)&&(identical(other.externalReference, externalReference) || other.externalReference == externalReference)&&(identical(other.note, note) || other.note == note));
}


@override
int get hashCode => Object.hash(runtimeType,sessionId,method,amount,idempotencyKey,externalReference,note);

@override
String toString() {
  return 'PaymentInput(sessionId: $sessionId, method: $method, amount: $amount, idempotencyKey: $idempotencyKey, externalReference: $externalReference, note: $note)';
}


}

/// @nodoc
abstract mixin class _$PaymentInputCopyWith<$Res> implements $PaymentInputCopyWith<$Res> {
  factory _$PaymentInputCopyWith(_PaymentInput value, $Res Function(_PaymentInput) _then) = __$PaymentInputCopyWithImpl;
@override @useResult
$Res call({
 String sessionId, PaymentMethod method, Money amount, String idempotencyKey, String? externalReference, String? note
});




}
/// @nodoc
class __$PaymentInputCopyWithImpl<$Res>
    implements _$PaymentInputCopyWith<$Res> {
  __$PaymentInputCopyWithImpl(this._self, this._then);

  final _PaymentInput _self;
  final $Res Function(_PaymentInput) _then;

/// Create a copy of PaymentInput
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? method = null,Object? amount = null,Object? idempotencyKey = null,Object? externalReference = freezed,Object? note = freezed,}) {
  return _then(_PaymentInput(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as PaymentMethod,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as Money,idempotencyKey: null == idempotencyKey ? _self.idempotencyKey : idempotencyKey // ignore: cast_nullable_to_non_nullable
as String,externalReference: freezed == externalReference ? _self.externalReference : externalReference // ignore: cast_nullable_to_non_nullable
as String?,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on

// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'payment_input.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$PaymentInput {
  String get sessionId => throw _privateConstructorUsedError;
  PaymentMethod get method => throw _privateConstructorUsedError;
  Money get amount => throw _privateConstructorUsedError;
  String get idempotencyKey => throw _privateConstructorUsedError;
  String? get externalReference => throw _privateConstructorUsedError;
  String? get note => throw _privateConstructorUsedError;

  /// Create a copy of PaymentInput
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PaymentInputCopyWith<PaymentInput> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PaymentInputCopyWith<$Res> {
  factory $PaymentInputCopyWith(
    PaymentInput value,
    $Res Function(PaymentInput) then,
  ) = _$PaymentInputCopyWithImpl<$Res, PaymentInput>;
  @useResult
  $Res call({
    String sessionId,
    PaymentMethod method,
    Money amount,
    String idempotencyKey,
    String? externalReference,
    String? note,
  });
}

/// @nodoc
class _$PaymentInputCopyWithImpl<$Res, $Val extends PaymentInput>
    implements $PaymentInputCopyWith<$Res> {
  _$PaymentInputCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PaymentInput
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sessionId = null,
    Object? method = null,
    Object? amount = null,
    Object? idempotencyKey = null,
    Object? externalReference = freezed,
    Object? note = freezed,
  }) {
    return _then(
      _value.copyWith(
            sessionId: null == sessionId
                ? _value.sessionId
                : sessionId // ignore: cast_nullable_to_non_nullable
                      as String,
            method: null == method
                ? _value.method
                : method // ignore: cast_nullable_to_non_nullable
                      as PaymentMethod,
            amount: null == amount
                ? _value.amount
                : amount // ignore: cast_nullable_to_non_nullable
                      as Money,
            idempotencyKey: null == idempotencyKey
                ? _value.idempotencyKey
                : idempotencyKey // ignore: cast_nullable_to_non_nullable
                      as String,
            externalReference: freezed == externalReference
                ? _value.externalReference
                : externalReference // ignore: cast_nullable_to_non_nullable
                      as String?,
            note: freezed == note
                ? _value.note
                : note // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PaymentInputImplCopyWith<$Res>
    implements $PaymentInputCopyWith<$Res> {
  factory _$$PaymentInputImplCopyWith(
    _$PaymentInputImpl value,
    $Res Function(_$PaymentInputImpl) then,
  ) = __$$PaymentInputImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String sessionId,
    PaymentMethod method,
    Money amount,
    String idempotencyKey,
    String? externalReference,
    String? note,
  });
}

/// @nodoc
class __$$PaymentInputImplCopyWithImpl<$Res>
    extends _$PaymentInputCopyWithImpl<$Res, _$PaymentInputImpl>
    implements _$$PaymentInputImplCopyWith<$Res> {
  __$$PaymentInputImplCopyWithImpl(
    _$PaymentInputImpl _value,
    $Res Function(_$PaymentInputImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PaymentInput
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sessionId = null,
    Object? method = null,
    Object? amount = null,
    Object? idempotencyKey = null,
    Object? externalReference = freezed,
    Object? note = freezed,
  }) {
    return _then(
      _$PaymentInputImpl(
        sessionId: null == sessionId
            ? _value.sessionId
            : sessionId // ignore: cast_nullable_to_non_nullable
                  as String,
        method: null == method
            ? _value.method
            : method // ignore: cast_nullable_to_non_nullable
                  as PaymentMethod,
        amount: null == amount
            ? _value.amount
            : amount // ignore: cast_nullable_to_non_nullable
                  as Money,
        idempotencyKey: null == idempotencyKey
            ? _value.idempotencyKey
            : idempotencyKey // ignore: cast_nullable_to_non_nullable
                  as String,
        externalReference: freezed == externalReference
            ? _value.externalReference
            : externalReference // ignore: cast_nullable_to_non_nullable
                  as String?,
        note: freezed == note
            ? _value.note
            : note // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$PaymentInputImpl implements _PaymentInput {
  const _$PaymentInputImpl({
    required this.sessionId,
    required this.method,
    required this.amount,
    required this.idempotencyKey,
    this.externalReference,
    this.note,
  });

  @override
  final String sessionId;
  @override
  final PaymentMethod method;
  @override
  final Money amount;
  @override
  final String idempotencyKey;
  @override
  final String? externalReference;
  @override
  final String? note;

  @override
  String toString() {
    return 'PaymentInput(sessionId: $sessionId, method: $method, amount: $amount, idempotencyKey: $idempotencyKey, externalReference: $externalReference, note: $note)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PaymentInputImpl &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId) &&
            (identical(other.method, method) || other.method == method) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.idempotencyKey, idempotencyKey) ||
                other.idempotencyKey == idempotencyKey) &&
            (identical(other.externalReference, externalReference) ||
                other.externalReference == externalReference) &&
            (identical(other.note, note) || other.note == note));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    sessionId,
    method,
    amount,
    idempotencyKey,
    externalReference,
    note,
  );

  /// Create a copy of PaymentInput
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PaymentInputImplCopyWith<_$PaymentInputImpl> get copyWith =>
      __$$PaymentInputImplCopyWithImpl<_$PaymentInputImpl>(this, _$identity);
}

abstract class _PaymentInput implements PaymentInput {
  const factory _PaymentInput({
    required final String sessionId,
    required final PaymentMethod method,
    required final Money amount,
    required final String idempotencyKey,
    final String? externalReference,
    final String? note,
  }) = _$PaymentInputImpl;

  @override
  String get sessionId;
  @override
  PaymentMethod get method;
  @override
  Money get amount;
  @override
  String get idempotencyKey;
  @override
  String? get externalReference;
  @override
  String? get note;

  /// Create a copy of PaymentInput
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PaymentInputImplCopyWith<_$PaymentInputImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

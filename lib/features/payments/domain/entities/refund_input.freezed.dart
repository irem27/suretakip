// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'refund_input.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$RefundInput {
  String get paymentId => throw _privateConstructorUsedError;
  Money get amount => throw _privateConstructorUsedError;
  String get idempotencyKey => throw _privateConstructorUsedError;
  String get reason => throw _privateConstructorUsedError;

  /// Create a copy of RefundInput
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RefundInputCopyWith<RefundInput> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RefundInputCopyWith<$Res> {
  factory $RefundInputCopyWith(
    RefundInput value,
    $Res Function(RefundInput) then,
  ) = _$RefundInputCopyWithImpl<$Res, RefundInput>;
  @useResult
  $Res call({
    String paymentId,
    Money amount,
    String idempotencyKey,
    String reason,
  });
}

/// @nodoc
class _$RefundInputCopyWithImpl<$Res, $Val extends RefundInput>
    implements $RefundInputCopyWith<$Res> {
  _$RefundInputCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RefundInput
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? paymentId = null,
    Object? amount = null,
    Object? idempotencyKey = null,
    Object? reason = null,
  }) {
    return _then(
      _value.copyWith(
            paymentId: null == paymentId
                ? _value.paymentId
                : paymentId // ignore: cast_nullable_to_non_nullable
                      as String,
            amount: null == amount
                ? _value.amount
                : amount // ignore: cast_nullable_to_non_nullable
                      as Money,
            idempotencyKey: null == idempotencyKey
                ? _value.idempotencyKey
                : idempotencyKey // ignore: cast_nullable_to_non_nullable
                      as String,
            reason: null == reason
                ? _value.reason
                : reason // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$RefundInputImplCopyWith<$Res>
    implements $RefundInputCopyWith<$Res> {
  factory _$$RefundInputImplCopyWith(
    _$RefundInputImpl value,
    $Res Function(_$RefundInputImpl) then,
  ) = __$$RefundInputImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String paymentId,
    Money amount,
    String idempotencyKey,
    String reason,
  });
}

/// @nodoc
class __$$RefundInputImplCopyWithImpl<$Res>
    extends _$RefundInputCopyWithImpl<$Res, _$RefundInputImpl>
    implements _$$RefundInputImplCopyWith<$Res> {
  __$$RefundInputImplCopyWithImpl(
    _$RefundInputImpl _value,
    $Res Function(_$RefundInputImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RefundInput
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? paymentId = null,
    Object? amount = null,
    Object? idempotencyKey = null,
    Object? reason = null,
  }) {
    return _then(
      _$RefundInputImpl(
        paymentId: null == paymentId
            ? _value.paymentId
            : paymentId // ignore: cast_nullable_to_non_nullable
                  as String,
        amount: null == amount
            ? _value.amount
            : amount // ignore: cast_nullable_to_non_nullable
                  as Money,
        idempotencyKey: null == idempotencyKey
            ? _value.idempotencyKey
            : idempotencyKey // ignore: cast_nullable_to_non_nullable
                  as String,
        reason: null == reason
            ? _value.reason
            : reason // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$RefundInputImpl implements _RefundInput {
  const _$RefundInputImpl({
    required this.paymentId,
    required this.amount,
    required this.idempotencyKey,
    required this.reason,
  });

  @override
  final String paymentId;
  @override
  final Money amount;
  @override
  final String idempotencyKey;
  @override
  final String reason;

  @override
  String toString() {
    return 'RefundInput(paymentId: $paymentId, amount: $amount, idempotencyKey: $idempotencyKey, reason: $reason)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RefundInputImpl &&
            (identical(other.paymentId, paymentId) ||
                other.paymentId == paymentId) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.idempotencyKey, idempotencyKey) ||
                other.idempotencyKey == idempotencyKey) &&
            (identical(other.reason, reason) || other.reason == reason));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, paymentId, amount, idempotencyKey, reason);

  /// Create a copy of RefundInput
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RefundInputImplCopyWith<_$RefundInputImpl> get copyWith =>
      __$$RefundInputImplCopyWithImpl<_$RefundInputImpl>(this, _$identity);
}

abstract class _RefundInput implements RefundInput {
  const factory _RefundInput({
    required final String paymentId,
    required final Money amount,
    required final String idempotencyKey,
    required final String reason,
  }) = _$RefundInputImpl;

  @override
  String get paymentId;
  @override
  Money get amount;
  @override
  String get idempotencyKey;
  @override
  String get reason;

  /// Create a copy of RefundInput
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RefundInputImplCopyWith<_$RefundInputImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

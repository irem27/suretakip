// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'payment.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$Payment {
  String get id => throw _privateConstructorUsedError;
  PaymentKind get kind => throw _privateConstructorUsedError;
  PaymentMethod get method => throw _privateConstructorUsedError;
  PaymentRecordStatus get status => throw _privateConstructorUsedError;
  int get amountMinor => throw _privateConstructorUsedError;
  String get currencyCode => throw _privateConstructorUsedError;
  String? get originalPaymentId => throw _privateConstructorUsedError;
  String? get externalReference => throw _privateConstructorUsedError;
  String? get note => throw _privateConstructorUsedError;
  String get receivedByMemberId => throw _privateConstructorUsedError;
  bool get receivedByMe => throw _privateConstructorUsedError;
  DateTime get receivedAt => throw _privateConstructorUsedError;
  String? get voidedByMemberId => throw _privateConstructorUsedError;
  DateTime? get voidedAt => throw _privateConstructorUsedError;
  String? get voidReason => throw _privateConstructorUsedError;

  /// Create a copy of Payment
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PaymentCopyWith<Payment> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PaymentCopyWith<$Res> {
  factory $PaymentCopyWith(Payment value, $Res Function(Payment) then) =
      _$PaymentCopyWithImpl<$Res, Payment>;
  @useResult
  $Res call({
    String id,
    PaymentKind kind,
    PaymentMethod method,
    PaymentRecordStatus status,
    int amountMinor,
    String currencyCode,
    String? originalPaymentId,
    String? externalReference,
    String? note,
    String receivedByMemberId,
    bool receivedByMe,
    DateTime receivedAt,
    String? voidedByMemberId,
    DateTime? voidedAt,
    String? voidReason,
  });
}

/// @nodoc
class _$PaymentCopyWithImpl<$Res, $Val extends Payment>
    implements $PaymentCopyWith<$Res> {
  _$PaymentCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Payment
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? kind = null,
    Object? method = null,
    Object? status = null,
    Object? amountMinor = null,
    Object? currencyCode = null,
    Object? originalPaymentId = freezed,
    Object? externalReference = freezed,
    Object? note = freezed,
    Object? receivedByMemberId = null,
    Object? receivedByMe = null,
    Object? receivedAt = null,
    Object? voidedByMemberId = freezed,
    Object? voidedAt = freezed,
    Object? voidReason = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            kind: null == kind
                ? _value.kind
                : kind // ignore: cast_nullable_to_non_nullable
                      as PaymentKind,
            method: null == method
                ? _value.method
                : method // ignore: cast_nullable_to_non_nullable
                      as PaymentMethod,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as PaymentRecordStatus,
            amountMinor: null == amountMinor
                ? _value.amountMinor
                : amountMinor // ignore: cast_nullable_to_non_nullable
                      as int,
            currencyCode: null == currencyCode
                ? _value.currencyCode
                : currencyCode // ignore: cast_nullable_to_non_nullable
                      as String,
            originalPaymentId: freezed == originalPaymentId
                ? _value.originalPaymentId
                : originalPaymentId // ignore: cast_nullable_to_non_nullable
                      as String?,
            externalReference: freezed == externalReference
                ? _value.externalReference
                : externalReference // ignore: cast_nullable_to_non_nullable
                      as String?,
            note: freezed == note
                ? _value.note
                : note // ignore: cast_nullable_to_non_nullable
                      as String?,
            receivedByMemberId: null == receivedByMemberId
                ? _value.receivedByMemberId
                : receivedByMemberId // ignore: cast_nullable_to_non_nullable
                      as String,
            receivedByMe: null == receivedByMe
                ? _value.receivedByMe
                : receivedByMe // ignore: cast_nullable_to_non_nullable
                      as bool,
            receivedAt: null == receivedAt
                ? _value.receivedAt
                : receivedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            voidedByMemberId: freezed == voidedByMemberId
                ? _value.voidedByMemberId
                : voidedByMemberId // ignore: cast_nullable_to_non_nullable
                      as String?,
            voidedAt: freezed == voidedAt
                ? _value.voidedAt
                : voidedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            voidReason: freezed == voidReason
                ? _value.voidReason
                : voidReason // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PaymentImplCopyWith<$Res> implements $PaymentCopyWith<$Res> {
  factory _$$PaymentImplCopyWith(
    _$PaymentImpl value,
    $Res Function(_$PaymentImpl) then,
  ) = __$$PaymentImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    PaymentKind kind,
    PaymentMethod method,
    PaymentRecordStatus status,
    int amountMinor,
    String currencyCode,
    String? originalPaymentId,
    String? externalReference,
    String? note,
    String receivedByMemberId,
    bool receivedByMe,
    DateTime receivedAt,
    String? voidedByMemberId,
    DateTime? voidedAt,
    String? voidReason,
  });
}

/// @nodoc
class __$$PaymentImplCopyWithImpl<$Res>
    extends _$PaymentCopyWithImpl<$Res, _$PaymentImpl>
    implements _$$PaymentImplCopyWith<$Res> {
  __$$PaymentImplCopyWithImpl(
    _$PaymentImpl _value,
    $Res Function(_$PaymentImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Payment
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? kind = null,
    Object? method = null,
    Object? status = null,
    Object? amountMinor = null,
    Object? currencyCode = null,
    Object? originalPaymentId = freezed,
    Object? externalReference = freezed,
    Object? note = freezed,
    Object? receivedByMemberId = null,
    Object? receivedByMe = null,
    Object? receivedAt = null,
    Object? voidedByMemberId = freezed,
    Object? voidedAt = freezed,
    Object? voidReason = freezed,
  }) {
    return _then(
      _$PaymentImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        kind: null == kind
            ? _value.kind
            : kind // ignore: cast_nullable_to_non_nullable
                  as PaymentKind,
        method: null == method
            ? _value.method
            : method // ignore: cast_nullable_to_non_nullable
                  as PaymentMethod,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as PaymentRecordStatus,
        amountMinor: null == amountMinor
            ? _value.amountMinor
            : amountMinor // ignore: cast_nullable_to_non_nullable
                  as int,
        currencyCode: null == currencyCode
            ? _value.currencyCode
            : currencyCode // ignore: cast_nullable_to_non_nullable
                  as String,
        originalPaymentId: freezed == originalPaymentId
            ? _value.originalPaymentId
            : originalPaymentId // ignore: cast_nullable_to_non_nullable
                  as String?,
        externalReference: freezed == externalReference
            ? _value.externalReference
            : externalReference // ignore: cast_nullable_to_non_nullable
                  as String?,
        note: freezed == note
            ? _value.note
            : note // ignore: cast_nullable_to_non_nullable
                  as String?,
        receivedByMemberId: null == receivedByMemberId
            ? _value.receivedByMemberId
            : receivedByMemberId // ignore: cast_nullable_to_non_nullable
                  as String,
        receivedByMe: null == receivedByMe
            ? _value.receivedByMe
            : receivedByMe // ignore: cast_nullable_to_non_nullable
                  as bool,
        receivedAt: null == receivedAt
            ? _value.receivedAt
            : receivedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        voidedByMemberId: freezed == voidedByMemberId
            ? _value.voidedByMemberId
            : voidedByMemberId // ignore: cast_nullable_to_non_nullable
                  as String?,
        voidedAt: freezed == voidedAt
            ? _value.voidedAt
            : voidedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        voidReason: freezed == voidReason
            ? _value.voidReason
            : voidReason // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$PaymentImpl extends _Payment {
  const _$PaymentImpl({
    required this.id,
    required this.kind,
    required this.method,
    required this.status,
    required this.amountMinor,
    required this.currencyCode,
    required this.originalPaymentId,
    required this.externalReference,
    required this.note,
    required this.receivedByMemberId,
    required this.receivedByMe,
    required this.receivedAt,
    required this.voidedByMemberId,
    required this.voidedAt,
    required this.voidReason,
  }) : super._();

  @override
  final String id;
  @override
  final PaymentKind kind;
  @override
  final PaymentMethod method;
  @override
  final PaymentRecordStatus status;
  @override
  final int amountMinor;
  @override
  final String currencyCode;
  @override
  final String? originalPaymentId;
  @override
  final String? externalReference;
  @override
  final String? note;
  @override
  final String receivedByMemberId;
  @override
  final bool receivedByMe;
  @override
  final DateTime receivedAt;
  @override
  final String? voidedByMemberId;
  @override
  final DateTime? voidedAt;
  @override
  final String? voidReason;

  @override
  String toString() {
    return 'Payment(id: $id, kind: $kind, method: $method, status: $status, amountMinor: $amountMinor, currencyCode: $currencyCode, originalPaymentId: $originalPaymentId, externalReference: $externalReference, note: $note, receivedByMemberId: $receivedByMemberId, receivedByMe: $receivedByMe, receivedAt: $receivedAt, voidedByMemberId: $voidedByMemberId, voidedAt: $voidedAt, voidReason: $voidReason)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PaymentImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.kind, kind) || other.kind == kind) &&
            (identical(other.method, method) || other.method == method) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.amountMinor, amountMinor) ||
                other.amountMinor == amountMinor) &&
            (identical(other.currencyCode, currencyCode) ||
                other.currencyCode == currencyCode) &&
            (identical(other.originalPaymentId, originalPaymentId) ||
                other.originalPaymentId == originalPaymentId) &&
            (identical(other.externalReference, externalReference) ||
                other.externalReference == externalReference) &&
            (identical(other.note, note) || other.note == note) &&
            (identical(other.receivedByMemberId, receivedByMemberId) ||
                other.receivedByMemberId == receivedByMemberId) &&
            (identical(other.receivedByMe, receivedByMe) ||
                other.receivedByMe == receivedByMe) &&
            (identical(other.receivedAt, receivedAt) ||
                other.receivedAt == receivedAt) &&
            (identical(other.voidedByMemberId, voidedByMemberId) ||
                other.voidedByMemberId == voidedByMemberId) &&
            (identical(other.voidedAt, voidedAt) ||
                other.voidedAt == voidedAt) &&
            (identical(other.voidReason, voidReason) ||
                other.voidReason == voidReason));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    kind,
    method,
    status,
    amountMinor,
    currencyCode,
    originalPaymentId,
    externalReference,
    note,
    receivedByMemberId,
    receivedByMe,
    receivedAt,
    voidedByMemberId,
    voidedAt,
    voidReason,
  );

  /// Create a copy of Payment
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PaymentImplCopyWith<_$PaymentImpl> get copyWith =>
      __$$PaymentImplCopyWithImpl<_$PaymentImpl>(this, _$identity);
}

abstract class _Payment extends Payment {
  const factory _Payment({
    required final String id,
    required final PaymentKind kind,
    required final PaymentMethod method,
    required final PaymentRecordStatus status,
    required final int amountMinor,
    required final String currencyCode,
    required final String? originalPaymentId,
    required final String? externalReference,
    required final String? note,
    required final String receivedByMemberId,
    required final bool receivedByMe,
    required final DateTime receivedAt,
    required final String? voidedByMemberId,
    required final DateTime? voidedAt,
    required final String? voidReason,
  }) = _$PaymentImpl;
  const _Payment._() : super._();

  @override
  String get id;
  @override
  PaymentKind get kind;
  @override
  PaymentMethod get method;
  @override
  PaymentRecordStatus get status;
  @override
  int get amountMinor;
  @override
  String get currencyCode;
  @override
  String? get originalPaymentId;
  @override
  String? get externalReference;
  @override
  String? get note;
  @override
  String get receivedByMemberId;
  @override
  bool get receivedByMe;
  @override
  DateTime get receivedAt;
  @override
  String? get voidedByMemberId;
  @override
  DateTime? get voidedAt;
  @override
  String? get voidReason;

  /// Create a copy of Payment
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PaymentImplCopyWith<_$PaymentImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

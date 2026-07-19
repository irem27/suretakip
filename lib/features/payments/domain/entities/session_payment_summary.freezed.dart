// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_payment_summary.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$SessionPaymentSummary {
  String get sessionId => throw _privateConstructorUsedError;
  Money get sessionTotal => throw _privateConstructorUsedError;
  Money get collected => throw _privateConstructorUsedError;
  Money get refunded => throw _privateConstructorUsedError;
  Money get netPaid => throw _privateConstructorUsedError;
  Money get remaining => throw _privateConstructorUsedError;
  SessionPaymentStatus get paymentStatus => throw _privateConstructorUsedError;
  String get currencyCode => throw _privateConstructorUsedError;
  List<Payment> get payments => throw _privateConstructorUsedError;

  /// Create a copy of SessionPaymentSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SessionPaymentSummaryCopyWith<SessionPaymentSummary> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SessionPaymentSummaryCopyWith<$Res> {
  factory $SessionPaymentSummaryCopyWith(
    SessionPaymentSummary value,
    $Res Function(SessionPaymentSummary) then,
  ) = _$SessionPaymentSummaryCopyWithImpl<$Res, SessionPaymentSummary>;
  @useResult
  $Res call({
    String sessionId,
    Money sessionTotal,
    Money collected,
    Money refunded,
    Money netPaid,
    Money remaining,
    SessionPaymentStatus paymentStatus,
    String currencyCode,
    List<Payment> payments,
  });
}

/// @nodoc
class _$SessionPaymentSummaryCopyWithImpl<
  $Res,
  $Val extends SessionPaymentSummary
>
    implements $SessionPaymentSummaryCopyWith<$Res> {
  _$SessionPaymentSummaryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SessionPaymentSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sessionId = null,
    Object? sessionTotal = null,
    Object? collected = null,
    Object? refunded = null,
    Object? netPaid = null,
    Object? remaining = null,
    Object? paymentStatus = null,
    Object? currencyCode = null,
    Object? payments = null,
  }) {
    return _then(
      _value.copyWith(
            sessionId: null == sessionId
                ? _value.sessionId
                : sessionId // ignore: cast_nullable_to_non_nullable
                      as String,
            sessionTotal: null == sessionTotal
                ? _value.sessionTotal
                : sessionTotal // ignore: cast_nullable_to_non_nullable
                      as Money,
            collected: null == collected
                ? _value.collected
                : collected // ignore: cast_nullable_to_non_nullable
                      as Money,
            refunded: null == refunded
                ? _value.refunded
                : refunded // ignore: cast_nullable_to_non_nullable
                      as Money,
            netPaid: null == netPaid
                ? _value.netPaid
                : netPaid // ignore: cast_nullable_to_non_nullable
                      as Money,
            remaining: null == remaining
                ? _value.remaining
                : remaining // ignore: cast_nullable_to_non_nullable
                      as Money,
            paymentStatus: null == paymentStatus
                ? _value.paymentStatus
                : paymentStatus // ignore: cast_nullable_to_non_nullable
                      as SessionPaymentStatus,
            currencyCode: null == currencyCode
                ? _value.currencyCode
                : currencyCode // ignore: cast_nullable_to_non_nullable
                      as String,
            payments: null == payments
                ? _value.payments
                : payments // ignore: cast_nullable_to_non_nullable
                      as List<Payment>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SessionPaymentSummaryImplCopyWith<$Res>
    implements $SessionPaymentSummaryCopyWith<$Res> {
  factory _$$SessionPaymentSummaryImplCopyWith(
    _$SessionPaymentSummaryImpl value,
    $Res Function(_$SessionPaymentSummaryImpl) then,
  ) = __$$SessionPaymentSummaryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String sessionId,
    Money sessionTotal,
    Money collected,
    Money refunded,
    Money netPaid,
    Money remaining,
    SessionPaymentStatus paymentStatus,
    String currencyCode,
    List<Payment> payments,
  });
}

/// @nodoc
class __$$SessionPaymentSummaryImplCopyWithImpl<$Res>
    extends
        _$SessionPaymentSummaryCopyWithImpl<$Res, _$SessionPaymentSummaryImpl>
    implements _$$SessionPaymentSummaryImplCopyWith<$Res> {
  __$$SessionPaymentSummaryImplCopyWithImpl(
    _$SessionPaymentSummaryImpl _value,
    $Res Function(_$SessionPaymentSummaryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SessionPaymentSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sessionId = null,
    Object? sessionTotal = null,
    Object? collected = null,
    Object? refunded = null,
    Object? netPaid = null,
    Object? remaining = null,
    Object? paymentStatus = null,
    Object? currencyCode = null,
    Object? payments = null,
  }) {
    return _then(
      _$SessionPaymentSummaryImpl(
        sessionId: null == sessionId
            ? _value.sessionId
            : sessionId // ignore: cast_nullable_to_non_nullable
                  as String,
        sessionTotal: null == sessionTotal
            ? _value.sessionTotal
            : sessionTotal // ignore: cast_nullable_to_non_nullable
                  as Money,
        collected: null == collected
            ? _value.collected
            : collected // ignore: cast_nullable_to_non_nullable
                  as Money,
        refunded: null == refunded
            ? _value.refunded
            : refunded // ignore: cast_nullable_to_non_nullable
                  as Money,
        netPaid: null == netPaid
            ? _value.netPaid
            : netPaid // ignore: cast_nullable_to_non_nullable
                  as Money,
        remaining: null == remaining
            ? _value.remaining
            : remaining // ignore: cast_nullable_to_non_nullable
                  as Money,
        paymentStatus: null == paymentStatus
            ? _value.paymentStatus
            : paymentStatus // ignore: cast_nullable_to_non_nullable
                  as SessionPaymentStatus,
        currencyCode: null == currencyCode
            ? _value.currencyCode
            : currencyCode // ignore: cast_nullable_to_non_nullable
                  as String,
        payments: null == payments
            ? _value._payments
            : payments // ignore: cast_nullable_to_non_nullable
                  as List<Payment>,
      ),
    );
  }
}

/// @nodoc

class _$SessionPaymentSummaryImpl implements _SessionPaymentSummary {
  const _$SessionPaymentSummaryImpl({
    required this.sessionId,
    required this.sessionTotal,
    required this.collected,
    required this.refunded,
    required this.netPaid,
    required this.remaining,
    required this.paymentStatus,
    required this.currencyCode,
    required final List<Payment> payments,
  }) : _payments = payments;

  @override
  final String sessionId;
  @override
  final Money sessionTotal;
  @override
  final Money collected;
  @override
  final Money refunded;
  @override
  final Money netPaid;
  @override
  final Money remaining;
  @override
  final SessionPaymentStatus paymentStatus;
  @override
  final String currencyCode;
  final List<Payment> _payments;
  @override
  List<Payment> get payments {
    if (_payments is EqualUnmodifiableListView) return _payments;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_payments);
  }

  @override
  String toString() {
    return 'SessionPaymentSummary(sessionId: $sessionId, sessionTotal: $sessionTotal, collected: $collected, refunded: $refunded, netPaid: $netPaid, remaining: $remaining, paymentStatus: $paymentStatus, currencyCode: $currencyCode, payments: $payments)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SessionPaymentSummaryImpl &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId) &&
            (identical(other.sessionTotal, sessionTotal) ||
                other.sessionTotal == sessionTotal) &&
            (identical(other.collected, collected) ||
                other.collected == collected) &&
            (identical(other.refunded, refunded) ||
                other.refunded == refunded) &&
            (identical(other.netPaid, netPaid) || other.netPaid == netPaid) &&
            (identical(other.remaining, remaining) ||
                other.remaining == remaining) &&
            (identical(other.paymentStatus, paymentStatus) ||
                other.paymentStatus == paymentStatus) &&
            (identical(other.currencyCode, currencyCode) ||
                other.currencyCode == currencyCode) &&
            const DeepCollectionEquality().equals(other._payments, _payments));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    sessionId,
    sessionTotal,
    collected,
    refunded,
    netPaid,
    remaining,
    paymentStatus,
    currencyCode,
    const DeepCollectionEquality().hash(_payments),
  );

  /// Create a copy of SessionPaymentSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SessionPaymentSummaryImplCopyWith<_$SessionPaymentSummaryImpl>
  get copyWith =>
      __$$SessionPaymentSummaryImplCopyWithImpl<_$SessionPaymentSummaryImpl>(
        this,
        _$identity,
      );
}

abstract class _SessionPaymentSummary implements SessionPaymentSummary {
  const factory _SessionPaymentSummary({
    required final String sessionId,
    required final Money sessionTotal,
    required final Money collected,
    required final Money refunded,
    required final Money netPaid,
    required final Money remaining,
    required final SessionPaymentStatus paymentStatus,
    required final String currencyCode,
    required final List<Payment> payments,
  }) = _$SessionPaymentSummaryImpl;

  @override
  String get sessionId;
  @override
  Money get sessionTotal;
  @override
  Money get collected;
  @override
  Money get refunded;
  @override
  Money get netPaid;
  @override
  Money get remaining;
  @override
  SessionPaymentStatus get paymentStatus;
  @override
  String get currencyCode;
  @override
  List<Payment> get payments;

  /// Create a copy of SessionPaymentSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SessionPaymentSummaryImplCopyWith<_$SessionPaymentSummaryImpl>
  get copyWith => throw _privateConstructorUsedError;
}

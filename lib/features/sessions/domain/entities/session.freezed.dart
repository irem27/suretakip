// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$Session {
  String get id => throw _privateConstructorUsedError;
  String get businessId => throw _privateConstructorUsedError;
  String? get customerId => throw _privateConstructorUsedError;
  String get serviceId => throw _privateConstructorUsedError;
  String get openedByMemberId => throw _privateConstructorUsedError;
  String? get closedByMemberId => throw _privateConstructorUsedError;
  SessionStatus get status => throw _privateConstructorUsedError;
  DateTime get startedAt => throw _privateConstructorUsedError;
  DateTime? get endedAt => throw _privateConstructorUsedError;
  int? get chargedMinutes => throw _privateConstructorUsedError;
  String get serviceNameSnapshot => throw _privateConstructorUsedError;
  int get pricePerMinuteMinorSnapshot => throw _privateConstructorUsedError;
  int get roundingIntervalMinutesSnapshot => throw _privateConstructorUsedError;
  int get minimumChargeMinutesSnapshot => throw _privateConstructorUsedError;
  String get currencyCodeSnapshot => throw _privateConstructorUsedError;
  int? get serviceSubtotalMinor => throw _privateConstructorUsedError;
  int? get productsSubtotalMinor => throw _privateConstructorUsedError;
  int get discountMinor => throw _privateConstructorUsedError;
  int get taxMinor => throw _privateConstructorUsedError;
  int? get grandTotalMinor => throw _privateConstructorUsedError;
  String? get notes => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;

  /// Create a copy of Session
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SessionCopyWith<Session> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SessionCopyWith<$Res> {
  factory $SessionCopyWith(Session value, $Res Function(Session) then) =
      _$SessionCopyWithImpl<$Res, Session>;
  @useResult
  $Res call({
    String id,
    String businessId,
    String? customerId,
    String serviceId,
    String openedByMemberId,
    String? closedByMemberId,
    SessionStatus status,
    DateTime startedAt,
    DateTime? endedAt,
    int? chargedMinutes,
    String serviceNameSnapshot,
    int pricePerMinuteMinorSnapshot,
    int roundingIntervalMinutesSnapshot,
    int minimumChargeMinutesSnapshot,
    String currencyCodeSnapshot,
    int? serviceSubtotalMinor,
    int? productsSubtotalMinor,
    int discountMinor,
    int taxMinor,
    int? grandTotalMinor,
    String? notes,
    DateTime createdAt,
    DateTime updatedAt,
  });
}

/// @nodoc
class _$SessionCopyWithImpl<$Res, $Val extends Session>
    implements $SessionCopyWith<$Res> {
  _$SessionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Session
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? businessId = null,
    Object? customerId = freezed,
    Object? serviceId = null,
    Object? openedByMemberId = null,
    Object? closedByMemberId = freezed,
    Object? status = null,
    Object? startedAt = null,
    Object? endedAt = freezed,
    Object? chargedMinutes = freezed,
    Object? serviceNameSnapshot = null,
    Object? pricePerMinuteMinorSnapshot = null,
    Object? roundingIntervalMinutesSnapshot = null,
    Object? minimumChargeMinutesSnapshot = null,
    Object? currencyCodeSnapshot = null,
    Object? serviceSubtotalMinor = freezed,
    Object? productsSubtotalMinor = freezed,
    Object? discountMinor = null,
    Object? taxMinor = null,
    Object? grandTotalMinor = freezed,
    Object? notes = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            businessId: null == businessId
                ? _value.businessId
                : businessId // ignore: cast_nullable_to_non_nullable
                      as String,
            customerId: freezed == customerId
                ? _value.customerId
                : customerId // ignore: cast_nullable_to_non_nullable
                      as String?,
            serviceId: null == serviceId
                ? _value.serviceId
                : serviceId // ignore: cast_nullable_to_non_nullable
                      as String,
            openedByMemberId: null == openedByMemberId
                ? _value.openedByMemberId
                : openedByMemberId // ignore: cast_nullable_to_non_nullable
                      as String,
            closedByMemberId: freezed == closedByMemberId
                ? _value.closedByMemberId
                : closedByMemberId // ignore: cast_nullable_to_non_nullable
                      as String?,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as SessionStatus,
            startedAt: null == startedAt
                ? _value.startedAt
                : startedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            endedAt: freezed == endedAt
                ? _value.endedAt
                : endedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            chargedMinutes: freezed == chargedMinutes
                ? _value.chargedMinutes
                : chargedMinutes // ignore: cast_nullable_to_non_nullable
                      as int?,
            serviceNameSnapshot: null == serviceNameSnapshot
                ? _value.serviceNameSnapshot
                : serviceNameSnapshot // ignore: cast_nullable_to_non_nullable
                      as String,
            pricePerMinuteMinorSnapshot: null == pricePerMinuteMinorSnapshot
                ? _value.pricePerMinuteMinorSnapshot
                : pricePerMinuteMinorSnapshot // ignore: cast_nullable_to_non_nullable
                      as int,
            roundingIntervalMinutesSnapshot:
                null == roundingIntervalMinutesSnapshot
                ? _value.roundingIntervalMinutesSnapshot
                : roundingIntervalMinutesSnapshot // ignore: cast_nullable_to_non_nullable
                      as int,
            minimumChargeMinutesSnapshot: null == minimumChargeMinutesSnapshot
                ? _value.minimumChargeMinutesSnapshot
                : minimumChargeMinutesSnapshot // ignore: cast_nullable_to_non_nullable
                      as int,
            currencyCodeSnapshot: null == currencyCodeSnapshot
                ? _value.currencyCodeSnapshot
                : currencyCodeSnapshot // ignore: cast_nullable_to_non_nullable
                      as String,
            serviceSubtotalMinor: freezed == serviceSubtotalMinor
                ? _value.serviceSubtotalMinor
                : serviceSubtotalMinor // ignore: cast_nullable_to_non_nullable
                      as int?,
            productsSubtotalMinor: freezed == productsSubtotalMinor
                ? _value.productsSubtotalMinor
                : productsSubtotalMinor // ignore: cast_nullable_to_non_nullable
                      as int?,
            discountMinor: null == discountMinor
                ? _value.discountMinor
                : discountMinor // ignore: cast_nullable_to_non_nullable
                      as int,
            taxMinor: null == taxMinor
                ? _value.taxMinor
                : taxMinor // ignore: cast_nullable_to_non_nullable
                      as int,
            grandTotalMinor: freezed == grandTotalMinor
                ? _value.grandTotalMinor
                : grandTotalMinor // ignore: cast_nullable_to_non_nullable
                      as int?,
            notes: freezed == notes
                ? _value.notes
                : notes // ignore: cast_nullable_to_non_nullable
                      as String?,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            updatedAt: null == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SessionImplCopyWith<$Res> implements $SessionCopyWith<$Res> {
  factory _$$SessionImplCopyWith(
    _$SessionImpl value,
    $Res Function(_$SessionImpl) then,
  ) = __$$SessionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String businessId,
    String? customerId,
    String serviceId,
    String openedByMemberId,
    String? closedByMemberId,
    SessionStatus status,
    DateTime startedAt,
    DateTime? endedAt,
    int? chargedMinutes,
    String serviceNameSnapshot,
    int pricePerMinuteMinorSnapshot,
    int roundingIntervalMinutesSnapshot,
    int minimumChargeMinutesSnapshot,
    String currencyCodeSnapshot,
    int? serviceSubtotalMinor,
    int? productsSubtotalMinor,
    int discountMinor,
    int taxMinor,
    int? grandTotalMinor,
    String? notes,
    DateTime createdAt,
    DateTime updatedAt,
  });
}

/// @nodoc
class __$$SessionImplCopyWithImpl<$Res>
    extends _$SessionCopyWithImpl<$Res, _$SessionImpl>
    implements _$$SessionImplCopyWith<$Res> {
  __$$SessionImplCopyWithImpl(
    _$SessionImpl _value,
    $Res Function(_$SessionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Session
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? businessId = null,
    Object? customerId = freezed,
    Object? serviceId = null,
    Object? openedByMemberId = null,
    Object? closedByMemberId = freezed,
    Object? status = null,
    Object? startedAt = null,
    Object? endedAt = freezed,
    Object? chargedMinutes = freezed,
    Object? serviceNameSnapshot = null,
    Object? pricePerMinuteMinorSnapshot = null,
    Object? roundingIntervalMinutesSnapshot = null,
    Object? minimumChargeMinutesSnapshot = null,
    Object? currencyCodeSnapshot = null,
    Object? serviceSubtotalMinor = freezed,
    Object? productsSubtotalMinor = freezed,
    Object? discountMinor = null,
    Object? taxMinor = null,
    Object? grandTotalMinor = freezed,
    Object? notes = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _$SessionImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        businessId: null == businessId
            ? _value.businessId
            : businessId // ignore: cast_nullable_to_non_nullable
                  as String,
        customerId: freezed == customerId
            ? _value.customerId
            : customerId // ignore: cast_nullable_to_non_nullable
                  as String?,
        serviceId: null == serviceId
            ? _value.serviceId
            : serviceId // ignore: cast_nullable_to_non_nullable
                  as String,
        openedByMemberId: null == openedByMemberId
            ? _value.openedByMemberId
            : openedByMemberId // ignore: cast_nullable_to_non_nullable
                  as String,
        closedByMemberId: freezed == closedByMemberId
            ? _value.closedByMemberId
            : closedByMemberId // ignore: cast_nullable_to_non_nullable
                  as String?,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as SessionStatus,
        startedAt: null == startedAt
            ? _value.startedAt
            : startedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        endedAt: freezed == endedAt
            ? _value.endedAt
            : endedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        chargedMinutes: freezed == chargedMinutes
            ? _value.chargedMinutes
            : chargedMinutes // ignore: cast_nullable_to_non_nullable
                  as int?,
        serviceNameSnapshot: null == serviceNameSnapshot
            ? _value.serviceNameSnapshot
            : serviceNameSnapshot // ignore: cast_nullable_to_non_nullable
                  as String,
        pricePerMinuteMinorSnapshot: null == pricePerMinuteMinorSnapshot
            ? _value.pricePerMinuteMinorSnapshot
            : pricePerMinuteMinorSnapshot // ignore: cast_nullable_to_non_nullable
                  as int,
        roundingIntervalMinutesSnapshot: null == roundingIntervalMinutesSnapshot
            ? _value.roundingIntervalMinutesSnapshot
            : roundingIntervalMinutesSnapshot // ignore: cast_nullable_to_non_nullable
                  as int,
        minimumChargeMinutesSnapshot: null == minimumChargeMinutesSnapshot
            ? _value.minimumChargeMinutesSnapshot
            : minimumChargeMinutesSnapshot // ignore: cast_nullable_to_non_nullable
                  as int,
        currencyCodeSnapshot: null == currencyCodeSnapshot
            ? _value.currencyCodeSnapshot
            : currencyCodeSnapshot // ignore: cast_nullable_to_non_nullable
                  as String,
        serviceSubtotalMinor: freezed == serviceSubtotalMinor
            ? _value.serviceSubtotalMinor
            : serviceSubtotalMinor // ignore: cast_nullable_to_non_nullable
                  as int?,
        productsSubtotalMinor: freezed == productsSubtotalMinor
            ? _value.productsSubtotalMinor
            : productsSubtotalMinor // ignore: cast_nullable_to_non_nullable
                  as int?,
        discountMinor: null == discountMinor
            ? _value.discountMinor
            : discountMinor // ignore: cast_nullable_to_non_nullable
                  as int,
        taxMinor: null == taxMinor
            ? _value.taxMinor
            : taxMinor // ignore: cast_nullable_to_non_nullable
                  as int,
        grandTotalMinor: freezed == grandTotalMinor
            ? _value.grandTotalMinor
            : grandTotalMinor // ignore: cast_nullable_to_non_nullable
                  as int?,
        notes: freezed == notes
            ? _value.notes
            : notes // ignore: cast_nullable_to_non_nullable
                  as String?,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        updatedAt: null == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc

class _$SessionImpl implements _Session {
  const _$SessionImpl({
    required this.id,
    required this.businessId,
    required this.customerId,
    required this.serviceId,
    required this.openedByMemberId,
    required this.closedByMemberId,
    required this.status,
    required this.startedAt,
    required this.endedAt,
    required this.chargedMinutes,
    required this.serviceNameSnapshot,
    required this.pricePerMinuteMinorSnapshot,
    required this.roundingIntervalMinutesSnapshot,
    required this.minimumChargeMinutesSnapshot,
    required this.currencyCodeSnapshot,
    required this.serviceSubtotalMinor,
    required this.productsSubtotalMinor,
    required this.discountMinor,
    required this.taxMinor,
    required this.grandTotalMinor,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  final String id;
  @override
  final String businessId;
  @override
  final String? customerId;
  @override
  final String serviceId;
  @override
  final String openedByMemberId;
  @override
  final String? closedByMemberId;
  @override
  final SessionStatus status;
  @override
  final DateTime startedAt;
  @override
  final DateTime? endedAt;
  @override
  final int? chargedMinutes;
  @override
  final String serviceNameSnapshot;
  @override
  final int pricePerMinuteMinorSnapshot;
  @override
  final int roundingIntervalMinutesSnapshot;
  @override
  final int minimumChargeMinutesSnapshot;
  @override
  final String currencyCodeSnapshot;
  @override
  final int? serviceSubtotalMinor;
  @override
  final int? productsSubtotalMinor;
  @override
  final int discountMinor;
  @override
  final int taxMinor;
  @override
  final int? grandTotalMinor;
  @override
  final String? notes;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  @override
  String toString() {
    return 'Session(id: $id, businessId: $businessId, customerId: $customerId, serviceId: $serviceId, openedByMemberId: $openedByMemberId, closedByMemberId: $closedByMemberId, status: $status, startedAt: $startedAt, endedAt: $endedAt, chargedMinutes: $chargedMinutes, serviceNameSnapshot: $serviceNameSnapshot, pricePerMinuteMinorSnapshot: $pricePerMinuteMinorSnapshot, roundingIntervalMinutesSnapshot: $roundingIntervalMinutesSnapshot, minimumChargeMinutesSnapshot: $minimumChargeMinutesSnapshot, currencyCodeSnapshot: $currencyCodeSnapshot, serviceSubtotalMinor: $serviceSubtotalMinor, productsSubtotalMinor: $productsSubtotalMinor, discountMinor: $discountMinor, taxMinor: $taxMinor, grandTotalMinor: $grandTotalMinor, notes: $notes, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SessionImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.businessId, businessId) ||
                other.businessId == businessId) &&
            (identical(other.customerId, customerId) ||
                other.customerId == customerId) &&
            (identical(other.serviceId, serviceId) ||
                other.serviceId == serviceId) &&
            (identical(other.openedByMemberId, openedByMemberId) ||
                other.openedByMemberId == openedByMemberId) &&
            (identical(other.closedByMemberId, closedByMemberId) ||
                other.closedByMemberId == closedByMemberId) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.startedAt, startedAt) ||
                other.startedAt == startedAt) &&
            (identical(other.endedAt, endedAt) || other.endedAt == endedAt) &&
            (identical(other.chargedMinutes, chargedMinutes) ||
                other.chargedMinutes == chargedMinutes) &&
            (identical(other.serviceNameSnapshot, serviceNameSnapshot) ||
                other.serviceNameSnapshot == serviceNameSnapshot) &&
            (identical(
                  other.pricePerMinuteMinorSnapshot,
                  pricePerMinuteMinorSnapshot,
                ) ||
                other.pricePerMinuteMinorSnapshot ==
                    pricePerMinuteMinorSnapshot) &&
            (identical(
                  other.roundingIntervalMinutesSnapshot,
                  roundingIntervalMinutesSnapshot,
                ) ||
                other.roundingIntervalMinutesSnapshot ==
                    roundingIntervalMinutesSnapshot) &&
            (identical(
                  other.minimumChargeMinutesSnapshot,
                  minimumChargeMinutesSnapshot,
                ) ||
                other.minimumChargeMinutesSnapshot ==
                    minimumChargeMinutesSnapshot) &&
            (identical(other.currencyCodeSnapshot, currencyCodeSnapshot) ||
                other.currencyCodeSnapshot == currencyCodeSnapshot) &&
            (identical(other.serviceSubtotalMinor, serviceSubtotalMinor) ||
                other.serviceSubtotalMinor == serviceSubtotalMinor) &&
            (identical(other.productsSubtotalMinor, productsSubtotalMinor) ||
                other.productsSubtotalMinor == productsSubtotalMinor) &&
            (identical(other.discountMinor, discountMinor) ||
                other.discountMinor == discountMinor) &&
            (identical(other.taxMinor, taxMinor) ||
                other.taxMinor == taxMinor) &&
            (identical(other.grandTotalMinor, grandTotalMinor) ||
                other.grandTotalMinor == grandTotalMinor) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    businessId,
    customerId,
    serviceId,
    openedByMemberId,
    closedByMemberId,
    status,
    startedAt,
    endedAt,
    chargedMinutes,
    serviceNameSnapshot,
    pricePerMinuteMinorSnapshot,
    roundingIntervalMinutesSnapshot,
    minimumChargeMinutesSnapshot,
    currencyCodeSnapshot,
    serviceSubtotalMinor,
    productsSubtotalMinor,
    discountMinor,
    taxMinor,
    grandTotalMinor,
    notes,
    createdAt,
    updatedAt,
  ]);

  /// Create a copy of Session
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SessionImplCopyWith<_$SessionImpl> get copyWith =>
      __$$SessionImplCopyWithImpl<_$SessionImpl>(this, _$identity);
}

abstract class _Session implements Session {
  const factory _Session({
    required final String id,
    required final String businessId,
    required final String? customerId,
    required final String serviceId,
    required final String openedByMemberId,
    required final String? closedByMemberId,
    required final SessionStatus status,
    required final DateTime startedAt,
    required final DateTime? endedAt,
    required final int? chargedMinutes,
    required final String serviceNameSnapshot,
    required final int pricePerMinuteMinorSnapshot,
    required final int roundingIntervalMinutesSnapshot,
    required final int minimumChargeMinutesSnapshot,
    required final String currencyCodeSnapshot,
    required final int? serviceSubtotalMinor,
    required final int? productsSubtotalMinor,
    required final int discountMinor,
    required final int taxMinor,
    required final int? grandTotalMinor,
    required final String? notes,
    required final DateTime createdAt,
    required final DateTime updatedAt,
  }) = _$SessionImpl;

  @override
  String get id;
  @override
  String get businessId;
  @override
  String? get customerId;
  @override
  String get serviceId;
  @override
  String get openedByMemberId;
  @override
  String? get closedByMemberId;
  @override
  SessionStatus get status;
  @override
  DateTime get startedAt;
  @override
  DateTime? get endedAt;
  @override
  int? get chargedMinutes;
  @override
  String get serviceNameSnapshot;
  @override
  int get pricePerMinuteMinorSnapshot;
  @override
  int get roundingIntervalMinutesSnapshot;
  @override
  int get minimumChargeMinutesSnapshot;
  @override
  String get currencyCodeSnapshot;
  @override
  int? get serviceSubtotalMinor;
  @override
  int? get productsSubtotalMinor;
  @override
  int get discountMinor;
  @override
  int get taxMinor;
  @override
  int? get grandTotalMinor;
  @override
  String? get notes;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;

  /// Create a copy of Session
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SessionImplCopyWith<_$SessionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

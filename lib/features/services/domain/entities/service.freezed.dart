// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'service.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$Service {
  String get id => throw _privateConstructorUsedError;
  String get businessId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  int get pricePerMinuteMinor => throw _privateConstructorUsedError;
  int get roundingIntervalMinutes => throw _privateConstructorUsedError;
  int get minimumChargeMinutes => throw _privateConstructorUsedError;
  String get currencyCode => throw _privateConstructorUsedError;
  bool get isActive => throw _privateConstructorUsedError;
  DateTime? get archivedAt => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;

  /// Create a copy of Service
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ServiceCopyWith<Service> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ServiceCopyWith<$Res> {
  factory $ServiceCopyWith(Service value, $Res Function(Service) then) =
      _$ServiceCopyWithImpl<$Res, Service>;
  @useResult
  $Res call({
    String id,
    String businessId,
    String name,
    int pricePerMinuteMinor,
    int roundingIntervalMinutes,
    int minimumChargeMinutes,
    String currencyCode,
    bool isActive,
    DateTime? archivedAt,
    DateTime createdAt,
    DateTime updatedAt,
  });
}

/// @nodoc
class _$ServiceCopyWithImpl<$Res, $Val extends Service>
    implements $ServiceCopyWith<$Res> {
  _$ServiceCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Service
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? businessId = null,
    Object? name = null,
    Object? pricePerMinuteMinor = null,
    Object? roundingIntervalMinutes = null,
    Object? minimumChargeMinutes = null,
    Object? currencyCode = null,
    Object? isActive = null,
    Object? archivedAt = freezed,
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
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            pricePerMinuteMinor: null == pricePerMinuteMinor
                ? _value.pricePerMinuteMinor
                : pricePerMinuteMinor // ignore: cast_nullable_to_non_nullable
                      as int,
            roundingIntervalMinutes: null == roundingIntervalMinutes
                ? _value.roundingIntervalMinutes
                : roundingIntervalMinutes // ignore: cast_nullable_to_non_nullable
                      as int,
            minimumChargeMinutes: null == minimumChargeMinutes
                ? _value.minimumChargeMinutes
                : minimumChargeMinutes // ignore: cast_nullable_to_non_nullable
                      as int,
            currencyCode: null == currencyCode
                ? _value.currencyCode
                : currencyCode // ignore: cast_nullable_to_non_nullable
                      as String,
            isActive: null == isActive
                ? _value.isActive
                : isActive // ignore: cast_nullable_to_non_nullable
                      as bool,
            archivedAt: freezed == archivedAt
                ? _value.archivedAt
                : archivedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
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
abstract class _$$ServiceImplCopyWith<$Res> implements $ServiceCopyWith<$Res> {
  factory _$$ServiceImplCopyWith(
    _$ServiceImpl value,
    $Res Function(_$ServiceImpl) then,
  ) = __$$ServiceImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String businessId,
    String name,
    int pricePerMinuteMinor,
    int roundingIntervalMinutes,
    int minimumChargeMinutes,
    String currencyCode,
    bool isActive,
    DateTime? archivedAt,
    DateTime createdAt,
    DateTime updatedAt,
  });
}

/// @nodoc
class __$$ServiceImplCopyWithImpl<$Res>
    extends _$ServiceCopyWithImpl<$Res, _$ServiceImpl>
    implements _$$ServiceImplCopyWith<$Res> {
  __$$ServiceImplCopyWithImpl(
    _$ServiceImpl _value,
    $Res Function(_$ServiceImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Service
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? businessId = null,
    Object? name = null,
    Object? pricePerMinuteMinor = null,
    Object? roundingIntervalMinutes = null,
    Object? minimumChargeMinutes = null,
    Object? currencyCode = null,
    Object? isActive = null,
    Object? archivedAt = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _$ServiceImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        businessId: null == businessId
            ? _value.businessId
            : businessId // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        pricePerMinuteMinor: null == pricePerMinuteMinor
            ? _value.pricePerMinuteMinor
            : pricePerMinuteMinor // ignore: cast_nullable_to_non_nullable
                  as int,
        roundingIntervalMinutes: null == roundingIntervalMinutes
            ? _value.roundingIntervalMinutes
            : roundingIntervalMinutes // ignore: cast_nullable_to_non_nullable
                  as int,
        minimumChargeMinutes: null == minimumChargeMinutes
            ? _value.minimumChargeMinutes
            : minimumChargeMinutes // ignore: cast_nullable_to_non_nullable
                  as int,
        currencyCode: null == currencyCode
            ? _value.currencyCode
            : currencyCode // ignore: cast_nullable_to_non_nullable
                  as String,
        isActive: null == isActive
            ? _value.isActive
            : isActive // ignore: cast_nullable_to_non_nullable
                  as bool,
        archivedAt: freezed == archivedAt
            ? _value.archivedAt
            : archivedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
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

class _$ServiceImpl implements _Service {
  const _$ServiceImpl({
    required this.id,
    required this.businessId,
    required this.name,
    required this.pricePerMinuteMinor,
    required this.roundingIntervalMinutes,
    required this.minimumChargeMinutes,
    required this.currencyCode,
    required this.isActive,
    required this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  final String id;
  @override
  final String businessId;
  @override
  final String name;
  @override
  final int pricePerMinuteMinor;
  @override
  final int roundingIntervalMinutes;
  @override
  final int minimumChargeMinutes;
  @override
  final String currencyCode;
  @override
  final bool isActive;
  @override
  final DateTime? archivedAt;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  @override
  String toString() {
    return 'Service(id: $id, businessId: $businessId, name: $name, pricePerMinuteMinor: $pricePerMinuteMinor, roundingIntervalMinutes: $roundingIntervalMinutes, minimumChargeMinutes: $minimumChargeMinutes, currencyCode: $currencyCode, isActive: $isActive, archivedAt: $archivedAt, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ServiceImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.businessId, businessId) ||
                other.businessId == businessId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.pricePerMinuteMinor, pricePerMinuteMinor) ||
                other.pricePerMinuteMinor == pricePerMinuteMinor) &&
            (identical(
                  other.roundingIntervalMinutes,
                  roundingIntervalMinutes,
                ) ||
                other.roundingIntervalMinutes == roundingIntervalMinutes) &&
            (identical(other.minimumChargeMinutes, minimumChargeMinutes) ||
                other.minimumChargeMinutes == minimumChargeMinutes) &&
            (identical(other.currencyCode, currencyCode) ||
                other.currencyCode == currencyCode) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.archivedAt, archivedAt) ||
                other.archivedAt == archivedAt) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    businessId,
    name,
    pricePerMinuteMinor,
    roundingIntervalMinutes,
    minimumChargeMinutes,
    currencyCode,
    isActive,
    archivedAt,
    createdAt,
    updatedAt,
  );

  /// Create a copy of Service
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ServiceImplCopyWith<_$ServiceImpl> get copyWith =>
      __$$ServiceImplCopyWithImpl<_$ServiceImpl>(this, _$identity);
}

abstract class _Service implements Service {
  const factory _Service({
    required final String id,
    required final String businessId,
    required final String name,
    required final int pricePerMinuteMinor,
    required final int roundingIntervalMinutes,
    required final int minimumChargeMinutes,
    required final String currencyCode,
    required final bool isActive,
    required final DateTime? archivedAt,
    required final DateTime createdAt,
    required final DateTime updatedAt,
  }) = _$ServiceImpl;

  @override
  String get id;
  @override
  String get businessId;
  @override
  String get name;
  @override
  int get pricePerMinuteMinor;
  @override
  int get roundingIntervalMinutes;
  @override
  int get minimumChargeMinutes;
  @override
  String get currencyCode;
  @override
  bool get isActive;
  @override
  DateTime? get archivedAt;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;

  /// Create a copy of Service
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ServiceImplCopyWith<_$ServiceImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

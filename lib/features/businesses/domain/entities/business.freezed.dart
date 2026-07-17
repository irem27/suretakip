// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'business.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$Business {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get currencyCode => throw _privateConstructorUsedError;
  String get timezone => throw _privateConstructorUsedError;
  bool get isActive => throw _privateConstructorUsedError;
  DateTime? get archivedAt => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;

  /// Create a copy of Business
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BusinessCopyWith<Business> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BusinessCopyWith<$Res> {
  factory $BusinessCopyWith(Business value, $Res Function(Business) then) =
      _$BusinessCopyWithImpl<$Res, Business>;
  @useResult
  $Res call({
    String id,
    String name,
    String currencyCode,
    String timezone,
    bool isActive,
    DateTime? archivedAt,
    DateTime createdAt,
    DateTime updatedAt,
  });
}

/// @nodoc
class _$BusinessCopyWithImpl<$Res, $Val extends Business>
    implements $BusinessCopyWith<$Res> {
  _$BusinessCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Business
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? currencyCode = null,
    Object? timezone = null,
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
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            currencyCode: null == currencyCode
                ? _value.currencyCode
                : currencyCode // ignore: cast_nullable_to_non_nullable
                      as String,
            timezone: null == timezone
                ? _value.timezone
                : timezone // ignore: cast_nullable_to_non_nullable
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
abstract class _$$BusinessImplCopyWith<$Res>
    implements $BusinessCopyWith<$Res> {
  factory _$$BusinessImplCopyWith(
    _$BusinessImpl value,
    $Res Function(_$BusinessImpl) then,
  ) = __$$BusinessImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    String currencyCode,
    String timezone,
    bool isActive,
    DateTime? archivedAt,
    DateTime createdAt,
    DateTime updatedAt,
  });
}

/// @nodoc
class __$$BusinessImplCopyWithImpl<$Res>
    extends _$BusinessCopyWithImpl<$Res, _$BusinessImpl>
    implements _$$BusinessImplCopyWith<$Res> {
  __$$BusinessImplCopyWithImpl(
    _$BusinessImpl _value,
    $Res Function(_$BusinessImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Business
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? currencyCode = null,
    Object? timezone = null,
    Object? isActive = null,
    Object? archivedAt = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _$BusinessImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        currencyCode: null == currencyCode
            ? _value.currencyCode
            : currencyCode // ignore: cast_nullable_to_non_nullable
                  as String,
        timezone: null == timezone
            ? _value.timezone
            : timezone // ignore: cast_nullable_to_non_nullable
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

class _$BusinessImpl implements _Business {
  const _$BusinessImpl({
    required this.id,
    required this.name,
    required this.currencyCode,
    required this.timezone,
    required this.isActive,
    required this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  final String id;
  @override
  final String name;
  @override
  final String currencyCode;
  @override
  final String timezone;
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
    return 'Business(id: $id, name: $name, currencyCode: $currencyCode, timezone: $timezone, isActive: $isActive, archivedAt: $archivedAt, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BusinessImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.currencyCode, currencyCode) ||
                other.currencyCode == currencyCode) &&
            (identical(other.timezone, timezone) ||
                other.timezone == timezone) &&
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
    name,
    currencyCode,
    timezone,
    isActive,
    archivedAt,
    createdAt,
    updatedAt,
  );

  /// Create a copy of Business
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BusinessImplCopyWith<_$BusinessImpl> get copyWith =>
      __$$BusinessImplCopyWithImpl<_$BusinessImpl>(this, _$identity);
}

abstract class _Business implements Business {
  const factory _Business({
    required final String id,
    required final String name,
    required final String currencyCode,
    required final String timezone,
    required final bool isActive,
    required final DateTime? archivedAt,
    required final DateTime createdAt,
    required final DateTime updatedAt,
  }) = _$BusinessImpl;

  @override
  String get id;
  @override
  String get name;
  @override
  String get currencyCode;
  @override
  String get timezone;
  @override
  bool get isActive;
  @override
  DateTime? get archivedAt;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;

  /// Create a copy of Business
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BusinessImplCopyWith<_$BusinessImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

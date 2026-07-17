// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_time_entry.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$SessionTimeEntry {
  String get id => throw _privateConstructorUsedError;
  String get businessId => throw _privateConstructorUsedError;
  String get sessionId => throw _privateConstructorUsedError;
  TimeEntryType get entryType => throw _privateConstructorUsedError;
  DateTime get startedAt => throw _privateConstructorUsedError;
  DateTime? get endedAt => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// Create a copy of SessionTimeEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SessionTimeEntryCopyWith<SessionTimeEntry> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SessionTimeEntryCopyWith<$Res> {
  factory $SessionTimeEntryCopyWith(
    SessionTimeEntry value,
    $Res Function(SessionTimeEntry) then,
  ) = _$SessionTimeEntryCopyWithImpl<$Res, SessionTimeEntry>;
  @useResult
  $Res call({
    String id,
    String businessId,
    String sessionId,
    TimeEntryType entryType,
    DateTime startedAt,
    DateTime? endedAt,
    DateTime createdAt,
  });
}

/// @nodoc
class _$SessionTimeEntryCopyWithImpl<$Res, $Val extends SessionTimeEntry>
    implements $SessionTimeEntryCopyWith<$Res> {
  _$SessionTimeEntryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SessionTimeEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? businessId = null,
    Object? sessionId = null,
    Object? entryType = null,
    Object? startedAt = null,
    Object? endedAt = freezed,
    Object? createdAt = null,
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
            sessionId: null == sessionId
                ? _value.sessionId
                : sessionId // ignore: cast_nullable_to_non_nullable
                      as String,
            entryType: null == entryType
                ? _value.entryType
                : entryType // ignore: cast_nullable_to_non_nullable
                      as TimeEntryType,
            startedAt: null == startedAt
                ? _value.startedAt
                : startedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            endedAt: freezed == endedAt
                ? _value.endedAt
                : endedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SessionTimeEntryImplCopyWith<$Res>
    implements $SessionTimeEntryCopyWith<$Res> {
  factory _$$SessionTimeEntryImplCopyWith(
    _$SessionTimeEntryImpl value,
    $Res Function(_$SessionTimeEntryImpl) then,
  ) = __$$SessionTimeEntryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String businessId,
    String sessionId,
    TimeEntryType entryType,
    DateTime startedAt,
    DateTime? endedAt,
    DateTime createdAt,
  });
}

/// @nodoc
class __$$SessionTimeEntryImplCopyWithImpl<$Res>
    extends _$SessionTimeEntryCopyWithImpl<$Res, _$SessionTimeEntryImpl>
    implements _$$SessionTimeEntryImplCopyWith<$Res> {
  __$$SessionTimeEntryImplCopyWithImpl(
    _$SessionTimeEntryImpl _value,
    $Res Function(_$SessionTimeEntryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SessionTimeEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? businessId = null,
    Object? sessionId = null,
    Object? entryType = null,
    Object? startedAt = null,
    Object? endedAt = freezed,
    Object? createdAt = null,
  }) {
    return _then(
      _$SessionTimeEntryImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        businessId: null == businessId
            ? _value.businessId
            : businessId // ignore: cast_nullable_to_non_nullable
                  as String,
        sessionId: null == sessionId
            ? _value.sessionId
            : sessionId // ignore: cast_nullable_to_non_nullable
                  as String,
        entryType: null == entryType
            ? _value.entryType
            : entryType // ignore: cast_nullable_to_non_nullable
                  as TimeEntryType,
        startedAt: null == startedAt
            ? _value.startedAt
            : startedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        endedAt: freezed == endedAt
            ? _value.endedAt
            : endedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc

class _$SessionTimeEntryImpl implements _SessionTimeEntry {
  const _$SessionTimeEntryImpl({
    required this.id,
    required this.businessId,
    required this.sessionId,
    required this.entryType,
    required this.startedAt,
    required this.endedAt,
    required this.createdAt,
  });

  @override
  final String id;
  @override
  final String businessId;
  @override
  final String sessionId;
  @override
  final TimeEntryType entryType;
  @override
  final DateTime startedAt;
  @override
  final DateTime? endedAt;
  @override
  final DateTime createdAt;

  @override
  String toString() {
    return 'SessionTimeEntry(id: $id, businessId: $businessId, sessionId: $sessionId, entryType: $entryType, startedAt: $startedAt, endedAt: $endedAt, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SessionTimeEntryImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.businessId, businessId) ||
                other.businessId == businessId) &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId) &&
            (identical(other.entryType, entryType) ||
                other.entryType == entryType) &&
            (identical(other.startedAt, startedAt) ||
                other.startedAt == startedAt) &&
            (identical(other.endedAt, endedAt) || other.endedAt == endedAt) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    businessId,
    sessionId,
    entryType,
    startedAt,
    endedAt,
    createdAt,
  );

  /// Create a copy of SessionTimeEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SessionTimeEntryImplCopyWith<_$SessionTimeEntryImpl> get copyWith =>
      __$$SessionTimeEntryImplCopyWithImpl<_$SessionTimeEntryImpl>(
        this,
        _$identity,
      );
}

abstract class _SessionTimeEntry implements SessionTimeEntry {
  const factory _SessionTimeEntry({
    required final String id,
    required final String businessId,
    required final String sessionId,
    required final TimeEntryType entryType,
    required final DateTime startedAt,
    required final DateTime? endedAt,
    required final DateTime createdAt,
  }) = _$SessionTimeEntryImpl;

  @override
  String get id;
  @override
  String get businessId;
  @override
  String get sessionId;
  @override
  TimeEntryType get entryType;
  @override
  DateTime get startedAt;
  @override
  DateTime? get endedAt;
  @override
  DateTime get createdAt;

  /// Create a copy of SessionTimeEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SessionTimeEntryImplCopyWith<_$SessionTimeEntryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

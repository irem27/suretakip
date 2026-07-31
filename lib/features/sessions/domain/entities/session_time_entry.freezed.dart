// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_time_entry.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SessionTimeEntry {

 String get id; String get businessId; String get sessionId; TimeEntryType get entryType; DateTime get startedAt; DateTime? get endedAt; DateTime get createdAt;
/// Create a copy of SessionTimeEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionTimeEntryCopyWith<SessionTimeEntry> get copyWith => _$SessionTimeEntryCopyWithImpl<SessionTimeEntry>(this as SessionTimeEntry, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionTimeEntry&&(identical(other.id, id) || other.id == id)&&(identical(other.businessId, businessId) || other.businessId == businessId)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.entryType, entryType) || other.entryType == entryType)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.endedAt, endedAt) || other.endedAt == endedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,businessId,sessionId,entryType,startedAt,endedAt,createdAt);

@override
String toString() {
  return 'SessionTimeEntry(id: $id, businessId: $businessId, sessionId: $sessionId, entryType: $entryType, startedAt: $startedAt, endedAt: $endedAt, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $SessionTimeEntryCopyWith<$Res>  {
  factory $SessionTimeEntryCopyWith(SessionTimeEntry value, $Res Function(SessionTimeEntry) _then) = _$SessionTimeEntryCopyWithImpl;
@useResult
$Res call({
 String id, String businessId, String sessionId, TimeEntryType entryType, DateTime startedAt, DateTime? endedAt, DateTime createdAt
});




}
/// @nodoc
class _$SessionTimeEntryCopyWithImpl<$Res>
    implements $SessionTimeEntryCopyWith<$Res> {
  _$SessionTimeEntryCopyWithImpl(this._self, this._then);

  final SessionTimeEntry _self;
  final $Res Function(SessionTimeEntry) _then;

/// Create a copy of SessionTimeEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? businessId = null,Object? sessionId = null,Object? entryType = null,Object? startedAt = null,Object? endedAt = freezed,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,businessId: null == businessId ? _self.businessId : businessId // ignore: cast_nullable_to_non_nullable
as String,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,entryType: null == entryType ? _self.entryType : entryType // ignore: cast_nullable_to_non_nullable
as TimeEntryType,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,endedAt: freezed == endedAt ? _self.endedAt : endedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [SessionTimeEntry].
extension SessionTimeEntryPatterns on SessionTimeEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SessionTimeEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SessionTimeEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SessionTimeEntry value)  $default,){
final _that = this;
switch (_that) {
case _SessionTimeEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SessionTimeEntry value)?  $default,){
final _that = this;
switch (_that) {
case _SessionTimeEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String businessId,  String sessionId,  TimeEntryType entryType,  DateTime startedAt,  DateTime? endedAt,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SessionTimeEntry() when $default != null:
return $default(_that.id,_that.businessId,_that.sessionId,_that.entryType,_that.startedAt,_that.endedAt,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String businessId,  String sessionId,  TimeEntryType entryType,  DateTime startedAt,  DateTime? endedAt,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _SessionTimeEntry():
return $default(_that.id,_that.businessId,_that.sessionId,_that.entryType,_that.startedAt,_that.endedAt,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String businessId,  String sessionId,  TimeEntryType entryType,  DateTime startedAt,  DateTime? endedAt,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _SessionTimeEntry() when $default != null:
return $default(_that.id,_that.businessId,_that.sessionId,_that.entryType,_that.startedAt,_that.endedAt,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc


class _SessionTimeEntry implements SessionTimeEntry {
  const _SessionTimeEntry({required this.id, required this.businessId, required this.sessionId, required this.entryType, required this.startedAt, required this.endedAt, required this.createdAt});


@override final  String id;
@override final  String businessId;
@override final  String sessionId;
@override final  TimeEntryType entryType;
@override final  DateTime startedAt;
@override final  DateTime? endedAt;
@override final  DateTime createdAt;

/// Create a copy of SessionTimeEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionTimeEntryCopyWith<_SessionTimeEntry> get copyWith => __$SessionTimeEntryCopyWithImpl<_SessionTimeEntry>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionTimeEntry&&(identical(other.id, id) || other.id == id)&&(identical(other.businessId, businessId) || other.businessId == businessId)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.entryType, entryType) || other.entryType == entryType)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.endedAt, endedAt) || other.endedAt == endedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,businessId,sessionId,entryType,startedAt,endedAt,createdAt);

@override
String toString() {
  return 'SessionTimeEntry(id: $id, businessId: $businessId, sessionId: $sessionId, entryType: $entryType, startedAt: $startedAt, endedAt: $endedAt, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$SessionTimeEntryCopyWith<$Res> implements $SessionTimeEntryCopyWith<$Res> {
  factory _$SessionTimeEntryCopyWith(_SessionTimeEntry value, $Res Function(_SessionTimeEntry) _then) = __$SessionTimeEntryCopyWithImpl;
@override @useResult
$Res call({
 String id, String businessId, String sessionId, TimeEntryType entryType, DateTime startedAt, DateTime? endedAt, DateTime createdAt
});




}
/// @nodoc
class __$SessionTimeEntryCopyWithImpl<$Res>
    implements _$SessionTimeEntryCopyWith<$Res> {
  __$SessionTimeEntryCopyWithImpl(this._self, this._then);

  final _SessionTimeEntry _self;
  final $Res Function(_SessionTimeEntry) _then;

/// Create a copy of SessionTimeEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? businessId = null,Object? sessionId = null,Object? entryType = null,Object? startedAt = null,Object? endedAt = freezed,Object? createdAt = null,}) {
  return _then(_SessionTimeEntry(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,businessId: null == businessId ? _self.businessId : businessId // ignore: cast_nullable_to_non_nullable
as String,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,entryType: null == entryType ? _self.entryType : entryType // ignore: cast_nullable_to_non_nullable
as TimeEntryType,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,endedAt: freezed == endedAt ? _self.endedAt : endedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on

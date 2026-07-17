// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'customer.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$Customer {
  String get id => throw _privateConstructorUsedError;
  String get businessId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String? get phone => throw _privateConstructorUsedError;
  String? get email => throw _privateConstructorUsedError;
  String? get notes => throw _privateConstructorUsedError;
  bool get isActive => throw _privateConstructorUsedError;
  DateTime? get archivedAt => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;

  /// Create a copy of Customer
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CustomerCopyWith<Customer> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CustomerCopyWith<$Res> {
  factory $CustomerCopyWith(Customer value, $Res Function(Customer) then) =
      _$CustomerCopyWithImpl<$Res, Customer>;
  @useResult
  $Res call({
    String id,
    String businessId,
    String name,
    String? phone,
    String? email,
    String? notes,
    bool isActive,
    DateTime? archivedAt,
    DateTime createdAt,
    DateTime updatedAt,
  });
}

/// @nodoc
class _$CustomerCopyWithImpl<$Res, $Val extends Customer>
    implements $CustomerCopyWith<$Res> {
  _$CustomerCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Customer
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? businessId = null,
    Object? name = null,
    Object? phone = freezed,
    Object? email = freezed,
    Object? notes = freezed,
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
            phone: freezed == phone
                ? _value.phone
                : phone // ignore: cast_nullable_to_non_nullable
                      as String?,
            email: freezed == email
                ? _value.email
                : email // ignore: cast_nullable_to_non_nullable
                      as String?,
            notes: freezed == notes
                ? _value.notes
                : notes // ignore: cast_nullable_to_non_nullable
                      as String?,
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
abstract class _$$CustomerImplCopyWith<$Res>
    implements $CustomerCopyWith<$Res> {
  factory _$$CustomerImplCopyWith(
    _$CustomerImpl value,
    $Res Function(_$CustomerImpl) then,
  ) = __$$CustomerImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String businessId,
    String name,
    String? phone,
    String? email,
    String? notes,
    bool isActive,
    DateTime? archivedAt,
    DateTime createdAt,
    DateTime updatedAt,
  });
}

/// @nodoc
class __$$CustomerImplCopyWithImpl<$Res>
    extends _$CustomerCopyWithImpl<$Res, _$CustomerImpl>
    implements _$$CustomerImplCopyWith<$Res> {
  __$$CustomerImplCopyWithImpl(
    _$CustomerImpl _value,
    $Res Function(_$CustomerImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Customer
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? businessId = null,
    Object? name = null,
    Object? phone = freezed,
    Object? email = freezed,
    Object? notes = freezed,
    Object? isActive = null,
    Object? archivedAt = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _$CustomerImpl(
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
        phone: freezed == phone
            ? _value.phone
            : phone // ignore: cast_nullable_to_non_nullable
                  as String?,
        email: freezed == email
            ? _value.email
            : email // ignore: cast_nullable_to_non_nullable
                  as String?,
        notes: freezed == notes
            ? _value.notes
            : notes // ignore: cast_nullable_to_non_nullable
                  as String?,
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

class _$CustomerImpl implements _Customer {
  const _$CustomerImpl({
    required this.id,
    required this.businessId,
    required this.name,
    required this.phone,
    required this.email,
    required this.notes,
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
  final String? phone;
  @override
  final String? email;
  @override
  final String? notes;
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
    return 'Customer(id: $id, businessId: $businessId, name: $name, phone: $phone, email: $email, notes: $notes, isActive: $isActive, archivedAt: $archivedAt, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CustomerImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.businessId, businessId) ||
                other.businessId == businessId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.phone, phone) || other.phone == phone) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.notes, notes) || other.notes == notes) &&
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
    phone,
    email,
    notes,
    isActive,
    archivedAt,
    createdAt,
    updatedAt,
  );

  /// Create a copy of Customer
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CustomerImplCopyWith<_$CustomerImpl> get copyWith =>
      __$$CustomerImplCopyWithImpl<_$CustomerImpl>(this, _$identity);
}

abstract class _Customer implements Customer {
  const factory _Customer({
    required final String id,
    required final String businessId,
    required final String name,
    required final String? phone,
    required final String? email,
    required final String? notes,
    required final bool isActive,
    required final DateTime? archivedAt,
    required final DateTime createdAt,
    required final DateTime updatedAt,
  }) = _$CustomerImpl;

  @override
  String get id;
  @override
  String get businessId;
  @override
  String get name;
  @override
  String? get phone;
  @override
  String? get email;
  @override
  String? get notes;
  @override
  bool get isActive;
  @override
  DateTime? get archivedAt;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;

  /// Create a copy of Customer
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CustomerImplCopyWith<_$CustomerImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

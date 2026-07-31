import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/database/app_database.dart';
import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/core/value_objects/money.dart';
import 'package:suretakip/features/businesses/data/local/businesses_local_data_source.dart';
import 'package:suretakip/features/businesses/data/repositories/cached_businesses_repository.dart';
import 'package:suretakip/features/businesses/domain/entities/business.dart';
import 'package:suretakip/features/businesses/domain/entities/business_member.dart';
import 'package:suretakip/features/businesses/domain/entities/onboarding_input.dart';
import 'package:suretakip/features/businesses/domain/repositories/businesses_repository.dart';

void main() {
  late AppDatabase db;
  late BusinessesLocalDataSource local;
  late _FakeRemote remote;
  late CachedBusinessesRepository repo;

  setUp(() {
    db = AppDatabase.forExecutor(NativeDatabase.memory());
    local = BusinessesLocalDataSource(db);
    remote = _FakeRemote();
    repo = CachedBusinessesRepository(remote: remote, local: local);
  });

  tearDown(() => db.close());

  test('önbellekte varsa getBusiness anında döner ve arkada tazeler', () async {
    await local.upsertBusiness(_business('cached'));
    remote.businesses = [_business('cached')];

    final result = await repo.getBusiness('cached');

    expect(result.id, 'cached');
  });

  test(
    'önbellek boşken getBusiness sunucudan çeker ve önbelleğe yazar',
    () async {
      remote.businesses = [_business('b1')];

      final result = await repo.getBusiness('b1');

      expect(result.id, 'b1');
      expect((await local.getBusiness('b1'))?.id, 'b1');
    },
  );

  test('önbellek boşken ağ hatası getBusiness için yükseltilir', () async {
    remote.throwNetwork = true;
    expect(repo.getBusiness('b1'), throwsA(isA<NetworkException>()));
  });

  test('updateBusiness sunucuya iletir ve sonucu önbelleğe yazar', () async {
    final updated = _business('b1');

    final result = await repo.updateBusiness(updated);

    expect(result.id, 'b1');
    expect(remote.updateBusinessCalls, [updated]);
    expect((await local.getBusiness('b1'))?.id, 'b1');
  });

  test('completeOnboarding sunucuya devredilir', () async {
    final input = OnboardingInput(
      businessName: 'Yeni İşletme',
      timezone: 'Europe/Istanbul',
      serviceName: 'Kesim',
      servicePricePerMinute: Money(minorUnits: 100, currencyCode: 'TRY'),
      roundingIntervalMinutes: 15,
      minimumChargeMinutes: 10,
    );
    remote.completeOnboardingResult = 'new-business-id';

    final id = await repo.completeOnboarding(input);

    expect(id, 'new-business-id');
    expect(remote.completeOnboardingCalls.single, input);
  });

  test('addMember sunucuya devredilir', () async {
    remote.addMemberResult = _member('m1', 'b1', MemberRole.staff);

    final member = await repo.addMember(
      businessId: 'b1',
      userId: 'u1',
      role: MemberRole.staff,
    );

    expect(member.id, 'm1');
    expect(remote.addMemberCalls.single, ('b1', 'u1', MemberRole.staff));
  });

  test('changeMemberRole sunucuya devredilir', () async {
    remote.changeMemberRoleResult = _member('m1', 'b1', MemberRole.admin);

    final member = await repo.changeMemberRole(
      memberId: 'm1',
      role: MemberRole.admin,
    );

    expect(member.role, MemberRole.admin);
    expect(remote.changeMemberRoleCalls.single, ('m1', MemberRole.admin));
  });

  test('setMemberActive sunucuya devredilir', () async {
    remote.setMemberActiveResult = _member('m1', 'b1', MemberRole.staff);

    final member = await repo.setMemberActive(memberId: 'm1', isActive: false);

    expect(member.id, 'm1');
    expect(remote.setMemberActiveCalls.single, ('m1', false));
  });

  test('removeMember sunucuya devredilir', () async {
    await repo.removeMember('m1');

    expect(remote.removeMemberCalls, ['m1']);
  });

  test('transferOwnership sunucuya devredilir', () async {
    await repo.transferOwnership(businessId: 'b1', toMemberId: 'm2');

    expect(remote.transferOwnershipCalls.single, ('b1', 'm2'));
  });
}

Business _business(String id) => Business(
  id: id,
  name: 'İşletme $id',
  currencyCode: 'TRY',
  timezone: 'Europe/Istanbul',
  isActive: true,
  archivedAt: null,
  createdAt: DateTime.utc(2026, 7, 1),
  updatedAt: DateTime.utc(2026, 7, 1),
);

BusinessMember _member(String id, String businessId, MemberRole role) =>
    BusinessMember(
      id: id,
      businessId: businessId,
      userId: 'user-1',
      role: role,
      isActive: true,
      createdAt: DateTime.utc(2026, 7, 1),
      updatedAt: DateTime.utc(2026, 7, 1),
    );

class _FakeRemote implements BusinessesRepository {
  List<Business> businesses = const [];
  bool throwNetwork = false;

  final List<Business> updateBusinessCalls = [];
  final List<OnboardingInput> completeOnboardingCalls = [];
  final List<(String, String, MemberRole)> addMemberCalls = [];
  final List<(String, MemberRole)> changeMemberRoleCalls = [];
  final List<(String, bool)> setMemberActiveCalls = [];
  final List<String> removeMemberCalls = [];
  final List<(String, String)> transferOwnershipCalls = [];

  String completeOnboardingResult = 'business-id';
  BusinessMember? addMemberResult;
  BusinessMember? changeMemberRoleResult;
  BusinessMember? setMemberActiveResult;

  @override
  Future<List<Business>> getBusinesses() async {
    if (throwNetwork) throw const NetworkException('çevrimdışı');
    return businesses;
  }

  @override
  Future<List<BusinessMember>> getMembers(String businessId) async => const [];

  @override
  Future<Business> getBusiness(String businessId) async {
    if (throwNetwork) throw const NetworkException('çevrimdışı');
    return businesses.firstWhere((b) => b.id == businessId);
  }

  @override
  Future<Business> updateBusiness(Business business) async {
    updateBusinessCalls.add(business);
    return business;
  }

  @override
  Future<String> completeOnboarding(OnboardingInput input) async {
    completeOnboardingCalls.add(input);
    return completeOnboardingResult;
  }

  @override
  Future<BusinessMember> addMember({
    required String businessId,
    required String userId,
    MemberRole role = MemberRole.staff,
  }) async {
    addMemberCalls.add((businessId, userId, role));
    return addMemberResult!;
  }

  @override
  Future<BusinessMember> changeMemberRole({
    required String memberId,
    required MemberRole role,
  }) async {
    changeMemberRoleCalls.add((memberId, role));
    return changeMemberRoleResult!;
  }

  @override
  Future<BusinessMember> setMemberActive({
    required String memberId,
    required bool isActive,
  }) async {
    setMemberActiveCalls.add((memberId, isActive));
    return setMemberActiveResult!;
  }

  @override
  Future<void> removeMember(String memberId) async {
    removeMemberCalls.add(memberId);
  }

  @override
  Future<void> transferOwnership({
    required String businessId,
    required String toMemberId,
  }) async {
    transferOwnershipCalls.add((businessId, toMemberId));
  }
}

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/database/app_database.dart';
import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/features/businesses/data/local/businesses_local_data_source.dart';
import 'package:suretakip/features/businesses/data/repositories/cached_businesses_repository.dart';
import 'package:suretakip/features/businesses/domain/entities/business.dart';
import 'package:suretakip/features/businesses/domain/entities/business_member.dart';
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

  test('çevrimiçi getBusinesses sunucudan döner ve önbelleğe yazar', () async {
    remote.businesses = [_business('b1'), _business('b2')];

    final result = await repo.getBusinesses();

    expect(result.map((b) => b.id), ['b1', 'b2']);
    expect((await local.getBusinesses()).map((b) => b.id), ['b1', 'b2']);
  });

  test('ağ hatasında getBusinesses önbellekten okur', () async {
    // Önce bir kez çevrimiçi senkron: önbellek dolar.
    remote.businesses = [_business('b1')];
    await repo.getBusinesses();

    // Sonra çevrimdışı: sunucu NetworkException atar.
    remote.throwNetwork = true;
    final result = await repo.getBusinesses();

    expect(result.map((b) => b.id), ['b1']);
  });

  test('önbellek boşken ağ hatası üyeler için yükseltilir', () async {
    remote.throwNetwork = true;
    expect(repo.getMembers('b1'), throwsA(isA<NetworkException>()));
  });

  test('önbellek boşken ağ hatası işletmeler için yükseltilir', () async {
    remote.throwNetwork = true;
    expect(repo.getBusinesses(), throwsA(isA<NetworkException>()));
  });

  test('ağ dışı hata (yetki) yükseltilir, önbelleğe düşülmez', () async {
    remote.throwAuth = true;
    expect(repo.getBusinesses(), throwsA(isA<AuthorizationException>()));
  });

  test('getMembers çevrimdışı önbellekten rolü korur', () async {
    remote.members = {
      'b1': [_member('m1', 'b1', MemberRole.owner)],
    };
    await repo.getMembers('b1');

    remote.throwNetwork = true;
    final cached = await repo.getMembers('b1');
    expect(cached.single.role, MemberRole.owner);
  });

  test('önbellek varsa işletmeleri uzak yanıtı beklemeden döndürür', () async {
    await local.replaceBusinesses([_business('cached')]);
    remote.businessesCompleter = Completer<List<Business>>();

    final result = await repo.getBusinesses().timeout(
      const Duration(milliseconds: 100),
    );

    expect(result.single.id, 'cached');
    remote.businessesCompleter!.complete([_business('fresh')]);
    await Future<void>.delayed(Duration.zero);
  });

  test('önbellek varsa üyeleri uzak yanıtı beklemeden döndürür', () async {
    await local.replaceMembers('b1', [
      _member('cached-member', 'b1', MemberRole.owner),
    ]);
    remote.membersCompleter = Completer<List<BusinessMember>>();

    final result = await repo
        .getMembers('b1')
        .timeout(const Duration(milliseconds: 100));

    expect(result.single.id, 'cached-member');
    remote.membersCompleter!.complete([
      _member('fresh-member', 'b1', MemberRole.admin),
    ]);
    await Future<void>.delayed(Duration.zero);
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
  Map<String, List<BusinessMember>> members = const {};
  bool throwNetwork = false;
  bool throwAuth = false;
  Completer<List<Business>>? businessesCompleter;
  Completer<List<BusinessMember>>? membersCompleter;

  Never _maybeThrow() {
    if (throwAuth) throw const AuthorizationException('yetkisiz');
    throw const NetworkException('çevrimdışı');
  }

  @override
  Future<List<Business>> getBusinesses() async {
    if (throwNetwork || throwAuth) _maybeThrow();
    final completer = businessesCompleter;
    if (completer != null) return completer.future;
    return businesses;
  }

  @override
  Future<List<BusinessMember>> getMembers(String businessId) async {
    if (throwNetwork || throwAuth) _maybeThrow();
    final completer = membersCompleter;
    if (completer != null) return completer.future;
    return members[businessId] ?? const [];
  }

  @override
  Future<Business> getBusiness(String businessId) async {
    if (throwNetwork || throwAuth) _maybeThrow();
    return businesses.firstWhere((b) => b.id == businessId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

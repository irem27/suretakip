import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/features/businesses/domain/entities/business.dart';
import 'package:suretakip/features/businesses/domain/entities/business_member.dart';
import 'package:suretakip/features/businesses/domain/entities/onboarding_input.dart';
import 'package:suretakip/features/businesses/domain/repositories/businesses_repository.dart';
import 'package:suretakip/features/businesses/presentation/pages/onboarding_page.dart';

void main() {
  testWidgets('işletme adı hatası alana bağlı Türkçe metinle gösterilir', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          businessesRepositoryProvider.overrideWithValue(
            _FakeBusinessesRepository(),
          ),
        ],
        child: const MaterialApp(home: OnboardingPage()),
      ),
    );
    await tester.pumpAndSettle();

    // Material Stepper her adım için controlsBuilder çalıştırır, yani sayfada
    // 5 adet 'Devam Et' butonu bulunur. Hepsi aynı onStepContinue'ya bağlı;
    // testte tek hedef gerektiği için ilkini tıklıyoruz.
    await tester.tap(find.widgetWithText(FilledButton, 'Devam Et').first);
    await tester.pumpAndSettle();

    expect(find.text('İşletme adı zorunlu.'), findsWidgets);
  });
}

class _FakeBusinessesRepository implements BusinessesRepository {
  @override
  Future<List<Business>> getBusinesses() async => const [];

  @override
  Future<Business> getBusiness(String businessId) async => _business();

  @override
  Future<Business> updateBusiness(Business business) async => business;

  @override
  Future<String> completeOnboarding(OnboardingInput input) async =>
      'business-1';

  @override
  Future<List<BusinessMember>> getMembers(String businessId) async => const [];

  @override
  Future<BusinessMember> addMember({
    required String businessId,
    required String userId,
    MemberRole role = MemberRole.staff,
  }) async => _member(businessId: businessId, userId: userId, role: role);

  @override
  Future<BusinessMember> changeMemberRole({
    required String memberId,
    required MemberRole role,
  }) async => _member(role: role);

  @override
  Future<BusinessMember> setMemberActive({
    required String memberId,
    required bool isActive,
  }) async => _member();

  @override
  Future<void> removeMember(String memberId) async {}

  @override
  Future<void> transferOwnership({
    required String businessId,
    required String toMemberId,
  }) async {}
}

Business _business() => Business(
  id: 'business-1',
  name: 'Test İşletmesi',
  currencyCode: 'TRY',
  timezone: 'Europe/Istanbul',
  isActive: true,
  archivedAt: null,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

BusinessMember _member({
  String businessId = 'business-1',
  String userId = 'user-1',
  MemberRole role = MemberRole.staff,
}) => BusinessMember(
  id: 'member-1',
  businessId: businessId,
  userId: userId,
  role: role,
  isActive: true,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

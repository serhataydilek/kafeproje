import 'package:flutter_test/flutter_test.dart';
import 'package:kafeproje/models/index.dart';
import 'package:kafeproje/models/service_result.dart';
import 'package:kafeproje/providers/app_provider.dart';
import 'package:kafeproje/services/supabase_service.dart';
import 'package:kafeproje/utils/service_error.dart';

import 'test_helpers.dart';

void main() {
  group('cafe owner claims', () {
    test('creates a claim for the current user', () async {
      final service = _FakeOwnerClaimsService();
      final container = createTestContainer(
        state: buildTestAppShellState(currentUser: testUser),
        overrides: [
          cafeOwnerClaimsServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(cafeOwnerClaimControllerProvider.notifier)
          .createClaim(
            cafeId: 'cafe-1',
            businessName: 'Cafe One',
            phone: '555',
          );

      expect(result.ok, isTrue);
      expect(service.claims, hasLength(1));
      expect(service.claims.single.userId, testUser.id);
      expect(service.claims.single.cafeId, 'cafe-1');
    });

    test('prevents duplicate pending claims for same user and cafe', () async {
      final service = _FakeOwnerClaimsService(
        claims: [
          _claim(
            id: 'claim-1',
            userId: testUser.id,
            cafeId: 'cafe-1',
          ),
        ],
      );
      final container = createTestContainer(
        state: buildTestAppShellState(currentUser: testUser),
        overrides: [
          cafeOwnerClaimsServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);

      await container.read(currentUserOwnerClaimsProvider.future);
      final result = await container
          .read(cafeOwnerClaimControllerProvider.notifier)
          .createClaim(
            cafeId: 'cafe-1',
            businessName: 'Cafe One',
          );

      expect(result.ok, isFalse);
      expect(result.errorType, ServiceErrorType.conflict);
      expect(service.claims, hasLength(1));
    });

    test('admin approve marks claim approved', () async {
      final service = _FakeOwnerClaimsService(
        claims: [_claim(id: 'claim-1', userId: 'owner-1', cafeId: 'cafe-1')],
      );
      final admin = testUser.copyWith(isAdmin: true, role: ProfileRole.admin);
      final container = createTestContainer(
        state: buildTestAppShellState(
          currentUser: admin,
          isAdmin: true,
        ),
        overrides: [
          cafeOwnerClaimsServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(cafeOwnerClaimAdminControllerProvider.notifier)
          .approve('claim-1');

      expect(result.ok, isTrue);
      expect(result.data?.status, CafeOwnerClaimStatus.approved);
      expect(service.approvedCafeOwners['cafe-1'], 'owner-1');
    });

    test('admin reject marks claim rejected without binding cafe', () async {
      final service = _FakeOwnerClaimsService(
        claims: [_claim(id: 'claim-1', userId: 'owner-1', cafeId: 'cafe-1')],
      );
      final admin = testUser.copyWith(isAdmin: true, role: ProfileRole.admin);
      final container = createTestContainer(
        state: buildTestAppShellState(
          currentUser: admin,
          isAdmin: true,
        ),
        overrides: [
          cafeOwnerClaimsServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(cafeOwnerClaimAdminControllerProvider.notifier)
          .reject('claim-1');

      expect(result.ok, isTrue);
      expect(result.data?.status, CafeOwnerClaimStatus.rejected);
      expect(service.approvedCafeOwners, isEmpty);
    });

    test('owner permission only covers owned cafes', () {
      final owner = testUser.copyWith(role: ProfileRole.cafeOwner);
      final owned = buildTestCafe(id: 'owned', name: 'Owned').copyWith(
        ownerUserId: () => owner.id,
      );
      final other = buildTestCafe(id: 'other', name: 'Other').copyWith(
        ownerUserId: () => 'someone-else',
      );
      final container = createTestContainer(
        state: buildTestAppShellState(
          currentUser: owner,
          cafes: [owned, other],
        ),
      );
      addTearDown(container.dispose);

      expect(container.read(canManageCafeProvider(owned)), isTrue);
      expect(container.read(canManageCafeProvider(other)), isFalse);
    });

    test('normal user cannot manage cafes', () {
      final cafe = buildTestCafe(id: 'cafe-1', name: 'Cafe One');
      final container = createTestContainer(
        state: buildTestAppShellState(
          currentUser: testUser,
          cafes: [cafe],
        ),
      );
      addTearDown(container.dispose);

      expect(container.read(canManageCafeProvider(cafe)), isFalse);
    });
  });
}

CafeOwnerClaim _claim({
  required String id,
  required String userId,
  required String cafeId,
  CafeOwnerClaimStatus status = CafeOwnerClaimStatus.pending,
}) {
  return CafeOwnerClaim(
    id: id,
    userId: userId,
    cafeId: cafeId,
    businessName: 'Business',
    status: status,
    createdAt: DateTime.utc(2026),
  );
}

class _FakeOwnerClaimsService implements CafeOwnerClaimsService {
  _FakeOwnerClaimsService({List<CafeOwnerClaim> claims = const []})
      : claims = [...claims];

  final List<CafeOwnerClaim> claims;
  final Map<String, String> approvedCafeOwners = {};

  @override
  Future<ServiceResult<CafeOwnerClaim>> approveClaim({
    required String claimId,
    required String reviewedBy,
  }) async {
    return _review(claimId, reviewedBy, CafeOwnerClaimStatus.approved);
  }

  @override
  Future<ServiceResult<CafeOwnerClaim>> createClaim({
    required String userId,
    required String cafeId,
    required String businessName,
    String? phone,
    String? note,
  }) async {
    final duplicate = claims.any(
      (claim) =>
          claim.userId == userId && claim.cafeId == cafeId && claim.isPending,
    );
    if (duplicate) {
      return ServiceResult.failure(
        errorType: ServiceErrorType.conflict,
        message: 'duplicate pending claim',
      );
    }
    final claim = CafeOwnerClaim(
      id: 'claim-${claims.length + 1}',
      userId: userId,
      cafeId: cafeId,
      businessName: businessName,
      phone: phone,
      note: note,
      status: CafeOwnerClaimStatus.pending,
      createdAt: DateTime.utc(2026, 5, 18),
    );
    claims.add(claim);
    return ServiceResult.success(data: claim);
  }

  @override
  Future<ServiceResult<List<CafeOwnerClaim>>> fetchClaimsForUser(
    String userId,
  ) async {
    return ServiceResult.success(
      data: claims.where((claim) => claim.userId == userId).toList(),
    );
  }

  @override
  Future<ServiceResult<List<CafeOwnerClaim>>> fetchPendingClaims() async {
    return ServiceResult.success(
      data: claims.where((claim) => claim.isPending).toList(),
    );
  }

  @override
  Future<ServiceResult<CafeOwnerClaim>> rejectClaim({
    required String claimId,
    required String reviewedBy,
  }) async {
    return _review(claimId, reviewedBy, CafeOwnerClaimStatus.rejected);
  }

  Future<ServiceResult<CafeOwnerClaim>> _review(
    String claimId,
    String reviewedBy,
    CafeOwnerClaimStatus status,
  ) async {
    final index = claims.indexWhere((claim) => claim.id == claimId);
    if (index == -1) {
      return ServiceResult.failure(errorType: ServiceErrorType.notFound);
    }
    final updated = claims[index].copyWith(
      status: status,
      reviewedAt: () => DateTime.utc(2026, 5, 18),
      reviewedBy: () => reviewedBy,
    );
    claims[index] = updated;
    if (status == CafeOwnerClaimStatus.approved) {
      approvedCafeOwners[updated.cafeId] = updated.userId;
    }
    return ServiceResult.success(data: updated);
  }
}

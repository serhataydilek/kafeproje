import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kafeproje/models/index.dart';
import 'package:kafeproje/models/service_result.dart';
import 'package:kafeproje/providers/app_provider.dart';
import 'package:kafeproje/services/supabase_service.dart';
import 'package:kafeproje/utils/request_cancellation.dart';
import 'package:kafeproje/utils/service_error.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

    test('admin approve completes if controller is disposed mid-flight',
        () async {
      final reviewGate = Completer<void>();
      final service = _FakeOwnerClaimsService(
        claims: [_claim(id: 'claim-1', userId: 'owner-1', cafeId: 'cafe-1')],
        reviewGate: reviewGate.future,
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

      final pendingApproval = container
          .read(cafeOwnerClaimAdminControllerProvider.notifier)
          .approve('claim-1');
      await Future<void>.delayed(Duration.zero);
      container.dispose();
      reviewGate.complete();

      final result = await pendingApproval;

      expect(result.ok, isTrue);
      expect(result.data?.status, CafeOwnerClaimStatus.approved);
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

    test('normal user assigned as owner_user_id still cannot manage cafe',
        () async {
      final assigned = buildTestCafe(id: 'assigned', name: 'Assigned').copyWith(
        ownerUserId: () => testUser.id,
      );
      final service = _FakeCafeCommandService({'assigned': assigned});
      final container = createTestContainer(
        state: buildTestAppShellState(
          currentUser: testUser,
          cafes: [assigned],
        ),
        overrides: [
          cafeCommandServiceProvider.overrideWithValue(service),
          cafeQueryServiceProvider.overrideWithValue(
            _FakeCafeQueryService([assigned]),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(canManageCafeProvider(assigned)), isFalse);

      final result = await container
          .read(cafeAdminMutationControllerProvider.notifier)
          .updateCafe(
            'assigned',
            const CafeAdminUpdateInput(name: 'Blocked'),
          );

      expect(result.ok, isFalse);
      expect(result.errorType, ServiceErrorType.auth);
      expect(service.ownerUpdateCalls, 0);
      expect(service.adminUpdateCalls, 0);
    });

    test('cafe owner can edit owned cafe allowed fields', () async {
      final owner = testUser.copyWith(role: ProfileRole.cafeOwner);
      final owned = buildTestCafe(id: 'owned', name: 'Owned').copyWith(
        ownerUserId: () => owner.id,
      );
      final service = _FakeCafeCommandService({'owned': owned});
      final container = createTestContainer(
        state: buildTestAppShellState(
          currentUser: owner,
          cafes: [owned],
        ),
        overrides: [
          cafeCommandServiceProvider.overrideWithValue(service),
          cafeQueryServiceProvider.overrideWithValue(
            _FakeCafeQueryService([owned]),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(cafeAdminMutationControllerProvider.notifier)
          .updateCafe(
            'owned',
            const CafeAdminUpdateInput(
              name: 'Owner Updated',
              isFeatured: true,
              ownerUserId: 'attacker',
            ),
          );

      expect(result.ok, isTrue);
      expect(service.ownerUpdateCalls, 1);
      expect(service.adminUpdateCalls, 0);
      expect(service.lastOwnerInput?.name, 'Owner Updated');
      expect(service.lastOwnerInput?.isFeatured, isNull);
      expect(service.lastOwnerInput?.ownerUserId, isNull);
    });

    test('cafe owner cannot edit unowned cafe', () async {
      final owner = testUser.copyWith(role: ProfileRole.cafeOwner);
      final other = buildTestCafe(id: 'other', name: 'Other').copyWith(
        ownerUserId: () => 'someone-else',
      );
      final service = _FakeCafeCommandService({'other': other});
      final container = createTestContainer(
        state: buildTestAppShellState(
          currentUser: owner,
          cafes: [other],
        ),
        overrides: [
          cafeCommandServiceProvider.overrideWithValue(service),
          cafeQueryServiceProvider.overrideWithValue(
            _FakeCafeQueryService([other]),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(cafeAdminMutationControllerProvider.notifier)
          .updateCafe(
            'other',
            const CafeAdminUpdateInput(name: 'Blocked'),
          );

      expect(result.ok, isFalse);
      expect(result.errorType, ServiceErrorType.auth);
      expect(service.ownerUpdateCalls, 0);
      expect(service.adminUpdateCalls, 0);
    });

    test('admin remains able to edit all cafes', () async {
      final admin = testUser.copyWith(isAdmin: true, role: ProfileRole.admin);
      final cafe = buildTestCafe(id: 'cafe-1', name: 'Cafe');
      final service = _FakeCafeCommandService({'cafe-1': cafe});
      final container = createTestContainer(
        state: buildTestAppShellState(
          currentUser: admin,
          isAdmin: true,
          cafes: [cafe],
        ),
        overrides: [
          cafeCommandServiceProvider.overrideWithValue(service),
          cafeQueryServiceProvider.overrideWithValue(
            _FakeCafeQueryService([cafe]),
          ),
          securityReadinessProvider.overrideWith(
            (ref) async => const SecurityReadinessReport(
              isReady: true,
              checkAvailable: true,
              rlsEnabled: true,
              hasAdminInsertPolicy: true,
              hasAdminUpdatePolicy: true,
              message: 'ready',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(cafeAdminMutationControllerProvider.notifier)
          .updateCafe(
            'cafe-1',
            const CafeAdminUpdateInput(isFeatured: true),
          );

      expect(result.ok, isTrue);
      expect(service.adminUpdateCalls, 1);
      expect(service.ownerUpdateCalls, 0);
      expect(service.lastAdminInput?.isFeatured, isTrue);
    });

    test('migration reviews claims transactionally and preserves admins', () {
      final sql = File(
        'supabase/migrations/20260523_001_owner_claim_security_hardening.sql',
      ).readAsStringSync();
      final ownerFunction = sql.substring(
        sql.indexOf('CREATE OR REPLACE FUNCTION public.owner_update_cafe'),
        sql.indexOf('CREATE OR REPLACE FUNCTION public.admin_approve'),
      );

      expect(sql, contains('admin_approve_cafe_owner_claim'));
      expect(sql, contains('SET owner_user_id = claim_row.user_id'));
      expect(sql, contains("SET role = 'cafe_owner'"));
      expect(sql, contains("role', '')) <> 'admin'"));
      expect(sql, contains("is_admin', '')) NOT IN ('true', 't', '1')"));
      expect(sql, contains('owner_update_cafe'));
      expect(ownerFunction, isNot(contains("'is_featured'")));
      expect(ownerFunction, isNot(contains("'owner_user_id'")));
      expect(
          sql,
          contains(
              'DROP POLICY IF EXISTS "Cafe owners can update owned cafes"'));
    });

    test('invite hardening requires cafe_owner role for owner updates', () {
      final sql = File(
        'supabase/migrations/20260525_001_cafe_owner_invite_hardening.sql',
      ).readAsStringSync();
      final edgeFunction = File(
        'supabase/functions/invite-cafe-owner/index.ts',
      ).readAsStringSync();

      expect(sql, contains("lower(coalesce(p.role, '')) = 'cafe_owner'"));
      expect(sql, contains('owner_user_id = auth.uid()'));
      expect(sql, isNot(contains("'owner_user_id'")));
      expect(edgeFunction, contains('SUPABASE_SERVICE_ROLE_KEY'));
      expect(edgeFunction, contains('inviteUserByEmail'));
      expect(edgeFunction, contains('listUsers'));
      expect(edgeFunction, contains('isAlreadyRegisteredError'));
      expect(edgeFunction, contains('google_uses_app_defaults'));
      expect(edgeFunction, contains('isMissingColumnError'));
      expect(edgeFunction, contains('Admin privileges are required'));
      expect(edgeFunction, contains('role: "cafe_owner"'));
      expect(edgeFunction, contains('inviteErrorResponse'));
      expect(edgeFunction, contains('"assign_cafe"'));
      expect(edgeFunction, contains('"cafe_assignment_failed"'));
      expect(edgeFunction, contains('"profile_upsert_failed"'));
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
  _FakeOwnerClaimsService({
    List<CafeOwnerClaim> claims = const [],
    this.reviewGate,
  }) : claims = [...claims];

  final List<CafeOwnerClaim> claims;
  final Map<String, String> approvedCafeOwners = {};
  final Future<void>? reviewGate;

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
    String? businessEmail,
    String? evidenceUrl,
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
      businessEmail: businessEmail,
      evidenceUrl: evidenceUrl,
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
    String? reason,
  }) async {
    return _review(claimId, reviewedBy, CafeOwnerClaimStatus.rejected);
  }

  Future<ServiceResult<CafeOwnerClaim>> _review(
    String claimId,
    String reviewedBy,
    CafeOwnerClaimStatus status,
  ) async {
    await reviewGate;
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

class _FakeCafeCommandService extends CafeCommandService {
  _FakeCafeCommandService(this.cafes)
      : super(
          SupabaseClient(
            'https://example.com',
            'anon-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        );

  final Map<String, Cafe> cafes;
  int adminUpdateCalls = 0;
  int ownerUpdateCalls = 0;
  CafeAdminUpdateInput? lastAdminInput;
  CafeAdminUpdateInput? lastOwnerInput;

  @override
  Future<ServiceResult<Cafe>> updateCafeByAdmin(
    String cafeId,
    CafeAdminUpdateInput input,
  ) async {
    adminUpdateCalls += 1;
    lastAdminInput = input;
    return ServiceResult.success(
      data: cafes[cafeId] ?? buildTestCafe(id: cafeId, name: 'Cafe'),
    );
  }

  @override
  Future<ServiceResult<Cafe>> updateCafeByOwner(
    String cafeId,
    CafeAdminUpdateInput input,
  ) async {
    ownerUpdateCalls += 1;
    lastOwnerInput = input;
    return ServiceResult.success(
      data: cafes[cafeId] ?? buildTestCafe(id: cafeId, name: 'Cafe'),
    );
  }
}

class _FakeCafeQueryService extends CafeQueryService {
  _FakeCafeQueryService(this.cafes)
      : super(
          SupabaseClient(
            'https://example.com',
            'anon-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        );

  final List<Cafe> cafes;

  @override
  Future<ServiceResult<Cafe?>> fetchCafeDetails(
    String cafeId, {
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) async {
    return fetchCafeById(
      cafeId,
      requestTimeout: requestTimeout,
      cancellationToken: cancellationToken,
    );
  }

  @override
  Future<ServiceResult<Cafe?>> fetchCafeById(
    String cafeId, {
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) async {
    Cafe? match;
    for (final cafe in cafes) {
      if (cafe.id == cafeId) {
        match = cafe;
        break;
      }
    }
    return ServiceResult.success(
      data: match,
    );
  }

  @override
  Future<ServiceResult<AdminCafePage>> fetchAdminCafes({
    String searchQuery = '',
    String district = 'all',
    String status = 'all',
    int limit = 60,
    int offset = 0,
    Duration? requestTimeout,
    RequestCancellationToken? cancellationToken,
  }) async {
    return ServiceResult.success(
      data: AdminCafePage(
        cafes: cafes,
        hasMore: false,
        offset: offset,
        limit: limit,
      ),
    );
  }
}

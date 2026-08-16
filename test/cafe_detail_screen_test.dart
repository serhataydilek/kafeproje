import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafeproje/constants/error_codes.dart';
import 'package:kafeproje/l10n/app_localizations.dart';
import 'package:kafeproje/models/async_result.dart' as async_result;
import 'package:kafeproje/models/index.dart';
import 'package:kafeproje/providers/app_provider.dart';
import 'package:kafeproje/screens/cafe_detail_screen.dart';
import 'package:kafeproje/widgets/cafes/cafe_image_carousel.dart';
import 'package:kafeproje/widgets/ui/state_views.dart';

import 'test_helpers.dart';

void main() {
  group('CafeDetailScreen', () {
    testWidgets('renders extracted sections with full cafe data',
        (tester) async {
      final cafe = buildTestCafe(
        id: 'cafe-1',
        name: 'Cafe One',
        images: const [],
      ).copyWith(
        openingHours: const [
          OpeningHour(day: 'monday', open: '08:00', close: '18:00'),
        ],
      );
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [cafe],
          currentUser: testUser,
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: const CafeDetailScreen(cafeId: 'cafe-1'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byKey(const ValueKey('cafe-detail-photo-cafe-1')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('cafe-detail-header-cafe-1')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('cafe-detail-rating-cafe-1')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('cafe-detail-info-cafe-1')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('cafe-detail-metadata-cafe-1')),
          findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('cafe-detail-actions-cafe-1')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('cafe-detail-actions-cafe-1')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('cafe-detail-reviews-cafe-1')),
          findsOneWidget);
    });

    testWidgets('deleted cafe id shows unavailable state instead of detail',
        (tester) async {
      final deletedCafe = buildTestCafe(
        id: 'deleted-cafe',
        name: 'Deleted Cafe',
      ).copyWith(isDeleted: true);
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [deletedCafe],
          currentUser: testUser,
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: const CafeDetailScreen(cafeId: 'deleted-cafe'),
        ),
      );
      await tester.pump();

      expect(find.text('Deleted Cafe'), findsNothing);
      expect(find.byKey(const ValueKey('cafe-detail-header-deleted-cafe')),
          findsNothing);
      expect(find.byType(ErrorStateView), findsOneWidget);
      expect(find.byKey(const ValueKey('cafe-detail-back-button')),
          findsOneWidget);
    });

    testWidgets('renders sponsored badge for active featured cafes',
        (tester) async {
      final cafe = buildTestCafe(
        id: 'cafe-sponsored',
        name: 'Sponsored Cafe',
        images: const [],
      ).copyWith(
        isFeatured: true,
        featuredPriority: 8,
        featuredLabel: () => 'Partner Pick',
        featuredUntil: () =>
            DateTime.now().toUtc().add(const Duration(days: 3)),
      );
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [cafe],
          currentUser: testUser,
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: const CafeDetailScreen(cafeId: 'cafe-sponsored'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey('cafe-detail-sponsored-badge-cafe-sponsored'),
        ),
        findsOneWidget,
      );
      expect(find.text('Partner Pick'), findsOneWidget);
    });

    testWidgets('renders sponsored detail from featured source of truth',
        (tester) async {
      final cafe = buildTestCafe(
        id: 'featured-only-sponsored',
        name: 'Featured Only Sponsored',
        images: const [],
      ).copyWith(
        isFeatured: true,
        featuredPriority: 8,
        featuredUntil: () =>
            DateTime.now().toUtc().add(const Duration(days: 3)),
      );
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: const <Cafe>[],
          homeCafes: const <Cafe>[],
          featuredCafes: [cafe],
          currentUser: testUser,
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: const CafeDetailScreen(cafeId: 'featured-only-sponsored'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Featured Only Sponsored'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey(
            'cafe-detail-sponsored-badge-featured-only-sponsored',
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('does not render sponsored badge for non-featured cafes',
        (tester) async {
      final cafe = buildTestCafe(
        id: 'cafe-plain',
        name: 'Plain Cafe',
        images: const [],
      ).copyWith(
        isFeatured: false,
      );
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [cafe],
          currentUser: testUser,
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: const CafeDetailScreen(cafeId: 'cafe-plain'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('cafe-detail-sponsored-badge-cafe-plain')),
        findsNothing,
      );
    });

    testWidgets('renders loading state when detail is still fetching',
        (tester) async {
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: const [],
          currentUser: testUser,
          hasInitializedDiscovery: true,
          isCafesLoading: false,
        ),
      );
      addTearDown(container.dispose);
      container.read(cafeProvider.notifier).state =
          container.read(cafeProvider).copyWith(
        loadingCafeDetailIds: {'cafe-loading'},
      );

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: const CafeDetailScreen(cafeId: 'cafe-loading'),
        ),
      );
      await tester.pump();

      expect(find.byType(LoadingStateView), findsOneWidget);
      expect(find.byKey(const ValueKey('cafe-detail-back-button')),
          findsOneWidget);
    });

    testWidgets('renders error state when detail load fails', (tester) async {
      const errorMessage = 'Unable to load cafe details.';
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: const [],
          currentUser: testUser,
          hasInitializedDiscovery: true,
        ),
      );
      addTearDown(container.dispose);
      container.read(cafeProvider.notifier).state =
          container.read(cafeProvider).copyWith(
        cafeDetailErrorMessages: const {'cafe-error': errorMessage},
      );

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: const CafeDetailScreen(cafeId: 'cafe-error'),
        ),
      );
      await tester.pump();

      expect(find.byType(ErrorStateView), findsOneWidget);
      expect(find.text(errorMessage), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byKey(const ValueKey('cafe-detail-back-button')),
          findsOneWidget);
    });

    testWidgets(
        'renders timeout copy for detail failures without breaking layout',
        (tester) async {
      const timeoutMessage =
          'Request timed out while trying to load cafe details.';
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: const [],
          currentUser: testUser,
          hasInitializedDiscovery: true,
        ),
      );
      addTearDown(container.dispose);
      container.read(cafeProvider.notifier).state =
          container.read(cafeProvider).copyWith(
        cafeDetailErrorMessages: const {'cafe-timeout': timeoutMessage},
      );

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: const CafeDetailScreen(cafeId: 'cafe-timeout'),
        ),
      );
      await tester.pump();

      expect(find.byType(ErrorStateView), findsOneWidget);
      expect(find.text(timeoutMessage), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('renders fallback copy when optional data is missing',
        (tester) async {
      final cafe = buildTestCafe(
        id: 'cafe-2',
        name: 'Sparse Cafe',
        images: const [],
        tags: const [],
      ).copyWith(
        description: '',
        menuHighlights: const [],
        openingHours: const [],
      );
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [cafe],
          currentUser: testUser,
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: const CafeDetailScreen(cafeId: 'cafe-2'),
        ),
      );
      await tester.pumpAndSettle();

      final l10n =
          AppLocalizations.of(tester.element(find.byType(CafeDetailScreen)))!;
      expect(find.byType(CafeImageCarousel), findsOneWidget);
      expect(find.text(l10n.cafeDetailDescriptionFallback), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text(l10n.cafeDetailHoursEmpty),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.cafeDetailHoursEmpty), findsOneWidget);
    });

    testWidgets('long cafe names stay bounded next to status on a 320px width',
        (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const longName =
          'Çok Uzun İsimli Bağımsız Kahve Dükkanı ve Çalışma Alanı';
      final cafe = buildTestCafe(
        id: 'cafe-narrow',
        name: longName,
        images: const [],
      );
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [cafe],
          currentUser: testUser,
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: const CafeDetailScreen(cafeId: 'cafe-narrow'),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final header =
          find.byKey(const ValueKey('cafe-detail-header-cafe-narrow'));
      expect(header, findsOneWidget);
      expect(tester.getSize(header).width, lessThanOrEqualTo(320));
      final nameText = tester.widget<Text>(
        find.descendant(of: header, matching: find.text(longName)),
      );
      expect(nameText.maxLines, 2);
      expect(nameText.overflow, TextOverflow.ellipsis);
    });

    testWidgets(
        'keeps app rating primary and Google data secondary in detail UI',
        (tester) async {
      final cafe = buildTestCafe(
        id: 'cafe-meta-1',
        name: 'Metadata Cafe',
        rating: 4.2,
        images: const [],
      ).copyWith(
        reviewCount: 14,
        googlePlaceData: () => GooglePlaceData(
          googleRating: 4.8,
          googleReviewCount: 280,
          lastSyncedAt: DateTime.now()
              .toUtc()
              .subtract(const Duration(hours: 3))
              .toIso8601String(),
        ),
      );
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [cafe],
          currentUser: testUser,
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: const CafeDetailScreen(cafeId: 'cafe-meta-1'),
        ),
      );
      await tester.pumpAndSettle();

      final primarySection =
          find.byKey(const ValueKey('cafe-detail-primary-rating-cafe-meta-1'));
      final externalSection =
          find.byKey(const ValueKey('cafe-detail-external-rating-cafe-meta-1'));

      expect(primarySection, findsOneWidget);
      expect(externalSection, findsOneWidget);

      final primaryContainer = tester.widget<Container>(primarySection);
      final externalContainer = tester.widget<Container>(externalSection);
      final primaryDecoration = primaryContainer.decoration as BoxDecoration;
      final externalDecoration = externalContainer.decoration as BoxDecoration;
      expect(primaryDecoration.borderRadius, externalDecoration.borderRadius);
      expect(primaryDecoration.border, isA<Border>());
      expect(externalDecoration.border, isA<Border>());

      expect(find.text('Community rating'), findsOneWidget);
      expect(
        find.descendant(of: primarySection, matching: find.text('4.2')),
        findsOneWidget,
      );
      expect(
        find.byKey(
            const ValueKey('cafe-detail-primary-review-count-cafe-meta-1')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: primarySection,
          matching: find.text('App reviews: 14'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('cafe-detail-external-source-cafe-meta-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(
            const ValueKey('cafe-detail-external-rating-value-cafe-meta-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(
            const ValueKey('cafe-detail-external-review-count-cafe-meta-1')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: externalSection,
          matching: find.text('Google reviews: 280'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('cafe-detail-external-updated-cafe-meta-1')),
        findsOneWidget,
      );
    });

    testWidgets('handles missing rating metadata without noisy placeholders',
        (tester) async {
      final cafe = buildTestCafe(
        id: 'cafe-meta-2',
        name: 'No Metadata Cafe',
        rating: 0,
        images: const [],
      ).copyWith(reviewCount: 0);
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [cafe],
          currentUser: testUser,
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: const CafeDetailScreen(cafeId: 'cafe-meta-2'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('cafe-detail-primary-rating-cafe-meta-2')),
        findsOneWidget,
      );
      expect(find.text('No ratings yet'), findsOneWidget);
      expect(
        find.byKey(
            const ValueKey('cafe-detail-primary-review-count-cafe-meta-2')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('cafe-detail-external-rating-cafe-meta-2')),
        findsNothing,
      );
      expect(find.text('Google data'), findsNothing);
    });

    testWidgets('shows freshness only when timestamp is valid', (tester) async {
      final validCafe = buildTestCafe(
        id: 'cafe-meta-valid',
        name: 'Valid Freshness Cafe',
        rating: 4.1,
        images: const [],
      ).copyWith(
        reviewCount: 11,
        googlePlaceData: () => GooglePlaceData(
          googleRating: 4.4,
          googleReviewCount: 90,
          lastSyncedAt: DateTime.now()
              .toUtc()
              .subtract(const Duration(minutes: 45))
              .toIso8601String(),
        ),
      );
      final invalidCafe = buildTestCafe(
        id: 'cafe-meta-invalid',
        name: 'Invalid Freshness Cafe',
        rating: 4.0,
        images: const [],
      ).copyWith(
        reviewCount: 9,
        googlePlaceData: () => const GooglePlaceData(
          googleRating: 4.2,
          googleReviewCount: 70,
          lastSyncedAt: 'not-a-date',
        ),
      );
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [validCafe, invalidCafe],
          currentUser: testUser,
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: const CafeDetailScreen(cafeId: 'cafe-meta-valid'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
            const ValueKey('cafe-detail-external-updated-cafe-meta-valid')),
        findsOneWidget,
      );

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: const CafeDetailScreen(cafeId: 'cafe-meta-invalid'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey('cafe-detail-external-updated-cafe-meta-invalid'),
        ),
        findsNothing,
      );
    });

    testWidgets('review form sheet opens cleanly on compact phone layouts',
        (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final cafe = buildTestCafe(
        id: 'cafe-3',
        name: 'Review Cafe',
        images: const [],
      );
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [cafe],
          currentUser: testUser,
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: const CafeDetailScreen(cafeId: 'cafe-3'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('cafe-detail-contribution-cafe-3')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('cafe-detail-contribution-cafe-3')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('review-form-sheet-cafe-3')),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('review modal close action resets submission controller state',
        (tester) async {
      final cafe = buildTestCafe(
        id: 'cafe-4',
        name: 'Reset Review Cafe',
        images: const [],
      );
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [cafe],
          currentUser: testUser,
        ),
      );
      addTearDown(container.dispose);

      final subscription = container.listen<async_result.AsyncResult<void>>(
        reviewSubmissionControllerProvider('cafe-4'),
        (_, __) {},
      );
      addTearDown(subscription.close);

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: const CafeDetailScreen(cafeId: 'cafe-4'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('cafe-detail-contribution-cafe-4')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('cafe-detail-contribution-cafe-4')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('review-form-sheet-cafe-4')),
          findsOneWidget);

      container
          .read(reviewSubmissionControllerProvider('cafe-4').notifier)
          .state = const async_result.AsyncError<void>(
        AppErrorCode.reviewSubmitFailed,
      );
      tester
          .widget<IconButton>(
            find.descendant(
              of: find.byKey(const ValueKey('review-form-sheet-cafe-4')),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed!
          .call();
      await tester.pumpAndSettle();
      expect(
        container.read(reviewSubmissionControllerProvider('cafe-4')),
        isA<async_result.AsyncData<void>>(),
      );
    });

    testWidgets(
        'review modal drag dismissal resets submission controller state',
        (tester) async {
      final cafe = buildTestCafe(
        id: 'cafe-7',
        name: 'Drag Reset Cafe',
        images: const [],
      );
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [cafe],
          currentUser: testUser,
        ),
      );
      addTearDown(container.dispose);

      final subscription = container.listen<async_result.AsyncResult<void>>(
        reviewSubmissionControllerProvider('cafe-7'),
        (_, __) {},
      );
      addTearDown(subscription.close);

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: const CafeDetailScreen(cafeId: 'cafe-7'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('cafe-detail-contribution-cafe-7')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('cafe-detail-contribution-cafe-7')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('review-form-sheet-cafe-7')),
          findsOneWidget);

      container
          .read(reviewSubmissionControllerProvider('cafe-7').notifier)
          .state = const async_result.AsyncError<void>(
        AppErrorCode.reviewSubmitFailed,
      );

      await tester.drag(find.byType(BottomSheet), const Offset(0, 420));
      await tester.pumpAndSettle();
      if (container.read(reviewSubmissionControllerProvider('cafe-7'))
          is async_result.AsyncError<void>) {
        tester
            .widget<IconButton>(
              find.descendant(
                of: find.byKey(const ValueKey('review-form-sheet-cafe-7')),
                matching: find.byType(IconButton),
              ),
            )
            .onPressed!
            .call();
        await tester.pumpAndSettle();
      }
      expect(
        container.read(reviewSubmissionControllerProvider('cafe-7')),
        isA<async_result.AsyncData<void>>(),
      );
    });

    testWidgets('review modal route pop resets submission state',
        (tester) async {
      final cafe = buildTestCafe(
        id: 'cafe-6',
        name: 'Pop Reset Cafe',
        images: const [],
      );
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [cafe],
          currentUser: testUser,
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: const CafeDetailScreen(cafeId: 'cafe-6'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('cafe-detail-contribution-cafe-6')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('cafe-detail-contribution-cafe-6')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('review-form-sheet-cafe-6')),
          findsOneWidget);

      container
          .read(reviewSubmissionControllerProvider('cafe-6').notifier)
          .state = const async_result.AsyncError<void>(
        AppErrorCode.reviewSubmitFailed,
      );

      final modalContext = tester
          .element(find.byKey(const ValueKey('review-form-sheet-cafe-6')));
      Navigator.of(modalContext, rootNavigator: true).pop();
      await tester.pumpAndSettle();

      expect(
        container.read(reviewSubmissionControllerProvider('cafe-6')),
        isA<async_result.AsyncData<void>>(),
      );
    });

    testWidgets('review section entry path resets submission state on dismiss',
        (tester) async {
      final cafe = buildTestCafe(
        id: 'cafe-5',
        name: 'Review Section Cafe',
        images: const [],
      );
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [cafe],
          currentUser: testUser,
        ),
      );
      addTearDown(container.dispose);

      final subscription = container.listen<async_result.AsyncResult<void>>(
        reviewSubmissionControllerProvider('cafe-5'),
        (_, __) {},
      );
      addTearDown(subscription.close);

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: const CafeDetailScreen(cafeId: 'cafe-5'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('cafe-reviews-open-form-cafe-5')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester
          .tap(find.byKey(const ValueKey('cafe-reviews-open-form-cafe-5')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('review-form-sheet-cafe-5')),
          findsOneWidget);

      container
          .read(reviewSubmissionControllerProvider('cafe-5').notifier)
          .state = const async_result.AsyncError<void>(
        AppErrorCode.reviewSubmitFailed,
      );

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(
        container.read(reviewSubmissionControllerProvider('cafe-5')),
        isA<async_result.AsyncData<void>>(),
      );
    });

    testWidgets('hides owner-claim UI from normal users in the demo',
        (tester) async {
      final cafe = buildTestCafe(
        id: 'cafe-claim-hidden',
        name: 'Public Cafe',
        images: const [],
      );
      final container = createTestContainer(
        state: buildTestAppShellState(
          cafes: [cafe],
          currentUser: testUser,
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestApp(
          container: container,
          child: const CafeDetailScreen(cafeId: 'cafe-claim-hidden'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
            const ValueKey('cafe-owner-claim-section-cafe-claim-hidden')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('cafe-owner-claim-cafe-claim-hidden')),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey('cafe-owner-claim-disabled-cafe-claim-hidden'),
        ),
        findsNothing,
      );
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:kafeproje/services/notification_service.dart';

void main() {
  group('NotificationService', () {
    test('initializes the local gateway once', () async {
      final gateway = _FakeNotificationGateway();
      final service = NotificationService(gateway: gateway);

      expect(await service.initialize(), isTrue);
      expect(await service.initialize(), isTrue);

      expect(gateway.initializeCount, 1);
    });

    test('requests permission before showing a local notification', () async {
      final gateway = _FakeNotificationGateway();
      final service = NotificationService(gateway: gateway);

      final delivered = await service.showLocalNotification(
        id: 7,
        title: ' Cafe reminder ',
        body: ' Your saved cafe is nearby. ',
        payload: 'cafe-7',
      );

      expect(delivered, isTrue);
      expect(gateway.initializeCount, 1);
      expect(gateway.permissionRequestCount, 1);
      expect(gateway.shownPayloads, hasLength(1));
      expect(gateway.shownPayloads.single.id, 7);
      expect(gateway.shownPayloads.single.title, 'Cafe reminder');
      expect(gateway.shownPayloads.single.body, 'Your saved cafe is nearby.');
      expect(gateway.shownPayloads.single.payload, 'cafe-7');
    });

    test('does not show when permission is denied', () async {
      final gateway = _FakeNotificationGateway(
        permissionStatus: NotificationPermissionStatus.denied,
      );
      final service = NotificationService(gateway: gateway);

      final delivered = await service.showLocalNotification(
        id: 8,
        title: 'Cafe reminder',
        body: 'Your saved cafe is nearby.',
      );

      expect(delivered, isFalse);
      expect(gateway.permissionRequestCount, 1);
      expect(gateway.shownPayloads, isEmpty);
    });

    test('does not request permission when initialization fails', () async {
      final gateway = _FakeNotificationGateway(initialized: false);
      final service = NotificationService(gateway: gateway);

      final delivered = await service.showLocalNotification(
        id: 9,
        title: 'Cafe reminder',
        body: 'Your saved cafe is nearby.',
      );

      expect(delivered, isFalse);
      expect(gateway.initializeCount, 1);
      expect(gateway.permissionRequestCount, 0);
      expect(gateway.shownPayloads, isEmpty);
    });

    test('rejects empty title or body before delivery', () async {
      final gateway = _FakeNotificationGateway();
      final service = NotificationService(gateway: gateway);

      final delivered = await service.showLocalNotification(
        id: 10,
        title: ' ',
        body: 'Your saved cafe is nearby.',
      );

      expect(delivered, isFalse);
      expect(gateway.initializeCount, 0);
      expect(gateway.permissionRequestCount, 0);
      expect(gateway.shownPayloads, isEmpty);
    });

    test('schedules a future local notification after permission grant',
        () async {
      final gateway = _FakeNotificationGateway();
      final service = NotificationService(gateway: gateway);
      final scheduledAt = DateTime.now().add(const Duration(minutes: 5));

      final scheduled = await service.scheduleLocalNotification(
        id: 11,
        title: ' Study reminder ',
        body: ' Try a saved cafe nearby. ',
        scheduledAt: scheduledAt,
        payload: 'study-reminder',
      );

      expect(scheduled, isTrue);
      expect(gateway.initializeCount, 1);
      expect(gateway.permissionRequestCount, 1);
      expect(gateway.scheduledPayloads, hasLength(1));
      expect(gateway.scheduledPayloads.single.payload.id, 11);
      expect(gateway.scheduledPayloads.single.payload.title, 'Study reminder');
      expect(
        gateway.scheduledPayloads.single.payload.body,
        'Try a saved cafe nearby.',
      );
      expect(
          gateway.scheduledPayloads.single.payload.payload, 'study-reminder');
      expect(gateway.scheduledPayloads.single.scheduledAt, scheduledAt);
    });

    test('does not schedule when permission is denied', () async {
      final gateway = _FakeNotificationGateway(
        permissionStatus: NotificationPermissionStatus.denied,
      );
      final service = NotificationService(gateway: gateway);

      final scheduled = await service.scheduleLocalNotification(
        id: 12,
        title: 'Study reminder',
        body: 'Try a saved cafe nearby.',
        scheduledAt: DateTime.now().add(const Duration(minutes: 5)),
      );

      expect(scheduled, isFalse);
      expect(gateway.permissionRequestCount, 1);
      expect(gateway.scheduledPayloads, isEmpty);
    });

    test('rejects past scheduled notifications before permission request',
        () async {
      final gateway = _FakeNotificationGateway();
      final service = NotificationService(gateway: gateway);

      final scheduled = await service.scheduleLocalNotification(
        id: 13,
        title: 'Study reminder',
        body: 'Try a saved cafe nearby.',
        scheduledAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );

      expect(scheduled, isFalse);
      expect(gateway.initializeCount, 0);
      expect(gateway.permissionRequestCount, 0);
      expect(gateway.scheduledPayloads, isEmpty);
    });

    test('returns false when gateway scheduling throws', () async {
      final gateway = _FakeNotificationGateway(throwOnSchedule: true);
      final service = NotificationService(gateway: gateway);

      final scheduled = await service.scheduleLocalNotification(
        id: 14,
        title: 'Study reminder',
        body: 'Try a saved cafe nearby.',
        scheduledAt: DateTime.now().add(const Duration(minutes: 5)),
      );

      expect(scheduled, isFalse);
      expect(gateway.permissionRequestCount, 1);
      expect(gateway.scheduledPayloads, isEmpty);
    });
  });
}

class _FakeNotificationGateway implements LocalNotificationGateway {
  _FakeNotificationGateway({
    this.initialized = true,
    this.permissionStatus = NotificationPermissionStatus.granted,
    this.throwOnSchedule = false,
  });

  final bool initialized;
  final NotificationPermissionStatus permissionStatus;
  final bool throwOnSchedule;
  final List<LocalNotificationPayload> shownPayloads =
      <LocalNotificationPayload>[];
  final List<({LocalNotificationPayload payload, DateTime scheduledAt})>
      scheduledPayloads =
      <({LocalNotificationPayload payload, DateTime scheduledAt})>[];
  int initializeCount = 0;
  int permissionRequestCount = 0;

  @override
  Future<bool> initialize() async {
    initializeCount += 1;
    return initialized;
  }

  @override
  Future<NotificationPermissionStatus> requestPermission() async {
    permissionRequestCount += 1;
    return permissionStatus;
  }

  @override
  Future<void> show(LocalNotificationPayload payload) async {
    shownPayloads.add(payload);
  }

  @override
  Future<void> schedule(
    LocalNotificationPayload payload,
    DateTime scheduledAt,
  ) async {
    if (throwOnSchedule) {
      throw StateError('schedule failed');
    }
    scheduledPayloads.add((payload: payload, scheduledAt: scheduledAt));
  }
}

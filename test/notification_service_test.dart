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
  });
}

class _FakeNotificationGateway implements LocalNotificationGateway {
  _FakeNotificationGateway({
    this.initialized = true,
    this.permissionStatus = NotificationPermissionStatus.granted,
  });

  final bool initialized;
  final NotificationPermissionStatus permissionStatus;
  final List<LocalNotificationPayload> shownPayloads =
      <LocalNotificationPayload>[];
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
}

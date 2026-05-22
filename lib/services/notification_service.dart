import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../utils/app_logger.dart';

enum NotificationPermissionStatus {
  granted,
  denied,
  unsupported,
}

class LocalNotificationPayload {
  const LocalNotificationPayload({
    required this.id,
    required this.title,
    required this.body,
    this.payload,
  });

  final int id;
  final String title;
  final String body;
  final String? payload;
}

abstract class LocalNotificationGateway {
  Future<bool> initialize();

  Future<NotificationPermissionStatus> requestPermission();

  Future<void> show(LocalNotificationPayload payload);
}

class FlutterLocalNotificationGateway implements LocalNotificationGateway {
  FlutterLocalNotificationGateway({
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channelId = 'kafeproje_local';
  static const _channelName = 'KafeProje';
  static const _channelDescription = 'Local app notifications';

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<bool> initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: android,
      iOS: darwin,
      macOS: darwin,
      linux: LinuxInitializationSettings(defaultActionName: 'Open'),
      windows: WindowsInitializationSettings(
        appName: 'KafeProje',
        appUserModelId: 'KafeProje.App',
        guid: '2F5C1D95-7C1D-4F7F-8A9D-8C2B452B9E2C',
      ),
    );

    return await _plugin.initialize(settings: settings) ?? false;
  }

  @override
  Future<NotificationPermissionStatus> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted == true
          ? NotificationPermissionStatus.granted
          : NotificationPermissionStatus.denied;
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted == true
          ? NotificationPermissionStatus.granted
          : NotificationPermissionStatus.denied;
    }

    final macos = _plugin.resolvePlatformSpecificImplementation<
        MacOSFlutterLocalNotificationsPlugin>();
    if (macos != null) {
      final granted = await macos.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted == true
          ? NotificationPermissionStatus.granted
          : NotificationPermissionStatus.denied;
    }

    return NotificationPermissionStatus.unsupported;
  }

  @override
  Future<void> show(LocalNotificationPayload payload) {
    const android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const details = NotificationDetails(
      android: android,
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );

    return _plugin.show(
      id: payload.id,
      title: payload.title,
      body: payload.body,
      notificationDetails: details,
      payload: payload.payload,
    );
  }
}

class NotificationService {
  NotificationService({
    LocalNotificationGateway? gateway,
  }) : _gateway = gateway ?? FlutterLocalNotificationGateway();

  final LocalNotificationGateway _gateway;
  Future<bool>? _initializeFuture;

  Future<bool> initialize() {
    return _initializeFuture ??= _initialize();
  }

  Future<bool> _initialize() async {
    try {
      final initialized = await _gateway.initialize();
      if (!initialized) {
        AppLogger.warn(
          'Local notification initialization returned false.',
          key: 'local-notification-init-false',
        );
      }
      return initialized;
    } catch (error, stackTrace) {
      AppLogger.error(
        'Local notification initialization failed',
        error: error,
        stackTrace: stackTrace,
        key: 'local-notification-init-error',
      );
      return false;
    }
  }

  Future<NotificationPermissionStatus> requestPermission() async {
    final initialized = await initialize();
    if (!initialized) {
      return NotificationPermissionStatus.unsupported;
    }

    try {
      return await _gateway.requestPermission();
    } catch (error, stackTrace) {
      AppLogger.error(
        'Local notification permission request failed',
        error: error,
        stackTrace: stackTrace,
        key: 'local-notification-permission-error',
      );
      return NotificationPermissionStatus.denied;
    }
  }

  Future<bool> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    bool requestPermissionIfNeeded = true,
  }) async {
    final normalizedTitle = title.trim();
    final normalizedBody = body.trim();
    if (normalizedTitle.isEmpty || normalizedBody.isEmpty) {
      return false;
    }

    final initialized = await initialize();
    if (!initialized) {
      return false;
    }

    if (requestPermissionIfNeeded) {
      final permission = await requestPermission();
      if (permission != NotificationPermissionStatus.granted) {
        return false;
      }
    }

    try {
      await _gateway.show(
        LocalNotificationPayload(
          id: id,
          title: normalizedTitle,
          body: normalizedBody,
          payload: payload,
        ),
      );
      return true;
    } catch (error, stackTrace) {
      AppLogger.error(
        'Local notification delivery failed',
        error: error,
        stackTrace: stackTrace,
        key: 'local-notification-show-error',
      );
      return false;
    }
  }
}

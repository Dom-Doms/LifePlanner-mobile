import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../data/services/push_api.dart';
import 'local_notification_service.dart';

@pragma('vm:entry-point')
Future<void> lifePlannerFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  try {
    await Firebase.initializeApp();
  } catch (error) {
    debugPrint('[push] Firebase background init skipped: $error');
  }
}

abstract class MobilePushRegistration {
  Future<void> registerCurrentDevice();
  Future<void> deleteCurrentTokenOnLogout();
}

abstract class MobilePushBackend {
  Future<void> registerToken({
    required String token,
    required String platform,
    String? deviceName,
  });

  Future<void> deleteToken(String token);
}

class PushApiMobilePushBackend implements MobilePushBackend {
  PushApiMobilePushBackend(this._pushApi);

  final PushApi _pushApi;

  @override
  Future<void> registerToken({
    required String token,
    required String platform,
    String? deviceName,
  }) async {
    await _pushApi.registerMobileDeviceToken(
      token: token,
      platform: platform,
      deviceName: deviceName,
    );
  }

  @override
  Future<void> deleteToken(String token) {
    return _pushApi.deleteMobileDeviceToken(token);
  }
}

abstract class MobilePushFirebaseGateway {
  Future<bool> initialize();
  Future<bool> requestPermission();
  Future<String?> getToken();
  Stream<String> get onTokenRefresh;
  Stream<MobilePushMessage> get onForegroundMessage;
  Stream<MobilePushMessage> get onNotificationTap;
  Future<MobilePushMessage?> getInitialMessage();
}

class FirebaseMessagingGateway implements MobilePushFirebaseGateway {
  bool _initialized = false;

  @override
  Future<bool> initialize() async {
    if (!_isAndroid) {
      return false;
    }
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(
        lifePlannerFirebaseMessagingBackgroundHandler,
      );
      _initialized = true;
      return true;
    } catch (error) {
      debugPrint('[push] Firebase Messaging non configurato: $error');
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (!_initialized) return false;
    final settings = await FirebaseMessaging.instance.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> getToken() {
    if (!_initialized) return Future.value(null);
    return FirebaseMessaging.instance.getToken();
  }

  @override
  Stream<String> get onTokenRefresh =>
      FirebaseMessaging.instance.onTokenRefresh;

  @override
  Stream<MobilePushMessage> get onForegroundMessage =>
      FirebaseMessaging.onMessage.map(MobilePushMessage.fromRemoteMessage);

  @override
  Stream<MobilePushMessage> get onNotificationTap => FirebaseMessaging
      .onMessageOpenedApp
      .map(MobilePushMessage.fromRemoteMessage);

  @override
  Future<MobilePushMessage?> getInitialMessage() async {
    if (!_initialized) return null;
    final message = await FirebaseMessaging.instance.getInitialMessage();
    return message == null
        ? null
        : MobilePushMessage.fromRemoteMessage(message);
  }
}

abstract class EventReminderNotifier {
  Future<void> showEventReminder(MobilePushMessage message);
}

class LocalEventReminderNotifier implements EventReminderNotifier {
  LocalEventReminderNotifier(this._notifications);

  final LocalNotificationService _notifications;

  @override
  Future<void> showEventReminder(MobilePushMessage message) {
    final eventId = message.data['eventId'] ?? '0';
    return _notifications.show(
      id: eventId.hashCode & 0x7fffffff,
      title: message.title ?? 'LifePlanner',
      body: message.body ?? '',
      vibrate: false,
    );
  }
}

class MobilePushService implements MobilePushRegistration {
  MobilePushService({
    required MobilePushBackend backend,
    required MobilePushFirebaseGateway firebase,
    required EventReminderNotifier notifier,
    required bool Function() isAuthenticated,
  }) : _backend = backend,
       _firebase = firebase,
       _notifier = notifier,
       _isAuthenticated = isAuthenticated;

  final MobilePushBackend _backend;
  final MobilePushFirebaseGateway _firebase;
  final EventReminderNotifier _notifier;
  final bool Function() _isAuthenticated;
  bool _available = false;
  bool _streamsStarted = false;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<MobilePushMessage>? _foregroundSubscription;
  StreamSubscription<MobilePushMessage>? _tapSubscription;

  Future<void> initialize() async {
    _available = await _firebase.initialize();
    if (!_available) {
      return;
    }
    await _firebase.requestPermission();
    _startStreams();
    final initialMessage = await _firebase.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  @override
  Future<void> registerCurrentDevice() async {
    if (!_isAndroid || !_isAuthenticated()) {
      return;
    }
    if (!_available) {
      await initialize();
    }
    if (!_available) {
      return;
    }
    final token = await _firebase.getToken();
    if (token == null || token.isEmpty) {
      return;
    }
    try {
      await _backend.registerToken(
        token: token,
        platform: 'ANDROID',
        deviceName: 'Android',
      );
      debugPrint('[push] mobile FCM token registrato');
    } catch (error) {
      debugPrint('[push] registrazione FCM fallita: $error');
    }
  }

  @override
  Future<void> deleteCurrentTokenOnLogout() async {
    if (!_isAndroid || !_available) {
      return;
    }
    final token = await _firebase.getToken();
    if (token == null || token.isEmpty) {
      return;
    }
    try {
      await _backend.deleteToken(token);
      debugPrint('[push] mobile FCM token disattivato');
    } catch (error) {
      debugPrint('[push] disattivazione FCM fallita: $error');
    }
  }

  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _tapSubscription?.cancel();
  }

  void _startStreams() {
    if (_streamsStarted) {
      return;
    }
    _streamsStarted = true;
    _tokenRefreshSubscription = _firebase.onTokenRefresh.listen((token) async {
      if (!_isAuthenticated()) {
        return;
      }
      try {
        await _backend.registerToken(
          token: token,
          platform: 'ANDROID',
          deviceName: 'Android',
        );
      } catch (error) {
        debugPrint('[push] refresh token FCM non registrato: $error');
      }
    });
    _foregroundSubscription = _firebase.onForegroundMessage.listen(
      _handleForegroundMessage,
    );
    _tapSubscription = _firebase.onNotificationTap.listen(
      _handleNotificationTap,
    );
  }

  Future<void> _handleForegroundMessage(MobilePushMessage message) async {
    if (message.data['type'] != 'EVENT_REMINDER') {
      return;
    }
    await _notifier.showEventReminder(message);
  }

  void _handleNotificationTap(MobilePushMessage message) {
    if (message.data['type'] == 'EVENT_REMINDER') {
      debugPrint(
        '[push] EVENT_REMINDER tap eventId=${message.data['eventId']} date=${message.data['eventDate']}',
      );
    }
  }
}

class MobilePushMessage {
  const MobilePushMessage({required this.data, this.title, this.body});

  final Map<String, String> data;
  final String? title;
  final String? body;

  factory MobilePushMessage.fromRemoteMessage(RemoteMessage message) {
    return MobilePushMessage(
      data: message.data.map(
        (key, value) => MapEntry(key, value?.toString() ?? ''),
      ),
      title: message.notification?.title,
      body: message.notification?.body,
    );
  }
}

bool get _isAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeplanner_mobile/core/notifications/mobile_push_service.dart';

void main() {
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('registers FCM token when user is authenticated', () async {
    final backend = FakeMobilePushBackend();
    final firebase = FakeFirebaseGateway(token: 'fcm-token');
    final service = MobilePushService(
      backend: backend,
      firebase: firebase,
      notifier: FakeEventReminderNotifier(),
      isAuthenticated: () => true,
    );

    await service.registerCurrentDevice();

    expect(backend.registeredTokens, ['fcm-token']);
    expect(backend.platforms, ['ANDROID']);
    await service.dispose();
  });

  test('does not register FCM token when user is unauthenticated', () async {
    final backend = FakeMobilePushBackend();
    final service = MobilePushService(
      backend: backend,
      firebase: FakeFirebaseGateway(token: 'fcm-token'),
      notifier: FakeEventReminderNotifier(),
      isAuthenticated: () => false,
    );

    await service.registerCurrentDevice();

    expect(backend.registeredTokens, isEmpty);
    await service.dispose();
  });

  test('registers refreshed FCM token only while authenticated', () async {
    var authenticated = true;
    final backend = FakeMobilePushBackend();
    final firebase = FakeFirebaseGateway(token: 'initial-token');
    final service = MobilePushService(
      backend: backend,
      firebase: firebase,
      notifier: FakeEventReminderNotifier(),
      isAuthenticated: () => authenticated,
    );

    await service.initialize();
    firebase.emitTokenRefresh('refreshed-token');
    await Future<void>.delayed(Duration.zero);
    authenticated = false;
    firebase.emitTokenRefresh('ignored-token');
    await Future<void>.delayed(Duration.zero);

    expect(backend.registeredTokens, ['refreshed-token']);
    await service.dispose();
  });

  test('foreground EVENT_REMINDER shows local notification', () async {
    final notifier = FakeEventReminderNotifier();
    final firebase = FakeFirebaseGateway(token: 'fcm-token');
    final service = MobilePushService(
      backend: FakeMobilePushBackend(),
      firebase: firebase,
      notifier: notifier,
      isAuthenticated: () => true,
    );

    await service.initialize();
    firebase.emitForegroundMessage(
      const MobilePushMessage(
        data: {'type': 'EVENT_REMINDER', 'eventId': '42'},
        title: 'Allenamento',
        body: 'alle 18:30',
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(notifier.messages.single.data['eventId'], '42');
    await service.dispose();
  });

  test(
    'logout tries to delete token but does not throw on backend failure',
    () async {
      final backend = FakeMobilePushBackend(deleteFails: true);
      final service = MobilePushService(
        backend: backend,
        firebase: FakeFirebaseGateway(token: 'fcm-token'),
        notifier: FakeEventReminderNotifier(),
        isAuthenticated: () => true,
      );

      await service.initialize();
      await service.deleteCurrentTokenOnLogout();

      expect(backend.deletedTokens, ['fcm-token']);
      await service.dispose();
    },
  );
}

class FakeMobilePushBackend implements MobilePushBackend {
  FakeMobilePushBackend({this.deleteFails = false});

  final bool deleteFails;
  final registeredTokens = <String>[];
  final deletedTokens = <String>[];
  final platforms = <String>[];

  @override
  Future<void> registerToken({
    required String token,
    required String platform,
    String? deviceName,
  }) async {
    registeredTokens.add(token);
    platforms.add(platform);
  }

  @override
  Future<void> deleteToken(String token) async {
    deletedTokens.add(token);
    if (deleteFails) {
      throw Exception('network');
    }
  }
}

class FakeFirebaseGateway implements MobilePushFirebaseGateway {
  FakeFirebaseGateway({this.token});

  final String? token;
  final _tokenRefreshController = StreamController<String>.broadcast();
  final _foregroundController = StreamController<MobilePushMessage>.broadcast();
  final _tapController = StreamController<MobilePushMessage>.broadcast();

  @override
  Future<bool> initialize() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<String?> getToken() async => token;

  @override
  Stream<String> get onTokenRefresh => _tokenRefreshController.stream;

  @override
  Stream<MobilePushMessage> get onForegroundMessage =>
      _foregroundController.stream;

  @override
  Stream<MobilePushMessage> get onNotificationTap => _tapController.stream;

  @override
  Future<MobilePushMessage?> getInitialMessage() async => null;

  void emitTokenRefresh(String token) {
    _tokenRefreshController.add(token);
  }

  void emitForegroundMessage(MobilePushMessage message) {
    _foregroundController.add(message);
  }
}

class FakeEventReminderNotifier implements EventReminderNotifier {
  final messages = <MobilePushMessage>[];

  @override
  Future<void> showEventReminder(MobilePushMessage message) async {
    messages.add(message);
  }
}

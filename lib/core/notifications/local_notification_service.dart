import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

class LocalNotificationService {
  LocalNotificationService({MethodChannel? channel})
    : _channel =
          channel ??
          const MethodChannel('lifeplanner_mobile/local_notifications');

  final MethodChannel _channel;

  Future<bool> requestPermission() async {
    try {
      return await _channel.invokeMethod<bool>('requestPermission') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> areNotificationsEnabled() async {
    try {
      return await _channel.invokeMethod<bool>('areNotificationsEnabled') ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> show({
    required int id,
    required String title,
    required String body,
    bool vibrate = false,
  }) async {
    try {
      await _channel.invokeMethod<void>('show', {
        'id': id,
        'title': title,
        'body': body,
        'vibrate': vibrate,
      });
    } on MissingPluginException {
      return;
    }
  }

  Future<void> vibrate() async {
    await _vibrateForeground(pattern: const [0, 180, 80, 180], durationMs: 240);
  }

  Future<void> vibrateForStepCompletion({
    required int currentStepIndex,
    required String type,
  }) async {
    debugPrint(
      'Runner vibration: step completed index=$currentStepIndex type=$type',
    );
    await _vibrateForeground(pattern: const [0, 180, 80, 180], durationMs: 240);
  }

  Future<void> _vibrateForeground({
    required List<int> pattern,
    required int durationMs,
  }) async {
    var packageVibrationStarted = false;
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator != false) {
        final supportsPattern = await Vibration.hasCustomVibrationsSupport();
        if (supportsPattern == true) {
          await Vibration.vibrate(pattern: pattern);
        } else {
          await Vibration.vibrate(duration: durationMs);
        }
        packageVibrationStarted = true;
      }
    } catch (error) {
      debugPrint('Runner vibration: package vibration failed $error');
    }

    if (packageVibrationStarted) return;
    try {
      await _channel.invokeMethod<void>('vibrate');
    } on MissingPluginException {
      return;
    } catch (error) {
      debugPrint('Runner vibration: platform fallback failed $error');
    }
  }
}

import 'package:flutter/services.dart';

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
    try {
      await _channel.invokeMethod<void>('vibrate');
    } on MissingPluginException {
      return;
    }
  }
}

import 'package:flutter/services.dart';

class SessionStorage {
  SessionStorage({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel('lifeplanner_mobile/session_storage');

  final MethodChannel _channel;
  String? _memorySession;

  Future<String?> readSession() async {
    try {
      return await _channel.invokeMethod<String>('read');
    } on MissingPluginException {
      return _memorySession;
    }
  }

  Future<void> writeSession(String value) async {
    _memorySession = value;
    try {
      await _channel.invokeMethod<void>('write', {'value': value});
    } on MissingPluginException {
      return;
    }
  }

  Future<void> clearSession() async {
    _memorySession = null;
    try {
      await _channel.invokeMethod<void>('clear');
    } on MissingPluginException {
      return;
    }
  }
}

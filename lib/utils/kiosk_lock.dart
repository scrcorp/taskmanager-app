import 'package:flutter/services.dart';

class KioskLock {
  static const _channel = MethodChannel('com.tigersplus.app/kiosk');

  static Future<bool> start() async {
    try {
      return await _channel.invokeMethod<bool>('start') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> stop() async {
    try {
      return await _channel.invokeMethod<bool>('stop') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> isLocked() async {
    try {
      return await _channel.invokeMethod<bool>('isLocked') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> moveToBack() async {
    try {
      return await _channel.invokeMethod<bool>('moveToBack') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}

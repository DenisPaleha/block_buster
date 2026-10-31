import 'package:flutter/services.dart';

class NativeBlockerBridge {
  static const MethodChannel _channel = MethodChannel('com.block_buster/native_bridge');

  /// Передает список пакетов для блокировки в SharedPreferences нативного слоя
  static Future<bool> setBlockedPackages(List<String> packages) async {
    try {
      final bool? success = await _channel.invokeMethod('setBlockedPackages', {
        'packages': packages,
      });
      return success ?? false;
    } on PlatformException catch (e) {
      print("Ошибка при передаче заблокированных пакетов: ${e.message}");
      return false;
    }
  }

  /// Начисляет разрешенное время (в секундах) на конкретный пакет
  static Future<int> addAllowedTime(String packageName, int seconds) async {
    try {
      final int? newTime = await _channel.invokeMethod('addAllowedTime', {
        'package': packageName,
        'seconds': seconds,
      });
      return newTime ?? 0;
    } on PlatformException catch (e) {
      print("Ошибка при начислении времени: ${e.message}");
      return 0;
    }
  }

  /// Получает оставшееся разрешенное время (в секундах)
  static Future<int> getTimeLeft(String packageName) async {
    try {
      final int? timeLeft = await _channel.invokeMethod('getTimeLeft', {
        'package': packageName,
      });
      return timeLeft ?? 0;
    } on PlatformException catch (e) {
      print("Ошибка при получении времени: ${e.message}");
      return 0;
    }
  }

  /// Проверяет, включена ли служба Accessibility в настройках телефона
  static Future<bool> isAccessibilityServiceEnabled() async {
    try {
      final bool? isEnabled = await _channel.invokeMethod('isAccessibilityServiceEnabled');
      return isEnabled ?? false;
    } on PlatformException catch (e) {
      print("Ошибка проверки Accessibility: ${e.message}");
      return false;
    }
  }

  /// Открывает системное меню специальных возможностей
  static Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } on PlatformException catch (e) {
      print("Ошибка открытия настроек: ${e.message}");
    }
  }
}
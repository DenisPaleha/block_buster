import 'package:flutter/services.dart';

class NativeBlockerBridge {
  static const MethodChannel _channel = MethodChannel('com.blockbuster/blocker');

  /// Сохранить список блокируемых пакетов в нативный слой
  static Future<void> setBlockedPackages(List<String> packages) async {
    try {
      await _channel.invokeMethod('setBlockedPackages', {
        'packages': packages,
      });
    } on PlatformException catch (e) {
      print("Ошибка при передаче списка пакетов: ${e.message}");
    }
  }

  /// Добавить секунды для конкретного пакета приложения
  static Future<void> addTime(String packageName, int seconds) async {
    try {
      await _channel.invokeMethod('addTime', {
        'packageName': packageName,
        'seconds': seconds,
      });
    } on PlatformException catch (e) {
      print("Ошибка при добавлении времени: ${e.message}");
    }
  }

  /// Получить оставшееся время в секундах
  static Future<int> getTimeLeft(String packageName) async {
    try {
      final int? timeLeft = await _channel.invokeMethod('getTimeLeft', {
        'packageName': packageName,
      });
      return timeLeft ?? 0;
    } on PlatformException catch (e) {
      print("Ошибка при получении времени: ${e.message}");
      return 0;
    }
  }

  /// Проверить, включена ли служба Accessibility
  static Future<bool> isAccessibilityServiceEnabled() async {
    try {
      final bool? enabled = await _channel.invokeMethod('isAccessibilityEnabled');
      return enabled ?? false;
    } on PlatformException catch (e) {
      print("Ошибка проверки службы: ${e.message}");
      return false;
    }
  }

  /// Открыть системные настройки Accessibility для выдачи разрешения
  static Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } on PlatformException catch (e) {
      print("Ошибка открытия настроек: ${e.message}");
    }
  }
}
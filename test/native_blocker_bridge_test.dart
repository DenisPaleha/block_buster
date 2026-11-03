import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:block_buster/services/native_blocker_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('com.blockbuster/blocker');
  final List<MethodCall> log = <MethodCall>[];

  setUp(() {
    log.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      log.add(methodCall);
      switch (methodCall.method) {
        case 'isAccessibilityEnabled':
          return true;
        case 'openAccessibilitySettings':
          return true;
        case 'setBlockedPackages':
          return true;
        case 'getBlockedPackages':
          return ['com.example.app'];
        case 'addTime':
          return true;
        case 'getTimeLeft':
          return 60;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('NativeBlockerBridge contract verification', () async {
    // 1. Проверка прав доступности (фактическое имя метода в классе)
    final isEnabled = await NativeBlockerBridge.isAccessibilityServiceEnabled();
    expect(isEnabled, isTrue);
    expect(log.last.method, 'isAccessibilityEnabled');

    // 2. Открытие настроек
    await NativeBlockerBridge.openAccessibilitySettings();
    expect(log.last.method, 'openAccessibilitySettings');

    // 3. Сохранение списка блокировки
    await NativeBlockerBridge.setBlockedPackages(['com.example.app']);
    expect(log.last.method, 'setBlockedPackages');
    expect(log.last.arguments['packages'], ['com.example.app']);

    // 4. Пополнение банка времени
    await NativeBlockerBridge.addTime('com.example.app', 60);
    expect(log.last.method, 'addTime');
    expect(log.last.arguments['packageName'], 'com.example.app');
    expect(log.last.arguments['seconds'], 60);

    // 5. Запрос остатка времени
    final left = await NativeBlockerBridge.getTimeLeft('com.example.app');
    expect(left, 60);
    expect(log.last.method, 'getTimeLeft');
    expect(log.last.arguments['packageName'], 'com.example.app');
  });
}
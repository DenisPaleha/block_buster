import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SpinnerBluetoothService {
  bool _isRunning = false;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothAdapterState>? _adapterSub;

  int? _lastHardwarePulses;

  final Function(String status) onStatusChanged;
  final Function(int deltaSpins, int totalRaw) onSpinsCaptured;

  SpinnerBluetoothService({
    required this.onStatusChanged,
    required this.onSpinsCaptured,
  });

  void start() async {
    if (_isRunning) return;
    _isRunning = true;

    // Восстанавливаем последний зафиксированный сырой счетчик из памяти
    final prefs = await SharedPreferences.getInstance();
    _lastHardwarePulses = prefs.getInt('last_hw_pulse_count');

    // Следим за состоянием адаптера Bluetooth
    _adapterSub = FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.on) {
        _startScanning();
      } else {
        onStatusChanged("Включите Bluetooth!");
      }
    });

    if (await FlutterBluePlus.adapterState.first == BluetoothAdapterState.on) {
      _startScanning();
    }
  }

  void _startScanning() async {
    if (!_isRunning) return;

    try {
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }

      onStatusChanged("Ожидание вращения спиннера... 📡");

      // Сканируем с низким порогом задержки, чтобы поймать 300 мс окно
      await FlutterBluePlus.startScan(
        androidScanMode: AndroidScanMode.lowLatency,
        continuousUpdates: true,
      );

      _scanSub?.cancel();
      _scanSub = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult r in results) {
          _processScanResult(r);
        }
      });
    } catch (e) {
      onStatusChanged("Ошибка BLE: $e");
    }
  }

  void _processScanResult(ScanResult r) {
    final adv = r.advertisementData;
    final mData = adv.manufacturerData;

    // Проверяем наличие нашего COMPANY_ID = 0xFFFF (65535)
    if (!mData.containsKey(0xFFFF)) return;

    final bytes = mData[0xFFFF];
    if (bytes == null || bytes.length < 4) return;

    // Распаковываем uint32 Little Endian (rawPulseCount)
    final int currentPulses = bytes[0] |
    (bytes[1] << 8) |
    (bytes[2] << 16) |
    (bytes[3] << 24);

    _handleNewPulseCount(currentPulses);
  }

  void _handleNewPulseCount(int currentPulses) async {
    if (_lastHardwarePulses == null) {
      // Первая фиксация после запуска приложения — просто запоминаем точку отсчета
      _lastHardwarePulses = currentPulses;
      _saveLastHwCount(currentPulses);
      onStatusChanged("Спиннер на связи! Базовый отсчёт: $currentPulses");
      return;
    }

    if (currentPulses > _lastHardwarePulses!) {
      // Спиннер крутился: считаем приращение
      final int delta = currentPulses - _lastHardwarePulses!;
      _lastHardwarePulses = currentPulses;
      _saveLastHwCount(currentPulses);

      onStatusChanged("Поймано +$delta об.! (Всего: $currentPulses)");
      onSpinsCaptured(delta, currentPulses);
    } else if (currentPulses < _lastHardwarePulses!) {
      // Произошел сброс (перезагрузка ESP32 или кнопка RESET)
      final int delta = currentPulses; // Считаем всё, что успел накрутить с нуля
      _lastHardwarePulses = currentPulses;
      _saveLastHwCount(currentPulses);

      if (delta > 0) {
        onStatusChanged("Сброс счетчика чипа. Зачтено: +$delta");
        onSpinsCaptured(delta, currentPulses);
      }
    }
  }

  Future<void> _saveLastHwCount(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_hw_pulse_count', count);
  }

  void stop() async {
    _isRunning = false;
    await _scanSub?.cancel();
    await _adapterSub?.cancel();
    if (FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
    }
    onStatusChanged("Сканирование остановлено");
  }

  void dispose() {
    stop();
  }
}
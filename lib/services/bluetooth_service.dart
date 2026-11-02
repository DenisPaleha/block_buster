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

    final prefs = await SharedPreferences.getInstance();
    _lastHardwarePulses = prefs.getInt('last_hw_pulse_count');

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

    // Фильтр 1: Проверяем имя устройства (в эфире или кэше)
    final name = adv.advName.isNotEmpty ? adv.advName : r.device.platformName;
    if (name.isNotEmpty && name != "Smart-Spinner") {
      return;
    }

    final mData = adv.manufacturerData;
    if (!mData.containsKey(0xFFFF)) return;

    final bytes = mData[0xFFFF];
    // ESP32 отправляет ровно 4 байта счетчика pulses
    if (bytes == null || bytes.length < 4) return;

    // Фильтр 2: Безопасная распаковка uint32 Little Endian без знакового расширения
    final int currentPulses = (
        (bytes[0] & 0xFF) |
        ((bytes[1] & 0xFF) << 8) |
        ((bytes[2] & 0xFF) << 16) |
        ((bytes[3] & 0xFF) << 24)
    ) & 0xFFFFFFFF;

    _handleNewPulseCount(currentPulses);
  }

  void _handleNewPulseCount(int currentPulses) async {
    if (_lastHardwarePulses == null) {
      _lastHardwarePulses = currentPulses;
      _saveLastHwCount(currentPulses);
      onStatusChanged("Спиннер обнаружен! Базовый отсчёт: $currentPulses");
      return;
    }

    if (currentPulses > _lastHardwarePulses!) {
      final int delta = currentPulses - _lastHardwarePulses!;

      // Фильтр 3: Sanity Check — спиннер за 3 секунды физически не сделает > 500 оборотов
      if (delta > 500) {
        onStatusChanged("Отброшен шум эфира: +$delta об.");
        // Синхронизируем базовую точку, не начисляя паразитные миллиарды
        _lastHardwarePulses = currentPulses;
        _saveLastHwCount(currentPulses);
        return;
      }

      _lastHardwarePulses = currentPulses;
      _saveLastHwCount(currentPulses);

      onStatusChanged("Поймано +$delta об.! (Всего: $currentPulses)");
      onSpinsCaptured(delta, currentPulses);

    } else if (currentPulses < _lastHardwarePulses!) {
      // Сброс контроллера при перезагрузке ESP32
      final int delta = currentPulses;
      _lastHardwarePulses = currentPulses;
      _saveLastHwCount(currentPulses);

      if (delta > 0 && delta <= 500) {
        onStatusChanged("Сброс чипа. Зачтено: +$delta");
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
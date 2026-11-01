import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/app_picker_screen.dart';
import 'screens/convert_wallet_screen.dart';
import 'widgets/permission_banner.dart';
import 'services/bluetooth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: HomeScreen(),
  ));
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _availableSpins = 0;
  String _bleStatus = "Инициализация...";
  late SpinnerBluetoothService _bleService;

  @override
  void initState() {
    super.initState();
    _loadSavedSpins();

    _bleService = SpinnerBluetoothService(
      onStatusChanged: (status) {
        if (mounted) setState(() => _bleStatus = status);
      },
      onSpinsCaptured: (delta, totalRaw) {
        _addSpins(delta);
      },
    );

    _bleService.start();
  }

  @override
  void dispose() {
    _bleService.dispose();
    super.dispose();
  }

  Future<void> _loadSavedSpins() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _availableSpins = prefs.getInt('bank_available_spins') ?? 0;
    });
  }

  Future<void> _addSpins(int delta) async {
    final prefs = await SharedPreferences.getInstance();
    final newBalance = _availableSpins + delta;
    await prefs.setInt('bank_available_spins', newBalance);
    if (mounted) {
      setState(() {
        _availableSpins = newBalance;
      });
    }
  }

  Future<void> _updateSpins(int newBalance) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('bank_available_spins', newBalance);
    if (mounted) {
      setState(() {
        _availableSpins = newBalance;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Block Buster'),
        actions: [
          IconButton(
            icon: const Icon(Icons.app_blocking_outlined),
            tooltip: 'Выбрать приложения',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AppPickerScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const AccessibilityPermissionBanner(),

          // Плашка со статусом BLE эфира
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.bluetooth_searching, size: 20, color: Colors.blueGrey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _bleStatus,
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.rotate_right_rounded, size: 80, color: Colors.blueAccent),
                  const SizedBox(height: 12),
                  const Text('Баланс оборотов:', style: TextStyle(fontSize: 16, color: Colors.grey)),
                  Text(
                    '$_availableSpins',
                    style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    ),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ConvertWalletScreen(
                            availableSpins: _availableSpins,
                            onSpinsSpent: (spent) {
                              _updateSpins(_availableSpins - spent);
                            },
                          ),
                        ),
                      );
                      _loadSavedSpins(); // Обновляем при возврате из кошелька
                    },
                    icon: const Icon(Icons.currency_exchange),
                    label: const Text('Конвертировать в минуты'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
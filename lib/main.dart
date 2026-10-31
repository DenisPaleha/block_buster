import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/app_picker_screen.dart';
import 'screens/convert_wallet_screen.dart';
import 'widgets/permission_banner.dart';

void main() {
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

  @override
  void initState() {
    super.initState();
    _loadSavedSpins();
  }

  Future<void> _loadSavedSpins() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _availableSpins = prefs.getInt('bank_available_spins') ?? 0;
    });
  }

  Future<void> _updateSpins(int newBalance) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('bank_available_spins', newBalance);
    setState(() {
      _availableSpins = newBalance;
    });
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
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ConvertWalletScreen(
                          availableSpins: _availableSpins,
                          onSpinsSpent: (spent) {
                            _updateSpins(_availableSpins - spent);
                          },
                        ),
                      ),
                    ),
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
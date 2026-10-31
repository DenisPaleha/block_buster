import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/native_blocker_bridge.dart';

class AppPickerScreen extends StatefulWidget {
  const AppPickerScreen({Key? key}) : super(key: key);

  @override
  State<AppPickerScreen> createState() => _AppPickerScreenState();
}

class _AppPickerScreenState extends State<AppPickerScreen> {
  List<AppInfo> _installedApps = [];
  Set<String> _selectedPackages = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAppsAndSelection();
  }

  Future<void> _loadAppsAndSelection() async {
    // 1. Загружаем сохраненный список заблокированных пакетов
    final prefs = await SharedPreferences.getInstance();
    final savedList = prefs.getStringList('saved_blocked_packages') ?? [];
    _selectedPackages = savedList.toSet();

    // 2. Получаем список приложений (исключая системные, только с лаунчером)
    final apps = await InstalledApps.getInstalledApps(
      excludeSystemApps: true,
      withIcon: true,
    );

    setState(() {
      _installedApps = apps;
      _isLoading = false;
    });
  }

  Future<void> _toggleApp(String packageName) async {
    setState(() {
      if (_selectedPackages.contains(packageName)) {
        _selectedPackages.remove(packageName);
      } else {
        _selectedPackages.add(packageName);
      }
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('saved_blocked_packages', _selectedPackages.toList());

    // Синхронизируем с нативным Kotlin-сервисом
    await NativeBlockerBridge.setBlockedPackages(_selectedPackages.toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Блокируемые приложения'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: _installedApps.length,
        itemBuilder: (context, index) {
          final app = _installedApps[index];
          final isBlocked = _selectedPackages.contains(app.packageName);

          return CheckboxListTile(
            value: isBlocked,
            onChanged: (_) => _toggleApp(app.packageName),
            title: Text(app.name),
            subtitle: Text(app.packageName),
            secondary: app.icon != null
                ? Image.memory(app.icon!, width: 40, height: 40)
                : const Icon(Icons.android),
          );
        },
      ),
    );
  }
}
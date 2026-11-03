import 'dart:async';
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
  String? _errorMessage;

  // Пакеты, которые категорически нельзя блокировать во избежание софт-лока устройства
  static const Set<String> _criticalPackages = {
    'com.blockbuster',
    'com.android.settings',
    'com.android.systemui',
    'com.google.android.packageinstaller',
    'com.android.packageinstaller',
  };

  @override
  void initState() {
    super.initState();
    _loadAppsAndSelection();
  }

  Future<void> _loadAppsAndSelection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedList = prefs.getStringList('saved_blocked_packages') ?? [];
      _selectedPackages = savedList.toSet();

      if (_selectedPackages.isNotEmpty) {
        await NativeBlockerBridge.setBlockedPackages(_selectedPackages.toList());
      }

      // excludeSystemApps: false позволяет загрузить предустановленный софт (YouTube, Chrome и т.д.)
      final apps = await InstalledApps.getInstalledApps(
        excludeSystemApps: false,
        withIcon: true,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException("Таймаут получения приложений"),
      );

      // Фильтруем: отсекаем критические настройки, сам Block Buster и рабочие столы (лаунчеры)
      final filtered = apps.where((app) {
        final pkg = app.packageName.toLowerCase();
        if (_criticalPackages.contains(pkg)) return false;
        if (pkg.contains('launcher') || pkg.contains('home')) return false;
        return true;
      }).toList();

      filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (mounted) {
        setState(() {
          _installedApps = filtered;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Ошибка загрузки приложений: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Не удалось загрузить список приложений. Проверьте разрешения.";
        });
      }
    }
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
          : _errorMessage != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });
                  _loadAppsAndSelection();
                },
                child: const Text('Повторить'),
              )
            ],
          ),
        ),
      )
          : _installedApps.isEmpty
          ? const Center(child: Text('Приложения не найдены'))
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
            secondary: app.icon != null && app.icon!.isNotEmpty
                ? Image.memory(
              app.icon!,
              width: 40,
              height: 40,
              errorBuilder: (_, __, ___) => const Icon(Icons.android),
            )
                : const Icon(Icons.android),
          );
        },
      ),
    );
  }
}
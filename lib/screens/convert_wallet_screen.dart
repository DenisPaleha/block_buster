import 'dart:async';
import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/native_blocker_bridge.dart';

class ConvertWalletScreen extends StatefulWidget {
  final int availableSpins;
  final Function(int spent) onSpinsSpent;

  const ConvertWalletScreen({
    Key? key,
    required this.availableSpins,
    required this.onSpinsSpent,
  }) : super(key: key);

  @override
  State<ConvertWalletScreen> createState() => _ConvertWalletScreenState();
}

class _ConvertWalletScreenState extends State<ConvertWalletScreen> with WidgetsBindingObserver {
  List<AppInfo> _blockedAppsInfo = [];
  Map<String, int> _remainingSecondsMap = {};
  bool _isLoading = true;
  late int _currentSpins;

  @override
  void initState() {
    super.initState();
    _currentSpins = widget.availableSpins;
    WidgetsBinding.instance.addObserver(this);
    _loadBlockedApps();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Обновляем остаток банка, когда пользователь возвращается в окно приложения
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadBlockedApps();
    }
  }

  Future<void> _loadBlockedApps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> blockedPackages = prefs.getStringList('saved_blocked_packages') ??
          prefs.getStringList('blocked_packages') ??
          [];

      if (blockedPackages.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final allApps = await InstalledApps.getInstalledApps(
        excludeSystemApps: false,
        withIcon: true,
      );

      final filtered = allApps
          .where((app) => blockedPackages.contains(app.packageName))
          .toList();

      Map<String, int> times = {};
      for (var app in filtered) {
        try {
          times[app.packageName] = await NativeBlockerBridge.getTimeLeft(app.packageName)
              .timeout(const Duration(seconds: 1), onTimeout: () => 0);
        } catch (_) {
          times[app.packageName] = 0;
        }
      }

      if (mounted) {
        setState(() {
          _blockedAppsInfo = filtered;
          _remainingSecondsMap = times;
        });
      }
    } catch (e) {
      debugPrint("Ошибка обновления данных: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addTimeToApp(String packageName, int secondsToAdd, int costSpins) async {
    if (_currentSpins < costSpins) return;

    await NativeBlockerBridge.addTime(packageName, secondsToAdd);
    widget.onSpinsSpent(costSpins);

    int updatedTime = 0;
    try {
      updatedTime = await NativeBlockerBridge.getTimeLeft(packageName)
          .timeout(const Duration(seconds: 1), onTimeout: () => 0);
    } catch (_) {
      updatedTime = (_remainingSecondsMap[packageName] ?? 0) + secondsToAdd;
    }

    if (mounted) {
      setState(() {
        _currentSpins -= costSpins;
        _remainingSecondsMap[packageName] = updatedTime;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Добавлено ${secondsToAdd ~/ 60} мин! Списано $costSpins об.'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  String _formatTime(int totalSeconds) {
    if (totalSeconds <= 0) return 'Заблокировано';
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes мин ${seconds.toString().padLeft(2, '0')} сек';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Конвертация оборотов'),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Доступно оборотов:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                Text(
                  '$_currentSpins',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _blockedAppsInfo.isEmpty
                ? const Center(
              child: Text(
                'Нет заблокированных приложений.\nДобавьте их на главном экране.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            )
                : ListView.separated(
              itemCount: _blockedAppsInfo.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final app = _blockedAppsInfo[index];
                final timeLeft = _remainingSecondsMap[app.packageName] ?? 0;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          (app.icon != null && app.icon!.isNotEmpty)
                              ? Image.memory(
                            app.icon!,
                            width: 40,
                            height: 40,
                            errorBuilder: (_, __, ___) => const Icon(Icons.android, size: 40),
                          )
                              : const Icon(Icons.android, size: 40),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  app.name ?? app.packageName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Осталось: ${_formatTime(timeLeft)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: timeLeft > 0 ? Colors.green.shade700 : Colors.red.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 6.0,
                        children: [
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onPressed: _currentSpins >= 100
                                ? () => _addTimeToApp(app.packageName, 60, 100)
                                : null,
                            child: const Text('+1 мин (100 об.)', style: TextStyle(fontSize: 12)),
                          ),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onPressed: _currentSpins >= 300
                                ? () => _addTimeToApp(app.packageName, 180, 300)
                                : null,
                            child: const Text('+3 мин (300 об.)', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
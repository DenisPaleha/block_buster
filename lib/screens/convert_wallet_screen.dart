import 'dart:async';
import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/native_blocker_bridge.dart';

class ConvertWalletScreen extends StatefulWidget {
  final int availableSpins;
  final Function(int spentSpins) onSpinsSpent;

  const ConvertWalletScreen({
    Key? key,
    required this.availableSpins,
    required this.onSpinsSpent,
  }) : super(key: key);

  @override
  State<ConvertWalletScreen> createState() => _ConvertWalletScreenState();
}

class _ConvertWalletScreenState extends State<ConvertWalletScreen> {
  List<AppInfo> _blockedAppsInfo = [];
  Map<String, int> _remainingSecondsMap = {};
  bool _isLoading = true;
  Timer? _refreshTimer;

  // Курс: 100 оборотов = 1 минута (60 секунд)
  final int spinsPerMinute = 100;

  @override
  void initState() {
    super.initState();
    _loadBlockedApps();
    // Обновляем таймер оставшегося времени каждые 3 секунды для актуальности UI
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) => _refreshTimes());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadBlockedApps() async {
    final prefs = await SharedPreferences.getInstance();
    final blockedPackages = prefs.getStringList('saved_blocked_packages') ?? [];

    if (blockedPackages.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // Получаем список приложений в переменную allApps
    final allApps = await InstalledApps.getInstalledApps(
      excludeSystemApps: true,
      withIcon: true,
    );

    // Фильтруем только заблокированные
    final filtered = allApps.where((app) => blockedPackages.contains(app.packageName)).toList();

    Map<String, int> times = {};
    for (var app in filtered) {
      times[app.packageName] = await NativeBlockerBridge.getTimeLeft(app.packageName);
    }

    if (mounted) {
      setState(() {
        _blockedAppsInfo = filtered;
        _remainingSecondsMap = times;
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshTimes() async {
    for (var app in _blockedAppsInfo) {
      final left = await NativeBlockerBridge.getTimeLeft(app.packageName);
      _remainingSecondsMap[app.packageName] = left;
    }
    if (mounted) setState(() {});
  }

  Future<void> _exchangeSpinsForTime(AppInfo app, int minutes) async {
    final neededSpins = minutes * spinsPerMinute;

    if (widget.availableSpins < neededSpins) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Нужно $neededSpins оборотов! Накрутите спиннером ещё.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final addedSeconds = minutes * 60;
    final newTotalSec = await NativeBlockerBridge.addAllowedTime(app.packageName, addedSeconds);

    // Списываем обороты из основного баланса спиннера
    widget.onSpinsSpent(neededSpins);

    setState(() {
      _remainingSecondsMap[app.packageName] = newTotalSec;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Успешно добавлено $minutes мин. для ${app.name}!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _formatSeconds(int totalSec) {
    if (totalSec <= 0) return 'Заблокировано';
    final min = totalSec ~/ 60;
    final sec = totalSec % 60;
    return '$min мин $sec сек';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Обмен оборотов на время'),
      ),
      body: Column(
        children: [
          // Виджет текущего баланса
          Card(
            margin: const EdgeInsets.all(16),
            color: Colors.blueGrey.shade900,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Доступно оборотов', style: TextStyle(color: Colors.white70)),
                      Text('Со спиннера', style: TextStyle(color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                  Text(
                    '${widget.availableSpins}',
                    style: const TextStyle(
                      color: Colors.amberAccent,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _blockedAppsInfo.isEmpty
                ? const Center(
              child: Text(
                'Сначала выберите приложения в списке блокировки',
                style: TextStyle(color: Colors.grey),
              ),
            )
                : ListView.builder(
              itemCount: _blockedAppsInfo.length,
              itemBuilder: (context, index) {
                final app = _blockedAppsInfo[index];
                final timeLeft = _remainingSecondsMap[app.packageName] ?? 0;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: app.icon != null
                              ? Image.memory(app.icon!, width: 44, height: 44)
                              : const Icon(Icons.android),
                          title: Text(app.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Осталось: ${_formatSeconds(timeLeft)}'),
                        ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton(
                              onPressed: () => _exchangeSpinsForTime(app, 5),
                              child: const Text('+5 мин (500 об.)'),
                            ),
                            ElevatedButton(
                              onPressed: () => _exchangeSpinsForTime(app, 15),
                              child: const Text('+15 мин (1500 об.)'),
                            ),
                          ],
                        ),
                      ],
                    ),
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
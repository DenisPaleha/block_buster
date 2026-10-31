import 'package:flutter/material.dart';
import '../services/native_blocker_bridge.dart';

class AccessibilityPermissionBanner extends StatefulWidget {
  const AccessibilityPermissionBanner({Key? key}) : super(key: key);

  @override
  State<AccessibilityPermissionBanner> createState() => _AccessibilityPermissionBannerState();
}

class _AccessibilityPermissionBannerState extends State<AccessibilityPermissionBanner> with WidgetsBindingObserver {
  bool _isEnabled = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Когда пользователь возвращается из системных настроек обратно в приложение, перепроверяем статус
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
    }
  }

  Future<void> _checkPermission() async {
    final enabled = await NativeBlockerBridge.isAccessibilityServiceEnabled();
    if (mounted) {
      setState(() {
        _isEnabled = enabled;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isEnabled) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Служба блокировки выключена',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Чтобы приложения блокировались автоматически, включите "Block Buster" в меню специальных возможностей.',
            style: TextStyle(fontSize: 13, color: Colors.black87),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade800,
                foregroundColor: Colors.white,
              ),
              onPressed: () => NativeBlockerBridge.openAccessibilitySettings(),
              icon: const Icon(Icons.settings, size: 18),
              label: const Text('Включить в настройках'),
            ),
          )
        ],
      ),
    );
  }
}
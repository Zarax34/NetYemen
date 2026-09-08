// lib/screens/networks/networks_screen.dart
import 'package:flutter/material.dart';
import '../../widgets/coming_soon.dart';

/// F-OWN-01/02/03/07/08 (تسجيل الشبكة، الملف والموقع، الباقات، تفويض
/// الموظفين، ربط SSID متعددة) — تُبنى في موجة لاحقة.
class NetworksScreen extends StatelessWidget {
  const NetworksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('شبكاتي')),
      body: const ComingSoon(
        icon: Icons.wifi_rounded,
        message: 'إدارة الشبكات والباقات — قريباً',
      ),
    );
  }
}

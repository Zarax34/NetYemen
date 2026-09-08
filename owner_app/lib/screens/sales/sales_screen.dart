// lib/screens/sales/sales_screen.dart
import 'package:flutter/material.dart';
import '../../widgets/coming_soon.dart';

/// F-OWN-06 (تحليلات المبيعات وتقارير التسوية) — تُبنى في موجة لاحقة عبر
/// `get_owner_commercial_summary`/`get_owner_settlements`.
class SalesScreen extends StatelessWidget {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المبيعات')),
      body: const ComingSoon(
        icon: Icons.point_of_sale_outlined,
        message: 'تحليلات المبيعات والتسويات — قريباً',
      ),
    );
  }
}

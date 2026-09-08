// lib/screens/inventory/inventory_screen.dart
import 'package:flutter/material.dart';
import '../../widgets/coming_soon.dart';

/// F-OWN-04/05 (رفع دفعات الكروت، والتحكم الفوري بالمخزون) — تُبنى في موجة
/// لاحقة عبر `admin_ingest_card_vault_batch`/`admin_list_card_vault_metadata`.
class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المخزون')),
      body: const ComingSoon(
        icon: Icons.inventory_2_outlined,
        message: 'رفع الكروت والتحكم بالمخزون — قريباً',
      ),
    );
  }
}

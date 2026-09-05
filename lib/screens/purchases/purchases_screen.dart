// lib/screens/purchases/purchases_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../utils/app_theme.dart';

class PurchasesScreen extends ConsumerWidget {
  const PurchasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchasesAsync = ref.watch(userPurchasesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('مشترياتي'),
      ),
      body: purchasesAsync.when(
        data: (purchases) {
          if (purchases.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 64,
                    color: AppTheme.textMuted,
                  ),
                  SizedBox(height: 16),
                  Text('لا توجد مشتريات حالياً'),
                  SizedBox(height: 8),
                  Text(
                    'ابدأ بشراء كرت من شبكة متاحة',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: purchases.length,
            itemBuilder: (context, index) {
              final purchase = purchases[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor:
                                AppTheme.primary.withValues(alpha: 0.1),
                            child: Text(
                              purchase.networkName?.isNotEmpty == true
                                  ? purchase.networkName![0]
                                  : '?',
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  purchase.networkName ?? 'شبكة غير معروفة',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  purchase.formattedDate,
                                  style: const TextStyle(
                                      color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${purchase.amountPaid} ر.ي',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          const Icon(
                            Icons.lock_outline,
                            size: 18,
                            color: AppTheme.textMuted,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              purchase.packageName ?? 'باقة',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('حدث خطأ')),
      ),
    );
  }
}

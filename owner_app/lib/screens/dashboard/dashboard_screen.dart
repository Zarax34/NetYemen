// lib/screens/dashboard/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/owned_network_model.dart';
import '../../providers/owner_providers.dart';
import '../../utils/app_theme.dart';
import '../auth/login_screen.dart';

/// الشاشة الرئيسية: قائمة شبكات المالك الحالي عبر [ownedNetworksProvider].
///
/// هذا هو المحتوى الحقيقي الوحيد في هذه الموجة؛ باقي التبويبات شاشات مؤقتة.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    await ref.read(ownerServiceProvider).signOut();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final networksAsync = ref.watch(ownedNetworksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('شبكاتي'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'تسجيل الخروج',
            onPressed: () => _signOut(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(ownedNetworksProvider.future),
        child: networksAsync.when(
          data: (networks) {
            if (networks.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Icon(Icons.wifi_off_rounded, size: 64, color: AppTheme.textMuted),
                  SizedBox(height: 16),
                  Center(child: Text('لا توجد شبكات مسجَّلة باسمك بعد')),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: networks.length,
              itemBuilder: (context, index) => _NetworkCard(network: networks[index]),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 120),
              Center(child: Text('تعذّر تحميل شبكاتك. اسحب للأسفل للمحاولة مرة أخرى.')),
            ],
          ),
        ),
      ),
    );
  }
}

class _NetworkCard extends StatelessWidget {
  final OwnedNetwork network;

  const _NetworkCard({required this.network});

  Color _statusColor() {
    switch (network.status) {
      case 'active':
        return AppTheme.accentDark;
      case 'suspended':
      case 'rejected':
        return AppTheme.error;
      default:
        return AppTheme.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
              child: Text(
                network.commercialName.isNotEmpty ? network.commercialName[0] : '؟',
                style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          network.commercialName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (network.isVerified) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.verified, size: 16, color: AppTheme.info),
                      ],
                    ],
                  ),
                  if (network.locationText.isNotEmpty)
                    Text(
                      network.locationText,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor().withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                network.status,
                style: TextStyle(color: _statusColor(), fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

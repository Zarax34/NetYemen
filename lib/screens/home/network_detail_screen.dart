// lib/screens/home/network_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/network_model.dart';
import '../../providers/app_providers.dart';
import '../../utils/app_theme.dart';
import 'purchase_success_screen.dart';

class NetworkDetailScreen extends ConsumerStatefulWidget {
  final Network network;

  const NetworkDetailScreen({super.key, required this.network});

  @override
  ConsumerState<NetworkDetailScreen> createState() =>
      _NetworkDetailScreenState();
}

class _NetworkDetailScreenState extends ConsumerState<NetworkDetailScreen> {
  NetworkPackage? _selected;
  bool _isPurchasing = false;

  /// مفتاح تكرار ثابت لمحاولة الشراء الحالية.
  ///
  /// يُولَّد مرة عند اختيار الباقة لا عند كل ضغطة، حتى تُرجع إعادة الإرسال
  /// بعد انقطاع الشبكة العملية الأولى بدل خصم المبلغ مرتين.
  String? _idempotencyKey;

  void _select(NetworkPackage package) {
    setState(() {
      _selected = package;
      _idempotencyKey = const Uuid().v4();
    });
  }

  Future<void> _purchase() async {
    final package = _selected;
    final key = _idempotencyKey;
    if (package == null || key == null) return;

    if (ref.read(walletBalanceProvider) < package.price) {
      _showError('رصيد غير كافٍ في المحفظة');
      return;
    }

    setState(() => _isPurchasing = true);

    try {
      final service = ref.read(supabaseServiceProvider);
      final result = await service.purchasePackage(
        packageId: package.id,
        idempotencyKey: key,
      );

      // الرصيد والمشتريات تغيّرا على الخادم.
      ref.invalidate(userProfileProvider);
      ref.invalidate(userPurchasesProvider);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PurchaseSuccessScreen(
            purchaseId: result.purchaseId,
            packageName: package.name,
            amountPaid: result.amountPaid,
            networkName: widget.network.commercialName,
          ),
        ),
      );
    } catch (e) {
      _showError(_purchaseErrorText(e));
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  /// يترجم أخطاء `purchase_package` المعروفة إلى رسائل مفهومة.
  String _purchaseErrorText(Object e) {
    final raw = e.toString();
    if (raw.contains('INSUFFICIENT_BALANCE')) return 'رصيد غير كافٍ في المحفظة';
    if (raw.contains('OUT_OF_STOCK') || raw.contains('NO_CARD')) {
      return 'نفدت كروت هذه الباقة، جرّب باقة أخرى';
    }
    if (raw.contains('WALLET_ACCOUNT_MISSING')) {
      return 'لم يتم إنشاء محفظتك بعد، أعد تسجيل الدخول';
    }
    if (raw.contains('PACKAGE_NOT_AVAILABLE') || raw.contains('NOT_PUBLIC')) {
      return 'هذه الباقة لم تعد متاحة';
    }
    return 'فشلت عملية الشراء: $raw';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final packagesAsync = ref.watch(networkPackagesProvider(widget.network.id));

    return Scaffold(
      appBar: AppBar(title: Text(widget.network.commercialName)),
      body: Column(
        children: [
          _header(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'اختر الباقة',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: packagesAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(
                        child: Text(
                          'تعذّر تحميل الباقات\n$e',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                      data: (packages) => packages.isEmpty
                          ? const Center(
                              child: Text(
                                'لا توجد باقات معروضة لهذه الشبكة حالياً',
                                style: TextStyle(color: AppTheme.textSecondary),
                              ),
                            )
                          : ListView.separated(
                              itemCount: packages.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (_, i) => _packageTile(packages[i]),
                            ),
                    ),
                  ),
                  if (_selected != null) _buyButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: AppTheme.primary,
      width: double.infinity,
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white,
            child: Text(
              widget.network.commercialName.isNotEmpty
                  ? widget.network.commercialName[0]
                  : '?',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.network.commercialName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.network.isVerified) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.verified_user_rounded,
                        color: Colors.greenAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'موثّقة',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  widget.network.locationText,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _packageTile(NetworkPackage package) {
    final isSelected = _selected?.id == package.id;
    final details = [package.durationText, package.speedText]
        .where((t) => t.isNotEmpty)
        .join(' - ');
    final currencyLabel = package.currency == 'YER' ? 'ر.ي' : package.currency;

    return InkWell(
      onTap: () => _select(package),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    package.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      details,
                      style: TextStyle(
                        fontSize: 13,
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.8)
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              '${package.price} $currencyLabel',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : AppTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buyButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: _isPurchasing ? null : _purchase,
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
          child: _isPurchasing
              ? const CircularProgressIndicator(color: Colors.white)
              : Text('شراء - ${_selected!.price} ر.ي'),
        ),
      ),
    );
  }
}

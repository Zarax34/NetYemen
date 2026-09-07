// lib/screens/home/purchase_success_screen.dart
import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../widgets/card_pin_reveal.dart';

/// تأكيد الشراء.
///
/// يعرض رقم الكرت مموّهاً افتراضياً؛ اللمس يستدعي `reveal_purchase_card_secret`
/// (يفكّ التشفير داخل قاعدة البيانات ويسجّل حدث تدقيق) ويكشف الرقم صريحاً
/// لصاحب الشراء فقط، مع زر نسخ.
class PurchaseSuccessScreen extends StatelessWidget {
  final String purchaseId;
  final String packageName;
  final int amountPaid;
  final String networkName;

  const PurchaseSuccessScreen({
    super.key,
    required this.purchaseId,
    required this.packageName,
    required this.amountPaid,
    required this.networkName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  size: 60,
                  color: AppTheme.accent,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'تم الشراء بنجاح!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '$networkName - $packageName',
                style: const TextStyle(color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'خُصم $amountPaid ر.ي من محفظتك',
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.accent),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.confirmation_number_outlined, color: AppTheme.accentDark),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'رقم الكرت',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    CardPinReveal(purchaseId: purchaseId),
                    const SizedBox(height: 12),
                    SelectableText(
                      'رقم العملية: $purchaseId',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  child: const Text('تم'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

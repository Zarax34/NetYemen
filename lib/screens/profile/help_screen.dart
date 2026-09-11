// lib/screens/profile/help_screen.dart
import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';

/// شاشة المساعدة — محتوى ثابت (FAQ وطرق التواصل).
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المساعدة'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildFaqCard(
            context,
            question: 'كيف أشحن محفظتي؟',
            answer:
                'اذهب إلى قسم المحفظة ← شحن الرصيد ← اختر جهة الدفع ← أدخل المبلغ ورقم الحوالة ← أرسل الطلب.\n'
                'ستتم مراجعة طلبك وإضافة الرصيد خلال ساعات العمل.',
          ),
          _buildFaqCard(
            context,
            question: 'كيف أشتري كرت إنترنت؟',
            answer:
                'اختر شبكة من الصفحة الرئيسية ← اختر الباقة المناسبة ← اضغط شراء.\n'
                'سيُخصم المبلغ من رصيد محفظتك وسيظهر الكرت في مشترياتي.',
          ),
          _buildFaqCard(
            context,
            question: 'كيف أكشف رقم الكرت (PIN)؟',
            answer:
                'اذهب إلى مشترياتي ← اضغط على العملية ← اضغط "كشف الرقم".\n'
                'سيظهر رقم الكرت مرة واحدة ويمكنك نسخه.',
          ),
          _buildFaqCard(
            context,
            question: 'ماذا لو لم يعمل الكرت؟',
            answer:
                'تواصل معنا عبر واتساب خلال 30 دقيقة من كشف الرقم.\n'
                'سنراجع الكرت مع صاحب الشبكة وسنعوّضك إذا ثبت العطل.',
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.support_agent_outlined, size: 40, color: AppTheme.primary),
                  const SizedBox(height: 12),
                  Text(
                    'تواصل معنا',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'للمساعدة أو الاستفسارات، تواصل معنا عبر واتساب.\n'
                    'لا نقبل أي عمليات مالية عبر واتساب.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqCard(
    BuildContext context, {
    required String question,
    required String answer,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: const Icon(Icons.help_outline, color: AppTheme.primary),
        title: Text(
          question,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              answer,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

// lib/screens/profile/about_screen.dart
import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';

/// شاشة عن التطبيق — معلومات ثابتة.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('عن التطبيق'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.wifi_rounded, size: 40, color: Colors.white),
              ),
              const SizedBox(height: 24),
              Text(
                'NetYemen',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'الإصدار 1.0.0',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Text(
                'منصة رقمية لشراء كروت الإنترنت من شبكات الواي فاي المحلية في اليمن.\n\n'
                'اشحن محفظتك، اختر شبكة قريبة منك، واشترِ باقة الإنترنت المناسبة بسهولة وأمان.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Text(
                '© ${DateTime.now().year} NetYemen',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

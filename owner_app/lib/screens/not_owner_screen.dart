// lib/screens/not_owner_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/owner_providers.dart';
import '../utils/app_theme.dart';
import 'auth/login_screen.dart';

/// تُعرض حين تنجح المصادقة لكن `get_owned_networks()` تعود فارغة — أي أن
/// المستخدم ليس صاحب شبكة. تسجّل خروجه فوراً؛ لا يبقى مصادَقاً في تطبيق
/// ليس له فيه دور.
class NotOwnerScreen extends ConsumerStatefulWidget {
  const NotOwnerScreen({super.key});

  @override
  ConsumerState<NotOwnerScreen> createState() => _NotOwnerScreenState();
}

class _NotOwnerScreenState extends ConsumerState<NotOwnerScreen> {
  @override
  void initState() {
    super.initState();
    // تسجيل خروج فوري: هذا التطبيق ليس مكاناً لحساب بلا شبكات مملوكة.
    ref.read(ownerServiceProvider).signOut();
  }

  void _backToLogin() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

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
              const Icon(
                Icons.block_outlined,
                size: 72,
                color: AppTheme.warning,
              ),
              const SizedBox(height: 24),
              const Text(
                'حسابك ليس صاحب شبكة',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'هذا التطبيق مخصّص لأصحاب الشبكات المسجَّلين فقط. '
                'إن كنت تريد شراء كروت إنترنت فاستخدم تطبيق NetYemen للعملاء.',
                style: TextStyle(color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _backToLogin,
                  child: const Text('العودة لتسجيل الدخول'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

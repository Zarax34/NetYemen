// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/app_theme.dart';
import '../providers/owner_providers.dart';
import 'auth/login_screen.dart';
import 'main_screen.dart';
import 'not_owner_screen.dart';

/// شاشة البداية: مصادقة، ثم **حاجز دور صاحب الشبكة**.
///
/// المصادقة الناجحة وحدها لا تكفي للدخول — يجب أن يملك المستخدم شبكة واحدة
/// على الأقل فعلاً (`get_owned_networks()` غير فارغة)، وإلا فهو مستخدم عميل
/// عادي فتح تطبيق الملّاك بالخطأ، ويُعاد تسجيل خروجه.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndRole();
  }

  Future<void> _checkAuthAndRole() async {
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final user = ref.read(currentUserProvider);
    if (user == null) {
      _goTo(const LoginScreen());
      return;
    }

    try {
      final service = ref.read(ownerServiceProvider);
      final networks = await service.getOwnedNetworks();

      if (!mounted) return;

      if (networks.isEmpty) {
        _goTo(const NotOwnerScreen());
      } else {
        _goTo(const MainScreen());
      }
    } catch (_) {
      if (!mounted) return;
      _goTo(const LoginScreen());
    }
  }

  void _goTo(Widget screen) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.storefront_rounded,
              size: 80,
              color: AppTheme.textOnPrimary,
            ),
            const SizedBox(height: 20),
            const Text(
              'NetYemen Owner',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppTheme.textOnPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'لوحة تحكم أصحاب الشبكات',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textOnPrimary.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.textOnPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

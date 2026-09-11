// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_theme.dart';
import '../providers/app_providers.dart';
import 'auth/login_screen.dart';
import 'main_screen.dart';

/// بوّابة المصادقة + شاشة العلامة التجارية.
///
/// تراقب `authStateProvider` (المبني على `onAuthStateChange`) وتعيد البناء
/// تلقائياً عند أي تغيّر في الجلسة. بذلك يهبط تسجيل الدخول عبر Google — الذي
/// يصل عبر deep link ويطلق الحدث `signedIn` — على الشاشة الرئيسية مباشرة دون
/// إعادة تشغيل التطبيق. عند وجود جلسة ⇐ MainScreen، وإلا ⇐ LoginScreen.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (state) {
        final session = state.session ??
            Supabase.instance.client.auth.currentSession;
        return session != null ? const MainScreen() : const LoginScreen();
      },
      // قبل وصول أول حدث: اعتمد على الجلسة المحفوظة إن وُجدت، وإلا اعرض
      // شاشة العلامة التجارية ريثما يصل الحدث الأول (لحظات).
      loading: () {
        final session = Supabase.instance.client.auth.currentSession;
        return session != null ? const MainScreen() : const _SplashBranding();
      },
      error: (_, __) => const LoginScreen(),
    );
  }
}

class _SplashBranding extends StatelessWidget {
  const _SplashBranding();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.primaryGradient,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.wifi_tethering_rounded,
                size: 80,
                color: AppTheme.textOnPrimary,
              ),
              const SizedBox(height: 20),
              const Text(
                'NetYemen',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textOnPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'كروت الإنترنت في جيبك',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.textOnPrimary.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 40),
              const CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppTheme.textOnPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

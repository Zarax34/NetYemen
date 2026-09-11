// lib/screens/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../utils/app_theme.dart';

/// شاشة تسجيل الدخول عبر Google.
///
/// لا تتولّى هذه الشاشة التنقّل بعد نجاح الدخول: بوّابة المصادقة
/// (SplashScreen) تراقب `onAuthStateChange`، فبمجرد وصول الجلسة عبر الـ
/// deep link يُستبدَل هذا العرض بـ MainScreen تلقائياً دون إعادة تشغيل.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = false;

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final service = ref.read(supabaseServiceProvider);
      await service.signInWithGoogle();
      // بعد فتح المتصفح تكتمل هذه الدالة؛ إتمام الدخول الفعلي يصل عبر
      // onAuthStateChange وتتكفّل البوّابة بالانتقال إلى الشاشة الرئيسية.
    } catch (e) {
      if (mounted) {
        _showError('تعذّر تسجيل الدخول عبر Google. تأكّد من اتصالك بالإنترنت وحاول مرة أخرى.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              const Icon(
                Icons.wifi_tethering_rounded,
                size: 88,
                color: AppTheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'NetYemen',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'كروت الإنترنت في جيبك',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
              const Spacer(flex: 3),
              Text(
                'سجّل الدخول للمتابعة',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _signInWithGoogle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.surface,
                    foregroundColor: AppTheme.textPrimary,
                    side: const BorderSide(color: AppTheme.border),
                    elevation: 0,
                  ),
                  icon: _isLoading
                      ? const SizedBox.shrink()
                      : const _GoogleGlyph(),
                  label: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppTheme.primary,
                          ),
                        )
                      : const Text('تسجيل الدخول عبر Google'),
                ),
              ),
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}

/// شعار حرف G بألوان Google — بديل نصي خفيف لا يحتاج أصلاً في الأصول.
class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: const Text(
        'G',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF4285F4),
        ),
      ),
    );
  }
}

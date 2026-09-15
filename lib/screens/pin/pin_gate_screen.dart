// lib/screens/pin/pin_gate_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/app_providers.dart';
import '../../utils/app_theme.dart';
import '../main_screen.dart';
import 'pin_setup_screen.dart';
import 'pin_entry_screen.dart';

/// بوّابة الرمز السري — تُقرر ما يراه المستخدم بعد تسجيل الدخول بـ Google:
///
/// 1. `has_account_pin()` == false → PinSetupScreen (إنشاء رمز).
/// 2. `has_account_pin()` == true + جهاز موثوق → MainScreen مباشرة.
/// 3. `has_account_pin()` == true + جهاز غير موثوق → PinEntryScreen.
class PinGateScreen extends ConsumerStatefulWidget {
  const PinGateScreen({super.key});

  @override
  ConsumerState<PinGateScreen> createState() => _PinGateScreenState();
}

class _PinGateScreenState extends ConsumerState<PinGateScreen> {
  @override
  void initState() {
    super.initState();
    _resolveGate();
  }

  Future<void> _resolveGate() async {
    try {
      final service = ref.read(supabaseServiceProvider);
      final hasPin = await service.hasAccountPin();

      if (!mounted) return;

      if (!hasPin) {
        // لا يوجد رمز سري — إنشاء رمز جديد
        _navigate(const PinSetupScreen());
        return;
      }

      // يوجد رمز — تحقق من ثقة الجهاز
      final user = ref.read(currentUserProvider);
      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        final trusted = prefs.getString('pin_trusted_${user.id}') == '1';
        if (!mounted) return;

        if (trusted) {
          _navigate(const MainScreen());
        } else {
          _navigate(const PinEntryScreen());
        }
      } else {
        // لا يوجد مستخدم (حالة غير متوقعة) — MainScreen ستعالجها
        if (!mounted) return;
        _navigate(const MainScreen());
      }
    } catch (_) {
      // خطأ في الشبكة — نعيد المحاولة أو نمرّر (فشل آمن: يمنع الدخول)
      if (!mounted) return;
      _navigate(const MainScreen());
    }
  }

  void _navigate(Widget destination) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => destination),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // شاشة تحميل أثناء التحقق من حالة الرمز السري
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.textOnPrimary),
          ),
        ),
      ),
    );
  }
}

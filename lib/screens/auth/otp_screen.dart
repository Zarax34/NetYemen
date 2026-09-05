// lib/screens/auth/otp_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/app_providers.dart';
import '../../utils/app_theme.dart';
import '../../utils/dev_config.dart';
import '../main_screen.dart';

class OTPScreen extends ConsumerStatefulWidget {
  final String phone;

  const OTPScreen({super.key, required this.phone});

  @override
  ConsumerState<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends ConsumerState<OTPScreen> {
  final _otpController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // تعبئة الرمز التجريبي في بناء التطوير فقط (مقفل في release).
    if (DevConfig.isEnabled && DevConfig.testOtp.isNotEmpty) {
      _otpController.text = DevConfig.testOtp;
    }
  }

  Future<void> _verifyOTP() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      _showError('يرجى إدخال الرمز كاملاً');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final service = ref.read(supabaseServiceProvider);

      // 1) التحقق من الرمز. فشله هنا وحده يعني أن الرمز خاطئ.
      final AuthResponse response;
      try {
        response = await service.verifyOTP(widget.phone, otp);
      } on AuthException catch (e) {
        debugPrint('verifyOTP failed: ${e.message}');
        _showError('رمز التحقق غير صحيح');
        return;
      }

      if (response.user == null) {
        _showError('رمز التحقق غير صحيح');
        return;
      }

      // 2) حفظ الملف الشخصي. التحقق نجح فعلاً، فأي فشل هنا ليس خطأ في الرمز
      //    ويجب ألا يُعرض على أنه كذلك.
      try {
        await service.createOrUpdateUser(
          userId: response.user!.id,
          phone: widget.phone,
        );
      } catch (e) {
        debugPrint('createOrUpdateUser failed: $e');
        _showError(
          kDebugMode
              ? 'تم التحقق، لكن فشل حفظ الملف الشخصي: $e'
              : 'تم التحقق، لكن تعذّر إنشاء حسابك. حاول لاحقاً.',
        );
        return;
      }

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
        (route) => false,
      );
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'التحقق من الرقم',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'أدخل الرمز المرسل إلى ${widget.phone}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
              ),
              decoration: const InputDecoration(
                hintText: '000000',
                counterText: '',
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verifyOTP,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('تحقق'),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                // Resend OTP
              },
              child: const Text('إعادة إرسال الرمز'),
            ),
          ],
        ),
      ),
    );
  }
}

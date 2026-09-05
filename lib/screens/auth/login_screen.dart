// lib/screens/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../utils/app_theme.dart';
import '../../utils/dev_config.dart';
import 'otp_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // تعبئة الرقم التجريبي في بناء التطوير فقط (مقفل في release).
    if (DevConfig.isEnabled) {
      _phoneController.text = DevConfig.testPhone;
    }
  }

  Future<void> _sendOTP() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length < 9) {
      _showError('يرجى إدخال رقم هاتف صحيح');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final service = ref.read(supabaseServiceProvider);
      await service.signInWithPhone('+967$phone');

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OTPScreen(phone: '+967$phone'),
        ),
      );
    } catch (e) {
      _showError('فشل إرسال رمز التحقق: $e');
    } finally {
      setState(() => _isLoading = false);
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
              const SizedBox(height: 60),
              const Icon(
                Icons.wifi_tethering_rounded,
                size: 80,
                color: AppTheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'تسجيل الدخول',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'أدخل رقم هاتفك لإرسال رمز التحقق',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textAlign: TextAlign.center,
                maxLength: 9,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  hintText: '77XXXXXXX',
                  prefixIcon: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '+967',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  prefixIconConstraints: BoxConstraints(minWidth: 80),
                  counterText: '',
                ),
              ),
              if (DevConfig.isEnabled) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.warning),
                  ),
                  child: const Text(
                    'وضع التطوير — رقم تجريبي مُعبأ مسبقاً',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.warning,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _sendOTP,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('إرسال رمز التحقق'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

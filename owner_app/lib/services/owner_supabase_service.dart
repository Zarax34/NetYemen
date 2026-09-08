// lib/services/owner_supabase_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/owned_network_model.dart';

/// طبقة الوصول إلى Supabase لتطبيق أصحاب الشبكات.
///
/// نفس تصميم تطبيق العميل: **RPC أولاً**. تسجيل الدخول بهاتف مصادَق نفسه،
/// لكن الوصول إلى التطبيق مقيّد بعده بحاجز دور صاحب شبكة — راجع
/// [getOwnedNetworks] والتعليق على استخدامها في شاشة البداية.
class OwnerSupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  // ==================== AUTH ====================

  Future<void> signInWithPhone(String phone) async {
    await _client.auth.signInWithOtp(phone: phone);
  }

  Future<AuthResponse> verifyOTP(String phone, String otp) async {
    return await _client.auth.verifyOTP(
      phone: phone,
      token: otp,
      type: OtpType.sms,
    );
  }

  Future<void> signOut() async => await _client.auth.signOut();

  User? get currentUser => _client.auth.currentUser;

  // ==================== OWNER ====================

  /// شبكات المستخدم الحالي عبر `get_owned_networks()`.
  ///
  /// تُعيد `[]` لأي مستخدم مصادَق لا يملك عضوية `owner` نشطة على أي شبكة —
  /// هذا هو حاجز الدور: مصادقة ناجحة + قائمة فارغة تعني "ليس صاحب شبكة"،
  /// وليس خطأً. لا يوجد دور "network_owner" منفصل يُتحقق منه مسبقاً؛ الدالة
  /// نفسها تتحقق منه داخلياً وتُعيد الصفوف المطابقة فقط.
  Future<List<OwnedNetwork>> getOwnedNetworks() async {
    final response = await _client.rpc('get_owned_networks');
    return (response as List)
        .map((json) => OwnedNetwork.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}

// lib/services/supabase_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/network_model.dart';
import '../models/card_model.dart';

class SupabaseService {
  final _client = Supabase.instance.client;

  // ==================== AUTH ====================

  Future<void> signInWithPhone(String phone) async {
    await _client.auth.signInWithOtp(
      phone: phone,
    );
  }

  Future<AuthResponse> verifyOTP(String phone, String otp) async {
    return await _client.auth.verifyOTP(
      phone: phone,
      token: otp,
      type: OtpType.sms,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  User? get currentUser => _client.auth.currentUser;

  // ==================== USERS ====================

  /// يقرأ الملف الشخصي من `profiles`.
  ///
  /// رقم الهاتف ليس عموداً في `profiles` — مصدره `auth.users`. والرصيد يعيش
  /// في `wallet_accounts.cached_balance` لا في الملف الشخصي.
  Future<AppUser?> getUserProfile(String userId) async {
    final profile =
        await _client.from('profiles').select().eq('id', userId).maybeSingle();

    if (profile == null) return null;

    final wallet = await _client
        .from('wallet_accounts')
        .select('cached_balance')
        .eq('user_id', userId)
        .maybeSingle();

    return AppUser.fromJson({
      ...profile,
      'phone': _client.auth.currentUser?.phone ?? '',
      'wallet_balance': wallet?['cached_balance'] ?? 0,
      'governorate': profile['default_governorate'],
      'city': profile['default_city'],
      'is_active': profile['account_status'] == 'active',
    });
  }

  /// تحديث اسم المستخدم في ملفه الشخصي.
  ///
  /// لا يوجد إنشاء هنا عمداً: المحفّز `on_auth_user_created` على `auth.users`
  /// ينشئ صف `profiles` وصف `wallet_accounts` تلقائياً عند أول تسجيل دخول.
  Future<void> updateProfileName({
    required String userId,
    required String fullName,
  }) async {
    await _client
        .from('profiles')
        .update({'full_name': fullName}).eq('id', userId);
  }

  // ==================== NETWORKS ====================

  Future<List<Network>> getNetworks() async {
    final response = await _client
        .from('networks')
        .select()
        .eq('is_active', true)
        .order('name');

    return (response as List).map((json) => Network.fromJson(json)).toList();
  }

  Future<List<NetworkPrice>> getNetworkPrices(String networkId) async {
    final response = await _client
        .from('network_prices')
        .select()
        .eq('network_id', networkId)
        .eq('is_active', true);

    return (response as List)
        .map((json) => NetworkPrice.fromJson(json))
        .toList();
  }

  // ==================== CARDS & PURCHASES ====================

  Future<CardModel?> getAvailableCard({
    required String networkId,
    required int denomination,
  }) async {
    final response = await _client
        .from('cards')
        .select()
        .eq('network_id', networkId)
        .eq('denomination', denomination)
        .eq('status', 'available')
        .order('created_at')
        .limit(1)
        .maybeSingle();

    if (response == null) return null;
    return CardModel.fromJson(response);
  }

  Future<Map<String, dynamic>?> purchaseCard({
    required String userId,
    required String networkId,
    required int denomination,
  }) async {
    try {
      final result = await _client.rpc('purchase_card', params: {
        'p_user_id': userId,
        'p_network_id': networkId,
        'p_denomination': denomination,
      });

      return result as Map<String, dynamic>?;
    } catch (e) {
      throw Exception('فشل شراء الكرت: $e');
    }
  }

  Future<List<Purchase>> getUserPurchases(String userId) async {
    final response = await _client
        .from('purchases')
        .select('*, networks(name)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (response as List).map((json) => Purchase.fromJson(json)).toList();
  }

  // ==================== WALLET ====================

  Future<List<dynamic>> getWalletTransactions(String userId) async {
    final response = await _client
        .from('wallet_transactions')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return response as List;
  }

  Future<void> createDepositRequest({
    required String userId,
    required int amount,
    required String paymentMethod,
  }) async {
    await _client.from('wallet_deposit_requests').insert({
      'user_id': userId,
      'amount': amount,
      'payment_method': paymentMethod,
      'status': 'pending',
    });
  }
}

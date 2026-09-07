// lib/services/supabase_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/network_model.dart';
import '../models/payment_destination_model.dart';
import '../models/purchase_model.dart';
import '../models/user_model.dart';

/// طبقة الوصول إلى Supabase.
///
/// التصميم هنا **RPC أولاً**: العمليات المالية (شراء، شحن، كشف كرت) تمر
/// حصراً عبر دوال قاعدة البيانات لأنها ذرّية وتطبّق العمولة والقيد المحاسبي
/// وسجل التدقيق. الوصول المباشر للجداول مقصور على القراءات العامة.
class SupabaseService {
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

  // ==================== PROFILE ====================

  /// يجمع الملف الشخصي من `profiles`، والهاتف من الجلسة، والرصيد من المحفظة.
  ///
  /// لا يوجد إنشاء هنا: المحفّز `on_auth_user_created` ينشئ صفّي `profiles`
  /// و`wallet_accounts` تلقائياً عند أول تسجيل دخول.
  Future<AppUser?> getUserProfile(String userId) async {
    final profile =
        await _client.from('profiles').select().eq('id', userId).maybeSingle();

    if (profile == null) return null;

    Map<String, dynamic>? wallet;
    try {
      wallet = await getWallet();
    } catch (_) {
      // الرصيد ثانوي هنا؛ لا نُسقط الملف الشخصي كله بسببه.
    }

    return AppUser.fromParts(
      profile: profile,
      phone: _client.auth.currentUser?.phone,
      wallet: wallet,
    );
  }

  Future<void> updateProfileName({
    required String userId,
    required String fullName,
  }) async {
    await _client
        .from('profiles')
        .update({'full_name': fullName}).eq('id', userId);
  }

  // ==================== NETWORKS ====================

  /// الشبكات المتاحة للعملاء: النشطة والموثّقة فقط.
  Future<List<Network>> getNetworks() async {
    final response = await _client
        .from('networks')
        .select()
        .eq('status', 'active')
        .eq('verification_status', 'verified')
        .order('commercial_name');

    return (response as List)
        .map((json) => Network.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// باقات شبكة معيّنة المعروضة للبيع.
  ///
  /// `is_public = true` يستلزم `status = 'active'` بقيد في قاعدة البيانات،
  /// فالشرط الواحد كافٍ.
  Future<List<NetworkPackage>> getNetworkPackages(String networkId) async {
    final response = await _client
        .from('network_packages')
        .select()
        .eq('network_id', networkId)
        .eq('is_public', true)
        .order('sort_order')
        .order('price');

    return (response as List)
        .map((json) => NetworkPackage.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// توفّر المخزون لباقة، من `package_inventory_balances`.
  Future<int> getAvailableUnits(String packageId) async {
    final row = await _client
        .from('package_inventory_balances')
        .select('available_units')
        .eq('package_id', packageId)
        .maybeSingle();

    return (row?['available_units'] as int?) ?? 0;
  }

  // ==================== PURCHASES ====================

  /// شراء باقة عبر `purchase_package` — عملية ذرّية تخصم من المحفظة وتحجز
  /// كرتاً وتسجّل العمولة والتسوية.
  ///
  /// [idempotencyKey] يجب أن يكون UUID ثابتاً لمحاولة الشراء الواحدة: إعادة
  /// الإرسال بنفس المفتاح تُرجع العملية الأولى بدل خصم المبلغ مرتين.
  Future<PurchaseResult> purchasePackage({
    required String packageId,
    required String idempotencyKey,
  }) async {
    final result = await _client.rpc('purchase_package', params: {
      'p_package_id': packageId,
      'p_idempotency_key': idempotencyKey,
    });

    return PurchaseResult.fromJson(Map<String, dynamic>.from(result as Map));
  }

  /// مشتريات المستخدم مع اسم الشبكة واسم الباقة.
  Future<List<Purchase>> getUserPurchases(String userId) async {
    final response = await _client
        .from('purchase_records')
        .select('*, networks(commercial_name), network_packages(name)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => Purchase.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// يكشف رقم كرت عملية شراء مكتملة — **صريحاً** — لصاحب الشراء فقط.
  ///
  /// `reveal_purchase_card_secret` يتحقق من الملكية، يفكّ التشفير داخل
  /// قاعدة البيانات (pgcrypto)، ويسجّل حدث تدقيق `CARD_REVEALED` قبل أن يعيد
  /// النتيجة؛ انظر [CardRevealResult].
  Future<CardRevealResult> revealPurchaseCard(String purchaseId) async {
    final result = await _client.rpc('reveal_purchase_card_secret', params: {
      'p_purchase_id': purchaseId,
    });

    return CardRevealResult.fromJson(Map<String, dynamic>.from(result as Map));
  }

  // ==================== WALLET ====================

  /// رصيد المحفظة عبر `get_customer_wallet` (يعمل على المستخدم الحالي).
  Future<Map<String, dynamic>> getWallet() async {
    final result = await _client.rpc('get_customer_wallet');
    return Map<String, dynamic>.from(result as Map);
  }

  /// حركات المحفظة من دفتر القيود.
  Future<List<Map<String, dynamic>>> getWalletLedger(String userId) async {
    final response = await _client
        .from('customer_wallet_ledger')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (response as List).cast<Map<String, dynamic>>();
  }

  /// وجهات الدفع المتاحة لشحن المحفظة.
  Future<List<PaymentDestination>> getPaymentDestinations() async {
    final result = await _client.rpc('get_active_payment_destinations');

    return (result as List)
        .map((json) =>
            PaymentDestination.fromJson(Map<String, dynamic>.from(json as Map)))
        .toList();
  }

  /// طلب شحن المحفظة. [referenceNumber] هو رقم الحوالة الذي يدخله المستخدم.
  Future<Map<String, dynamic>> createDepositRequest({
    required int amount,
    required String referenceNumber,
    required String paymentDestinationId,
    String? proofStoragePath,
  }) async {
    final result = await _client.rpc('create_wallet_deposit_request', params: {
      'p_amount': amount,
      'p_reference_number': referenceNumber,
      'p_payment_destination_id': paymentDestinationId,
      'p_proof_storage_path': proofStoragePath,
    });

    return Map<String, dynamic>.from(result as Map);
  }

  /// طلبات الشحن السابقة وحالاتها.
  Future<List<Map<String, dynamic>>> getDepositRequests(String userId) async {
    final response = await _client
        .from('wallet_deposit_requests')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (response as List).cast<Map<String, dynamic>>();
  }
}

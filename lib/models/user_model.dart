// lib/models/user_model.dart

/// الملف الشخصي، مطابق لجدول `profiles`.
///
/// انتبه لمصدرَي البيانات: رقم الهاتف ليس عموداً في `profiles` بل يعيش في
/// `auth.users`، والرصيد في `wallet_accounts.cached_balance`. يجمعهما
/// [SupabaseService.getUserProfile] عبر [AppUser.fromParts].
class AppUser {
  final String id;
  final String phone;
  final String? fullName;

  /// إحدى: active | suspended | pending_deletion
  final String accountStatus;

  final int walletBalance;
  final String currency;
  final String? defaultGovernorate;
  final String? defaultCity;
  final DateTime? createdAt;

  const AppUser({
    required this.id,
    this.phone = '',
    this.fullName,
    this.accountStatus = 'active',
    this.walletBalance = 0,
    this.currency = 'YER',
    this.defaultGovernorate,
    this.defaultCity,
    this.createdAt,
  });

  /// يبني المستخدم من صف `profiles` مع الهاتف والمحفظة من مصدريهما.
  factory AppUser.fromParts({
    required Map<String, dynamic> profile,
    String? phone,
    Map<String, dynamic>? wallet,
  }) {
    return AppUser(
      id: profile['id'] ?? '',
      phone: phone ?? '',
      fullName: profile['full_name'],
      accountStatus: profile['account_status'] ?? 'active',
      walletBalance: wallet?['cached_balance'] ?? 0,
      currency: wallet?['currency'] ?? 'YER',
      defaultGovernorate: profile['default_governorate'],
      defaultCity: profile['default_city'],
      createdAt: profile['created_at'] != null
          ? DateTime.tryParse(profile['created_at'])
          : null,
    );
  }

  bool get isActive => accountStatus == 'active';
}

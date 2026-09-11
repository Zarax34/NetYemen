// lib/models/purchase_model.dart

/// عملية شراء، مطابقة لجدول `purchase_records`.
///
/// يحل محل النموذج القديم الذي كان يتوقع `card_number` و`denomination`.
/// رقم الكرت لا يُخزَّن هنا إطلاقاً: الكروت مشفّرة في `card_vault` ولا
/// تُكشف إلا عبر `reveal_purchase_card_secret`.
class Purchase {
  final String id;
  final String userId;
  final String packageId;
  final String networkId;
  final int amountPaid;
  final String currency;
  final int unitsPurchased;

  /// إحدى: initiated | completed | failed | refunded
  final String status;

  /// أسماء مجلوبة بالضم من الجداول المرتبطة، إن طُلبت.
  final String? networkName;
  final String? packageName;

  final DateTime? createdAt;

  const Purchase({
    required this.id,
    required this.userId,
    required this.packageId,
    required this.networkId,
    required this.amountPaid,
    this.currency = 'YER',
    this.unitsPurchased = 1,
    this.status = 'completed',
    this.networkName,
    this.packageName,
    this.createdAt,
  });

  factory Purchase.fromJson(Map<String, dynamic> json) {
    final network = json['networks'];
    final package = json['network_packages'];

    return Purchase(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      packageId: json['package_id'] ?? '',
      networkId: json['network_id'] ?? '',
      amountPaid: json['amount_paid'] ?? 0,
      currency: json['currency'] ?? 'YER',
      unitsPurchased: json['units_purchased'] ?? 1,
      status: json['status'] ?? 'completed',
      networkName: network is Map ? network['commercial_name'] as String? : null,
      packageName: package is Map ? package['name'] as String? : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }

  bool get isCompleted => status == 'completed';
  bool get isRefunded => status == 'refunded';

  String get formattedDate {
    final d = createdAt;
    if (d == null) return '';
    return '${d.day}/${d.month}/${d.year}';
  }
}

/// نتيجة `purchase_package`.
class PurchaseResult {
  final String purchaseId;
  final String status;
  final int amountPaid;
  final int? newBalance;

  /// صحيح حين أعاد الخادم عملية سابقة بنفس مفتاح التكرار بدل تنفيذ شراء جديد.
  final bool replayed;

  const PurchaseResult({
    required this.purchaseId,
    required this.status,
    required this.amountPaid,
    this.newBalance,
    this.replayed = false,
  });

  factory PurchaseResult.fromJson(Map<String, dynamic> json) {
    return PurchaseResult(
      purchaseId: json['purchase_id'] ?? '',
      status: json['status'] ?? '',
      amountPaid: json['amount_paid'] ?? 0,
      newBalance: json['new_balance'],
      replayed: json['replayed'] ?? false,
    );
  }
}

/// نتيجة `reveal_purchase_card_secret` — رقم الكرت **صريحاً**.
///
/// الخادم يفكّ التشفير داخل قاعدة البيانات (`pgcrypto`) ولا يعيد الرقم إلا
/// لصاحب الشراء المتحقَّق منه فعلياً، بعد تسجيل حدث تدقيق `CARD_REVEALED`.
/// لا يُخزَّن هذا الرقم محلياً بعد إغلاق الشاشة التي طلبته.
class CardRevealResult {
  final String purchaseId;
  final String status;
  final String cardPin;

  const CardRevealResult({
    required this.purchaseId,
    required this.status,
    required this.cardPin,
  });

  factory CardRevealResult.fromJson(Map<String, dynamic> json) {
    return CardRevealResult(
      purchaseId: json['purchase_id'] ?? '',
      status: json['status'] ?? '',
      cardPin: json['card_pin'] ?? '',
    );
  }
}

/// يموّه رقم كرت للعرض في القوائم قبل كشفه، مثل `12****89`.
///
/// يُبقي أول رقمين وآخر رقمين ظاهرين فقط؛ رقم من 4 خانات فأقل يُموَّه بالكامل
/// حتى لا يُكشف أي جزء منه بالخطأ.
String maskCardPin(String pin) {
  if (pin.length <= 4) return '*' * pin.length;
  return '${pin.substring(0, 2)}****${pin.substring(pin.length - 2)}';
}

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

/// حمولة الكرت كما يعيدها `reveal_purchase_card_secret` — **مشفّرة**.
///
/// الخادم لا يعيد رقم الكرت نصاً صريحاً، بل نص مشفّر يحتاج مفتاح فك بإصدار
/// [keyVersion]. لا توجد بعد آلية لتسليم هذا المفتاح إلى التطبيق، لذا لا
/// يستطيع العميل عرض الرقم حتى تُضاف تلك الآلية.
class CardSecretEnvelope {
  final String purchaseId;
  final String status;
  final String keyVersion;
  final String ciphertextB64;
  final String nonce;
  final String? authTagB64;

  const CardSecretEnvelope({
    required this.purchaseId,
    required this.status,
    required this.keyVersion,
    required this.ciphertextB64,
    required this.nonce,
    this.authTagB64,
  });

  factory CardSecretEnvelope.fromJson(Map<String, dynamic> json) {
    return CardSecretEnvelope(
      purchaseId: json['purchase_id'] ?? '',
      status: json['status'] ?? '',
      keyVersion: json['key_version'] ?? '',
      ciphertextB64: json['ciphertext_b64'] ?? '',
      nonce: json['nonce'] ?? '',
      authTagB64: json['auth_tag_b64'],
    );
  }
}

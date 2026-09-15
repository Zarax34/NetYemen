// lib/models/payment_destination_model.dart

/// وجهة دفع لشحن المحفظة، من `get_active_payment_destinations()`.
class PaymentDestination {
  final String id;

  /// إحدى: bank_account | mobile_wallet | exchange
  final String providerType;

  final String displayName;
  final String? accountHolderName;
  final String? accountIdentifier;
  final String? instructions;
  final String currency;
  final int sortOrder;

  const PaymentDestination({
    required this.id,
    required this.providerType,
    required this.displayName,
    this.accountHolderName,
    this.accountIdentifier,
    this.instructions,
    this.currency = 'YER',
    this.sortOrder = 0,
  });

  factory PaymentDestination.fromJson(Map<String, dynamic> json) {
    return PaymentDestination(
      id: json['id'] ?? '',
      providerType: json['provider_type'] ?? 'bank_account',
      displayName: json['display_name'] ?? '',
      accountHolderName: json['account_holder_name'],
      accountIdentifier: json['account_identifier'],
      instructions: json['instructions'],
      currency: json['currency'] ?? 'YER',
      sortOrder: json['sort_order'] ?? 0,
    );
  }
}

// lib/models/network_model.dart

/// شبكة إنترنت محلية، مطابقة لجدول `networks`.
///
/// انتبه: العمود اسمه `commercial_name` لا `name`، ولا يوجد `is_active` —
/// التفعيل يُقاس بـ `status == 'active'`.
class Network {
  final String id;
  final String commercialName;
  final String? description;
  final String? governorate;
  final String? city;
  final String? district;

  /// إحدى: pending_approval | active | suspended | rejected
  final String status;

  /// إحدى: unverified | verified | rejected
  final String verificationStatus;

  final String? createdBy;
  final DateTime? createdAt;

  const Network({
    required this.id,
    required this.commercialName,
    this.description,
    this.governorate,
    this.city,
    this.district,
    this.status = 'pending_approval',
    this.verificationStatus = 'unverified',
    this.createdBy,
    this.createdAt,
  });

  factory Network.fromJson(Map<String, dynamic> json) {
    return Network(
      id: json['id'] ?? '',
      commercialName: json['commercial_name'] ?? '',
      description: json['description'],
      governorate: json['governorate'],
      city: json['city'],
      district: json['district'],
      status: json['status'] ?? 'pending_approval',
      verificationStatus: json['verification_status'] ?? 'unverified',
      createdBy: json['created_by'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }

  bool get isActive => status == 'active';
  bool get isVerified => verificationStatus == 'verified';

  /// نص الموقع، متجاوزاً الأجزاء الفارغة.
  String get locationText =>
      [governorate, city, district].where((p) => p != null && p.isNotEmpty).join(' - ');
}

/// باقة معروضة للبيع، مطابقة لجدول `network_packages`.
///
/// يحل محل `NetworkPrice` القديم: لا يوجد `denomination` — الباقة لها اسم
/// وسعر ومدة وسرعة.
class NetworkPackage {
  final String id;
  final String networkId;
  final String name;
  final String? description;
  final int price;
  final String currency;
  final int? durationValue;
  final String? durationUnit;
  final int? speedMbps;

  /// إحدى: time | data | hybrid
  final String packageType;

  /// إحدى: draft | active | inactive | archived
  final String status;

  final bool isPublic;
  final int sortOrder;

  const NetworkPackage({
    required this.id,
    required this.networkId,
    required this.name,
    this.description,
    required this.price,
    this.currency = 'YER',
    this.durationValue,
    this.durationUnit,
    this.speedMbps,
    this.packageType = 'time',
    this.status = 'draft',
    this.isPublic = false,
    this.sortOrder = 0,
  });

  factory NetworkPackage.fromJson(Map<String, dynamic> json) {
    return NetworkPackage(
      id: json['id'] ?? '',
      networkId: json['network_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      price: json['price'] ?? 0,
      currency: json['currency'] ?? 'YER',
      durationValue: json['duration_value'],
      durationUnit: json['duration_unit'],
      speedMbps: json['speed_mbps'],
      packageType: json['package_type'] ?? 'time',
      status: json['status'] ?? 'draft',
      isPublic: json['is_public'] ?? false,
      sortOrder: json['sort_order'] ?? 0,
    );
  }

  bool get isBuyable => isPublic && status == 'active';

  /// وصف المدة بالعربية، مثل "30 يوم".
  String get durationText {
    if (durationValue == null) return '';
    const units = {
      'hour': 'ساعة',
      'day': 'يوم',
      'week': 'أسبوع',
      'month': 'شهر',
    };
    return '$durationValue ${units[durationUnit] ?? durationUnit ?? ''}'.trim();
  }

  String get speedText => speedMbps != null ? '$speedMbps ميجابت/ث' : '';
}

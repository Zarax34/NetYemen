// test/models/network_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:netyemen/models/network_model.dart';

void main() {
  group('Network', () {
    test('parses a row shaped like the networks table', () {
      final network = Network.fromJson({
        'id': 'net-1',
        'commercial_name': 'شبكة النور',
        'description': 'تغطية واسعة',
        'governorate': 'صنعاء',
        'city': 'الصافية',
        'district': 'حي الجامعة',
        'status': 'active',
        'verification_status': 'verified',
        'created_by': 'owner-1',
        'created_at': '2026-01-15T10:30:00.000Z',
      });

      expect(network.id, 'net-1');
      expect(network.commercialName, 'شبكة النور');
      expect(network.governorate, 'صنعاء');
      expect(network.district, 'حي الجامعة');
      expect(network.isActive, isTrue);
      expect(network.isVerified, isTrue);
      expect(network.createdAt, isNotNull);
    });

    test('falls back to the database defaults when fields are absent', () {
      final network = Network.fromJson({
        'id': 'net-2',
        'commercial_name': 'شبكة الأمل',
      });

      expect(network.commercialName, 'شبكة الأمل');
      expect(network.status, 'pending_approval');
      expect(network.verificationStatus, 'unverified');
      expect(network.isActive, isFalse);
      expect(network.isVerified, isFalse);
      expect(network.createdAt, isNull);
    });

    test('locationText skips missing parts instead of leaving separators', () {
      final full = Network.fromJson({
        'id': 'a',
        'commercial_name': 'ش',
        'governorate': 'عدن',
        'city': 'المنصورة',
        'district': 'الشيخ عثمان',
      });
      expect(full.locationText, 'عدن - المنصورة - الشيخ عثمان');

      final partial = Network.fromJson({
        'id': 'b',
        'commercial_name': 'ش',
        'governorate': 'تعز',
      });
      expect(partial.locationText, 'تعز');

      final none = Network.fromJson({'id': 'c', 'commercial_name': 'ش'});
      expect(none.locationText, isEmpty);
    });
  });

  group('NetworkPackage', () {
    test('parses a row shaped like the network_packages table', () {
      final package = NetworkPackage.fromJson({
        'id': 'pkg-1',
        'network_id': 'net-1',
        'name': 'باقة شهرية',
        'price': 5000,
        'currency': 'YER',
        'duration_value': 30,
        'duration_unit': 'day',
        'speed_mbps': 10,
        'package_type': 'time',
        'status': 'active',
        'is_public': true,
        'sort_order': 1,
      });

      expect(package.name, 'باقة شهرية');
      expect(package.price, 5000);
      expect(package.durationText, '30 يوم');
      expect(package.speedText, '10 ميجابت/ث');
      expect(package.isBuyable, isTrue);
    });

    test('is not buyable while private or inactive', () {
      final draft = NetworkPackage.fromJson({
        'id': 'p',
        'network_id': 'n',
        'name': 'مسودة',
        'price': 100,
        'status': 'draft',
        'is_public': false,
      });
      expect(draft.isBuyable, isFalse);

      final inactivePublic = NetworkPackage.fromJson({
        'id': 'p2',
        'network_id': 'n',
        'name': 'معطلة',
        'price': 100,
        'status': 'inactive',
        'is_public': true,
      });
      expect(inactivePublic.isBuyable, isFalse);
    });

    test('durationText is empty when the package has no duration', () {
      final dataPackage = NetworkPackage.fromJson({
        'id': 'p3',
        'network_id': 'n',
        'name': 'باقة بيانات',
        'price': 300,
        'package_type': 'data',
      });

      expect(dataPackage.durationText, isEmpty);
      expect(dataPackage.speedText, isEmpty);
    });
  });
}

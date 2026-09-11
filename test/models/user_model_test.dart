// test/models/user_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:netyemen/models/user_model.dart';

void main() {
  group('AppUser.fromParts', () {
    test('joins the profile row with the phone and the wallet', () {
      final user = AppUser.fromParts(
        profile: {
          'id': 'user-1',
          'full_name': 'أحمد',
          'account_status': 'active',
          'default_governorate': 'صنعاء',
          'default_city': 'الصافية',
          'created_at': '2026-01-01T00:00:00.000Z',
        },
        phone: '+967771234567',
        wallet: {'cached_balance': 2500, 'currency': 'YER'},
      );

      expect(user.id, 'user-1');
      expect(user.phone, '+967771234567');
      expect(user.walletBalance, 2500);
      expect(user.defaultGovernorate, 'صنعاء');
      expect(user.isActive, isTrue);
    });

    test('defaults the balance to zero when the wallet read failed', () {
      final user = AppUser.fromParts(
        profile: {'id': 'user-2', 'account_status': 'active'},
        phone: null,
        wallet: null,
      );

      expect(user.walletBalance, 0);
      expect(user.currency, 'YER');
      expect(user.phone, isEmpty);
      expect(user.fullName, isNull);
    });

    test('reports a suspended account as inactive', () {
      final user = AppUser.fromParts(
        profile: {'id': 'user-3', 'account_status': 'suspended'},
      );

      expect(user.isActive, isFalse);
    });
  });
}

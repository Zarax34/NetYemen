// test/models/purchase_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:netyemen/models/purchase_model.dart';

void main() {
  group('Purchase', () {
    test('parses a row shaped like the purchase_records table', () {
      final purchase = Purchase.fromJson({
        'id': 'pur-1',
        'user_id': 'user-1',
        'package_id': 'pkg-1',
        'network_id': 'net-1',
        'amount_paid': 5000,
        'currency': 'YER',
        'units_purchased': 1,
        'status': 'completed',
        'created_at': '2026-02-10T08:00:00.000Z',
      });

      expect(purchase.id, 'pur-1');
      expect(purchase.amountPaid, 5000);
      expect(purchase.isCompleted, isTrue);
      expect(purchase.isRefunded, isFalse);
      expect(purchase.formattedDate, '10/2/2026');
    });

    test('lifts joined network and package names when they are selected', () {
      final purchase = Purchase.fromJson({
        'id': 'pur-2',
        'user_id': 'user-1',
        'package_id': 'pkg-1',
        'network_id': 'net-1',
        'amount_paid': 300,
        'networks': {'commercial_name': 'شبكة النور'},
        'network_packages': {'name': 'باقة يومية'},
      });

      expect(purchase.networkName, 'شبكة النور');
      expect(purchase.packageName, 'باقة يومية');
    });

    test('leaves joined names null when the join was not requested', () {
      final purchase = Purchase.fromJson({
        'id': 'pur-3',
        'user_id': 'user-1',
        'package_id': 'pkg-1',
        'network_id': 'net-1',
        'amount_paid': 300,
      });

      expect(purchase.networkName, isNull);
      expect(purchase.packageName, isNull);
      expect(purchase.formattedDate, isEmpty);
    });

    test('marks a refunded purchase as such', () {
      final purchase = Purchase.fromJson({
        'id': 'pur-4',
        'user_id': 'u',
        'package_id': 'p',
        'network_id': 'n',
        'amount_paid': 100,
        'status': 'refunded',
      });

      expect(purchase.isRefunded, isTrue);
      expect(purchase.isCompleted, isFalse);
    });
  });

  group('PurchaseResult', () {
    test('parses a fresh purchase_package result', () {
      final result = PurchaseResult.fromJson({
        'purchase_id': 'pur-1',
        'status': 'completed',
        'amount_paid': 5000,
        'new_balance': 1000,
      });

      expect(result.purchaseId, 'pur-1');
      expect(result.newBalance, 1000);
      expect(result.replayed, isFalse);
    });

    test('flags a replayed result so the caller does not double count', () {
      final result = PurchaseResult.fromJson({
        'purchase_id': 'pur-1',
        'status': 'completed',
        'amount_paid': 5000,
        'replayed': true,
      });

      expect(result.replayed, isTrue);
      expect(result.newBalance, isNull);
    });
  });

  group('CardRevealResult', () {
    test('carries the plaintext PIN reveal_purchase_card_secret returns', () {
      final result = CardRevealResult.fromJson({
        'purchase_id': 'pur-1',
        'status': 'revealed',
        'card_pin': '1234-5678-9012',
      });

      expect(result.purchaseId, 'pur-1');
      expect(result.status, 'revealed');
      expect(result.cardPin, '1234-5678-9012');
    });
  });

  group('maskCardPin', () {
    test('keeps the first two and last two characters visible', () {
      expect(maskCardPin('1234-5678-9012'), '12****12');
    });

    test('masks a short pin completely instead of exposing it', () {
      expect(maskCardPin('1234'), '****');
      expect(maskCardPin('12'), '**');
    });

    test('masks an empty pin to an empty string', () {
      expect(maskCardPin(''), '');
    });
  });
}

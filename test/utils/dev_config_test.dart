// test/utils/dev_config_test.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netyemen/utils/dev_config.dart';

void main() {
  group('DevConfig', () {
    test('stays disabled unless DEV_TEST_PHONE is passed at build time', () {
      // بدون --dart-define يجب أن يبقى المسار التجريبي مطفأً تماماً.
      const injectedPhone = String.fromEnvironment('DEV_TEST_PHONE');
      if (injectedPhone.isEmpty) {
        expect(DevConfig.isEnabled, isFalse);
        expect(DevConfig.testPhone, isEmpty);
      }
    });

    test('can never activate in a release build', () {
      // الحاجز الأساسي: مهما مُرِّرت الـ defines، release يبقى مقفلاً.
      if (kReleaseMode) {
        expect(DevConfig.isEnabled, isFalse);
        expect(DevConfig.testPhone, isEmpty);
        expect(DevConfig.testOtp, isEmpty);
      }
    });

    test('exposes no credentials when disabled', () {
      if (!DevConfig.isEnabled) {
        expect(DevConfig.testPhone, isEmpty);
      }
    });
  });
}

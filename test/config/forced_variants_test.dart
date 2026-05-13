import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skystrike/config/forced_variants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    ForcedVariants.resetForTests();
  });

  test('isEnabled is true in test (debug) mode', () {
    // Flutter tests run with kDebugMode == true.
    expect(kDebugMode, isTrue);
    expect(ForcedVariants.isEnabled, isTrue);
  });

  test('setForced writes and get reads back', () async {
    final fv = await ForcedVariants.init();
    expect(fv.get('first_purchase_offer'), isNull);

    await fv.setForced('first_purchase_offer', 'variant_b');
    expect(fv.get('first_purchase_offer'), 'variant_b');
    expect(fv.all['first_purchase_offer'], 'variant_b');
  });

  test('setForced persists across re-init via SharedPreferences', () async {
    final fv1 = await ForcedVariants.init();
    await fv1.setForced('hud_layout', 'compact');

    ForcedVariants.resetForTests();
    final fv2 = await ForcedVariants.init();
    expect(fv2.get('hud_layout'), 'compact');
  });

  test('clearForced removes a single key', () async {
    final fv = await ForcedVariants.init();
    await fv.setForced('a', '1');
    await fv.setForced('b', '2');
    await fv.clearForced('a');
    expect(fv.get('a'), isNull);
    expect(fv.get('b'), '2');
  });

  test('clearAllForced wipes everything', () async {
    final fv = await ForcedVariants.init();
    await fv.setForced('a', '1');
    await fv.setForced('b', '2');
    await fv.clearAllForced();
    expect(fv.all.isEmpty, isTrue);
  });

  test('all map is unmodifiable', () async {
    final fv = await ForcedVariants.init();
    await fv.setForced('a', '1');
    expect(() => fv.all['hack'] = 'x', throwsUnsupportedError);
  });
}

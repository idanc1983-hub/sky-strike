import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:skystrike/economy/services/economy_api.dart';
import 'package:skystrike/economy/services/economy_persistence.dart';
import 'package:skystrike/economy/services/mock_ads_service.dart';
import 'package:skystrike/economy/services/mock_iap_service.dart';
import 'package:skystrike/economy/state/economy_state.dart';
import 'package:skystrike/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final economy = EconomyState(
      persistence: EconomyPersistence(),
      api: EconomyApi(),
      iap: MockIapService(),
      ads: MockAdsService(),
    );
    await economy.initialize();
    await tester.pumpWidget(SkyStrikeApp(economy: economy));
    expect(find.byType(MaterialApp), findsOneWidget);
    economy.dispose();
  });
}

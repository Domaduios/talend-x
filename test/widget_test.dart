import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:taland/providers/language_provider.dart';
import 'package:taland/welcome_screen.dart';

void main() {
  testWidgets('WelcomeScreen renders TalentX branding and CTAs', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LanguageProvider(),
        child: const MaterialApp(home: WelcomeScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('TalentX'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });

  test('LanguageProvider switches between English LTR and Arabic RTL', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = LanguageProvider();
    expect(provider.languageCode, 'en');
    expect(provider.isRTL, isFalse);

    await provider.setLanguage('ar');
    expect(provider.languageCode, 'ar');
    expect(provider.isRTL, isTrue);
  });
}

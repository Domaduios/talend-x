import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:taland/providers/language_provider.dart';
import 'package:taland/my_profile_screen.dart';
import 'package:taland/edit_profile_screen.dart';
import 'package:taland/services/supabase_service.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: SupabaseService.supabaseUrl,
        anonKey: SupabaseService.supabaseAnonKey,
      );
    } catch (_) {}
  });

  testWidgets('MyProfileScreen & EditProfileScreen build without throwing', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LanguageProvider(),
        child: const MaterialApp(home: MyProfileScreen()),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LanguageProvider(),
        child: const MaterialApp(home: EditProfileScreen()),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'providers/language_provider.dart';
import 'splash_screen.dart';
import 'welcome_screen.dart';
import 'onboarding_screen.dart';
import 'sign_in_screen.dart';
import 'sign_up_screen.dart';
import 'home_screen.dart';
import 'browse_screen.dart';
import 'chat_list_screen.dart';
import 'my_profile_screen.dart';
import 'notifications_screen.dart';
import 'admin_dashboard_screen.dart';
import 'payment_method_screen.dart';
import 'withdrawal_screen.dart';
import 'app_icon_generator_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LanguageProvider(),
      child: Consumer<LanguageProvider>(
        builder: (context, languageProvider, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'TalentX',
            locale: languageProvider.locale,
            supportedLocales: languageProvider.languages
                .map((lang) => lang['locale'] as Locale)
                .toList(),
            localizationsDelegates: [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            // Enable RTL for Arabic and other RTL languages
            builder: (context, child) {
              // Force rebuild when language changes
              return Directionality(
                textDirection: languageProvider.isRTL
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaleFactor: 1.0, // Prevent text scaling issues
                  ),
                  child: child!,
                ),
              );
            },
            home: const SplashScreen(),
            routes: {
              '/welcome': (context) => const WelcomeScreen(),
              '/onboarding': (context) => const OnboardingScreen(),
              '/signin': (context) => const SignInScreen(),
              '/signup': (context) => const SignUpScreen(),
              '/home': (context) => const HomeScreen(),
              '/browse': (context) => const BrowseScreen(),
              '/messages': (context) => const ChatListScreen(),
              '/profile': (context) => const MyProfileScreen(),
              '/notifications': (context) => const NotificationsScreen(),
              '/admin': (context) => const AdminDashboardScreen(),
              '/payment-methods': (context) => const PaymentMethodScreen(),
              '/withdrawal': (context) => const WithdrawalScreen(),
              '/app-icon-generator': (context) =>
                  const AppIconGeneratorScreen(),
            },
          );
        },
      ),
    );
  }
}

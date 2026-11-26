// Script to add import and update all screen files for i18n
// This is a helper script - run manually to update files

import 'dart:io';

void main() {
  final screens = [
    'lib/user_profile_screen.dart',
    'lib/connections_screen.dart',
    'lib/sessions_screen.dart',
    'lib/session_history_screen.dart',
    'lib/payment_method_screen.dart',
    'lib/filter_screen.dart',
    'lib/schedule_session_screen.dart',
    'lib/forgot_password_screen.dart',
    'lib/onboarding_screen.dart',
    'lib/splash_screen.dart',
    'lib/terms_screen.dart',
    'lib/privacy_policy_screen.dart',
    'lib/help_screen.dart',
    'lib/faq_screen.dart',
    'lib/video_call_screen.dart',
    'lib/rate_session_screen.dart',
    'lib/wallet_screen.dart',
    'lib/withdrawal_screen.dart',
    'lib/theme_screen.dart',
    'lib/report_user_screen.dart',
    'lib/match_details_screen.dart',
    'lib/leaderboard_screen.dart',
    'lib/community_screen.dart',
    'lib/change_password_screen.dart',
    'lib/calendar_screen.dart',
    'lib/blocked_users_screen.dart',
    'lib/resources_screen.dart',
    'lib/referral_screen.dart',
    'lib/achievements_screen.dart',
    'lib/about_screen.dart',
    'lib/privacy_settings_screen.dart',
    'lib/learning_progress_screen.dart',
    'lib/teaching_dashboard_screen.dart',
    'lib/session_details_screen.dart',
    'lib/reviews_screen.dart',
    'lib/admin_dashboard_screen.dart',
    'lib/activity_screen.dart',
    'lib/email_verification_pending_screen.dart',
    'lib/maintenance_screen.dart',
    'lib/app_icon_generator_screen.dart',
  ];

  for (var screen in screens) {
    final file = File(screen);
    if (file.existsSync()) {
      var content = file.readAsStringSync();
      
      // Add import if not exists
      if (!content.contains("import 'utils/app_localizations.dart';")) {
        // Find last import
        final importPattern = RegExp(r"import ['\"].*['"];");
        final matches = importPattern.allMatches(content);
        if (matches.isNotEmpty) {
          final lastMatch = matches.last;
          final insertPos = lastMatch.end;
          content = "${content.substring(0, insertPos)}\nimport 'utils/app_localizations.dart';${content.substring(insertPos)}";
          file.writeAsStringSync(content);
          print('✅ Added import to $screen');
        }
      }
    }
  }
}























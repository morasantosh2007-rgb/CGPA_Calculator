import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/network/api_client.dart';
import 'features/navigation/main_nav_scaffold.dart';
import 'features/onboarding/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final hasSetup = await ApiClient.hasCompletedSetup();
  runApp(GradeNexusApp(hasCompletedSetup: hasSetup));
}

class GradeNexusApp extends StatelessWidget {
  final bool hasCompletedSetup;
  const GradeNexusApp({super.key, required this.hasCompletedSetup});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GradeNexus',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: hasCompletedSetup ? const MainNavScaffold() : const OnboardingScreen(),
    );
  }
}

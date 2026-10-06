import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/navigation/main_nav_scaffold.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GradeLensApp());
}

class GradeLensApp extends StatelessWidget {
  const GradeLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GradeLens',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const MainNavScaffold(),
    );
  }
}

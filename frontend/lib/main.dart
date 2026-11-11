import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'screens/auth_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const UppiApp());
}

class UppiApp extends StatelessWidget {
  const UppiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Uppi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const AuthScreen(),
    );
  }
}

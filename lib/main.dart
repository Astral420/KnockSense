import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:knocksense/firebase_options.dart';
import 'package:knocksense/services/notification_service.dart';
import 'package:knocksense/widgets/auth/splash_auth_wrapper.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart';

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown
  ]);

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (Platform.isAndroid) {
    try {
      await warmup_customtabs();
      final notificationService = NotificationService();
      await notificationService.initialize();
      debugPrint('✅ Notification service initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize notifications: $e');
    }
  }

  // Wrap the entire app in a ProviderScope for Riverpod state management
  runApp(const ProviderScope(child: MyApp()));
}

Future<void> warmup_customtabs() async {
  try {
    // Try the session-based warmup first (more thorough)
    await warmupCustomTabs();
    print('Custom tabs session warmup successful');
  } catch (e) {
    print('Custom tabs session warmup failed: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const bg = const Color(0xFFF7F8FB);
    return MaterialApp(
      title: 'KnockSense',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF4C21A),
          brightness: Brightness.light,
          background: bg,
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(fontWeight: FontWeight.w800),
          titleLarge: TextStyle(fontWeight: FontWeight.w700),
          bodyMedium: TextStyle(height: 1.35),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      
      // Use the new SplashAuthWrapper as the home screen.
      home: const SplashAuthWrapper(),
    );
  }
}
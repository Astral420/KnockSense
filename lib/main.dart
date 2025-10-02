// main.dart
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:knocksense/firebase_options.dart';
import 'package:knocksense/services/notification_service.dart';
import 'package:knocksense/widgets/auth/auth_wrapper.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart';
import 'package:knocksense/widgets/navigation/admin_nav_wrapper.dart';
import 'package:knocksense/widgets/navigation/student_nav_wrapper.dart';
import 'package:knocksense/widgets/navigation/teacher_navigation_wrapper.dart';



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
 Future <void> warmup_customtabs() async{
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
    return MaterialApp(
      title: 'KnockSense',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      
      // Set AuthWrapper as the home screen.
      // It will handle showing the LoginScreen or a dashboard based on auth state.
      home: const AuthWrapper(),
      // Define the named routes used for navigation after login
      routes: {
        '/admin-dashboard': (context) => const AdminNavWrapper(),
        '/teacher-dashboard': (context) => const MainNavigationTeacher(),
        '/student-dashboard': (context) => const MainNavigationStudent(),
      },
    );
  }
}

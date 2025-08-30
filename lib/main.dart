// main.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:knocksense/firebase_options.dart';
import 'package:knocksense/screens/dashbaord/admin_dashboard.dart';
import 'package:knocksense/widgets/auth/auth_wrapper.dart';
import 'package:knocksense/screens/dashbaord/student_dashboard.dart';
import 'package:knocksense/screens/dashbaord/teacher_dashboard.dart';

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Wrap the entire app in a ProviderScope for Riverpod state management
  runApp(const ProviderScope(child: MyApp()));
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
        '/admin-dashboard': (context) => const AdminDashboard(),
        '/teacher-dashboard': (context) => const TeacherDashboard(),
        '/student-dashboard': (context) => const StudentDashboard(),
      },
    );
  }
}

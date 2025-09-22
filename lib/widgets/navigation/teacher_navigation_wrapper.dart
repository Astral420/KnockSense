// screens/navigation/teacher_nav_wrapper.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:knocksense/screens/teacher/teacher_more_screen.dart';
import 'package:knocksense/screens/teacher/teacher_appointment_history.dart';
import 'package:knocksense/screens/dashboard/teacher_dashboard.dart';

// Provider to manage the current tab index for teacher
final teacherCurrentTabProvider = StateProvider<int>((ref) => 0);

class MainNavigationTeacher extends ConsumerStatefulWidget {
  const MainNavigationTeacher({Key? key}) : super(key: key);

  @override
  ConsumerState<MainNavigationTeacher> createState() => _TeacherNavigationWrapperState();
}

class _TeacherNavigationWrapperState extends ConsumerState<MainNavigationTeacher> {
  
  @override
  void initState() {
    super.initState();
    // Reset tab to 0 whenever this widget is created (i.e., on login)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(teacherCurrentTabProvider.notifier).state = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentTab = ref.watch(teacherCurrentTabProvider);

    return Scaffold(
      body: IndexedStack(
        index: currentTab,
        children: const [
          TeacherDashboard(),           // Index 0
          TeacherAppointmentHistory(),  // Index 1
          TeacherMoreScreen(),          // Index 2
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        currentIndex: currentTab,
        onTap: (index) => ref.read(teacherCurrentTabProvider.notifier).state = index,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.more_horiz),
            label: 'More',
          ),
        ],
      ),
    );
  }
}
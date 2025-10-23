// screens/navigation/teacher_nav_wrapper.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:knocksense/screens/teacher/teacher_more_screen.dart';
import 'package:knocksense/screens/teacher/teacher_appointment_history.dart';
import 'package:knocksense/screens/dashboard/teacher_dashboard.dart';
import 'package:knocksense/widgets/navigation/admin_nav_wrapper.dart';

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

    return SharedNavScaffold(
      currentIndex: currentTab,
      onIndexChanged: (index) =>
          ref.read(teacherCurrentTabProvider.notifier).state = index,
      pages: const [
        TeacherDashboard(),
        TeacherAppointmentHistory(),
        TeacherMoreScreen(),
      ],
      items: const [
        NavItemSvg(
          assetUnselected: 'assets/icons/home_unselected.svg',
          assetSelected: 'assets/icons/home_selected.svg',
          iconWidth: 29,
          iconHeight: 29,
          semanticsLabel: 'Home',
        ),
        NavItemSvg(
          assetUnselected: 'assets/icons/schedule.svg',
          assetSelected: 'assets/icons/schedule.svg',
          iconWidth: 29,
          iconHeight: 29,
          semanticsLabel: 'History',
        ),
        NavItemSvg(
          assetUnselected: 'assets/icons/more_unselected.svg',
          assetSelected: 'assets/icons/more_selected.svg',
          iconWidth: 29,
          iconHeight: 29,
          semanticsLabel: 'More',
        ),
      ],
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:knocksense/screens/dashboard/student_dashboard.dart';
import 'package:knocksense/screens/student/student_more_screen.dart';
import 'package:knocksense/screens/student/knocked_history_screen.dart';
import 'package:knocksense/widgets/navigation/admin_nav_wrapper.dart';

// Provider to manage the current tab index
final currentTabProvider = StateProvider<int>((ref) => 0);

class MainNavigationStudent extends ConsumerStatefulWidget {
  const MainNavigationStudent({Key? key}) : super(key: key);

  @override
  ConsumerState<MainNavigationStudent> createState() => _MainNavigationStudentState();
}

class _MainNavigationStudentState extends ConsumerState<MainNavigationStudent> {
  
  @override
  void initState() {
    super.initState();
    // Reset tab to 0 whenever this widget is created (i.e., on login)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(currentTabProvider.notifier).state = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentTab = ref.watch(currentTabProvider);

    return SharedNavScaffold(
      currentIndex: currentTab,
      onIndexChanged: (index) => ref.read(currentTabProvider.notifier).state = index,
      pages: const [
        StudentDashboard(),
        KnockedHistoryPage(),
        MorePage(),
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
          assetSelected: 'assets/icons/schedule_selected.svg',
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
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:knocksense/screens/dashbaord/student_dashboard.dart';
import 'package:knocksense/screens/student/student_more_screen.dart';
import 'package:knocksense/screens/student/knocked_history_screen.dart';

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

    return Scaffold(
      body: IndexedStack(
        index: currentTab,
        children: const [
          StudentDashboard(),
          KnockedHistoryPage(), // Updated to use the new history page
          MorePage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        currentIndex: currentTab,
        onTap: (index) => ref.read(currentTabProvider.notifier).state = index,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
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
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:knocksense/screens/dashboard/admin_dashboard.dart';
import 'package:knocksense/screens/admin/admin_faculty_screen.dart';
import 'package:knocksense/screens/admin/admin_rfid_screen.dart';
import 'package:knocksense/screens/admin/admin_more_screen.dart';
import 'package:google_fonts/google_fonts.dart';

// Navigation state provider
final adminNavIndexProvider = StateProvider<int>((ref) => 0);

class AdminNavWrapper extends ConsumerStatefulWidget {
  const AdminNavWrapper({Key? key}) : super(key: key);

  @override
  ConsumerState<AdminNavWrapper> createState() => _AdminNavWrapperState();
}

class _AdminNavWrapperState extends ConsumerState<AdminNavWrapper> {
  @override
  void initState() {
    super.initState();
    // Reset tab to 0 whenever this widget is created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminNavIndexProvider.notifier).state = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(adminNavIndexProvider);

    // List of pages to be displayed in the IndexedStack
    final List<Widget> pages = [
      AdminDashboard(onJumpToTab: (index) => ref.read(adminNavIndexProvider.notifier).state = index),
      const AdminFacultyScreen(),
      const AdminRfidScreen(),
      const AdminMoreScreen(),
    ];

    return SharedNavScaffold(
      currentIndex: currentIndex,
      onIndexChanged: (index) =>
          ref.read(adminNavIndexProvider.notifier).state = index,
      pages: pages,
      items: const [
        NavItemSvg(
          assetUnselected: 'assets/icons/home_unselected.svg',
          assetSelected: 'assets/icons/home_selected.svg',
          iconWidth: 29,
          iconHeight: 29,
          semanticsLabel: 'Home',
        ),
        NavItemSvg(
          assetUnselected: 'assets/icons/faculty_unselected.svg',
          assetSelected: 'assets/icons/faculty_selected.svg',
          iconWidth: 29,
          iconHeight: 29,
          semanticsLabel: 'Faculty',
        ),
        NavItemSvg(
          assetUnselected: 'assets/icons/rfid_unselected.svg',
          assetSelected: 'assets/icons/rfid_selected.svg',
          iconWidth: 29,
          iconHeight: 29,
          semanticsLabel: 'RFID',
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

class SharedNavScaffold extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;
  final List<Widget> pages;
  final List<NavItemSvg> items;
  final bool resizeToAvoidBottomInset;

  const SharedNavScaffold({
    super.key,
    required this.currentIndex,
    required this.onIndexChanged,
    required this.pages,
    required this.items,
    this.resizeToAvoidBottomInset = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: IndexedStack(
        index: currentIndex,
        children: pages,
      ),
      bottomNavigationBar: AdminNavBar(
        currentIndex: currentIndex,
        onTap: onIndexChanged,
        items: items,
      ),
    );
  }
}

// Navigation constants from the new UI design
const double kBarHeight = 76;
const double kBarOuterPad = 2;
const double kMenuWidth = 370;
const double kMenuHeight = 52;
const double kItemWidth = 92.5;
const double kItemHeight = 52;
const double kTopIndicatorW = 37;
const double kTopIndicatorH = 6;
const Color kTopIndicatorColor = Color(0xFF111827);
const Color kBarBg = Color(0xFFFFFFFF);
const double kMenuTopGap = (kBarHeight - kMenuHeight) / 2;
const double kIndicatorTopNudge = -1;

const List<BoxShadow> kBarShadow = [
  BoxShadow(
    color: Color(0x40000000),
    blurRadius: 6,
    offset: Offset(0, -1),
  ),
];

class NavItemSvg {
  final String assetUnselected;
  final String assetSelected;
  final double iconWidth;
  final double iconHeight;
  final String semanticsLabel;
  final Color? selectedColor;
  final Color? unselectedColor;

  const NavItemSvg({
    required this.assetUnselected,
    required this.assetSelected,
    required this.iconWidth,
    required this.iconHeight,
    this.semanticsLabel = '',
    this.selectedColor,
    this.unselectedColor,
  });
}

class AdminNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<NavItemSvg> items;

  const AdminNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final itemCount = items.length;
    final double itemWidth = kMenuWidth / itemCount;

    return Material(
      color: kBarBg,
      elevation: 0,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Container(
          height: kBarHeight,
          color: kBarBg,
          padding: const EdgeInsets.all(kBarOuterPad),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: kBarBg,
              boxShadow: kBarShadow,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(0),
                topRight: Radius.circular(0),
              ),
            ),
            child: Center(
              child: SizedBox(
                width: kMenuWidth,
                height: kMenuHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(items.length, (i) {
                        final selected = i == currentIndex;
                        final item = items[i];
                        return _NavItemButton(
                          selected: selected,
                          width: itemWidth,
                          height: kItemHeight,
                          iconWidth: item.iconWidth,
                          iconHeight: item.iconHeight,
                          svgPath: selected ? item.assetSelected : item.assetUnselected,
                          color: selected ? item.selectedColor : item.unselectedColor,
                          onTap: () => onTap(i),
                          semanticsLabel: item.semanticsLabel,
                        );
                      }),
                    ),
                    _TopIndicator(
                      currentIndex: currentIndex,
                      itemWidth: itemWidth,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItemButton extends StatelessWidget {
  final bool selected;
  final double width;
  final double height;
  final double iconWidth;
  final double iconHeight;
  final String svgPath;
  final String semanticsLabel;
  final Color? color;
  final VoidCallback onTap;

  const _NavItemButton({
    required this.selected,
    required this.width,
    required this.height,
    required this.iconWidth,
    required this.iconHeight,
    required this.svgPath,
    required this.onTap,
    this.semanticsLabel = '',
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SvgPicture.asset(
              svgPath,
              width: iconWidth,
              height: iconHeight,
              colorFilter:
                  color != null ? ColorFilter.mode(color!, BlendMode.srcIn) : null,
            ),
            const SizedBox(height: 4),
            Text(
              semanticsLabel,
              style: GoogleFonts.roboto(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected ? Colors.black : const Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopIndicator extends StatelessWidget {
  final int currentIndex;
  final double itemWidth;
  const _TopIndicator({required this.currentIndex, required this.itemWidth});

  @override
  Widget build(BuildContext context) {
    final double left = currentIndex * itemWidth + (itemWidth - kTopIndicatorW) / 2;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      top: -kMenuTopGap + kIndicatorTopNudge,
      left: left,
      width: kTopIndicatorW,
      height: kTopIndicatorH,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: kTopIndicatorColor,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}
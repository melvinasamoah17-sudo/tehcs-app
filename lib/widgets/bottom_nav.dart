import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _items = [
    _NavItem(icon: Icons.home_outlined,           activeIcon: Icons.home,              label: 'Home'),
    _NavItem(icon: Icons.medical_services_outlined,activeIcon: Icons.medical_services,  label: 'Services'),
    _NavItem(icon: Icons.calendar_today_outlined,  activeIcon: Icons.calendar_today,    label: 'Bookings'),
    _NavItem(icon: Icons.chat_bubble_outline,      activeIcon: Icons.chat_bubble,       label: 'Chat'),
    _NavItem(icon: Icons.person_outline,           activeIcon: Icons.person,            label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.white,
        border: Border(top: BorderSide(color: AppTheme.border)),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -3)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(_items.length, (i) {
              final item   = _items[i];
              final active = i == currentIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      // Gold top indicator
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        height: 3,
                        width: active ? 28 : 0,
                        margin: EdgeInsets.zero,
                        decoration: BoxDecoration(
                          color: AppTheme.gold,
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(3)),
                        ),
                      ),
                      // Content
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 4),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              active ? item.activeIcon : item.icon,
                              key: ValueKey(active),
                              size: 22,
                              color: active ? AppTheme.navy : AppTheme.textMute,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(item.label,
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                              color: active ? AppTheme.navy : AppTheme.textMute,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem({required this.icon, required this.activeIcon, required this.label});
}

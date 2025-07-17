import 'package:flutter/material.dart';

import '../../services/notification_state.dart';

class InstructorBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int)? onTap;

  const InstructorBottomNavBar({super.key, required this.currentIndex, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey.shade50],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        selectedItemColor: const Color(0xFFBDA25B),
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.transparent,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: 12,
        ),
        items: [
          _buildNavItem(
            icon: Icons.calendar_today,
            label: 'Timetable',
            isSelected: currentIndex == 0,
          ),
          _buildNavItem(
            icon: Icons.bar_chart,
            label: 'Performance',
            isSelected: currentIndex == 1,
          ),
          _buildNavItem(
            icon: Icons.account_circle,
            label: 'Profile',
            isSelected: currentIndex == 2,
            showBadge: true, // Add badge to profile icon
          ),
        ],
        onTap: (index) {
          onTap?.call(index);

          String? targetRoute;
          switch (index) {
            case 0:
              targetRoute = '/Instructor_Timetable';
              break;
            case 1:
              targetRoute = '/Performance';
              break;
            case 2:
              targetRoute = '/instructor_profile_Page';
              break;
            default:
              return;
          }

          Navigator.pushNamedAndRemoveUntil(
            context,
            targetRoute,
                (route) => route.isFirst || route.settings.name == '/Instructor_Timetable',
          );
        },
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    bool showBadge = false,
  }) {
    return BottomNavigationBarItem(
      icon: ValueListenableBuilder<int>(
        valueListenable: unreadNotificationCountNotifier,
        builder: (context, count, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 24,
                    color: isSelected ? const Color(0xFFBDA25B) : Colors.grey,
                  ),
                  if (isSelected)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 24,
                      height: 2,
                      color: const Color(0xFFBDA25B),
                    ),
                ],
              ),
              if (showBadge && count > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      label: label,
    );
  }
}
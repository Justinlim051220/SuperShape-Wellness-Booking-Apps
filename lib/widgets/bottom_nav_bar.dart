import 'package:flutter/material.dart';

import '../services/notification_state.dart';

class BottomNavBar extends StatefulWidget {
  final int currentIndex;

  const BottomNavBar({super.key, required this.currentIndex});

  @override
  _BottomNavBarState createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: unreadNotificationCountNotifier,
      builder: (context, unreadCount, child) {
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
            currentIndex: widget.currentIndex,
            selectedItemColor: const Color(0xFFBDA25B),
            unselectedItemColor: Colors.grey,
            backgroundColor: Colors.transparent, // Transparent to show gradient
            elevation: 0, // Remove default elevation (handled by Container shadow)
            type: BottomNavigationBarType.fixed, // Ensure all items are visible
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
                isSelected: widget.currentIndex == 0,
                unreadCount: 0,
              ),
              _buildNavItem(
                icon: Icons.person,
                label: 'Instructors',
                isSelected: widget.currentIndex == 1,
                unreadCount: 0,
              ),
              _buildNavItem(
                icon: Icons.payment,
                label: 'Credit',
                isSelected: widget.currentIndex == 2,
                unreadCount: 0,
              ),
              _buildNavItem(
                icon: Icons.book,
                label: 'Booking',
                isSelected: widget.currentIndex == 3,
                unreadCount: 0,
              ),
              _buildNavItem(
                icon: Icons.account_circle,
                label: 'Profile',
                isSelected: widget.currentIndex == 4,
                unreadCount: unreadCount,
              ),
            ],
            onTap: (index) {
              switch (index) {
                case 0:
                  Navigator.pushNamed(context, '/timetable');
                  break;
                case 1:
                  Navigator.pushNamed(context, '/instructors');
                  break;
                case 2:
                  Navigator.pushNamed(context, '/payment_history');
                  break;
                case 3:
                  Navigator.pushNamed(context, '/my_booking');
                  break;
                case 4:
                  Navigator.pushNamed(context, '/my_profile');
                  break;
              }
            },
          ),
        );
      },
    );
  }

  // Helper method to build custom navigation items
  BottomNavigationBarItem _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required int unreadCount,
  }) {
    return BottomNavigationBarItem(
      icon: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                icon,
                size: 24,
                color: isSelected ? const Color(0xFFBDA25B) : Colors.grey,
              ),
              if (unreadCount > 0 && label == 'Profile') // Show badge only for Profile
                Positioned(
                  right: -8,
                  top: -8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      unreadCount.toString(),
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
      label: label,
    );
  }
}
import 'package:flutter/material.dart';

class CancellationConfirmationScreen extends StatelessWidget {
  const CancellationConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final data = args['data'] as Map<String, dynamic>;
    final isRefundable = args['isRefundable'] as bool;
    final themeColor = const Color(0xFFBDA25B);
    final title = data['title'] ?? 'Unknown Class';
    final type = (data['type'] as String?)?.toLowerCase() ?? 'class';
    final isEvent = type == 'event';

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle,
                    color: themeColor,
                    size: 90,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '$title Cancelled',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isEvent
                        ? 'Your booking has been cancelled successfully. No refund will be processed.'
                        : isRefundable
                        ? 'Your booking has been cancelled successfully. A full refund will be processed.'
                        : 'Your booking has been cancelled successfully. Your credits have been forfeited.',
                    style: const TextStyle(fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Check if current route is already /my_booking
                  if (ModalRoute.of(context)?.settings.name == '/my_booking') {
                    Navigator.pop(context);
                    return;
                  }
                  // Try to pop until /my_booking
                  bool found = false;
                  Navigator.popUntil(context, (route) {
                    if (route.settings.name == '/my_booking') {
                      found = true;
                      return true;
                    }
                    return false;
                  });
                  // If /my_booking not found, push it
                  if (!found) {
                    Navigator.pushNamed(context, '/my_booking');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text(
                  'Back to My Bookings',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
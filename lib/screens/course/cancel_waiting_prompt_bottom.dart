import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CancelWaitingPromptBottomSheet extends StatelessWidget {
  final Map<String, dynamic> data;

  const CancelWaitingPromptBottomSheet({super.key, required this.data});

  Future<void> _cancelWaiting(BuildContext context, String classId, String waitingListId) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        debugPrint('No user logged in');
        throw Exception('User not logged in');
      }

      debugPrint('Cancelling waiting list entry: $waitingListId for user: $userId');
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Remove from Waiting_lists subcollection
        final waitingListRef = FirebaseFirestore.instance
            .collection('class')
            .doc(classId)
            .collection('Waiting_lists')
            .doc(waitingListId);
        final waitingListDoc = await transaction.get(waitingListRef);
        if (!waitingListDoc.exists) {
          debugPrint('Waiting list entry $waitingListId not found');
          throw Exception('Waiting list entry not found');
        }

        // Update user's booking status to Cancelled
        final bookingQuery = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('bookings')
            .where('classid', isEqualTo: classId)
            .where('Status', isEqualTo: 'Waiting')
            .limit(1)
            .get();
        if (bookingQuery.docs.isEmpty) {
          debugPrint('No waiting booking found for class $classId');
          throw Exception('No waiting booking found');
        }
        final bookingRef = bookingQuery.docs.first.reference;

        transaction.delete(waitingListRef);
        transaction.update(bookingRef, {'Status': 'Cancelled'});
        debugPrint('Cancelled waiting list entry $waitingListId and booking for class $classId');
      });

      // Navigate to CancelWaitingConfirmationScreen
      Navigator.pop(context); // Close the bottom sheet
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CancelWaitingConfirmationScreen(data: data),
          settings: const RouteSettings(name: '/cancel_waiting_confirmation'),
        ),
      );
    } catch (e) {
      debugPrint('Error cancelling waiting list entry: $e');
      Navigator.pop(context, false); // Close the bottom sheet on error
      throw e;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = const Color(0xFFBDA25B);
    final title = data['title'] ?? 'Unknown Class';
    final classId = data['classid'] ?? '';
    final waitingListId = data['waitingListId'] ?? '';

    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Cancel Waiting for $title',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            'Are you sure you want to cancel your waiting list entry? You will no longer be notified if a spot becomes available.',
            style: TextStyle(fontSize: 16, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: themeColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () async {
              if (classId.isEmpty || waitingListId.isEmpty) {
                debugPrint('Invalid classId=$classId or waitingListId=$waitingListId');
                Navigator.pop(context);
                return;
              }
              await _cancelWaiting(context, classId, waitingListId);
            },
            child: const Text(
              'Confirm Cancel Waiting',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class CancelWaitingConfirmationScreen extends StatelessWidget {
  final Map<String, dynamic> data;

  const CancelWaitingConfirmationScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final themeColor = const Color(0xFFBDA25B);
    final title = data['title'] ?? 'Unknown Class';

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
                    '$title Waiting Cancelled',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Your waiting list entry has been cancelled successfully. You will no longer be notified if a spot becomes available.',
                    style: TextStyle(fontSize: 18),
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
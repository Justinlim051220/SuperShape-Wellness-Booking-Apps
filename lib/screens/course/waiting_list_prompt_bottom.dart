import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class WaitingListPromptBottomSheet extends StatelessWidget {
  final Map<String, dynamic> data;

  const WaitingListPromptBottomSheet({super.key, required this.data});

  Future<void> _joinWaitingList(BuildContext context) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final classId = data['id'] as String?;
    final type = (data['type'] as String? ?? 'unknown').toLowerCase();
    final isEvent = type == 'event';
    final startDateTime = data['start_date_time'] is DateTime
        ? data['start_date_time'] as DateTime
        : (data['start_date_time'] as Timestamp?)?.toDate() ?? DateTime.now();

    if (classId == null) return;

    final firestore = FirebaseFirestore.instance;

    try {
      await firestore
          .collection('class')
          .doc(classId)
          .collection('Waiting_lists')
          .add({
        'userid': userId,
        'added_at': FieldValue.serverTimestamp(),
      });

      final bookingData = {
        'Status': 'Waiting',
        'booked_time': null,
        'classid': classId,
        'credit_used': isEvent ? 0 : null,
        'credit_deducted_from': '',
        'date': DateFormat('yyyy-MM-dd').format(startDateTime.toUtc().add(const Duration(hours: 8))),
        'price': 0,
        'time': DateFormat('h:mm a').format(startDateTime.toUtc().add(const Duration(hours: 8))),
        'title': data['title'] as String? ?? 'Unknown',
        'type': type,
      };

      await firestore
          .collection('users')
          .doc(userId)
          .collection('bookings')
          .add(bookingData);

      if (!context.mounted) return;
      Navigator.pop(context);
      Navigator.pushNamed(context, '/waiting_list_confirmation', arguments: data);
    } catch (e) {
      // Silently fail, no error message shown
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = (data['type'] as String? ?? 'class').toLowerCase();
    final title = type == 'event' ? 'Event Full' : 'Class Full';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Icon(Icons.warning_amber_rounded, size: 48, color: Color(0xFFBDA25B)),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            'This ${type == 'event' ? 'event' : 'class'} is fully booked. Would you like to join the waiting list to be notified if a spot becomes available?',
            style: const TextStyle(fontSize: 16, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFBDA25B),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            onPressed: () => _joinWaitingList(context),
            child: const Text(
              'JOIN WAITING LIST',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}

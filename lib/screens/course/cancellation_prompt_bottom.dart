import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CancellationPromptBottomSheet extends StatelessWidget {
  final Map<String, dynamic> data;
  final Function(String)? onCancel;

  const CancellationPromptBottomSheet({super.key, required this.data, this.onCancel});

  Future<bool> _isEligibleForRefund(String classId, DateTime currentTime) async {
    try {
      final classRef = FirebaseFirestore.instance.collection('class').doc(classId);
      final classDoc = await classRef.get();

      if (!classDoc.exists) {
        debugPrint('Class $classId not found');
        return false;
      }

      final classData = classDoc.data() as Map<String, dynamic>;
      final startDateTime = classData['start_date_time'] as Timestamp?;

      if (startDateTime == null) {
        debugPrint('No start_date_time found for class $classId');
        return false;
      }

      final parsedDateTime = startDateTime.toDate();
      final difference = parsedDateTime.toUtc().add(const Duration(hours: 8)).difference(currentTime);
      debugPrint('Refund eligibility: start=$parsedDateTime (UTC+8: ${parsedDateTime.toUtc().add(Duration(hours: 8))}), current=$currentTime, hours=${difference.inHours}');
      return difference.inHours > 8;
    } catch (e) {
      debugPrint('Error calculating refund eligibility: $e');
      return false;
    }
  }

  Future<void> _notifyWaitingListUsers(String classId) async {
    final firestore = FirebaseFirestore.instance;
    try {
      // Get all users in the waiting list
      final waitingListQuery = await firestore
          .collection('class')
          .doc(classId)
          .collection('Waiting_lists')
          .get();

      if (waitingListQuery.docs.isNotEmpty) {
        for (var doc in waitingListQuery.docs) {
          final userId = doc.data()['userid'] as String;
          // Placeholder for notification logic (e.g., using FCM)
          debugPrint('Notifying user $userId for available slot in class $classId');
          // Remove the user from the waiting list after notification
          await firestore
              .collection('class')
              .doc(classId)
              .collection('Waiting_lists')
              .doc(doc.id)
              .delete();
        }
      } else {
        debugPrint('No users found in waiting list for class $classId');
      }
    } catch (e) {
      debugPrint('Error notifying waiting list users: $e');
    }
  }

  Future<void> _cancelBooking(BuildContext context, String bookingId, String classId, bool isRefundable) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        debugPrint('No user logged in');
        throw Exception('User not logged in');
      }

      debugPrint('Cancelling booking: $bookingId for user: $userId');
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final bookingRef = FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('bookings')
            .doc(bookingId);
        final bookingDoc = await transaction.get(bookingRef);
        if (!bookingDoc.exists) {
          debugPrint('Booking $bookingId not found');
          throw Exception('Booking not found');
        }

        final bookingData = bookingDoc.data() as Map<String, dynamic>;
        final credit_deducted_from = bookingData['credit_deducted_from'] as String?;
        final credit_used = (bookingData['credit_used'] as num?)?.toInt() ?? 0;

        DocumentSnapshot? packageDoc;
        if (isRefundable && credit_deducted_from != null && credit_deducted_from.isNotEmpty && credit_used > 0) {
          final packageRef = FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('Credit_Remains')
              .doc(credit_deducted_from);
          packageDoc = await transaction.get(packageRef);
          if (!packageDoc.exists) {
            debugPrint('Credit_Remains $credit_deducted_from not found');
            throw Exception('Credit package not found');
          }
        }

        final classRef = FirebaseFirestore.instance.collection('class').doc(classId);
        final classDoc = await transaction.get(classRef);
        if (!classDoc.exists) {
          debugPrint('Class $classId not found');
        }

        transaction.update(bookingRef, {'Status': 'Cancelled'});
        debugPrint('Updated booking $bookingId status to Cancelled');

        if (isRefundable && credit_deducted_from != null && credit_deducted_from.isNotEmpty && credit_used > 0 && packageDoc != null) {
          final packageData = packageDoc.data() as Map<String, dynamic>;
          final currentCredits = (packageData['credits_remaining'] as num?)?.toInt() ?? 0;
          if (currentCredits + credit_used >= 0) {
            transaction.update(
              FirebaseFirestore.instance.collection('users').doc(userId).collection('Credit_Remains').doc(credit_deducted_from),
              {'credits_remaining': FieldValue.increment(credit_used)},
            );
            debugPrint('Refunded $credit_used credits to Credit_Remains/$credit_deducted_from');
          } else {
            debugPrint('Invalid credit amount: $currentCredits + $credit_used');
            throw Exception('Invalid credit amount');
          }
        } else {
          debugPrint('No refund: isRefundable=$isRefundable, credit_deducted_from=$credit_deducted_from, credit_used=$credit_used');
        }

        if (classDoc.exists) {
          final classData = classDoc.data() as Map<String, dynamic>;
          final currentBooked = (classData['booked'] as num?)?.toInt() ?? 0;
          if (currentBooked > 0) {
            transaction.update(classRef, {'booked': FieldValue.increment(-1)});
            debugPrint('Decremented booked count for class $classId');
          } else {
            debugPrint('Class $classId booked count is already 0');
          }
        }
      });

      // Notify all users on the waiting list
      await _notifyWaitingListUsers(classId);

      onCancel?.call(bookingId);
      debugPrint('Cancellation successful for booking $bookingId');
    } catch (e) {
      debugPrint('Error cancelling booking: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to cancel booking: $e')),
      );
      throw e;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = const Color(0xFFBDA25B);
    final title = data['title'] ?? 'Unknown Class';
    final date = data['date'] ?? 'Unknown Date';
    final time = data['time'] ?? '--:--';
    final currentTime = DateTime.now().toUtc().add(const Duration(hours: 8));
    final type = (data['type'] as String?)?.toLowerCase() ?? 'class';
    final isEvent = type == 'event';
    final classId = data['classid'] ?? data['id'] ?? '';
    final bookingId = data['bookingId'] ?? '';
    final cancellationPolicy = isEvent
        ? 'You will not receive a refund for Event.\nDO YOU SURE WANT TO CANCEL?'
        : 'Full refund if cancelled more than 8 hours before the class.\nCredits forfeited if cancelled less than 8 hours before.';

    return FutureBuilder<bool>(
      future: _isEligibleForRefund(classId, currentTime),
      builder: (context, snapshot) {
        final isRefundable = isEvent ? false : (snapshot.data ?? false);
        final refundMessage = isEvent
            ? 'You will NOT receive any refund'
            : isRefundable
            ? 'You will receive a full refund.'
            : 'Your credits will be forfeited.';
        final refundColor = isEvent ? Colors.red : isRefundable ? Colors.green : Colors.red;

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
                'Cancel $title',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Current Time: ${DateFormat('h:mm a, MMM yyyy').format(currentTime)}',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Cancellation Policy',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: themeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: themeColor.withOpacity(0.3)),
                ),
                child: Text(
                  cancellationPolicy,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: themeColor,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: refundColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  refundMessage,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: refundColor,
                  ),
                  textAlign: TextAlign.center,
                ),
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
                  if (bookingId.isEmpty || classId.isEmpty) {
                    debugPrint('Invalid bookingId=$bookingId or classId=$classId');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invalid booking or class ID')),
                    );
                    Navigator.pop(context);
                    return;
                  }
                  try {
                    await _cancelBooking(context, bookingId, classId, isRefundable);
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/cancellation_confirmation', arguments: {
                      'data': data,
                      'isRefundable': isRefundable,
                    });
                  } catch (e) {
                    Navigator.pop(context);
                  }
                },
                child: const Text(
                  'Confirm Cancellation',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
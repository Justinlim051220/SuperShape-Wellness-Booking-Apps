import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class CancellationPolicyBottomSheet extends StatelessWidget {
  final Map<String, dynamic> data;

  const CancellationPolicyBottomSheet({super.key, required this.data});

  // Placeholder function to update booking status to Approved after payment
  Future<void> _updateBookingToApproved(String userId, String bookingId, String classId) async {
    print('CancellationPolicyBottomSheet _updateBookingToApproved: Updating bookingId=$bookingId to Approved');
    final firestore = FirebaseFirestore.instance;
    try {
      await firestore
          .collection('users')
          .doc(userId)
          .collection('bookings')
          .doc(bookingId)
          .update({
        'Status': 'Approved',
        'booked_time': FieldValue.serverTimestamp(),
      });
      print('CancellationPolicyBottomSheet _updateBookingToApproved: Successfully updated bookingId=$bookingId to Approved');

      // Optionally increment booked count for events
      await firestore.collection('class').doc(classId).update({
        'booked': FieldValue.increment(1),
      });
      print('CancellationPolicyBottomSheet _updateBookingToApproved: Incremented booked count for classId=$classId');
    } catch (e) {
      print('CancellationPolicyBottomSheet _updateBookingToApproved: Error: $e');
      // Handle error (e.g., log to analytics or notify admin)
    }
  }

  Future<void> _bookClass(BuildContext context) async {
    print('CancellationPolicyBottomSheet _bookClass: Starting with data=$data');
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      print('CancellationPolicyBottomSheet _bookClass: No user ID');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in!')),
      );
      return;
    }

    final firestore = FirebaseFirestore.instance;
    final classId = data['id'] as String?;
    final credit = (data['credit'] as num?)?.toInt() ?? 0;
    final classType = data['class_type'] as String?;
    final type = (data['type'] as String? ?? 'unknown').toLowerCase();
    final isEvent = type == 'event';
    final startDateTime = data['start_date_time'] is DateTime
        ? data['start_date_time'] as DateTime
        : (data['start_date_time'] as Timestamp?)?.toDate() ?? DateTime.now();

    if (classId == null) {
      print('CancellationPolicyBottomSheet _bookClass: Invalid classId');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid class data')),
      );
      return;
    }

    String? bookingId; // Initialize bookingId as null

    try {
      // Check class availability for both group and event classes
      final classDoc = await firestore.collection('class').doc(classId).get();
      if (!classDoc.exists) {
        print('CancellationPolicyBottomSheet _bookClass: Class document not found for classId=$classId');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Class not found. Please try again.')),
        );
        return;
      }
      final booked = (classDoc.data()?['booked'] as num?)?.toInt() ?? 0;
      final slots = (classDoc.data()?['slot'] as num?)?.toInt() ?? 0;
      print('CancellationPolicyBottomSheet _bookClass: Class availability - booked=$booked, slots=$slots');
      if (booked >= slots) {
        print('CancellationPolicyBottomSheet _bookClass: ${isEvent ? 'Event' : 'Class'} is full, booked=$booked, slots=$slots');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${isEvent ? 'Event' : 'Class'} is full. Please join the waiting list.')),
        );
        return;
      }
      final classPrice = (classDoc.data()?['price'] as num?)?.toDouble() ?? 0.0;

      // Check waiting list
      print('CancellationPolicyBottomSheet _bookClass: Querying Waiting_lists for userId=$userId, classId=$classId');
      final waitingListQuery = await firestore
          .collection('class')
          .doc(classId)
          .collection('Waiting_lists')
          .where('userid', isEqualTo: userId)
          .get();

      print('CancellationPolicyBottomSheet _bookClass: Waiting list query returned ${waitingListQuery.docs.length} documents');
      waitingListQuery.docs.forEach((doc) {
        print('CancellationPolicyBottomSheet _bookClass: Waiting list docId=${doc.id}, data=${doc.data()}');
      });

      // Check for existing waiting booking
      print('CancellationPolicyBottomSheet _bookClass: Querying bookings for classId=$classId, Status=Waiting');
      final waitingBookingQuery = await firestore
          .collection('users')
          .doc(userId)
          .collection('bookings')
          .where('classid', isEqualTo: classId)
          .where('Status', isEqualTo: 'Waiting')
          .limit(1)
          .get();

      print('CancellationPolicyBottomSheet _bookClass: Waiting booking query returned ${waitingBookingQuery.docs.length} documents');
      waitingBookingQuery.docs.forEach((doc) {
        print('CancellationPolicyBottomSheet _bookClass: Waiting booking docId=${doc.id}, data=${doc.data()}');
      });

      await firestore.runTransaction((transaction) async {
        // Delete all waiting list entries
        for (var waitingListDoc in waitingListQuery.docs) {
          final waitingListRef = firestore
              .collection('class')
              .doc(classId)
              .collection('Waiting_lists')
              .doc(waitingListDoc.id);
          print('CancellationPolicyBottomSheet _bookClass: Scheduling deletion of waiting list entry, docId=${waitingListDoc.id}');
          transaction.delete(waitingListRef);
        }

        final bookingData = {
          'Status': isEvent ? 'Pending' : 'Booked',
          'booked_time': FieldValue.serverTimestamp(),
          'classid': classId,
          'credit_used': isEvent ? 0 : credit,
          'date': DateFormat('yyyy-MM-dd').format(startDateTime.toUtc().add(const Duration(hours: 8))),
          'price': isEvent ? classPrice : 0.0, // Use class price for events
          'time': DateFormat('h:mm a').format(startDateTime.toUtc().add(const Duration(hours: 8))),
          'title': data['title'] as String? ?? 'Unknown',
          'type': type,
        };

        // Select package for non-event classes (type matches class type or 'trial')
        if (!isEvent) {
          final packagesSnapshot = await firestore
              .collection('users')
              .doc(userId)
              .collection('Credit_Remains')
              .where('is_active', isEqualTo: true)
              .where('credits_remaining', isGreaterThanOrEqualTo: credit)
              .where('validUntil', isGreaterThan: Timestamp.now())
              .where('classType', isEqualTo: classType)
              .where('type', whereIn: [type, 'trial'])
              .orderBy('validUntil', descending: false)
              .limit(1)
              .get();

          if (packagesSnapshot.docs.isEmpty) {
            print('CancellationPolicyBottomSheet _bookClass: No eligible packages found for classType=$classType, type=$type or trial, credit=$credit');
            throw Exception('No active $classType package or trial with enough credits!');
          }

          final package = packagesSnapshot.docs.first;
          final packageId = package.id;
          final packageType = package.data()['type'] as String;
          final currentCredits = (package.data()['credits_remaining'] as num).toInt();
          print('CancellationPolicyBottomSheet _bookClass: Selected packageId=$packageId, type=$packageType, validUntil=${package.data()['validUntil']}, currentCredits=$currentCredits, newCredits=${currentCredits - credit}');

          transaction.update(
            firestore
                .collection('users')
                .doc(userId)
                .collection('Credit_Remains')
                .doc(packageId),
            {'credits_remaining': currentCredits - credit},
          );

          bookingData['credit_deducted_from'] = packageId;
        }

        // Update existing waiting booking or create new
        if (waitingBookingQuery.docs.isNotEmpty) {
          final waitingBookingDoc = waitingBookingQuery.docs.first;
          bookingId = waitingBookingDoc.id;
          final bookingRef = firestore
              .collection('users')
              .doc(userId)
              .collection('bookings')
              .doc(bookingId);
          print('CancellationPolicyBottomSheet _bookClass: Updating existing booking with ID=$bookingId, data=$bookingData');
          transaction.set(bookingRef, bookingData, SetOptions(merge: true));
        } else {
          final bookingRef = firestore
              .collection('users')
              .doc(userId)
              .collection('bookings')
              .doc();
          bookingId = bookingRef.id;
          print('CancellationPolicyBottomSheet _bookClass: Creating new booking with ID=$bookingId, data=$bookingData');
          transaction.set(bookingRef, bookingData);
        }

        // Increment booked count only for group classes here
        if (!isEvent) {
          print('CancellationPolicyBottomSheet _bookClass: Incrementing booked count for classId=$classId');
          transaction.update(
            firestore.collection('class').doc(classId),
            {'booked': FieldValue.increment(1)},
          );
        }
      });

      if (!context.mounted) return;
      print('CancellationPolicyBottomSheet _bookClass: Booking processed with ID=$bookingId');
      print('CancellationPolicyBottomSheet _bookClass: Transaction completed successfully for classId=$classId');
      Navigator.pop(context);
      final args = {
        'amount': isEvent ? classPrice : 0.0,
        'packageId': isEvent ? '' : classId,
        'title': data['title'] as String? ?? 'Unknown',
        'additionalData': {
          'type': type,
          'bookingId': bookingId ?? 'unknown',
          'classId': classId,
          // Pass callback for payment success
          'onPaymentSuccess': isEvent
              ? () => _updateBookingToApproved(userId, bookingId ?? 'unknown', classId)
              : null,
        },
      };
      print('CancellationPolicyBottomSheet _bookClass: Navigating to ${isEvent ? '/payment_options' : '/class_confirmation'} with args=$args');
      Navigator.pushNamed(context, isEvent ? '/payment_options' : '/class_confirmation', arguments: args).then((result) {
        // Handle payment result for events
        if (isEvent && result == true && context.mounted) {
          print('CancellationPolicyBottomSheet _bookClass: Payment successful, updating bookingId=$bookingId to Approved');
          _updateBookingToApproved(userId, bookingId ?? 'unknown', classId);
        }
      });
    } catch (e) {
      print('CancellationPolicyBottomSheet _bookClass: Error: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Booking failed: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    print('CancellationPolicyBottomSheet build: data=$data');
    final type = (data['type'] as String? ?? 'class').toLowerCase();
    final isEvent = type == 'event';
    final title = isEvent ? 'Event Cancellation Policy' : 'Class Cancellation Policy';
    final description = isEvent
        ? '• Please note: bookings are non-refundable. \n • Are you sure you\'d like to proceed?'
        : '• Cancel >8 hours: Full refund\n• Cancel <8 hours: Credit forfeited';
    final credit = (data['credit'] as num?)?.toInt() ?? 0;
    final price = (data['price'] as num?)?.toDouble() ?? 0.0;

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 32,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
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
          const Icon(Icons.info_outline, size: 48, color: Color(0xFFBDA25B)),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 16,
              height: 1.5,
              color: Colors.grey[600],
            ),
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
            onPressed: () => _bookClass(context),
            child: Text(
              isEvent
                  ? 'I UNDERSTAND & AGREE - RM${price.toStringAsFixed(2)}'
                  : 'I UNDERSTAND & AGREE - $credit CREDIT(S)',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'CANCEL',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
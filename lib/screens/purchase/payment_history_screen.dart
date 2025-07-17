import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> paymentHistory = [];
  bool isLoading = true;
  final Map<String, String> _previousStatuses = {};

  @override
  void initState() {
    super.initState();
    _loadPaymentHistory();
    _setupPaymentListener();
  }

  Future<void> _loadPaymentHistory() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        print('No authenticated user found');
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to view payment history')),
        );
        return;
      }

      print('Loading payment history for user: $userId');
      final querySnapshot = await _firestore
          .collection('Payment')
          .where('userid', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();
      print('Query snapshot size: ${querySnapshot.docs.length}');

      final payments = querySnapshot.docs.map((doc) {
        final data = doc.data();
        _previousStatuses[doc.id] = data['Status'] as String? ?? 'Unknown';
        return {
          'id': doc.id,
          'packageId': data['PackageID'] as String?,
          'createdAt': data['createdAt'] as Timestamp?,
          'status': data['Status'] as String? ?? 'Unknown',
          'amount': data['amount'] as num? ?? 0.0,
          'uploadedReceiptURL': data['UploadedReceiptURL'] as String?,
          'approveBy': data['approveBy'] as String? ?? '',
        };
      }).toList();

      for (var payment in payments) {
        final packageId = payment['packageId'] as String?;
        if (packageId != null && packageId.isNotEmpty) {
          // Handle package payments
          final packageDoc = await _firestore
              .collection('Credit_Packages')
              .doc(packageId)
              .get();
          payment['description'] = packageDoc.exists
              ? (packageDoc.data()?['title'] as String?)?.isNotEmpty == true
              ? packageDoc.data()!['title'] as String
              : 'Unknown Package'
              : 'Unknown Package';
        } else {
          // Handle event payments
          final bookingSnapshot = await _firestore
              .collection('users')
              .doc(userId)
              .collection('bookings')
              .where('paymentId', isEqualTo: payment['id'])
              .where('type', isEqualTo: 'event')
              .limit(1)
              .get();
          payment['description'] = bookingSnapshot.docs.isNotEmpty
              ? bookingSnapshot.docs.first.data()['title'] as String? ??
              'Unknown Event'
              : 'Unknown Event';
        }
      }

      setState(() {
        paymentHistory = payments;
        isLoading = false;
      });
      print('Payment History Length: ${paymentHistory.length}');
    } catch (e, stackTrace) {
      print('Error loading payment history: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading payment history: $e')),
      );
    }
  }

  void _setupPaymentListener() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    _firestore
        .collection('Payment')
        .where('userid', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docChanges) {
        if (doc.type == DocumentChangeType.modified) {
          final newData = doc.doc.data() as Map<String, dynamic>;
          final currentStatus = newData['Status'] as String? ?? 'Unknown';
          final previousStatus = _previousStatuses[doc.doc.id] ?? 'Unknown';
          if (currentStatus == 'Approved' && previousStatus != 'Approved') {
            _processApprovedPayment(doc.doc.id, newData);
            _previousStatuses[doc.doc.id] = currentStatus;
          }
        }
      }
    }, onError: (error) {
      print('Error listening to payments: $error');
    });
  }

  Future<void> _processApprovedPayment(String paymentId, Map<String, dynamic> paymentData) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final packageId = paymentData['PackageID'] as String?;
      if (packageId == null || packageId.isEmpty) {
        // Handle event payment
        final bookingSnapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('bookings')
            .where('paymentId', isEqualTo: paymentId)
            .where('type', isEqualTo: 'event')
            .limit(1)
            .get();
        if (bookingSnapshot.docs.isNotEmpty) {
          final bookingId = bookingSnapshot.docs.first.id;
          final bookingData = bookingSnapshot.docs.first.data();
          if (bookingData['Status'] == 'Pending') {
            await _firestore
                .collection('users')
                .doc(userId)
                .collection('bookings')
                .doc(bookingId)
                .update({'Status': 'Booked'});
            print('PaymentHistoryScreen: Updated booking $bookingId to Booked');
          }
        }
      }
      // Removed package payment handling to prevent Credit_Remains creation
    } catch (e) {
      print('Error processing approved payment: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    print('Building PaymentHistoryScreen with paymentHistory length: ${paymentHistory.length}');
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Payment History',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFBDA25B),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : paymentHistory.isEmpty
          ? const Center(child: Text('No payment history available.'))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: paymentHistory.length,
        itemBuilder: (context, index) {
          final record = paymentHistory[index];
          print('Rendering payment record $index: $record');
          final date = record['createdAt'] != null
              ? DateFormat('yyyy-MM-dd hh:mm a')
              .format((record['createdAt'] as Timestamp).toDate())
              : 'Unknown Date';
          final description =
              record['description'] as String? ?? 'Unknown Transaction';
          final status = record['status'] as String? ?? 'Unknown';
          final color =
          status == 'Approved' ? Colors.green : Colors.orange;
          final icon = status == 'Approved'
              ? Icons.check_circle_outline
              : Icons.pending_outlined;

          return Card(
            margin: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
            shadowColor: Colors.grey.withOpacity(0.2),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [Colors.white, Colors.grey.shade50],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                leading: Icon(
                  icon,
                  color: color,
                  size: 30,
                ),
                title: Text(
                  description,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                subtitle: Text(
                  date,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                trailing: Text(
                  status,
                  style: TextStyle(
                    fontSize: 14,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
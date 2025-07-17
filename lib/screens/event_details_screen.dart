import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EventDetailsScreen extends StatefulWidget {
  const EventDetailsScreen({super.key});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Map<String, dynamic>? eventData;
  Map<String, dynamic>? instructorData;
  bool _isLoading = true;
  bool _hasBooked = false;
  String? _eventId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    print('EventDetailsScreen: Received arguments=$args');
    _eventId = args?['id'] as String?;
    if (_eventId != null && _eventId!.isNotEmpty) {
      _loadEventData();
      _checkBookingStatus();
    } else {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid event ID.')),
      );
    }
  }

  Future<void> _loadEventData() async {
    try {
      final doc = await _firestore.collection('class').doc(_eventId).get();
      if (doc.exists) {
        final data = doc.data()!;
        final instructorDoc = await _firestore.collection('users').doc(data['instructor_id']).get();
        setState(() {
          eventData = {
            'id': _eventId,
            'title': data['title'] ?? 'Unknown Event',
            'start_date_time': (data['start_date_time'] as Timestamp?)?.toDate() ?? DateTime.now(),
            'duration': data['duration'] ?? '',
            'booked': data['booked'] ?? 0,
            'slots': data['slot'] ?? 0,
            'price': data['price']?.toDouble() ?? 0.0,
            'description': data['description'] ?? 'No description available',
            'instructor_id': data['instructor_id'],
            'placeholder_image': data['placeholder_image'] ?? 'assets/default.jpg',
            'type': data['type'] ?? 'event',
            'class_type': data['class_type'] ?? 'unknown',
          };
          instructorData = instructorDoc.data() ?? {'full_name': 'Unknown Instructor', 'photo_url': null};
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event not found.')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading event: $e')),
      );
    }
  }

  Future<void> _checkBookingStatus() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null || _eventId == null) return;

    try {
      final query = await _firestore
          .collection('users')
          .doc(userId)
          .collection('bookings')
          .where('classid', isEqualTo: _eventId)
          .where('Status', whereIn: ['Booked', 'Pending'])
          .limit(1)
          .get();
      setState(() {
        _hasBooked = query.docs.isNotEmpty;
      });
    } catch (e) {
      print('Error checking booking status: $e');
    }
  }

  Future<void> bookEvent(String eventId, double price) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in')),
      );
      return;
    }

    try {
      print('Booking event: eventId=$eventId, price=$price');
      // Check existing booking
      final existingBooking = await _firestore
          .collection('users')
          .doc(userId)
          .collection('bookings')
          .where('classid', isEqualTo: eventId)
          .where('Status', whereIn: ['Booked', 'Pending'])
          .limit(1)
          .get();
      if (existingBooking.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have already booked this event.')),
        );
        return;
      }

      // Check slot availability
      final eventDoc = await _firestore.collection('class').doc(eventId).get();
      final booked = (eventDoc.data()?['booked'] as num?)?.toInt() ?? 0;
      final slots = (eventDoc.data()?['slots'] as num?)?.toInt() ?? 0;
      if (booked >= slots) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No slots available for this event.')),
        );
        return;
      }

      // Create booking
      final bookingRef = _firestore.collection('users').doc(userId).collection('bookings').doc();
      final bookingData = {
        'classid': eventId,
        'Status': 'Pending',
        'booked_time': FieldValue.serverTimestamp(),
        'title': eventData!['title'] ?? 'Unknown Event',
        'type': eventData!['type'] ?? 'event',
        'price': price,
        'date': DateFormat('yyyy-MM-dd').format(
          eventData!['start_date_time'].toUtc().add(const Duration(hours: 8)),
        ),
        'time': DateFormat('h:mm a').format(
          eventData!['start_date_time'].toUtc().add(const Duration(hours: 8)),
        ),
        'credit_deducted_from': '',
        'credit_used': 0,
        'paymentId': '',
      };
      await bookingRef.set(bookingData);
      print('Created booking: ${bookingRef.id} with Status: Pending');

      // Navigate to payment options
      Navigator.pushNamed(
        context,
        '/payment_options',
        arguments: {
          'packageId': eventId,
          'amount': price,
          'title': eventData!['title'] ?? 'Unknown Event',
          'additionalData': {
            'type': eventData!['type'] ?? 'event',
            'bookingId': bookingRef.id,
            'id': eventId,
            'price': price,
            'title': eventData!['title'],
            'class_type': eventData!['class_type'],
            'start_date_time': eventData!['start_date_time'],
            'duration': eventData!['duration'],
            'description': eventData!['description'],
            'instructor_id': eventData!['instructor_id'],
            'placeholder_image': eventData!['placeholder_image'],
          },
        },
      );
      print('Navigating to /payment_options with packageId: $eventId, amount: $price');
    } catch (e) {
      print('Error booking event: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error booking event: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (eventData == null) {
      return const Scaffold(
        body: Center(child: Text('Event not found')),
      );
    }

    final title = eventData!['title'] ?? 'Unknown Event';
    final startDateTime = eventData!['start_date_time'] as DateTime;
    final date = DateFormat('EEEE, MMM d, yyyy').format(startDateTime);
    final time = DateFormat('h:mm a').format(startDateTime);
    final duration = eventData!['duration'] ?? '';
    final price = eventData!['price']?.toDouble() ?? 0.0;
    final description = eventData!['description'] ?? 'No description';
    final booked = eventData!['booked'] ?? 0;
    final slots = eventData!['slots'] ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Event Details')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // UI elements for event details (simplified)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                Text('$date • $time • $duration'),
                Text('Price: RM ${price.toStringAsFixed(2)}'),
                Text('Slots: $booked/$slots'),
                Text(description),
                const SizedBox(height: 16),
                if (!_hasBooked)
                  ElevatedButton(
                    onPressed: () => bookEvent(_eventId!, price),
                    child: const Text('Book Now'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../course/course_details_screen.dart';

class MyBookingScreen extends StatefulWidget {
  const MyBookingScreen({super.key});

  @override
  State<MyBookingScreen> createState() => _MyBookingScreenState();
}

class _MyBookingScreenState extends State<MyBookingScreen> {
  bool _showUpcoming = true;
  final Color themeColor = const Color(0xFFBDA25B);
  bool _isLoading = false;
  String _errorMessage = '';
  bool _isMounted = false;

  List<Map<String, dynamic>> upcomingBookings = [];
  List<Map<String, dynamic>> pastBookings = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    _loadBookingData();
  }

  @override
  void dispose() {
    _isMounted = false;
    super.dispose();
  }

  Future<void> _loadBookingData() async {
    if (!_isMounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      upcomingBookings = [];
      pastBookings = [];
    });

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        if (_isMounted) {
          setState(() {
            _errorMessage = 'User not logged in';
            _isLoading = false;
          });
        }
        debugPrint('No user logged in');
        return;
      }

      debugPrint('Fetching bookings for user: $userId');
      final now = DateTime.now().toUtc().add(const Duration(hours: 8));
      debugPrint('Current time (UTC+8): $now');
      final bookingsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('bookings')
          .orderBy('booked_time', descending: true)
          .get();

      debugPrint('Found ${bookingsSnapshot.docs.length} bookings');
      for (var doc in bookingsSnapshot.docs) {
        final bookingData = doc.data();
        debugPrint('Processing booking: ${doc.id}, data: $bookingData');
        final classId = bookingData['classid'] as String?;
        if (classId == null || classId.isEmpty) {
          debugPrint('Skipping booking ${doc.id}: Missing or empty classid');
          continue;
        }

        final classDoc = await _firestore.collection('class').doc(classId).get();
        if (!classDoc.exists) {
          debugPrint('Skipping booking ${doc.id}: Class $classId not found');
          continue;
        }

        final classData = classDoc.data()!;
        final date = bookingData['date'] as String?;
        final time = bookingData['time'] as String?;
        DateTime startDateTime;
        try {
          startDateTime = DateFormat('yyyy-MM-dd h:mm a').parse('$date $time');
          debugPrint('Parsed start_date_time for booking ${doc.id}: $startDateTime');
        } catch (e) {
          debugPrint('Error parsing date/time for booking ${doc.id}: $e');
          continue;
        }

        // Assume event duration is 1 hour (adjust as needed)
        final endDateTime = startDateTime.add(const Duration(hours: 1));
        final isPast = endDateTime.toUtc().add(const Duration(hours: 8)).isBefore(now);
        var status = bookingData['Status'] as String? ?? 'Unknown';
        debugPrint('Booking ${doc.id} status: $status, isPast: $isPast');

        // Update status to 'Completed' if the event has ended and status is 'Booked'
        if (status == 'Booked' && isPast) {
          try {
            await _firestore
                .collection('users')
                .doc(userId)
                .collection('bookings')
                .doc(doc.id)
                .update({'Status': 'Completed'});
            status = 'Completed';
            debugPrint('Updated booking ${doc.id} to Completed');
          } catch (e) {
            debugPrint('Error updating booking ${doc.id} to Completed: $e');
          }
        }

        final instructorId = classData['instructor_id'] as String?;
        String instructorName = 'Unknown Instructor';
        String instructorImage = '';

        if (instructorId != null && instructorId.isNotEmpty) {
          final instructorDoc = await _firestore.collection('users').doc(instructorId).get();
          if (instructorDoc.exists) {
            final instructorData = instructorDoc.data()!;
            instructorName = instructorData['full_name'] as String? ?? 'Unknown Instructor';
            instructorImage = instructorData['photo_url'] as String? ?? '';
          }
        }

        final booking = {
          ...bookingData,
          'bookingId': doc.id,
          'title': bookingData['title'] as String? ?? classData['title'] as String? ?? 'Unknown Class',
          'date': date,
          'time': time,
          'start_date_time': startDateTime,
          'instructor': instructorName,
          'instructor_image': instructorImage,
          'placeholder_image': classData['placeholder_image'] as String? ?? 'assets/default.jpg',
          'class_type': classData['class_type'] as String? ?? 'unknown',
          'type': bookingData['type'] as String? ?? classData['type'] as String? ?? 'unknown',
          'credit': (classData['credit'] as num?)?.toInt() ?? 0,
          'description': classData['description'] as String? ?? '',
          'slot': (classData['slot'] as num?)?.toInt() ?? 0,
          'booked': (classData['booked'] as num?)?.toInt() ?? 0,
          'status': status,
          'classid': classId,
        };

        if (_isMounted) {
          if ((status == 'Booked' || status == 'Waiting' || status == 'Pending') && !isPast) {
            upcomingBookings.add(booking);
            debugPrint('Added to upcoming: ${booking['bookingId']}');
          } else {
            pastBookings.add(booking);
            debugPrint('Added to past: ${booking['bookingId']}');
          }
        }
      }

      if (_isMounted) {
        setState(() {
          upcomingBookings.sort((a, b) => a['start_date_time'].compareTo(b['start_date_time']));
          pastBookings.sort((a, b) => b['start_date_time'].compareTo(a['start_date_time']));
          _isLoading = false;
        });
        debugPrint('Upcoming bookings: ${upcomingBookings.length}');
        debugPrint('Past bookings: ${pastBookings.length}');
      }
    } catch (error) {
      if (_isMounted) {
        setState(() {
          _errorMessage = 'Failed to load bookings. Please try again.';
          _isLoading = false;
        });
      }
      debugPrint('Error loading bookings: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentList = _showUpcoming ? upcomingBookings : pastBookings;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double basePadding = screenWidth * 0.04; // ≈12-16px
    final double baseFontSize = screenWidth * 0.04; // ≈14-16px

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: themeColor,
        centerTitle: true,
        title: Text(
          'MY BOOKINGS',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: baseFontSize * 1.2,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: basePadding, horizontal: basePadding),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _showUpcoming ? themeColor : Colors.transparent,
                      foregroundColor: _showUpcoming ? Colors.white : themeColor,
                      side: BorderSide(
                        color: themeColor,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: EdgeInsets.symmetric(
                        vertical: basePadding * 0.8,
                      ),
                      elevation: _showUpcoming ? 3 : 0,
                    ),
                    onPressed: () => setState(() => _showUpcoming = true),
                    child: Text(
                      'Upcoming Booking',
                      style: TextStyle(
                        fontSize: baseFontSize * 0.9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: basePadding),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !_showUpcoming ? themeColor : Colors.transparent,
                      foregroundColor: !_showUpcoming ? Colors.white : themeColor,
                      side: BorderSide(
                        color: themeColor,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: EdgeInsets.symmetric(
                        vertical: basePadding * 0.8,
                      ),
                      elevation: !_showUpcoming ? 3 : 0,
                    ),
                    onPressed: () => setState(() => _showUpcoming = false),
                    child: Text(
                      'Past Booking',
                      style: TextStyle(
                        fontSize: baseFontSize * 0.9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFBDA25B)),
              ),
            )
                : _errorMessage.isNotEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadBookingData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
                : currentList.isEmpty
                ? Center(
              child: Text(
                _showUpcoming ? 'No upcoming bookings available.' : 'No past bookings available.',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
                : ListView.builder(
              itemCount: currentList.length,
              itemBuilder: (context, index) {
                final item = currentList[index];
                final className = item['title'] ?? 'Unknown Class';
                final time = item['time'] ?? '--:--';
                final date = item['date'] ?? 'Unknown Date';
                final instructor = item['instructor'] ?? 'Unknown';
                final status = item['status'] ?? 'Unknown';

                return GestureDetector(
                  onTap: () {
                    debugPrint('Navigating to CourseDetailsScreen with bookingData: $item');
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CourseDetailsScreen(
                          bookingData: item,
                          fromBooking: _showUpcoming,
                          onCancel: null, // Handled in CancellationPromptBottomSheet
                        ),
                      ),
                    ).then((_) => _loadBookingData());
                  },
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                    color: const Color(0xFFF5F5F5),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            className,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text('$time • $date'),
                          Text('Instructor: $instructor'),
                          const SizedBox(height: 8),
                          Chip(
                            label: Text(status),
                            backgroundColor: status == 'Booked'
                                ? Colors.green[100]
                                : status == 'Waiting' || status == 'Pending'
                                ? Colors.orange[100]
                                : status == 'Completed'
                                ? Colors.blue[100]
                                : status == 'Cancelled' || status == 'Rejected'
                                ? Colors.red[100]
                                : Colors.grey[200],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 3),
    );
  }
}
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'waiting_list_prompt_bottom.dart';
import 'cancellation_policy_bottom.dart';
import 'cancellation_prompt_bottom.dart';
import 'cancel_waiting_prompt_bottom.dart';

class CourseDetailsScreen extends StatefulWidget {
  final Map<String, dynamic>? bookingData;
  final bool fromBooking;
  final Function(String)? onCancel;

  const CourseDetailsScreen({
    super.key,
    this.bookingData,
    this.fromBooking = false,
    this.onCancel,
  });

  @override
  State<CourseDetailsScreen> createState() => _CourseDetailsScreenState();
}

class _CourseDetailsScreenState extends State<CourseDetailsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Map<String, dynamic>? classData;
  Map<String, dynamic>? instructorData;
  List<Map<String, dynamic>> userPackages = [];
  bool _isLoading = true;
  bool _hasBooked = false;
  bool _isOnWaitingList = false;
  bool _isMounted = false;
  StreamSubscription<DocumentSnapshot>? _classSubscription;

  @override
  void initState() {
    print('CourseDetailsScreen initState: bookingData=${widget.bookingData}, fromBooking=${widget.fromBooking}');
    super.initState();
    _isMounted = true;
    _loadClassData();
    _loadUserPackages();
    _checkBookingStatus();
    _checkWaitingListStatus();
  }

  @override
  void dispose() {
    _isMounted = false;
    _classSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkBookingStatus() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null || classData == null) {
      print('CourseDetailsScreen _checkBookingStatus: userId=$userId, classData=$classData');
      return;
    }

    try {
      final query = await _firestore
          .collection('users')
          .doc(userId)
          .collection('bookings')
          .where('classid', isEqualTo: classData!['id'])
          .where('Status', whereIn: ['Booked', 'Pending', 'Waiting'])
          .limit(1)
          .get();

      if (_isMounted) {
        setState(() {
          _hasBooked = query.docs.isNotEmpty && query.docs.first['Status'] != 'Waiting';
          print('CourseDetailsScreen _checkBookingStatus: hasBooked=$_hasBooked, queryDocs=${query.docs.length}, status=${query.docs.isNotEmpty ? query.docs.first['Status'] : 'none'}');
        });
      }
    } catch (e) {
      print('CourseDetailsScreen _checkBookingStatus: Error: $e');
    }
  }

  Future<void> _checkWaitingListStatus() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null || classData == null) {
      print('CourseDetailsScreen _checkWaitingListStatus: userId=$userId, classData=$classData');
      return;
    }

    try {
      final query = await _firestore
          .collection('class')
          .doc(classData!['id'])
          .collection('Waiting_lists')
          .where('userid', isEqualTo: userId)
          .limit(1)
          .get();

      if (_isMounted) {
        setState(() {
          _isOnWaitingList = query.docs.isNotEmpty;
          print('CourseDetailsScreen _checkWaitingListStatus: isOnWaitingList=$_isOnWaitingList, queryDocs=${query.docs.length}');
        });
      }
    } catch (e) {
      print('CourseDetailsScreen _checkWaitingListStatus: Error: $e');
    }
  }

  Future<void> _loadClassData() async {
    final classId = widget.bookingData?['id'] ?? widget.bookingData?['classid'] ?? (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?)?['id'];
    print('CourseDetailsScreen _loadClassData: classId=$classId');
    if (classId == null || classId.isEmpty) {
      if (_isMounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid class ID. Please try again.')),
        );
      }
      return;
    }

    try {
      final doc = await _firestore.collection('class').doc(classId).get();
      if (doc.exists) {
        final data = doc.data()!;
        final instructorDoc = await _firestore.collection('users').doc(data['instructor_id']).get();
        print('CourseDetailsScreen _loadClassData: Class data=$data');
        print('CourseDetailsScreen _loadClassData: Placeholder image=${data['placeholder_image']}, Price=${data['price']}');
        if (_isMounted) {
          setState(() {
            classData = {
              'id': classId,
              'booked': data['booked'] ?? 0,
              'slots': data['slot'] ?? 0,
              'credit': data['credit'] ?? 0,
              'price': data['price']?.toDouble() ?? 0.0,
              'start_date_time': (data['start_date_time'] as Timestamp?)?.toDate() ?? DateTime.now(),
              'description': data['description'] ?? 'No description available',
              'duration': data['duration'] ?? '',
              'instructor_id': data['instructor_id'],
              'placeholder_image': data['placeholder_image'] ?? 'assets/default.jpg',
              'title': data['title'] ?? 'Unknown Title',
              'class_type': data['class_type'] ?? 'unknown',
              'type': data['type'] ?? 'unknown',
            };
            instructorData = instructorDoc.data() ?? {
              'full_name': 'Unknown Instructor',
              'photo_url': null,
            };
            _isLoading = false;
          });

          _classSubscription = _firestore.collection('class').doc(classId).snapshots().listen((snapshot) {
            if (snapshot.exists && _isMounted) {
              final data = snapshot.data()!;
              setState(() {
                classData?['booked'] = data['booked'] ?? 0;
                classData?['slots'] = data['slot'] ?? 0;
                print('CourseDetailsScreen _classSubscription: Updated booked=${classData?['booked']}, slots=${classData?['slots']}');
              });
              _checkBookingStatus();
              _checkWaitingListStatus();
            }
          }, onError: (e) {
            print('CourseDetailsScreen _classSubscription: Error: $e');
          });

          await Future.wait([
            _checkBookingStatus(),
            _checkWaitingListStatus(),
          ]);
        }
      } else {
        if (_isMounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Class not found.')),
          );
        }
      }
    } catch (e) {
      print('CourseDetailsScreen _loadClassData: Error: $e');
      if (_isMounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading class: $e')),
        );
      }
    }
  }

  Future<void> _loadUserPackages() async {
    final userId = _auth.currentUser?.uid;
    print('CourseDetailsScreen _loadUserPackages: userId=$userId');
    if (userId == null) {
      if (_isMounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('Credit_Remains')
          .where('is_active', isEqualTo: true)
          .get();
      if (_isMounted) {
        setState(() {
          userPackages = snapshot.docs.map((doc) => doc.data()..['id'] = doc.id).toList();
          _isLoading = false;
          print('CourseDetailsScreen _loadUserPackages: Loaded ${userPackages.length} packages');
        });
      }
    } catch (e) {
      print('CourseDetailsScreen _loadUserPackages: Error: $e');
      if (_isMounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool canBookClass(String? classType, int credit, String type) {
    if (classType == null) return false;
    final eligiblePackages = userPackages.where((pkg) =>
    pkg['classType'] == classType &&
        (pkg['type'] == type|| pkg['type'] == 'trial')&&
        ((pkg['credits_remaining'] as num?)?.toInt() ?? 0) >= credit &&
        (pkg['validUntil'] as Timestamp?)?.toDate().isAfter(DateTime.now()) == true);
    return eligiblePackages.isNotEmpty;
  }

  Future<void> _bookClass(String classId, int credit) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in')),
      );
      return;
    }

    try {
      print('CourseDetailsScreen _bookClass: Starting booking process for classId=$classId, userId=$userId');

      // Check for eligible packages
      final eligiblePackages = userPackages.where((pkg) =>
      pkg['classType'] == classData?['class_type'] &&
          (pkg['type'] == classData?['type'] || pkg['type'] == 'trial') &&
          ((pkg['credits_remaining'] as num?)?.toInt() ?? 0) >= credit &&
          (pkg['validUntil'] as Timestamp?)?.toDate().isAfter(DateTime.now()) == true);

      if (eligiblePackages.isEmpty) {
        print('CourseDetailsScreen _bookClass: No eligible packages found for classType=${classData?['class_type']}, type=${classData?['type']}, credit=$credit');
        showErrorDialog(
          'You do not have an active ${classData?['class_type']} package with enough credits. Please purchase a suitable package.',
        );
        return;
      }

      final selectedPackage = eligiblePackages.reduce((a, b) =>
      (a['validUntil'] as Timestamp).compareTo(b['validUntil'] as Timestamp) < 0 ? a : b);
      final packageId = selectedPackage['id'];
      final currentCredits = (selectedPackage['credits_remaining'] as num?)?.toInt() ?? 0;
      final newCredits = currentCredits - credit;
      print('CourseDetailsScreen _bookClass: Selected packageId=$packageId, currentCredits=$currentCredits, newCredits=$newCredits');

      // Check class availability
      final classDoc = await _firestore.collection('class').doc(classId).get();
      if (!classDoc.exists) {
        print('CourseDetailsScreen _bookClass: Class document not found for classId=$classId');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Class not found. Please try again.')),
        );
        return;
      }
      final booked = (classDoc.data()?['booked'] as num?)?.toInt() ?? 0;
      final slots = (classDoc.data()?['slot'] as num?)?.toInt() ?? 0;
      print('CourseDetailsScreen _bookClass: Class availability - booked=$booked, slots=$slots');
      if (booked >= slots) {
        print('CourseDetailsScreen _bookClass: Class is full, booked=$booked, slots=$slots');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Class is full. Please join the waiting list.')),
        );
        return;
      }

      // Check waiting list for the current user
      print('CourseDetailsScreen _bookClass: Querying Waiting_lists for userId=$userId, classId=$classId');
      final waitingListQuery = await _firestore
          .collection('class')
          .doc(classId)
          .collection('Waiting_lists')
          .where('userid', isEqualTo: userId)
          .get();
      print('CourseDetailsScreen _bookClass: Waiting list query returned ${waitingListQuery.docs.length} documents');
      waitingListQuery.docs.forEach((doc) {
        print('CourseDetailsScreen _bookClass: Waiting list docId=${doc.id}, data=${doc.data()}');
      });

      // Execute transaction
      try {
        await _firestore.runTransaction((transaction) async {
          // Delete all waiting list entries for this user and class
          for (var waitingListDoc in waitingListQuery.docs) {
            final waitingListRef = _firestore
                .collection('class')
                .doc(classId)
                .collection('Waiting_lists')
                .doc(waitingListDoc.id);
            print('CourseDetailsScreen _bookClass: Scheduling deletion of waiting list entry, docId=${waitingListDoc.id}');
            transaction.delete(waitingListRef);
          }

          // Create new booking
          final bookingRef = _firestore
              .collection('users')
              .doc(userId)
              .collection('bookings')
              .doc();
          print('CourseDetailsScreen _bookClass: Creating new booking, bookingRef=${bookingRef.path}');
          transaction.set(bookingRef, {
            'classid': classId,
            'Status': 'Booked',
            'booked_time': FieldValue.serverTimestamp(),
            'date': DateFormat('yyyy-MM-dd').format(classData!['start_date_time'].toUtc().add(const Duration(hours: 8))),
            'time': DateFormat('h:mm a').format(classData!['start_date_time'].toUtc().add(const Duration(hours: 8))),
            'credit_deducted_from': packageId,
            'credit_used': credit,
            'title': classData!['title'],
            'type': classData!['type'],
            'price': classData!['price'],
          });

          // Update package credits
          final packageRef = _firestore
              .collection('users')
              .doc(userId)
              .collection('Credit_Remains')
              .doc(packageId);
          print('CourseDetailsScreen _bookClass: Updating package credits, packageId=$packageId, newCredits=$newCredits');
          transaction.update(packageRef, {'credits_remaining': newCredits});

          // Increment booked count
          final classRef = _firestore.collection('class').doc(classId);
          print('CourseDetailsScreen _bookClass: Incrementing booked count for classId=$classId');
          transaction.update(classRef, {
            'booked': FieldValue.increment(1),
          });
        });

        print('CourseDetailsScreen _bookClass: Transaction completed successfully for classId=$classId');
        if (_isMounted) {
          setState(() {
            _hasBooked = true;
            _isOnWaitingList = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Booking confirmed! Credit deducted.')),
          );
          Navigator.pushNamed(context, '/class_confirmation', arguments: classData);
        }
      } catch (e) {
        print('CourseDetailsScreen _bookClass: Transaction failed: $e');
        if (_isMounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error booking class: $e')),
          );
        }
      }
    } catch (e) {
      print('CourseDetailsScreen _bookClass: General error: $e');
      if (_isMounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error booking class: $e')),
        );
      }
    }
  }

  void showErrorDialog(String message) {
    if (!_isMounted) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 60),
              const SizedBox(height: 20),
              const Text('Booking Error', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 12),
              Text(message, style: const TextStyle(fontSize: 16, color: Colors.grey), textAlign: TextAlign.center),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFBDA25B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    if (_isMounted) {
                      Navigator.pushNamed(context, '/payment_history').catchError((e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Navigation error: $e')),
                        );
                        return Future.value();
                      });
                    }
                  },
                  child: const Text('PURCHASE PACKAGE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCEL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    final utcPlus8 = dateTime.toUtc().add(const Duration(hours: 8));
    return DateFormat('EEEE, dd MMMM yyyy').format(utcPlus8);
  }

  String _calculateTimeRange(DateTime startDateTime, String duration) {
    try {
      int minutes = 0;
      final parts = duration.trim().split(' ');
      if (parts.contains('hour') || parts.contains('hours')) {
        final hoursIndex = parts.indexWhere((part) => part == 'hour' || part == 'hours');
        final hours = int.parse(parts[hoursIndex - 1]);
        minutes += hours * 60;
        if (parts.contains('minute') || parts.contains('minutes')) {
          final minutesIndex = parts.indexWhere((part) => part == 'minute' || part == 'minutes');
          final mins = int.parse(parts[minutesIndex - 1]);
          minutes += mins;
        }
      } else if (parts.contains('minute') || parts.contains('minutes')) {
        final minutesIndex = parts.indexWhere((part) => part == 'minute' || part == 'minutes');
        final mins = int.parse(parts[minutesIndex - 1]);
        minutes += mins;
      }
      final utcPlus8Start = startDateTime.toUtc().add(const Duration(hours: 8));
      final endDateTime = utcPlus8Start.add(Duration(minutes: minutes));
      final startFormatted = DateFormat('ha').format(utcPlus8Start).toLowerCase();
      final endFormatted = DateFormat('ha').format(endDateTime).toLowerCase();
      return '$startFormatted - $endFormatted';
    } catch (e) {
      print('CourseDetailsScreen _calculateTimeRange: Error: $e');
      return '--:-- - --:--';
    }
  }

  bool _hasEventEnded(DateTime startDateTime) {
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    return startDateTime.toUtc().add(const Duration(hours: 8)).isBefore(now);
  }

  bool _isWithinEightHours(DateTime startDateTime, String type) {
    if (type != 'class') return false;
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    final eightHoursFromNow = now.add(const Duration(hours: 8));
    return startDateTime.toUtc().add(const Duration(hours: 8)).isBefore(eightHoursFromNow);
  }

  Widget _buildHeaderImage(BuildContext context, String imagePath, String title) {
    return Stack(
      children: [
        if (imagePath.startsWith('http'))
          Image.network(
            imagePath,
            height: 250,
            width: double.infinity,
            fit: BoxFit.cover,
            cacheHeight: 250,
            cacheWidth: (MediaQuery.of(context).size.width).toInt(),
            loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                height: 250,
                color: Colors.grey[200],
                child: Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
              );
            },
            errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
              print('CourseDetailsScreen _buildHeaderImage: Image load error for $title: $error');
              return Container(
                height: 250,
                color: Colors.grey[200],
                child: Center(
                  child: Text(
                    'Image not available',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),
                ),
              );
            },
          )
        else
          Image.asset(
            imagePath,
            height: 250,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              height: 250,
              color: Colors.grey[200],
              child: Center(
                child: Text(
                  'Image not available',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                ),
              ),
            ),
          ),
        Container(
          height: 250,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withOpacity(0.6)],
            ),
          ),
        ),
        Positioned(
          bottom: 16,
          left: 16,
          child: Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(color: Colors.black.withOpacity(0.5), offset: const Offset(1, 1), blurRadius: 3)],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFFBDA25B)),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: const Color(0xFFBDA25B),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeRow(BuildContext context, String formattedDate, String timeRange, double booked, double slots) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(formattedDate,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.black87, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(timeRange,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600], fontWeight: FontWeight.bold)),
          ],
        ),
        if (slots > 0 && booked >= 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFBDA25B).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${booked.toInt()}/${slots.toInt()}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFFBDA25B), fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }

  Widget _buildDetailText(BuildContext context, String text) {
    return Text(text,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.black87, fontWeight: FontWeight.w500));
  }

  Widget _buildInstructorRow(BuildContext context, String instructor, String? instructorImage) {
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundImage: instructorImage != null ? NetworkImage(instructorImage) : null,
          backgroundColor: Colors.grey[200],
          child: instructorImage == null ? Icon(Icons.person, color: Colors.grey[600]) : null,
        ),
        const SizedBox(width: 12),
        Text(instructor,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.black87, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildDescriptionText(BuildContext context, String text) {
    return Text(text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600], height: 1.5));
  }

  Widget _buildActionSection(BuildContext context) {
    if (classData == null) return const SizedBox.shrink();
    final startDateTime = classData!['start_date_time'] as DateTime;
    final bookedNum = (classData!['booked'] as num?)?.toDouble();
    final slotsNum = (classData!['slots'] as num?)?.toDouble();
    final booked = bookedNum ?? 0.0;
    final slots = slotsNum ?? 0.0;
    final isFull = booked >= slots;
    final type = classData!['type'] ?? 'unknown';
    final credit = (classData!['credit'] as num?)?.toInt() ?? 0;
    final classType = classData!['class_type'] as String?;
    final price = (classData!['price'] as num?)?.toDouble() ?? 0.0;

    print('CourseDetailsScreen _buildActionSection: hasBooked=$_hasBooked, isOnWaitingList=$_isOnWaitingList, isFull=$isFull, type=$type');

    if (_hasEventEnded(startDateTime)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Text(
            type == 'event' ? 'This event has ended.' : 'This class has ended.',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: Colors.grey[600], fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    if (type == 'group' && _isWithinEightHours(startDateTime, type)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Text(
            'Booking closed (less than 8 hours to start)',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: Colors.grey[600], fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    if (_hasBooked) {
      return _buildCancellationButton(context, classData!);
    }

    if (_isOnWaitingList && isFull) {
      return _buildCancelWaitingButton(context, classData!);
    }

    return _buildBookButton(context, isFull, type, price, credit, classData!, classType);
  }

  Widget _buildCancellationButton(BuildContext context, Map<String, dynamic> classData) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Container(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFBDA25B),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
          ),
          onPressed: () async {
            if (!_isMounted) return;
            final userId = _auth.currentUser?.uid;
            if (userId == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('User not logged in')),
              );
              return;
            }
            try {
              final bookingQuery = await _firestore
                  .collection('users')
                  .doc(userId)
                  .collection('bookings')
                  .where('classid', isEqualTo: classData['id'])
                  .where('Status', whereIn: ['Booked', 'Pending'])
                  .limit(1)
                  .get();
              if (bookingQuery.docs.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No active booking found for this class.')),
                );
                return;
              }
              final bookingDoc = bookingQuery.docs.first;
              final bookingData = bookingDoc.data();
              final bookingId = bookingDoc.id;
              print('CourseDetailsScreen _buildCancellationButton: Opening CancellationPromptBottomSheet with bookingId=$bookingId, bookingData=$bookingData');
              await showModalBottomSheet<bool>(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (context) => CancellationPromptBottomSheet(
                  data: {
                    'bookingId': bookingId,
                    'classid': classData['id'],
                    'title': classData['title'],
                    'date': bookingData['date'] ?? DateFormat('yyyy-MM-dd').format(classData['start_date_time'].toUtc().add(const Duration(hours: 8))),
                    'time': bookingData['time'] ?? DateFormat('h:mm a').format(classData['start_date_time'].toUtc().add(const Duration(hours: 8))),
                    'credit_deducted_from': bookingData['credit_deducted_from'],
                    'credit_used': bookingData['credit_used'],
                    'type': bookingData['type'] ?? classData['type'],
                    'price': bookingData['price'] ?? classData['price'],
                    'start_date_time': classData['start_date_time'],
                  },
                  onCancel: widget.onCancel,
                ),
              );
              if (_isMounted) {
                await _checkBookingStatus();
                await _checkWaitingListStatus();
              }
            } catch (e) {
              print('CourseDetailsScreen _buildCancellationButton: Error: $e');
              if (_isMounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error fetching booking: $e')),
                );
              }
            }
          },
          child: const Text('Cancel Booking',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildCancelWaitingButton(BuildContext context, Map<String, dynamic> classData) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Container(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red[600],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
          ),
          onPressed: () async {
            if (!_isMounted) return;
            final userId = _auth.currentUser?.uid;
            if (userId == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('User not logged in')),
              );
              return;
            }
            try {
              final waitingListQuery = await _firestore
                  .collection('class')
                  .doc(classData['id'])
                  .collection('Waiting_lists')
                  .where('userid', isEqualTo: userId)
                  .limit(1)
                  .get();
              if (waitingListQuery.docs.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No waiting list entry found for this class.')),
                );
                return;
              }
              final waitingListDoc = waitingListQuery.docs.first;
              final waitingListId = waitingListDoc.id;
              print('CourseDetailsScreen _buildCancelWaitingButton: Opening CancelWaitingPromptBottomSheet with waitingListId=$waitingListId');
              final result = await showModalBottomSheet<bool>(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (context) => CancelWaitingPromptBottomSheet(
                  data: {
                    'classid': classData['id'],
                    'title': classData['title'],
                    'waitingListId': waitingListId,
                  },
                ),
              );
              if (result == true && _isMounted) {
                setState(() => _isOnWaitingList = false);
                await _checkBookingStatus();
                await _checkWaitingListStatus();
              }
            } catch (e) {
              print('CourseDetailsScreen _buildCancelWaitingButton: Error: $e');
              if (_isMounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error fetching waiting list entry: $e')),
                );
              }
            }
          },
          child: const Text('Cancel Waiting',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildBookButton(
      BuildContext context, bool isFull, String type, double price, int credit, Map<String, dynamic> data, String? classType) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFBDA25B),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        onPressed: _hasBooked
            ? null
            : () {
          print('CourseDetailsScreen _buildBookButton: Button pressed, isFull=$isFull, type=$type, classType=$classType, credit=$credit, price=$price');
          if (!_isMounted) return;
          if (isFull) {
            print('CourseDetailsScreen _buildBookButton: Showing WaitingListPromptBottomSheet for classId=${data['id']}');
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (context) => WaitingListPromptBottomSheet(data: data),
            ).then((_) {
              if (_isMounted) {
                _checkWaitingListStatus();
              }
            });
          } else {
            if (type == 'group' && !canBookClass(classType, credit, data['type'])) {
              print('CourseDetailsScreen _buildBookButton: No eligible package for group class, classType=$classType');
              showErrorDialog(
                'You do not have an active $classType package with enough credits of type ${data['type']}. Please purchase a suitable package.',
              );
            } else {
              print('CourseDetailsScreen _buildBookButton: Showing CancellationPolicyBottomSheet for classId=${data['id']}, type=$type');
              showModalBottomSheet<bool>(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (context) => CancellationPolicyBottomSheet(data: data),
              ).then((value) {
                if (value == true && _isMounted) {
                  if (type == 'group') {
                    print('CourseDetailsScreen _buildBookButton: Booking group classId=${data['id']}');
                    _bookClass(data['id'], credit);
                  } else if (type == 'event') {
                    print('CourseDetailsScreen _buildBookButton: Event booking confirmed, navigating to payment for classId=${data['id']}');
                  }
                }
              });
            }
          }
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isFull
                  ? 'CLASS FULL - JOIN WAITING LIST'
                  : type == 'event'
                  ? 'BOOK NOW - RM${price.toStringAsFixed(2)}'
                  : 'BOOK NOW | $credit CREDITS',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (!isFull) ...[
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward, size: 20, color: Colors.white),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('CourseDetailsScreen build: classData=$classData, instructorData=$instructorData');
    if (classData == null && instructorData == null) {
      return Scaffold(
        body: Center(
          child: _isLoading
              ? const CircularProgressIndicator(color: Color(0xFFBDA25B))
              : const Text('Failed to load class details. Check your connection or data.'),
        ),
      );
    }

    final title = classData!['title'] ?? 'Unknown Title';
    final startDateTime = classData!['start_date_time'] as DateTime;
    final date = _formatDate(startDateTime);
    final timeRange = _calculateTimeRange(startDateTime, classData!['duration']);
    final duration = classData!['duration'] ?? '';
    final instructor = instructorData?['full_name'] ?? 'Unknown Instructor';
    final instructorImage = instructorData?['photo_url'];
    final imagePath = classData!['placeholder_image'] ?? 'assets/default.jpg';
    final description = classData!['description'] ?? 'No description available';
    final type = classData!['type'] ?? 'unknown';
    final credit = (classData!['credit'] as num?)?.toInt() ?? 0;
    final price = (classData!['price'] as num?)?.toDouble() ?? 0.0;
    final bookedNum = (classData!['booked'] as num?)?.toDouble();
    final slotsNum = (classData!['slots'] as num?)?.toDouble();
    final booked = bookedNum ?? 0.0;
    final slots = slotsNum ?? 0.0;

    final appBarTitle = type == 'event' ? 'Event Details' : 'Class Details';
    final costText = type == 'event' ? 'RM ${price.toStringAsFixed(2)}' : '$credit Credit(s)';
    print('CourseDetailsScreen build: Using imagePath=$imagePath, title=$title, type=$type');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFBDA25B), // Theme color
        foregroundColor: Colors.white,            // White text/icons
        centerTitle: false,                       // Align left
        title: Text(
          appBarTitle,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: const Color(0xFFBDA25B),
          statusBarBrightness: Brightness.dark,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderImage(context, imagePath, title),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(context, 'Time', Icons.access_time),
                  const SizedBox(height: 8),
                  _buildTimeRow(context, date, timeRange, booked, slots),
                  const Divider(color: Colors.grey, thickness: 0.5),
                  const SizedBox(height: 16),
                  _buildSectionHeader(context, 'Duration', Icons.hourglass_empty),
                  const SizedBox(height: 8),
                  _buildDetailText(context, duration),
                  const Divider(color: Colors.grey, thickness: 0.5),
                  const SizedBox(height: 16),
                  _buildSectionHeader(context, 'Instructor', Icons.person),
                  const SizedBox(height: 8),
                  _buildInstructorRow(context, instructor, instructorImage),
                  const Divider(color: Colors.grey, thickness: 0.5),
                  const SizedBox(height: 16),
                  _buildSectionHeader(context, 'Cost', Icons.payment),
                  const SizedBox(height: 8),
                  _buildDetailText(context, costText),
                  const Divider(color: Colors.grey, thickness: 0.5),
                  const SizedBox(height: 16),
                  _buildSectionHeader(context, 'Description', Icons.description),
                  const SizedBox(height: 8),
                  _buildDescriptionText(context, description),
                  const SizedBox(height: 24),
                  _buildActionSection(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
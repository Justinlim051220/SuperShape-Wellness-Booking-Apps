import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

class InstructorCourseDetailsScreen extends StatefulWidget {
  final String classId;

  const InstructorCourseDetailsScreen({super.key, required this.classId});

  @override
  _InstructorCourseDetailsScreenState createState() => _InstructorCourseDetailsScreenState();
}

class _InstructorCourseDetailsScreenState extends State<InstructorCourseDetailsScreen> {
  late Future<DocumentSnapshot> _classFuture;
  late Future<List<Map<String, dynamic>>> _studentsFuture;
  final TextEditingController _remarksController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _classFuture = FirebaseFirestore.instance.collection('class').doc(widget.classId).get();
    _studentsFuture = _classFuture.then((classDoc) {
      if (classDoc.exists) {
        return _fetchBookedStudents(widget.classId);
      } else {
        return Future.value([]);
      }
    });
  }

  Future<List<Map<String, dynamic>>> _fetchBookedStudents(String classId) async {
    try {
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .get();

      final List<Map<String, dynamic>> bookedStudents = [];

      for (final userDoc in usersSnapshot.docs) {
        final bookingsSnapshot = await userDoc.reference
            .collection('bookings')
            .where('classid', isEqualTo: classId)
            .where('Status', whereIn: ['Booked', 'Completed'])
            .get();

        if (bookingsSnapshot.docs.isNotEmpty) {
          bookedStudents.add({
            'name': userDoc['full_name'] ?? 'Unknown Student',
          });
        }
      }

      return bookedStudents;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching students: $e')),
      );
      return [];
    }
  }

  String _formatDate(Timestamp timestamp) {
    try {
      final date = timestamp.toDate();
      return DateFormat('EEEE, MMMM d, yyyy').format(date);
    } catch (e) {
      return 'Unknown Date';
    }
  }

  String _calculateTimeRange(Timestamp startTimestamp, String duration) {
    try {
      final startDateTime = startTimestamp.toDate();
      int minutes = 0;
      final parts = duration.trim().split(' ');
      if (parts.contains('hour') || parts.contains('hours')) {
        final hoursIndex = parts.indexWhere((part) => part == 'hour' || part == 'hours');
        final hours = int.tryParse(parts[hoursIndex - 1]) ?? 0;
        minutes += hours * 60;
        if (parts.contains('minute') || parts.contains('minutes')) {
          final minutesIndex = parts.indexWhere((part) => part == 'minute' || part == 'minutes');
          final mins = int.tryParse(parts[minutesIndex - 1]) ?? 0;
          minutes += mins;
        }
      } else if (parts.contains('minute') || parts.contains('minutes')) {
        final minutesIndex = parts.indexWhere((part) => part == 'minute' || part == 'minutes');
        final mins = int.tryParse(parts[minutesIndex - 1]) ?? 0;
        minutes += mins;
      }
      final endDateTime = startDateTime.add(Duration(minutes: minutes));
      final startFormatted = DateFormat('ha').format(startDateTime).toLowerCase();
      final endFormatted = DateFormat('ha').format(endDateTime).toLowerCase();
      return '$startFormatted - $endFormatted';
    } catch (e) {
      return '--:-- - --:--';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: _classFuture,
      builder: (context, classSnapshot) {
        if (classSnapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFBDA25B)),
              ),
            ),
          );
        }
        if (classSnapshot.hasError) {
          return Center(child: Text('Error: ${classSnapshot.error}'));
        }
        if (!classSnapshot.hasData || !classSnapshot.data!.exists) {
          return const Center(child: Text('Class not found'));
        }

        final classData = classSnapshot.data!.data() as Map<String, dynamic>;
        final String title = classData['title'] ?? 'Untitled';
        final String placeholderImage = classData['placeholder_image'] ?? '';
        final Timestamp startDateTime = classData['start_date_time'] ?? Timestamp.now();
        final String duration = classData['duration'] ?? 'Unknown';
        final String instructor = classData['instructor'] ?? 'Unknown';
        final String instructorImage = classData['instructor_image'] ?? '';
        final String description = classData['description'] ?? 'No description';
        final int booked = classData['booked'] ?? 0;
        final int slots = classData['slot'] ?? 0;
        final String? remarks = classData['remarks'];

        _remarksController.text = remarks ?? '';

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _studentsFuture,
          builder: (context, studentsSnapshot) {
            if (studentsSnapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(
                backgroundColor: Colors.white,
                body: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFBDA25B)),
                  ),
                ),
              );
            }
            if (studentsSnapshot.hasError) {
              return Center(child: Text('Error fetching students: ${studentsSnapshot.error}'));
            }

            final students = studentsSnapshot.data ?? [];

            final appBarTitle = classData['type'] == 'event' ? 'Event Details' : 'Class Details';

            return Scaffold(
              appBar: AppBar(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                title: Text(
                  appBarTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                elevation: 0,
                systemOverlayStyle: const SystemUiOverlayStyle(
                  statusBarBrightness: Brightness.dark,
                  statusBarIconBrightness: Brightness.light,
                ),
              ),
              body: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderImage(context, placeholderImage, title),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader(context, 'Time', Icons.access_time),
                          const SizedBox(height: 8),
                          _buildTimeRow(context, _formatDate(startDateTime), _calculateTimeRange(startDateTime, duration), booked, slots),
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
                          _buildSectionHeader(context, 'Description', Icons.description),
                          const SizedBox(height: 8),
                          _buildDescriptionText(context, description),
                          const Divider(color: Colors.grey, thickness: 0.5),
                          const SizedBox(height: 16),
                          _buildSectionHeader(context, 'Students', Icons.group),
                          const SizedBox(height: 8),
                          _buildStudentsSection(context, students.map((s) => s['name'] as String).toList()),
                          const Divider(color: Colors.grey, thickness: 0.5),
                          const SizedBox(height: 16),
                          _buildSectionHeader(context, 'Remarks', Icons.note),
                          const SizedBox(height: 8),
                          _buildRemarksSection(context, remarks),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeaderImage(BuildContext context, String imageUrl, String title) {
    return Stack(
      children: [
        Image.network(
          imageUrl,
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
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(0.6),
              ],
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
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.5),
                  offset: const Offset(1, 1),
                  blurRadius: 3,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).primaryColor),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).primaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeRow(BuildContext context, String formattedDate, String timeRange, int booked, int slots) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formattedDate,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              timeRange,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        if (slots > 0 && booked >= 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${booked.toInt()}/${slots.toInt()}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDetailText(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
        color: Colors.black87,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildInstructorRow(BuildContext context, String instructor, String? instructorImage) {
    return Row(
      children: [
        if (instructorImage != null && instructorImage.isNotEmpty)
          CircleAvatar(
            radius: 20,
            backgroundImage: NetworkImage(instructorImage),
            backgroundColor: Colors.grey[200],
            onBackgroundImageError: (_, __) => Icon(Icons.person, color: Colors.grey[600]),
          )
        else
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey[200],
            child: Icon(Icons.person, color: Colors.grey[600]),
          ),
        const SizedBox(width: 12),
        Text(
          instructor,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionText(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Colors.grey[600],
        height: 1.5,
      ),
    );
  }

  Widget _buildStudentsSection(BuildContext context, List<String> studentNames) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${studentNames.length} Student${studentNames.length == 1 ? '' : 's'} Attending',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        ...studentNames.map((name) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Text(
            name,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        )),
      ],
    );
  }

  Widget _buildRemarksSection(BuildContext context, String? initialRemarks) {
    return Stack(
      children: [
        TextField(
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Add remarks for this class...',
          ),
          controller: _remarksController,
        ),
        Positioned(
          bottom: 8,
          right: 8,
          child: GestureDetector(
            onTap: () async {
              final newRemarks = _remarksController.text;
              try {
                await FirebaseFirestore.instance.collection('class').doc(widget.classId).set(
                  {'remarks': newRemarks},
                  SetOptions(merge: true),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Remarks saved')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error saving remarks: $e')),
                );
              }
            },
            child: Text(
              'OK',
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
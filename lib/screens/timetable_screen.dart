import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/bottom_nav_bar.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  DateTime selectedDate = DateTime.now();
  List<Map<String, dynamic>> allClasses = [];
  List<Map<String, dynamic>> allEvents = [];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    try {
      final snapshot = await _firestore
          .collection('class')
          .where('type', whereIn: ['group', 'event'])
          .get();
      final List<Map<String, dynamic>> classes = [];
      final List<Map<String, dynamic>> events = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final instructorId = data['instructor_id'] as String?;
        String instructorName;
        if (instructorId != null && instructorId.isNotEmpty) {
          final instructorDoc = await _firestore.collection('users').doc(instructorId).get();
          instructorName = instructorDoc.data()?['full_name'] ?? 'Unknown Instructor';
        } else {
          instructorName = 'Unknown Instructor';
        }
        final classData = {
          'id': doc.id,
          'title': data['title'] ?? 'Unknown Title',
          'start_date_time': (data['start_date_time'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'duration': data['duration'] ?? '',
          'booked': data['booked'] ?? 0,
          'slots': data['slot'] ?? 0,
          'instructor_id': instructorId,
          'instructor_name': instructorName,
          'type': data['type'] ?? 'unknown',
          'price': data['price'] ?? 0,
        };
        if (data['type'] == 'group') {
          classes.add(classData);
        } else if (data['type'] == 'event') {
          events.add(classData);
        }
      }

      setState(() {
        allClasses = classes;
        allEvents = events;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
      setState(() {
        allClasses = [];
        allEvents = [];
      });
    }
  }

  List<Map<String, dynamic>> get filteredClasses => allClasses.where((cls) {
    final classDate = DateTime(cls['start_date_time'].year, cls['start_date_time'].month, cls['start_date_time'].day);
    return isSameDay(classDate, selectedDate);
  }).toList();

  List<Map<String, dynamic>> get filteredEvents => allEvents.where((event) {
    final eventDate = DateTime(event['start_date_time'].year, event['start_date_time'].month, event['start_date_time'].day);
    return isSameDay(eventDate, selectedDate);
  }).toList();

  bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFFBDA25B),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  List<DateTime> getWeekDates(DateTime date) {
    final int currentWeekday = date.weekday;
    final DateTime firstDay = date.subtract(Duration(days: currentWeekday - 1));
    return List.generate(7, (index) => firstDay.add(Duration(days: index)));
  }

  String _formatTime(DateTime dateTime) {
    return DateFormat('h:mm a').format(dateTime).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final weekDates = getWeekDates(selectedDate);
    final formattedDate = DateFormat('EEEE, MMM d, yyyy').format(selectedDate);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFFBDA25B),
        centerTitle: true,
        title: const Text(
          'Timetable',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        automaticallyImplyLeading: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16.0),
            child: IconButton(
              icon: const Icon(
                Icons.calendar_today,
                color: Colors.white,
              ),
              onPressed: () => _selectDate(context),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDateSelector(weekDates),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              formattedDate,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                if (filteredClasses.isNotEmpty) ...[
                  _buildSectionTitle('Classes'),
                  ...filteredClasses.map(_buildClassCard).toList(),
                ],
                if (filteredEvents.isNotEmpty) ...[
                  _buildSectionTitle('Events'),
                  ...filteredEvents.map(_buildEventCard).toList(),
                ],
                if (filteredClasses.isEmpty && filteredEvents.isEmpty) const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No classes or events scheduled for this day.'),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavBar(currentIndex: 0),
    );
  }

  Widget _buildDateSelector(List<DateTime> weekDates) {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: weekDates.length,
        itemBuilder: (context, index) {
          final date = weekDates[index];
          final isSelected = isSameDay(date, selectedDate);

          return GestureDetector(
            onTap: () {
              setState(() {
                selectedDate = date;
              });
            },
            child: Container(
              width: 64,
              margin: const EdgeInsets.symmetric(horizontal: 8.0),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFBDA25B) : Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('E').format(date),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date.day.toString(),
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFFBDA25B),
        ),
      ),
    );
  }

  Widget _buildClassCard(Map<String, dynamic> cls) {
    final time = _formatTime(cls['start_date_time']);
    final classId = cls['id'] as String?;
    print('Navigating with arguments: ${{'id': classId}}');
    if (classId == null || classId.isEmpty) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text('Invalid class data', style: TextStyle(color: Colors.red)),
        ),
      );
    }
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      color: const Color(0xFFF5F5F5),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.pushNamed(
            context,
            '/course_details',
            arguments: {'id': classId},
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Image.asset('assets/s.png', height: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cls['title'] ?? 'Unknown Class',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$time • ${cls['duration'] ?? 'Unknown Duration'} • Instructor: ${cls['instructor_name'] ?? 'Unknown'}',
                      style: const TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.people, size: 28, color: Color(0xFFBDA25B)),
                  const SizedBox(width: 10),
                  Text(
                    '${cls['booked']?.toInt() ?? 0}/${cls['slots']?.toInt() ?? 0}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    final time = _formatTime(event['start_date_time']);
    final eventId = event['id'] as String?;
    print('Navigating with arguments: ${{'id': eventId}}');
    if (eventId == null || eventId.isEmpty) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text('Invalid event data', style: TextStyle(color: Colors.red)),
        ),
      );
    }
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      color: const Color(0xFFF5F5F5),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.pushNamed(
            context,
            '/course_details',
            arguments: {'id': eventId},
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Image.asset('assets/s.png', height: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event['title'] ?? 'Unknown Event',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$time • ${event['duration'] ?? 'Unknown Duration'} • Instructor: ${event['instructor_name'] ?? 'Unknown'}',
                      style: const TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.people, size: 28, color: Color(0xFFBDA25B)),
                  const SizedBox(width: 10),
                  Text(
                    '${event['booked']?.toInt() ?? 0}/${event['slots']?.toInt() ?? 0}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
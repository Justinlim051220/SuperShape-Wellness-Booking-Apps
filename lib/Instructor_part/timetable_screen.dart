import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import './Instructor_widgets/bottom_nav_bar.dart';
import 'Instuctor_model/class_model.dart';

class InstructorTimetableScreen extends StatefulWidget {
  final bool isInstructor;
  final InstructorBottomNavBar insbottomNavBar;

  const InstructorTimetableScreen({
    super.key,
    this.isInstructor = true,
    required this.insbottomNavBar,
  });

  @override
  State<InstructorTimetableScreen> createState() => _InstructorTimetableScreenState();
}

class _InstructorTimetableScreenState extends State<InstructorTimetableScreen> {
  DateTime selectedDate = DateTime.now();
  List<ClassModel> allClasses = [];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not logged in')),
        );
        setState(() {
          allClasses = [];
        });
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('class')
          .where('instructor_id', isEqualTo: userId)
          .get();

      setState(() {
        allClasses = snapshot.docs.map((doc) {
          final data = doc.data();
          debugPrint('Firestore doc ${doc.id}: $data');

          DateTime? startDateTime;
          try {
            startDateTime = (data['start_date_time'] as Timestamp?)?.toDate();
          } catch (e) {
            debugPrint('Timestamp parsing error for doc ${doc.id}: $e');
          }

          return ClassModel(
            id: doc.id,
            title: data['title'] as String? ?? 'Untitled',
            date: startDateTime?.toIso8601String() ?? '',
            time: startDateTime != null
                ? DateFormat('h:mm a').format(startDateTime)
                : 'Unknown',
            duration: data['duration'] as String? ?? 'Unknown',
            instructor: data['instructor'] as String? ?? 'Unknown',
            instructorImage: data['instructor_image'] as String?,
            status: data['status'] as String? ?? '',
            image: data['placeholder_image'] as String? ?? '',
            description: data['description'] as String? ?? '',
            type: data['type'] as String? ?? '',
            credit: (data['credit'] as num?)?.toInt() ?? 0,
            price: (data['price'] as num?)?.toDouble() ?? 0.0,
            booked: (data['booked'] as num?)?.toDouble() ?? 0.0,
            slots: (data['slot'] as num?)?.toDouble() ?? 0.0,
          );
        }).toList();
      });
    } catch (e, stackTrace) {
      debugPrint('Error loading classes: $e\n$stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading classes: $e')),
      );
      setState(() {
        allClasses = [];
      });
    }
  }

  List<ClassModel> get filteredClasses => allClasses.where((cls) {
    if (cls.date.isEmpty) return false;
    try {
      final classDate = DateTime.parse(cls.date);
      return isSameDay(classDate, selectedDate);
    } catch (e) {
      debugPrint('Date parsing error for class ${cls.id}: $e');
      return false;
    }
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
            colorScheme: const ColorScheme.light(
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

  @override
  Widget build(BuildContext context) {
    final weekDates = getWeekDates(selectedDate);
    final formattedDate = DateFormat('EEEE, MMM d, yyyy').format(selectedDate);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFBDA25B),
        centerTitle: true,
        title: const Text(
          'Timetable',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            onPressed: () => _selectDate(context),
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
                ] else
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No classes scheduled for this day.'),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: widget.insbottomNavBar,
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

  Widget _buildClassCard(ClassModel cls) {
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
            '/instructor_course_details',
            arguments: cls,
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
                      cls.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${cls.time} • ${cls.duration} • Instructor: ${cls.instructor}',
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
                    '${cls.booked.toInt()}/${cls.slots.toInt()}',
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
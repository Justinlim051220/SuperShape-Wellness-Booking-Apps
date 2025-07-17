import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/instructor_model.dart' show Instructor;
import '../../widgets/bottom_nav_bar.dart';
import 'instructor_detail_screen.dart';

class InstructorPage extends StatelessWidget {
  const InstructorPage({super.key});

  Stream<List<Instructor>> fetchInstructors() {
    return FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'instructor')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
      final data = doc.data();
      return Instructor.fromJson(data, userId: doc.id);
    }).toList());
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double baseFontSize = screenWidth * 0.04;
    final Color themeColor = const Color(0xFFBDA25B);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: Text(
          'OUR INSTRUCTORS',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: baseFontSize * 1.2,
          ),
        ),
      ),
      body: StreamBuilder<List<Instructor>>(
        stream: fetchInstructors(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error loading data: ${snapshot.error}', style: Theme.of(context).textTheme.bodyLarge));
          }

          final instructors = snapshot.data ?? [];
          if (instructors.isEmpty) {
            return Center(child: Text('No instructors available.', style: Theme.of(context).textTheme.bodyLarge));
          }

          return ListView.builder(
            itemCount: instructors.length,
            itemBuilder: (context, index) {
              final instructor = instructors[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InstructorDetailPage(userId: instructor.userId!),
                    ),
                  );
                },
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                  color: const Color(0xFFF5F5F5),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 45,
                          backgroundColor: Colors.grey[200],
                          child: ClipOval(
                            child: instructor.photo != null && instructor.photo!.isNotEmpty
                                ? Image.network(
                              instructor.photo!,
                              width: 90,
                              height: 90,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, size: 45, color: Colors.grey),
                            )
                                : Image.asset(
                              'assets/yushiko.png',
                              width: 90,
                              height: 90,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                instructor.name ?? 'Unknown Instructor',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: themeColor,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                (instructor.specializations?.isNotEmpty ?? false)
                                    ? instructor.specializations!.join(', ')
                                    : 'No Specialization',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                instructor.bio ?? 'No bio available.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.black54,
                                  fontSize: 12,
                                ),
                                maxLines: 2, // Limits the bio to 2 lines
                                overflow: TextOverflow.ellipsis, // Adds "..." if the text overflows
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 1),
    );
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/instructor_model.dart';

class InstructorDetailPage extends StatelessWidget {
  final String userId;

  const InstructorDetailPage({super.key, required this.userId});

  Stream<Instructor> fetchInstructor() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) => Instructor.fromJson(doc.data() ?? {}, userId: doc.id));
  }

  Stream<List<UpcomingClass>> fetchUpcomingClasses() {
    final now = DateTime.now();
    return FirebaseFirestore.instance
        .collection('class')
        .where('instructor_id', isEqualTo: userId)
        .where('start_date_time', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
      return UpcomingClass.fromJson(doc.data());
    }).toList());
  }

  @override
  Widget build(BuildContext context) {
    final Color themeColor = const Color(0xFFBDA25B);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        title: Text(
          'Instructor Profile',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: StreamBuilder<Instructor>(
        stream: fetchInstructor(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: Theme.of(context).textTheme.bodyLarge));
          } else if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('Instructor not found.', style: TextStyle(fontSize: 16)));
          }

          final instructor = snapshot.data!;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cover Photo and Avatar
                Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[300], // Fallback if no image
                        image: instructor.coverPhoto != null && instructor.coverPhoto!.isNotEmpty
                            ? DecorationImage(
                          image: NetworkImage(instructor.coverPhoto!),
                          fit: BoxFit.cover,
                          colorFilter: ColorFilter.mode(
                            Colors.black.withOpacity(0.3),
                            BlendMode.darken,
                          ),
                          onError: (exception, stackTrace) => const AssetImage('assets/pilates_cover.jpg'),
                        )
                            :  DecorationImage(
                          image: AssetImage('assets/pilates_cover.jpg'),
                          fit: BoxFit.cover,
                          colorFilter: ColorFilter.mode(
                            Colors.black.withOpacity(0.3),
                            BlendMode.darken,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 120),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                        child: CircleAvatar(
                          radius: 46,
                          backgroundImage: instructor.photo != null && instructor.photo!.isNotEmpty
                              ? NetworkImage(instructor.photo!)
                              : const AssetImage('assets/yushiko.png'),
                          onBackgroundImageError: (exception, stackTrace) => const AssetImage('assets/yushiko.png'),
                        ),
                      ),
                    ),
                  ],
                ),
                // Name and Email (Centered)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        instructor.name ?? '',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        instructor.email ?? '',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                // Main Content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Bio Section
                      Text(
                        'Bio',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: themeColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        instructor.bio ?? '',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.black87,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Divider(color: Colors.grey.shade300, thickness: 1),
                      const SizedBox(height: 16),
                      // Years of Experience
                      Text(
                        'Years of Experience',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: themeColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${instructor.experienceYears ?? 0} Years',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Divider(color: Colors.grey.shade300, thickness: 1),
                      const SizedBox(height: 16),
                      // Certifications
                      Text(
                        'Certifications & Qualifications',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: themeColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Column(
                        children: (instructor.certifications ?? []).map((cert) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.verified, size: 18, color: Colors.green),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    cert,
                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      Divider(color: Colors.grey.shade300, thickness: 1),
                      const SizedBox(height: 16),
                      // Specializations
                      Text(
                        'Specializations & Focus Areas',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: themeColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Column(
                        children: (instructor.specializations ?? []).map((spec) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.star_border,
                                  size: 10,
                                  color: Color(0xFFBDA25B),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    spec,
                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      Divider(color: Colors.grey.shade300, thickness: 1),
                      const SizedBox(height: 16),
                      // Phone Number
                      Text(
                        'Phone Number',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: themeColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.phone,
                              size: 18,
                              color: Color(0xFFBDA25B),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                instructor.phoneNumber ?? 'Not available',
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Divider(color: Colors.grey.shade300, thickness: 1),
                      const SizedBox(height: 16),
                      // Upcoming Classes
                      Text(
                        'Upcoming Classes',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: themeColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      StreamBuilder<List<UpcomingClass>>(
                        stream: fetchUpcomingClasses(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          } else if (snapshot.hasError) {
                            return Text(
                              'Error loading classes: ${snapshot.error}',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Colors.black54,
                                fontStyle: FontStyle.italic,
                              ),
                            );
                          }
                          final classes = snapshot.data ?? [];
                          if (classes.isEmpty) {
                            return Text(
                              'No upcoming classes scheduled.',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Colors.black54,
                                fontStyle: FontStyle.italic,
                              ),
                            );
                          }
                          return Column(
                            children: classes.map((classInfo) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 6.0,
                                      spreadRadius: 0,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.event, size: 24, color: themeColor),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            classInfo.title,
                                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${classInfo.date} at ${classInfo.time}',
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
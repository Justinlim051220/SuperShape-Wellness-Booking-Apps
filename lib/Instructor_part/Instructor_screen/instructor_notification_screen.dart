import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../services/notification_state.dart';

class InstructorNotificationsScreen extends StatefulWidget {
  const InstructorNotificationsScreen({super.key});

  @override
  State<InstructorNotificationsScreen> createState() => _InstructorNotificationsScreenState();
}

class _InstructorNotificationsScreenState extends State<InstructorNotificationsScreen> {
  bool _showAll = false;

  Future<String?> _getUserFullName() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return null;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      return doc.data()?['full_name'] as String?;
    } catch (e) {
      debugPrint('Error fetching user full name: $e');
      return null;
    }
  }

  Stream<List<Map<String, dynamic>>> _fetchAnnouncements() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    return FirebaseFirestore.instance
        .collection('Notification')
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .where((data) {
      final type = data['type'] as String?;
      final to = (data['to'] as List<dynamic>?)?.cast<String>() ?? [];
      return type == 'ALL' || (userId != null && to.contains(userId));
    })
        .toList());
  }

  Future<void> _refreshNotifications() async {
    try {
      await FirebaseFirestore.instance.collection('Notification').get();
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        final notifications = await FirebaseFirestore.instance
            .collection('Notification')
            .where('to', arrayContains: userId)
            .where('read', isEqualTo: false)
            .get();
        unreadNotificationCountNotifier.value = notifications.docs.length;
      }
      setState(() {});
      await Future.delayed(const Duration(seconds: 1));
    } catch (e) {
      debugPrint('Error refreshing notifications: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Instructor Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFBDA25B),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarBrightness: Brightness.light,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshNotifications,
        color: const Color(0xFFBDA25B),
        backgroundColor: Colors.white,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: _fetchAnnouncements(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(color: Color(0xFFBDA25B)),
                      ),
                    );
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading announcements: ${snapshot.error}',
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  final announcements = snapshot.data ?? [];
                  if (announcements.isEmpty) {
                    return const Column(
                      children: [
                        SizedBox(height: 100),
                        Icon(
                          Icons.notifications_none,
                          size: 60,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 20),
                        Text(
                          'NOTHING HERE',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    );
                  }

                  announcements.sort((a, b) {
                    final timestampA = (a['timestamp'] as Timestamp?)?.toDate() ?? DateTime(0);
                    final timestampB = (b['timestamp'] as Timestamp?)?.toDate() ?? DateTime(0);
                    return timestampB.compareTo(timestampA);
                  });

                  final displayedAnnouncements = _showAll ? announcements : announcements.take(3).toList();

                  return FutureBuilder<String?>(
                    future: _getUserFullName(),
                    builder: (context, nameSnapshot) {
                      final userName = nameSnapshot.data ?? 'User';
                      return Column(
                        children: [
                          ...displayedAnnouncements.map((data) {
                            final announcement = data['announcement'] as String? ?? '';
                            final isLong = announcement.length > 100;
                            final truncatedText = isLong
                                ? '${announcement.substring(0, 100)}People... '
                                : announcement;
                            final isRead = data['read'] as bool? ?? false;
                            return Stack(
                              children: [
                                InkWell(
                                  onTap: () {
                                    FirebaseFirestore.instance
                                        .collection('Notification')
                                        .doc(data['id'])
                                        .update({'read': true}).then((_) {
                                      FirebaseFirestore.instance
                                          .collection('Notification')
                                          .where('to', arrayContains: FirebaseAuth.instance.currentUser?.uid)
                                          .where('read', isEqualTo: false)
                                          .get()
                                          .then((snapshot) {
                                        unreadNotificationCountNotifier.value = snapshot.docs.length;
                                      });
                                    }).catchError((e) {
                                      debugPrint('Error marking notification as read: $e');
                                    });
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => InstructorNotificationDetailScreen(
                                          subject: data['subject'] as String? ?? 'No Subject',
                                          announcement: announcement,
                                          by: data['by'] as String? ?? 'Unknown',
                                          timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
                                        ),
                                      ),
                                    );
                                  },
                                  child: _buildNotificationCard(
                                    userName: userName,
                                    subject: data['subject'] as String? ?? 'No Subject',
                                    announcement: truncatedText,
                                    by: data['by'] as String? ?? 'Unknown',
                                    timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
                                    isLong: isLong,
                                    id: data['id'] as String,
                                    isRead: isRead,
                                  ),
                                ),
                                if (!isRead)
                                  Positioned(
                                    right: 0,
                                    top: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 16,
                                        minHeight: 16,
                                      ),

                                    ),
                                  ),
                              ],
                            );
                          }).toList(),
                          if (!_showAll && announcements.length > 3)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Center(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFBDA25B),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    elevation: 3,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _showAll = true;
                                    });
                                  },
                                  child: const Text(
                                    'VIEW MORE',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard({
    required String userName,
    required String subject,
    required String announcement,
    required String by,
    required DateTime timestamp,
    required String id,
    required bool isRead,
    bool isLong = false,
  }) {
    return Card(
      color: const Color(0xFFFFFFFF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white,
                  backgroundImage: AssetImage('assets/logo.png'),
                ),
                const SizedBox(width: 12),
                Text(
                  by,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Subject: $subject',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                style: const TextStyle(height: 1.5, color: Colors.black),
                children: [
                  TextSpan(text: 'Hi $userName,\n\n'),
                  TextSpan(text: announcement),
                  if (isLong)
                    const TextSpan(
                      text: ' Read More',
                      style: TextStyle(
                        color: Color(0xFFBDA25B),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Super Shape Wellness Team\n$by',
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat('dd MMM yyyy, hh:mm a').format(timestamp.toUtc().add(const Duration(hours: 8))),
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InstructorNotificationDetailScreen extends StatelessWidget {
  final String subject;
  final String announcement;
  final String by;
  final DateTime timestamp;

  const InstructorNotificationDetailScreen({
    super.key,
    required this.subject,
    required this.announcement,
    required this.by,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double baseFontSize = screenWidth * 0.04;
    final double basePadding = screenWidth * 0.05;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Instructor Notification Details', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFBDA25B),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarBrightness: Brightness.light,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: basePadding,
            vertical: basePadding * 1.5,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: const BoxDecoration(
                      color: Color(0xFFBDA25B),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Instructor Notification Details',
                      style: TextStyle(
                        fontSize: baseFontSize * 1.1,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      softWrap: true,
                    ),
                  ),
                ],
              ),
              SizedBox(height: basePadding * 0.8),
              const Divider(color: Color(0xFFBDA25B), thickness: 1),
              SizedBox(height: basePadding * 0.6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Subject: ',
                    style: TextStyle(
                      fontSize: baseFontSize * 0.95,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      subject,
                      style: TextStyle(
                        fontSize: baseFontSize * 0.95,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                      softWrap: true,
                    ),
                  ),
                ],
              ),
              SizedBox(height: basePadding * 0.6),
              const Divider(color: Color(0xFFBDA25B), thickness: 1),
              SizedBox(height: basePadding * 0.6),
              Text(
                announcement,
                style: TextStyle(
                  fontSize: baseFontSize * 0.85,
                  height: 1.6,
                  color: Colors.black54,
                ),
                softWrap: true,
                textAlign: TextAlign.left,
              ),
              SizedBox(height: basePadding * 0.6),
              const Divider(color: Color(0xFFBDA25B), thickness: 1),
              SizedBox(height: basePadding * 0.6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sent by: ',
                    style: TextStyle(
                      fontSize: baseFontSize * 0.85,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      by,
                      style: TextStyle(
                        fontSize: baseFontSize * 0.85,
                        color: Colors.black54,
                      ),
                      softWrap: true,
                    ),
                  ),
                ],
              ),
              SizedBox(height: basePadding * 0.4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Date: ',
                    style: TextStyle(
                      fontSize: baseFontSize * 0.75,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      DateFormat('dd MMM yyyy, hh:mm a').format(timestamp.toUtc().add(const Duration(hours: 8))),
                      style: TextStyle(
                        fontSize: baseFontSize * 0.75,
                        color: Colors.grey,
                      ),
                      softWrap: true,
                    ),
                  ),
                ],
              ),
              SizedBox(height: basePadding * 1.2),
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFBDA25B),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: basePadding * 2,
                      vertical: basePadding * 0.8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 3,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'BACK',
                    style: TextStyle(
                      fontSize: baseFontSize * 0.9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NotificationService {
  static Stream<List<Map<String, dynamic>>> getAnnouncements(String userId) {
    return FirebaseFirestore.instance
        .collection('Notification')
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .where((data) {
      final type = data['type'] as String?;
      final to = (data['to'] as List<dynamic>?)?.cast<String>() ?? [];
      return type == 'ALL' || to.contains(userId);
    })
        .toList());
  }

  static Future<void> addAnnouncement({
    required String announcement,
    required String by,
    required String subject,
    required List<String> to,
    required String type,
  }) async {
    await FirebaseFirestore.instance.collection('Notification').add({
      'announcement': announcement,
      'by': by,
      'subject': subject,
      'timestamp': Timestamp.now(),
      'to': to,
      'type': type,
      'read': false,
    });
  }

  static Future<void> clearAnnouncements() async {
    final snapshot = await FirebaseFirestore.instance.collection('Notification').get();
    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }
}
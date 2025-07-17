import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
import '../../services/notification_state.dart';
import '../../widgets/bottom_nav_bar.dart';
import 'package_card.dart'; // Import the PackageCard widget

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  _MyProfileScreenState createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  bool _showActive = true;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late StreamSubscription<QuerySnapshot> _subscription;
  late StreamSubscription<QuerySnapshot> _notificationSubscription;
  final Set<String> _processedCreditIds = {}; // Track processed credit IDs
  int _unreadNotificationCount = 0; // Track unread notifications

  @override
  void initState() {
    super.initState();
    _subscribeToCreditRemains();
    _subscribeToNotifications();
    _loadLastViewedTimestamp();
  }

  @override
  void dispose() {
    _subscription.cancel();
    _notificationSubscription.cancel();
    super.dispose();
  }

  void _subscribeToCreditRemains() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    _subscription = _firestore
        .collection('users')
        .doc(userId)
        .collection('Credit_Remains')
        .snapshots()
        .listen((snapshot) {
      print('Snapshot received with ${snapshot.docChanges.length} changes at ${DateTime.now()}');
      if (mounted) {
        setState(() {});
        _checkAndUpdateInactiveCredits(snapshot);
      }
    }, onError: (error) {
      print('Error listening to Credit_Remains: $error at ${DateTime.now()}');
    });
  }

  void _subscribeToNotifications() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    _notificationSubscription = _firestore
        .collection('Notification')
        .where('to', arrayContains: userId)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        _updateUnreadNotificationCount(snapshot);
      }
    }, onError: (error) {
      print('Error listening to notifications: $error at ${DateTime.now()}');
    });
  }

  Future<void> _loadLastViewedTimestamp() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final doc = await _firestore.collection('users').doc(userId).get();
    final lastViewed = (doc.data()?['last_notification_viewed'] as Timestamp?)?.toDate() ?? DateTime(0);
    _updateUnreadNotificationCountBasedOnLastViewed(lastViewed);
  }

  void _updateUnreadNotificationCount(QuerySnapshot snapshot) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    _firestore.collection('users').doc(userId).get().then((doc) {
      final lastViewed = (doc.data()?['last_notification_viewed'] as Timestamp?)?.toDate() ?? DateTime(0);
      _updateUnreadNotificationCountBasedOnLastViewed(lastViewed);
    });
  }

  void _updateUnreadNotificationCountBasedOnLastViewed(DateTime lastViewed) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final snapshot = _firestore.collection('Notification').where('to', arrayContains: userId).get();
    snapshot.then((value) {
      _unreadNotificationCount = value.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime(0);
        return timestamp.isAfter(lastViewed);
      }).length;
      unreadNotificationCountNotifier.value = _unreadNotificationCount; // Update global notifier
      if (mounted) setState(() {});
    });
  }

  bool _isPackageActive(Map<String, dynamic> data) {
    final creditsRemaining = data['credits_remaining'] as num? ?? 0;
    final validUntil = (data['validUntil'] as Timestamp?)?.toDate() ?? DateTime(1970);
    final now = DateTime.now();
    final isActive = creditsRemaining > 0 && validUntil.isAfter(now);
    print('Checking isActive for credits_remaining: $creditsRemaining, validUntil: $validUntil, now: $now, result: $isActive');
    return isActive;
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMMM yyyy').format(date);
  }

  Future<void> _checkAndUpdateInactiveCredits(QuerySnapshot snapshot) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    for (var doc in snapshot.docChanges) {
      print('Processing change for doc ID: ${doc.doc.id}, type: ${doc.type} at ${DateTime.now()}');
      if (doc.type == DocumentChangeType.modified || doc.type == DocumentChangeType.added) {
        final data = doc.doc.data() as Map<String, dynamic>;
        final creditId = doc.doc.id;
        final creditsRemaining = data['credits_remaining'] as num? ?? 0;
        final validUntil = (data['validUntil'] as Timestamp?)?.toDate() ?? DateTime(1970);
        final now = DateTime.now();
        final shouldBeActive = creditsRemaining > 0 && validUntil.isAfter(now);
        final currentIsActive = data['is_active'] as bool? ?? true;

        print('Current state - creditId: $creditId, credits_remaining: $creditsRemaining, validUntil: $validUntil, currentIsActive: $currentIsActive, shouldBeActive: $shouldBeActive');

        if (currentIsActive != shouldBeActive) {
          print('Updating is_active to $shouldBeActive for creditId: $creditId');
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('Credit_Remains')
              .doc(creditId)
              .update({'is_active': shouldBeActive});
          print('Update completed for creditId: $creditId at ${DateTime.now()}');
        } else {
          print('No update needed for creditId: $creditId');
        }
        _processedCreditIds.add(creditId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double basePadding = screenWidth * 0.04;
    final double baseFontSize = screenWidth * 0.04;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFBDA25B),
        centerTitle: true,
        title: Text(
          'MY PROFILE',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: baseFontSize * 1.2,
          ),
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Color(0xFFF9F9F9)],
            ),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(basePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: basePadding),
                  _buildListTile(
                    context,
                    title: 'Account Settings',
                    route: '/account_settings',
                    baseFontSize: baseFontSize,
                  ),
                  _buildListTile(
                    context,
                    title: 'Change Password',
                    route: '/change_password',
                    baseFontSize: baseFontSize,
                  ),
                  _buildListTile(
                    context,
                    title: 'Term & Condition',
                    route: '/terms_conditions',
                    baseFontSize: baseFontSize,
                  ),
                  _buildListTile(
                    context,
                    title: 'Notification',
                    route: '/notifications',
                    baseFontSize: baseFontSize,
                    unreadCount: _unreadNotificationCount,
                  ),
                  ListTile(
                    title: Text(
                      'Log Out',
                      style: TextStyle(
                        fontSize: baseFontSize * 0.95,
                        color: const Color(0xFFBDA25B),
                      ),
                    ),
                    trailing: const Icon(
                      Icons.logout,
                      color: Color(0xFFBDA25B),
                    ),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return Dialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Container(
                              padding: EdgeInsets.all(basePadding * 1.5),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.logout,
                                    color: Color(0xFFBDA25B),
                                    size: 48,
                                  ),
                                  SizedBox(height: basePadding),
                                  Text(
                                    'Log Out?',
                                    style: TextStyle(
                                      fontSize: baseFontSize * 1.2,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: basePadding * 0.75),
                                  Text(
                                    'Are you sure you want to log out?',
                                    style: TextStyle(fontSize: baseFontSize * 0.9),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: basePadding * 1.5),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            padding: EdgeInsets.symmetric(
                                              vertical: basePadding * 0.8,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            side: const BorderSide(
                                              color: Color(0xFFBDA25B),
                                            ),
                                          ),
                                          onPressed: () => Navigator.of(context).pop(),
                                          child: Text(
                                            'CANCEL',
                                            style: TextStyle(
                                              color: const Color(0xFFBDA25B),
                                              fontWeight: FontWeight.bold,
                                              fontSize: baseFontSize * 0.85,
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: basePadding),
                                      Expanded(
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFBDA25B),
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            padding: EdgeInsets.symmetric(
                                              vertical: basePadding * 0.8,
                                            ),
                                          ),
                                          onPressed: () async {
                                            Navigator.of(context).pop();
                                            await FirebaseAuth.instance.signOut();
                                            Navigator.pushNamedAndRemoveUntil(
                                              context,
                                              '/login',
                                                  (Route<dynamic> route) => false,
                                            );
                                          },
                                          child: Text(
                                            'LOG OUT',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: baseFontSize * 0.85,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  SizedBox(height: basePadding * 1.5),
                  Text(
                    'My Packages',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: baseFontSize * 1.2,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: basePadding),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _showActive
                                ? const Color(0xFFBDA25B)
                                : Colors.transparent,
                            foregroundColor: _showActive
                                ? Colors.white
                                : const Color(0xFFBDA25B),
                            side: const BorderSide(
                              color: Color(0xFFBDA25B),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            padding: EdgeInsets.symmetric(
                              vertical: basePadding * 0.8,
                            ),
                            elevation: _showActive ? 3 : 0,
                          ),
                          onPressed: () {
                            setState(() {
                              _showActive = true;
                            });
                          },
                          child: Text(
                            'Active Packages',
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
                            backgroundColor: !_showActive
                                ? const Color(0xFFBDA25B)
                                : Colors.transparent,
                            foregroundColor: !_showActive
                                ? Colors.white
                                : const Color(0xFFBDA25B),
                            side: const BorderSide(
                              color: Color(0xFFBDA25B),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            padding: EdgeInsets.symmetric(
                              vertical: basePadding * 0.8,
                            ),
                            elevation: !_showActive ? 3 : 0,
                          ),
                          onPressed: () {
                            setState(() {
                              _showActive = false;
                            });
                          },
                          child: Text(
                            'Past Packages',
                            style: TextStyle(
                              fontSize: baseFontSize * 0.9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: basePadding),
                  StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('users')
                        .doc(_auth.currentUser?.uid)
                        .collection('Credit_Remains')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: Color(0xFFBDA25B)));
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Text(
                            _showActive
                                ? 'No active packages available.'
                                : 'No past packages available.',
                            style: TextStyle(
                              fontSize: baseFontSize * 0.9,
                              color: Colors.grey[600],
                            ),
                          ),
                        );
                      }

                      final packages = snapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final isActive = _isPackageActive(data);
                        return _showActive ? isActive : !isActive;
                      }).map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final title = data['title'] as String? ?? 'Unknown Title';
                        final validUntil =
                            (data['validUntil'] as Timestamp?)?.toDate() ??
                                DateTime(1970);
                        final creditsTotal = data['credits_total'] as num? ?? 0;
                        final creditsRemaining =
                            data['credits_remaining'] as num? ?? 0;

                        return PackageCard(
                          title: title,
                          validUntil: _formatDate(validUntil),
                          creditsTotal: creditsTotal.toInt(),
                          creditsRemaining: creditsRemaining.toInt(),
                          isActive: _isPackageActive(data),
                        );
                      }).toList();

                      return ListView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        itemCount: packages.length,
                        itemBuilder: (context, index) => packages[index],
                      );
                    },
                  ),
                  SizedBox(height: basePadding),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavBar(currentIndex: 4),
    );
  }

  Widget _buildListTile(
      BuildContext context, {
        required String title,
        required String route,
        required double baseFontSize,
        int unreadCount = 0,
      }) {
    return ListTile(
      title: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: baseFontSize * 0.95,
              color: Colors.grey[800],
            ),
          ),
          if (unreadCount > 0) // Show red dot and unread count if there are unread notifications
            Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4.0),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 4.0),
                  child: Text(
                    '$unreadCount',
                    style: TextStyle(
                      fontSize: baseFontSize * 0.75,
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
      trailing: const Icon(
        Icons.arrow_forward,
        color: Color(0xFFBDA25B),
      ),
      onTap: () {
        if (title == 'Notification') {
          // Update last viewed timestamp and reset unread count
          final userId = _auth.currentUser?.uid;
          if (userId != null) {
            _firestore.collection('users').doc(userId).update({
              'last_notification_viewed': FieldValue.serverTimestamp(),
            });
            setState(() {
              _unreadNotificationCount = 0;
              unreadNotificationCountNotifier.value = 0; // Reset global notifier
            });
          }
        }
        Navigator.pushNamed(context, route);
      },
    );
  }
}
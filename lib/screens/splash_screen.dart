import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();

    _checkAuthAndRedirect();
  }

  Future<void> _checkAuthAndRedirect() async {
    await Future.delayed(const Duration(seconds: 3));

    final user = _auth.currentUser;

    if (user == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final role = doc.data()?['role'];

      if (role == 'student') {
        Navigator.pushReplacementNamed(context, '/timetable');
      } else if (role == 'instructor') {
        Navigator.pushReplacementNamed(context, '/ins_timetable');
      } else {
        // Unknown or undefined role
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      debugPrint('Error fetching role: $e');
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ScaleTransition(
          scale: _animation,
          child: Image.asset(
            'assets/logo.png',
            height: 280,
          ),
        ),
      ),
    );
  }
}

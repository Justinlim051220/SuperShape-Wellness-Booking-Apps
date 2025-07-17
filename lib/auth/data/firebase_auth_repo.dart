/*
Firebase is Backend
 */


import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../domain/entities/app_user.dart';
import '../domain/repos/auth_repo.dart';

class FirebaseAuthRepo implements AuthRepo {
  final FirebaseAuth firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  @override
  Future<AppUser?> loginwithEmailPassword(String email, String password) async {
    try {
      final UserCredential userCredential = await firebaseAuth
          .signInWithEmailAndPassword(email: email, password: password);

      final uid = userCredential.user!.uid;

      // Get role from Firestore
      final doc = await firestore.collection('users').doc(uid).get();
      final role = doc.data()?['role'] ?? 'student';

      return AppUser(
        uid: uid,
        email: email,
        role: role,
      );
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  @override
  Future<AppUser?> registerwithEmailPassword(String name, String email, String password) async {
    try {
      final UserCredential userCredential = await firebaseAuth
          .createUserWithEmailAndPassword(email: email, password: password);

      final uid = userCredential.user!.uid;

      // Save user data to Firestore
      await firestore.collection('users').doc(uid).set({
        'uid': uid,
        'email': email,
        'name': name,
        'role': 'student', // default role
      });

      return AppUser(uid: uid, email: email, role: 'student');
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }

  @override
  Future<void> deleteAccount() async {
    try {
      final user = firebaseAuth.currentUser;
      if (user == null) throw Exception('No user logged in');

      await firestore.collection('users').doc(user.uid).delete();
      await user.delete();
      await logout();
    } catch (e) {
      throw Exception('Failed to delete account: $e');
    }
  }

  @override
  Future<AppUser?> getCurrentUser() async {
    final user = firebaseAuth.currentUser;
    if (user == null) return null;

    final doc = await firestore.collection('users').doc(user.uid).get();
    final data = doc.data();
    if (data == null) return null;

    return AppUser(
      uid: user.uid,
      email: user.email ?? '',
      role: data['role'] ?? 'student',
    );
  }

  @override
  Future<void> logout() async {
    await firebaseAuth.signOut();
  }

  @override
  Future<String> sendPasswordResetEmail(String email) async {
    try {
      await firebaseAuth.sendPasswordResetEmail(email: email);
      return "Password reset Email! Check your inbox.";
    } catch (e) {
      throw Exception('Failed to send reset email: $e');
    }
  }
}

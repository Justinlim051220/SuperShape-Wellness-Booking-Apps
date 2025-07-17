/*
AUTH REPOSITORY- Outlines  the possibles auth operation for this app.
*/

import '../entities/app_user.dart';
abstract class AuthRepo{
  Future<AppUser?>loginwithEmailPassword(String email, String password);
  Future<AppUser?>registerwithEmailPassword(
      String name, String email, String password);
  Future<void>logout();
  Future<AppUser?>getCurrentUser();
  Future<String>sendPasswordResetEmail(String email);
  Future<void>deleteAccount();
}
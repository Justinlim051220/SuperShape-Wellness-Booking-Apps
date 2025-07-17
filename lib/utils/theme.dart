import 'package:flutter/material.dart';

final ThemeData myTheme = ThemeData(
  primaryColor: const Color(0xFFBDA25B),
  scaffoldBackgroundColor: Colors.white,
  textTheme: ThemeData.light().textTheme,
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFFBDA25B),
      foregroundColor: Colors.white,
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    focusedBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: Color(0xFFBDA25B), width: 2),
      borderRadius: const BorderRadius.all(Radius.circular(8)),
    ),
    labelStyle: const TextStyle(color: Color(0xFF000000)),
    border: const OutlineInputBorder(),
  ),
  textSelectionTheme: const TextSelectionThemeData(
    cursorColor: Colors.black,
    selectionColor: Colors.black26,
    selectionHandleColor: Colors.black,
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: Color(0xFFBDA25B),
    selectedItemColor: Colors.white,
    unselectedItemColor: Colors.grey,
  ),
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: Color(0xFFBDA25B), // Set default color for progress indicators
    circularTrackColor: Colors.grey, // Optional: background track color for CircularProgressIndicator
  ),
);

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class CourseCancellationScreen extends StatelessWidget {
  const CourseCancellationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};

    if (data.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Missing booking data')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Cancellation Policy"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 60),
            const SizedBox(height: 20),
            const Text(
              'Cancellation Terms',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              '• Cancel >12 hours: Full refund\n• Cancel <12 hours: Credit forfeited',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.left,
            ),
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/class_confirmation', arguments: data);
              },
              child: const Text('I UNDERSTAND & AGREE'),
            ),
          ],
        ),
      ),
    );
  }
}
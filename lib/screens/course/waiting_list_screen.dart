import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class WaitingListScreen extends StatelessWidget {
  const WaitingListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic>? item = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    if (item == null || item.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('No class data available.')),
      );
    }

    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              item['title'] ?? 'Unknown Class',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Text('This Class is Full!'),
            const SizedBox(height: 16),
            const Text('Join the waiting list and get notified if a spot opens.'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Added to waiting list')),
                );
                Navigator.pushNamed(context, '/timetable');
              },
              child: const Text('JOIN WAITING LIST'),
            ),
          ],
        ),
      ),
    );
  }
}
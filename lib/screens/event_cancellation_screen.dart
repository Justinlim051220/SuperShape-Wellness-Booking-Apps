import 'package:flutter/material.dart';

class EventCancellationScreen extends StatelessWidget {
  const EventCancellationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final event = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;

    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Event Cancellation Policy', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Text('Cancel >48 hours: Full refund'),
            Text('Cancel <48 hours: Credit forfeited'),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/event_purchase', arguments: event);
              },
              child: Text('I UNDERSTAND, PROCEED WITH THE BOOKING'),
            ),
          ],
        ),
      ),
    );
  }
}
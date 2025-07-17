import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class PaymentOptionsScreen extends StatelessWidget {
  final double amount;
  final String packageId;
  final String? title;
  final Map<String, dynamic>? additionalData;

  const PaymentOptionsScreen({
    super.key,
    required this.amount,
    required this.packageId,
    this.title,
    this.additionalData,
  });

  Stream<List<Map<String, dynamic>>> _paymentMethodsStream() {
    return FirebaseFirestore.instance
        .collection('payment_methods')
        .snapshots()
        .map((snap) {
      print('DEBUG: Raw snapshot docs count => ${snap.docs.length}');
      print('DEBUG: Raw snapshot data => ${snap.docs.map((doc) => doc.data()).toList()}');
      return snap.docs.map((doc) {
        final data = doc.data();
        return {
          'method': data['method'] ?? doc.id,
          'icon': data['icon'],
          'description': data['description'],
          'route': data['route'],
        };
      })
          .where((m) =>
      m.containsKey('icon') &&
          m.containsKey('description') &&
          m.containsKey('route') &&
          m['method'] != null)
          .toList();
    });
  }

  Future<void> _testNetworkConnection() async {
    try {
      final response = await http.get(Uri.parse('https://www.google.com'));
      print('Network test: ${response.statusCode}');
    } catch (e) {
      print('Network test failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    _testNetworkConnection();
    const themeColor = Color(0xFFBDA25B);
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>? ?? {};
    final amount = args['amount'] as double? ?? this.amount;
    final packageId = args['packageId'] as String? ?? this.packageId;
    final title = args['title'] as String? ?? this.title;
    final additionalData = args['additionalData'] as Map<String, dynamic>? ?? this.additionalData ?? {};
    final isEvent = (additionalData['type'] as String?)?.toLowerCase() == 'event';
    print('PaymentOptionsScreen: amount=$amount, packageId=$packageId, title=$title, additionalData=$additionalData, isEvent=$isEvent');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Payment Method'),
        centerTitle: true,
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _paymentMethodsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading methods: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No payment methods available'));
          }
          final methods = snapshot.data!;
          print('DEBUG: Loaded ${methods.length} methods => $methods');
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: methods.length,
            itemBuilder: (context, i) {
              final method = methods[i];
              return _buildPaymentTile(
                context,
                icon: _getIcon(method['icon'] as String?),
                label: method['description'] as String? ?? '',
                methodName: method['method'] as String,
                amount: amount,
                packageId: packageId,
                title: title,
                additionalData: additionalData,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPaymentTile(
      BuildContext context, {
        required IconData icon,
        required String label,
        required String methodName,
        required double amount,
        required String packageId,
        String? title,
        Map<String, dynamic>? additionalData,
      }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFFBDA25B)),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          final args = {
            'method': methodName,
            'amount': amount,
            'packageId': packageId,
            'title': title,
            'additionalData': additionalData,
          };
          print('PaymentOptionsScreen: Navigating to /payment_method with args=$args');
          Navigator.pushNamed(context, '/payment_method', arguments: args);
        },
      ),
    );
  }

  IconData _getIcon(String? iconName) {
    switch (iconName) {
      case 'qr_code_scanner':
        return Icons.qr_code_scanner;
      case 'account_balance':
        return Icons.account_balance;
      case 'money':
        return Icons.money;
      default:
        return Icons.payment;
    }
  }
}
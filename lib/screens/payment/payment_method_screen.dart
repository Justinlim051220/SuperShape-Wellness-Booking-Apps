import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PaymentMethodScreen extends StatelessWidget {
  final String method;
  final double amount;
  final String packageId;
  final String? title;
  final Map<String, dynamic>? additionalData;

  const PaymentMethodScreen({
    super.key,
    required this.method,
    required this.amount,
    required this.packageId,
    this.title,
    this.additionalData,
  });

  Future<Map<String, dynamic>> _loadData() async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('payment_methods')
          .where('method', isEqualTo: method)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        return {
          'method': method,
          'details': 'No details available.',
        };
      }

      final doc = query.docs.first;
      final data = doc.data();
      data['method'] = method;
      return data;
    } catch (e) {
      return {
        'method': method,
        'details': 'Failed to load payment method: $e',
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    const themeColor = Color(0xFFBDA25B);
    String? type;
    Map<String, dynamic> flattenedAdditionalData = {};
    if (additionalData != null) {
      type = (additionalData!['type'] as String?)?.toLowerCase();
      flattenedAdditionalData = Map<String, dynamic>.from(additionalData!);
      if (type == null && additionalData!.containsKey('additionalData')) {
        print('PaymentMethodScreen: Warning - Nested additionalData detected');
        final nestedData = additionalData!['additionalData'] as Map<String, dynamic>?;
        if (nestedData != null) {
          type = (nestedData['type'] as String?)?.toLowerCase();
          flattenedAdditionalData = Map<String, dynamic>.from(nestedData);
          if (nestedData.containsKey('additionalData')) {
            final innerData = nestedData['additionalData'] as Map<String, dynamic>?;
            if (innerData != null) {
              type ??= (innerData['type'] as String?)?.toLowerCase();
              flattenedAdditionalData = Map<String, dynamic>.from(innerData);
            }
          }
        }
      }
    }
    final isEvent = type == 'event';
    print('PaymentMethodScreen build: method=$method, packageId=$packageId, amount=$amount, title=$title, additionalData=$additionalData, type=$type, isEvent=$isEvent');

    if (!isEvent && packageId.isEmpty) {
      print('PaymentMethodScreen: Error - packageId is empty for non-event booking');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid package ID')),
        );
      });
    } else if (additionalData == null || type == null) {
      print('PaymentMethodScreen: Warning - additionalData or type is null: additionalData=$additionalData, type=$type');
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: _loadData(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data!;
        final imagePath = data['image'] as String?;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              data['method'],
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            foregroundColor: Colors.white,
            backgroundColor: themeColor,
            centerTitle: true,
            elevation: 0,
            systemOverlayStyle: const SystemUiOverlayStyle(
              statusBarBrightness: Brightness.light,
              statusBarIconBrightness: Brightness.dark,
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imagePath != null && imagePath.isNotEmpty) ...[
                  Center(
                    child: Container(
                      height: 200,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Image.network(
                        imagePath,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(child: Text('Failed to load QR code image'));
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
                const Text(
                  'Payment Instructions',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Card(
                  color: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildStyledText(data['details'] ?? 'No details available.'),
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.upload_file, size: 20),
                    label: const Text(
                      "Upload Receipt",
                      style: TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      print('PaymentMethodScreen: Navigating to /upload_receipt with arguments: packageId=$packageId, amount=$amount, title=$title, additionalData=$flattenedAdditionalData');
                      Navigator.pushNamed(
                        context,
                        '/upload_receipt',
                        arguments: {
                          'amount': amount,
                          'packageId': packageId,
                          'title': title,
                          'additionalData': flattenedAdditionalData,
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStyledText(String rawText) {
    final lines = rawText.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        final parts = line.split(':');
        if (parts.length >= 2) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 16, color: Colors.black),
                children: [
                  TextSpan(text: '${parts[0].trim()}: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: parts.sublist(1).join(':').trim()),
                ],
              ),
            ),
          );
        } else {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(line, style: const TextStyle(fontSize: 16)),
          );
        }
      }).toList(),
    );
  }
}
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GeneralPurchaseScreen extends StatefulWidget {
  final String? title;
  final String? subtitle;
  final double amount;
  final Map<String, dynamic>? additionalData;
  final String packageId; // Added to pass the package document ID

  const GeneralPurchaseScreen({
    super.key,
    this.title,
    this.subtitle,
    required this.amount,
    this.additionalData,
    required this.packageId, // Required parameter for package ID
  });

  @override
  State<GeneralPurchaseScreen> createState() => _GeneralPurchaseScreenState();
}

class _GeneralPurchaseScreenState extends State<GeneralPurchaseScreen> {
  bool _termsAgreed = false;

  @override
  Widget build(BuildContext context) {
    final tax = 0.0;
    final total = widget.amount + tax;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Confirm Your Purchase',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFBDA25B),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarBrightness: Brightness.light,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title ?? 'Purchase Item',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        widget.subtitle!,
                        style: const TextStyle(fontSize: 18),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 20),
                    Text('Subtotal: RM${widget.amount.toStringAsFixed(2)}'),
                    const SizedBox(height: 8),
                    Text('Tax: RM${tax.toStringAsFixed(2)}'),
                    const SizedBox(height: 8),
                    Text(
                      'Total (Incl. Tax): RM${total.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: _termsAgreed,
                  onChanged: (value) {
                    setState(() {
                      _termsAgreed = value ?? false;
                    });
                  },
                  activeColor: const Color(0xFFBDA25B),
                ),
                Expanded(
                  child: Text(
                    'I have read and agree to the Terms of Service',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _termsAgreed
                    ? () {
                  Navigator.pushNamed(
                    context,
                    '/payment_options',
                    arguments: {
                      'amount': total,
                      'title': widget.title,
                      'packageId': widget.packageId, // Pass package ID
                      'additionalData': widget.additionalData,
                    },
                  );
                }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFBDA25B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'CONTINUE TO PAYMENT',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
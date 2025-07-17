import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'payment_history_screen.dart';
import '../../widgets/bottom_nav_bar.dart';
import 'general_purchase_screen.dart';

class CreditScreen extends StatefulWidget {
  const CreditScreen({super.key});

  @override
  State<CreditScreen> createState() => _CreditScreenState();
}

class _CreditScreenState extends State<CreditScreen> {
  List<Map<String, dynamic>> creditPackages = [];
  Map<String, dynamic>? preferredClass; // Holds the trial promo package
  bool isLoading = true;
  String? selectedPackageType;

  @override
  void initState() {
    super.initState();
    _loadFromFirestore();
  }

  Future<void> _loadFromFirestore() async {
    setState(() => isLoading = true);
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
      final snapshot = await FirebaseFirestore.instance
          .collection('Credit_Packages')
          .get();

      final List<Map<String, dynamic>> docs = snapshot.docs.map((doc) {
        return {...doc.data(), 'id': doc.id}; // Include document ID
      }).toList();

      // Get list of purchased trial package IDs
      final purchasedTrialIds = <String>{};
      final creditRemainsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('Credit_Remains')
          .get();
      for (var doc in creditRemainsSnapshot.docs) {
        final packageId = doc['packageId'] as String?;
        final packageDoc = await FirebaseFirestore.instance
            .collection('Credit_Packages')
            .doc(packageId)
            .get();
        if (packageDoc.exists && (packageDoc.data()?['type'] as String?)?.toLowerCase() == 'trial') {
          purchasedTrialIds.add(packageId!);
        }
      }

      // Extract the trial promo package, excluding purchased ones
      Map<String, dynamic>? trialPackage;
      docs.removeWhere((pkg) {
        if ((pkg['type'] as String?)?.toLowerCase() == 'trial') {
          if (purchasedTrialIds.contains(pkg['id'])) {
            return true; // Remove if already purchased
          }
          trialPackage = pkg;
          return true; // Remove to isolate trial package
        }
        return false;
      });

      setState(() {
        creditPackages = docs;
        preferredClass = trialPackage; // Only set if not purchased
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading packages: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final baseFontSize = screenWidth * 0.04;

    final filtered = selectedPackageType == null
        ? []
        : creditPackages
        .where((pkg) => pkg['type'] == selectedPackageType)
        .toList();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFBDA25B),
        centerTitle: true,
        title: Text(
          'CREDIT PAGE',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: baseFontSize * 1.2,
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFBDA25B)))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (preferredClass != null) ...[
              const Text(
                'Trial Promo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildPackageCard(preferredClass!, isPromo: true),
              const SizedBox(height: 24),
            ],
            const Text(
              'Credit Packages',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            DropdownButton<String>(
              value: selectedPackageType,
              hint: const Text('Select Package Type'),
              isExpanded: true,
              items: const [
                DropdownMenuItem(
                  value: 'group',
                  child: Text('Group Class Package'),
                ),
                DropdownMenuItem(
                  value: 'private',
                  child: Text('Private Class Package'),
                ),
              ],
              onChanged: (val) => setState(() => selectedPackageType = val),
              style: const TextStyle(fontSize: 16, color: Colors.black),
              dropdownColor: Colors.white,
              underline: Container(
                height: 2,
                color: const Color(0xFFBDA25B),
              ),
            ),
            const SizedBox(height: 16),
            if (selectedPackageType == null)
              const Center(child: Text('Please select a package type.'))
            else if (filtered.isEmpty)
              const Center(child: Text('No packages available.'))
            else
              ...filtered.map((pkg) => _buildPackageCard(pkg)).toList(),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PaymentHistoryScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFBDA25B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 2,
              ),
              child: const Text('VIEW PAYMENT HISTORY'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 2),
    );
  }

  Widget _buildPackageCard(Map<String, dynamic> pkg, {bool isPromo = false}) {
    final title = pkg['title'] ?? '';
    final credits = (pkg['credits'] as num?)?.toInt() ?? 0;
    final price = (pkg['price'] as num?)?.toDouble() ?? 0.0;
    final validity = pkg['validity'] ?? '';
    final type = pkg['type'] ?? '';
    final packageId = pkg['id'] as String; // Assert non-null since added in _loadFromFirestore

    final header = isPromo
        ? Row(
      children: const [
        Icon(Icons.star, color: Color(0xFFBDA25B), size: 24),
        SizedBox(width: 8),
        Text('Promo', style: TextStyle(fontWeight: FontWeight.bold)),
      ],
    )
        : const SizedBox();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      color: const Color(0xFFF5F5F5),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (isPromo) ...[
            header,
            const SizedBox(height: 8),
          ],
          Text(title,
              style: TextStyle(fontSize: isPromo ? 20 : 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('$credits Credits'),
          Text('Valid for $validity days'),
          if (!isPromo)
            Text('Type: ${type == "group" ? "Group Class" : "Private Class"}'),
          const SizedBox(height: 8),
          Text('RM${price.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFBDA25B))),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: () async {
                final userId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

                // Check if the package is a trial
                final packageDoc = await FirebaseFirestore.instance
                    .collection('Credit_Packages')
                    .doc(packageId)
                    .get();
                if (packageDoc.exists) {
                  final packageData = packageDoc.data() as Map<String, dynamic>;
                  final isTrial = (packageData['type'] as String?)?.toLowerCase() == 'trial';

                  if (isTrial) {
                    // Check for existing approved trial purchase
                    final creditRemainsSnapshot = await FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .collection('Credit_Remains')
                        .where('packageId', isEqualTo: packageId)
                        .limit(1)
                        .get();
                    if (creditRemainsSnapshot.docs.isNotEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('You can only purchase this trial package once.')),
                      );
                      return;
                    }

                    // Check for pending trial purchase attempts
                    final pendingPaymentsSnapshot = await FirebaseFirestore.instance
                        .collection('Payment')
                        .where('userid', isEqualTo: userId)
                        .where('PackageID', isEqualTo: packageId)
                        .where('Status', isEqualTo: 'Pending')
                        .limit(1)
                        .get();
                    if (pendingPaymentsSnapshot.docs.isNotEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('You already have a pending purchase for this trial package.')),
                      );
                      return;
                    }
                  }
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GeneralPurchaseScreen(
                      title: title,
                      subtitle: '$credits Credits • Valid for $validity days',
                      amount: price,
                      additionalData: pkg,
                      packageId: packageId, // Pass the document ID
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFBDA25B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 2,
              ),
              child: Text(isPromo ? 'PURCHASE NOW' : 'PURCHASE'),
            ),
          ),
        ]),
      ),
    );
  }
}
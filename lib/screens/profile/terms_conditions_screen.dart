import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TermsConditionScreen extends StatelessWidget {
  const TermsConditionScreen({super.key});

  Future<List<Map<String, dynamic>>> _loadTermsFromFirestore() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('terms_and_conditions')
        .orderBy('section')
        .get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double baseFontSize = screenWidth * 0.04;
    final double basePadding = screenWidth * 0.05;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadTermsFromFirestore(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Error loading terms: ${snapshot.error}')),
          );
        }
        final termsSections = snapshot.data ?? [];

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const Text('Terms and Conditions', style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: const Color(0xFFBDA25B),
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            systemOverlayStyle: const SystemUiOverlayStyle(
              statusBarBrightness: Brightness.light,
              statusBarIconBrightness: Brightness.dark,
            ),
          ),
          body: SafeArea(
            child: termsSections.isEmpty
                ? const Center(child: Text('No terms available.', style: TextStyle(color: Colors.grey)))
                : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, Color(0xFFF9F9F9)],
                ),
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: basePadding,
                  vertical: basePadding * 1.5,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...termsSections.map((section) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(section['section'], baseFontSize),
                        if (section.containsKey('highlight') && section['highlight'] != null)
                          _buildHighlightCard(section['highlight'], baseFontSize, screenWidth),
                        _buildSectionContent(
                          section['content'] ?? '',
                          bulletPoints: section['bullet_points'] != null
                              ? List<String>.from(section['bullet_points'])
                              : null,
                          baseFontSize: baseFontSize,
                        ),
                        SizedBox(height: basePadding * 1.4),
                      ],
                    )),
                    Center(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFBDA25B),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: basePadding * 2,
                            vertical: basePadding * 0.8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 3,
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'BACK',
                          style: TextStyle(
                            fontSize: baseFontSize * 0.9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String text, double baseFontSize) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(right: 12),
          decoration: const BoxDecoration(
            color: Color(0xFFBDA25B),
            shape: BoxShape.circle,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: baseFontSize * 1.1,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            softWrap: true,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionContent(String text, {List<String>? bulletPoints, required double baseFontSize}) {
    return Padding(
      padding: EdgeInsets.only(left: baseFontSize * 1.2, top: baseFontSize * 0.7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: baseFontSize * 0.9,
              height: 1.6,
              color: Colors.black54,
            ),
            softWrap: true,
          ),
          if (bulletPoints != null) ...[
            SizedBox(height: baseFontSize * 0.7),
            ...bulletPoints.map((point) => Padding(
              padding: EdgeInsets.only(bottom: baseFontSize * 0.5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: baseFontSize * 0.3, right: baseFontSize * 0.5),
                    child: const Icon(Icons.circle, size: 6, color: Color(0xFFBDA25B)),
                  ),
                  Expanded(
                    child: Text(
                      point,
                      style: TextStyle(
                        fontSize: baseFontSize * 0.85,
                        height: 1.5,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildHighlightCard(String text, double baseFontSize, double screenWidth) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(
        left: baseFontSize * 1.2,
        top: baseFontSize * 0.7,
        bottom: baseFontSize * 0.7,
      ),
      padding: EdgeInsets.all(baseFontSize * 0.9),
      decoration: BoxDecoration(
        color: const Color(0xFFBDA25B).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFBDA25B).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: baseFontSize * 0.85,
          fontWeight: FontWeight.w600,
          color: const Color(0xFFBDA25B),
          height: 1.5,
        ),
        softWrap: true,
      ),
    );
  }
}

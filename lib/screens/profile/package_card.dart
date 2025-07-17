import 'package:flutter/material.dart';

class PackageCard extends StatelessWidget {
  final String title;
  final String validUntil;
  final int creditsTotal;
  final int creditsRemaining;
  final bool isActive;

  const PackageCard({
    super.key,
    required this.title,
    required this.validUntil,
    required this.creditsTotal,
    required this.creditsRemaining,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double baseFontSize = screenWidth * 0.04; // ≈14-16px
    final double basePadding = screenWidth * 0.03; // ≈8-12px

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      color: const Color(0xFFF5F5F5),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: basePadding * 1.5,
          vertical: basePadding * 0.8,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: baseFontSize * 0.95,
            color: Colors.grey[800],
          ),
          softWrap: true,
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: basePadding * 0.3),
            Text(
              validUntil,
              style: TextStyle(
                fontSize: baseFontSize * 0.85,
                color: Colors.grey[600],
              ),
              softWrap: true,
              maxLines: 1,
            ),
            SizedBox(height: basePadding * 0.2),
            Row(
              children: [
                Text(
                  'Credits: ',
                  style: TextStyle(
                    fontSize: baseFontSize * 0.85,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  '$creditsRemaining/$creditsTotal',
                  style: TextStyle(
                    fontSize: baseFontSize * 0.85,
                    fontWeight: FontWeight.bold,
                    color: isActive ? const Color(0xFFBDA25B) : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Icon(
          isActive ? Icons.check_circle : Icons.history,
          color: isActive ? const Color(0xFFBDA25B) : Colors.grey[600],
          size: baseFontSize * 1.2,
        ),
      ),
    );
  }
}
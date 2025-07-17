import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../Instructor_widgets/bottom_nav_bar.dart';

class PerformanceScreen extends StatefulWidget {
  final Widget? bottomNavBar;

  const PerformanceScreen({super.key, this.bottomNavBar});

  @override
  _PerformanceScreenState createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  List<Map<String, dynamic>>? _classData;
  List<int> _bookedCounts = [];
  bool _isLoading = true;

  // Predefined colors for class types
  final Map<String, Color> _classTypeColors = {
    'pilates': Colors.blue,
    'yoga': Colors.green,
    'zumba': Colors.red,
    // Add more class types and colors as needed
  };

  @override
  void initState() {
    super.initState();
    _loadPerformanceData();
  }

  Future<void> _loadPerformanceData() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not logged in')),
        );
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('class')
          .where('instructor_id', isEqualTo: userId)
          .get();

      // Group by class_type and count sessions
      final classTypes = <String, int>{};
      final bookedCounts = <int>[];
      for (var doc in snapshot.docs) {
        final classType = doc.data()['class_type'] as String? ?? 'Unknown';
        classTypes[classType] = (classTypes[classType] ?? 0) + 1;
        final booked = doc.data()['booked'] as int? ?? 0;
        bookedCounts.add(booked);
      }

      // Convert to list for pie chart
      final classTypeData = classTypes.entries.map((entry) {
        return {
          'type': entry.key,
          'sessions': entry.value,
          'color': _classTypeColors[entry.key] ?? Colors.grey, // Store Color object directly
        };
      }).toList();

      setState(() {
        _classData = classTypeData;
        _bookedCounts = bookedCounts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading performance data: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFBDA25B),
        centerTitle: true,
        title: const Text(
          'Performance',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        automaticallyImplyLeading: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16.0),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _classData == null || _classData!.isEmpty
          ? const Center(child: Text('No performance data available.'))
          : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance Overview',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildPieChartSection(context),
            const Divider(color: Colors.grey, thickness: 0.5),
            const SizedBox(height: 16),
            _buildMetricsSection(context),
          ],
        ),
      ),
      bottomNavigationBar: widget.bottomNavBar ?? const InstructorBottomNavBar(currentIndex: 1),
    );
  }

  Widget _buildPieChartSection(BuildContext context) {
    final totalSessions = _classData!.fold<int>(0, (sum, item) => sum + (item['sessions'] as int));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Class Type Distribution',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sections: _classData!.asMap().entries.map((entry) {
                final data = entry.value;
                final percentage = (data['sessions'] / totalSessions) * 100;
                return PieChartSectionData(
                  color: data['color'] as Color, // Use Color object directly
                  value: data['sessions'].toDouble(),
                  title: '${percentage.toStringAsFixed(1)}%',
                  radius: 60,
                  titleStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }).toList(),
              sectionsSpace: 2,
              centerSpaceRadius: 40,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Column(
          children: _classData!.asMap().entries.map((entry) {
            final data = entry.value;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    color: data['color'] as Color,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${data['type']}: ${data['sessions']} sessions',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMetricsSection(BuildContext context) {
    final totalClasses = _classData!.fold<int>(0, (sum, item) => sum + (item['sessions'] as int));
    final averageAttendance = _bookedCounts.isEmpty
        ? 0.0
        : _bookedCounts.reduce((a, b) => a + b) / _bookedCounts.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Key Metrics',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        _buildMetricCard(
          context,
          icon: Icons.class_,
          title: 'Total Classes Conducted',
          value: '$totalClasses',
        ),
        const Divider(color: Colors.grey, thickness: 0.5),
        _buildMetricCard(
          context,
          icon: Icons.group,
          title: 'Average Attendance per Class',
          value: averageAttendance.toStringAsFixed(1),
        ),
      ],
    );
  }

  Widget _buildMetricCard(BuildContext context, {required IconData icon, required String title, String? value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Icon(icon, size: 28, color: Theme.of(context).primaryColor),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value ?? 'N/A',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
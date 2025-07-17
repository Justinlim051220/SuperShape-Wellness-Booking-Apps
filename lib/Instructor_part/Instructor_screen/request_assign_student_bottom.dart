import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../Instuctor_model/class_model.dart';

class RequestAssignStudentBottomSheet extends StatefulWidget {
  final ClassModel data;
  final Function(String, String)? onAssignRequest;

  const RequestAssignStudentBottomSheet({
    super.key,
    required this.data,
    this.onAssignRequest,
  });

  @override
  _RequestAssignStudentBottomSheetState createState() =>
      _RequestAssignStudentBottomSheetState();
}

class _RequestAssignStudentBottomSheetState
    extends State<RequestAssignStudentBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, String>> _searchResults = [];
  List<Map<String, String>> _allStudents = [];
  final Set<String> _requestedStudentIds = {}; // To track requests
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    try {
      final String jsonString =
      await rootBundle.loadString('assets/students.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      setState(() {
        _allStudents = (jsonData['students'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map((student) => {
          'id': student['id'] as String,
          'name': student['name'] as String,
        })
            .toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading students: $e')),
      );
    }
  }

  void _searchStudents(String query) {
    setState(() {
      _isSearching = query.isNotEmpty;
      _searchResults = _allStudents
          .where((student) =>
          student['name']!.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  void _handleRequest(String studentId, String studentName) {
    setState(() {
      _requestedStudentIds.add(studentId);
    });
    widget.onAssignRequest?.call(studentId, studentName);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Request Successfully'),
        backgroundColor: const Color(0xFFBDA25B),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final studentsToShow =
    _isSearching ? _searchResults : []; // Show results only when searching

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Request Assign Student',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.black54),
                        onPressed: () => Navigator.pop(context),
                        tooltip: 'Cancel',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Search bar
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search student by name',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: _searchStudents,
                  ),
                  const SizedBox(height: 16),

                  // Message or search results
                  if (!_isSearching)
                    Text(
                      'Enter a name to search for students.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                    )
                  else if (studentsToShow.isEmpty)
                    Text(
                      'No students found.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                    )
                  else
                    ...studentsToShow.map((student) {
                      final studentId = student['id']!;
                      final studentName = student['name']!;
                      final isRequested = _requestedStudentIds.contains(studentId);

                      return ListTile(
                        title: Text(
                          studentName,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        trailing: ElevatedButton(
                          onPressed: isRequested
                              ? null
                              : () => _handleRequest(studentId, studentName),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isRequested
                                ? const Color(0xFFBDA25B).withOpacity(0.5) // Transparent gold
                                : const Color(0xFFBDA25B), // Normal gold
                            foregroundColor: Colors.white, // Always white text
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            disabledBackgroundColor: const Color(0xFFBDA25B).withOpacity(0.5),
                            disabledForegroundColor: Colors.white, // Keep white even when disabled
                          ),
                          child: Text(isRequested ? 'Requested' : 'Request'),
                        ),
                      );
                    }),

                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

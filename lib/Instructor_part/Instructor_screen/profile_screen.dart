import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../Instructor_widgets/bottom_nav_bar.dart';
import '../../services/notification_state.dart'; // Import notification state
import 'dart:async'; // For StreamSubscription

class ProfileScreen extends StatefulWidget {
  final Widget? bottomNavBar;

  const ProfileScreen({super.key, this.bottomNavBar});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  Map<String, dynamic> _profileData = {};
  bool _isLoading = true;
  bool _isEditing = false;
  String? _errorMessage;
  File? _profileImage;
  File? _coverImage;

  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _experienceYearsController = TextEditingController();
  final _certificationController = TextEditingController();
  final _specializationController = TextEditingController();

  List<String> _certifications = [];
  List<String> _specializations = [];

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Notification-related fields
  late StreamSubscription<QuerySnapshot> _notificationSubscription;
  int _unreadNotificationCount = 0;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _subscribeToNotifications();
    _loadLastViewedTimestamp();
  }

  Future<void> _loadProfileData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Please log in to view your profile.';
        });
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        return;
      }

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Profile not found.';
        });
        return;
      }

      final data = doc.data()!;
      if (data['role'] != 'instructor') {
        setState(() {
          _isLoading = false;
          _errorMessage = 'This screen is only for instructors.';
        });
        return;
      }

      setState(() {
        _profileData = data;
        _nameController.text = data['full_name'] ?? '';
        _bioController.text = data['bio'] ?? '';
        _experienceYearsController.text = (data['experienceYears'] ?? 0).toString();
        _certifications = List<String>.from(data['certifications'] ?? []);
        _specializations = List<String>.from(data['classType'] ?? []);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading profile data: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load profile data: $e';
      });
    }
  }

  void _subscribeToNotifications() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    _notificationSubscription = _firestore
        .collection('Notification')
        .where('to', arrayContains: userId)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        _updateUnreadNotificationCount(snapshot);
      }
    }, onError: (error) {
      debugPrint('Error listening to notifications: $error at ${DateTime.now()}');
    });
  }

  Future<void> _loadLastViewedTimestamp() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final doc = await _firestore.collection('users').doc(userId).get();
    final lastViewed = (doc.data()?['last_notification_viewed'] as Timestamp?)?.toDate() ?? DateTime(0);
    _updateUnreadNotificationCountBasedOnLastViewed(lastViewed);
  }

  void _updateUnreadNotificationCount(QuerySnapshot snapshot) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    _firestore.collection('users').doc(userId).get().then((doc) {
      final lastViewed = (doc.data()?['last_notification_viewed'] as Timestamp?)?.toDate() ?? DateTime(0);
      _updateUnreadNotificationCountBasedOnLastViewed(lastViewed);
    });
  }

  void _updateUnreadNotificationCountBasedOnLastViewed(DateTime lastViewed) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final snapshot = _firestore.collection('Notification').where('to', arrayContains: userId).get();
    snapshot.then((value) {
      _unreadNotificationCount = value.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime(0);
        return timestamp.isAfter(lastViewed);
      }).length;
      unreadNotificationCountNotifier.value = _unreadNotificationCount; // Update global notifier
      if (mounted) setState(() {});
    });
  }

  Future<String?> _uploadImage(File image, String path) async {
    try {
      final ref = _storage.ref().child(path);
      await ref.putFile(image);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading image: $e');
      setState(() {
        _errorMessage = 'Failed to upload image: $e';
      });
      return null;
    }
  }

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _pickCoverImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _coverImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      setState(() {
        _errorMessage = 'Please fill in all required fields.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'User not logged in.';
        });
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        return;
      }

      String? photoUrl = _profileData['photo_url'];
      String? coverPhotoUrl = _profileData['coverPhoto_url'];

      if (_profileImage != null) {
        photoUrl = await _uploadImage(
          _profileImage!,
          'users/${user.uid}/profile.jpg',
        );
      }

      if (_coverImage != null) {
        coverPhotoUrl = await _uploadImage(
          _coverImage!,
          'users/${user.uid}/cover.jpg',
        );
      }

      final updatedData = {
        'full_name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
        'experienceYears': int.tryParse(_experienceYearsController.text) ?? 0,
        'certifications': _certifications,
        'classType': _specializations,
        'role': 'instructor',
        'phone': _profileData['phone'] ?? '',
        'dob': _profileData['dob'] ?? '',
        if (photoUrl != null) 'photo_url': photoUrl,
        if (coverPhotoUrl != null) 'coverPhoto_url': coverPhotoUrl,
      };

      await _firestore.collection('users').doc(user.uid).update(updatedData);

      setState(() {
        _profileData = {..._profileData, ...updatedData};
        _isEditing = false;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error saving profile: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to save profile: $e';
      });
    }
  }

  void _toggleEdit() {
    if (_isEditing) {
      _saveProfile();
    } else {
      setState(() => _isEditing = true);
    }
  }

  void _addCertification(String cert) {
    if (cert.trim().isNotEmpty) {
      setState(() {
        _certifications.add(cert.trim());
        _certificationController.clear();
      });
    }
  }

  void _addSpecialization(String spec) {
    if (spec.trim().isNotEmpty) {
      setState(() {
        _specializations.add(spec.trim());
        _specializationController.clear();
      });
    }
  }

  void _logout() async {
    await _auth.signOut();
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login',
          (Route<dynamic> route) => false,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _experienceYearsController.dispose();
    _certificationController.dispose();
    _specializationController.dispose();
    _notificationSubscription.cancel(); // Cancel subscription
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
        bottomNavigationBar: InstructorBottomNavBar(currentIndex: 2),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          title: Text(
            'My Profile',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
          leading: ValueListenableBuilder<int>(
            valueListenable: unreadNotificationCountNotifier,
            builder: (context, unreadCount, child) {
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications, color: Colors.white),
                    onPressed: () {
                      final userId = _auth.currentUser?.uid;
                      if (userId != null) {
                        _firestore.collection('users').doc(userId).update({
                          'last_notification_viewed': FieldValue.serverTimestamp(),
                        });
                        unreadNotificationCountNotifier.value = 0; // Reset count
                        setState(() {
                          _unreadNotificationCount = 0;
                        });
                      }
                      Navigator.pushNamed(context, '/instructor_notifications');
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          automaticallyImplyLeading: false,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _errorMessage!,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });
                  _loadProfileData();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        bottomNavigationBar: widget.bottomNavBar ?? const InstructorBottomNavBar(currentIndex: 2),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        title: Text(
          'My Profile',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        leading: ValueListenableBuilder<int>(
          valueListenable: unreadNotificationCountNotifier,
          builder: (context, unreadCount, child) {
            return Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications, color: Colors.white),
                  onPressed: () {
                    final userId = _auth.currentUser?.uid;
                    if (userId != null) {
                      _firestore.collection('users').doc(userId).update({
                        'last_notification_viewed': FieldValue.serverTimestamp(),
                      });
                      unreadNotificationCountNotifier.value = 0; // Reset count
                      setState(() {
                        _unreadNotificationCount = 0;
                      });
                    }
                    Navigator.pushNamed(context, '/instructor_notifications');
                  },
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit),
            onPressed: _toggleEdit,
          ),
        ],
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cover Photo and Avatar
            Stack(
              alignment: Alignment.topCenter,
              children: [
                GestureDetector(
                  onTap: _isEditing ? _pickCoverImage : null,
                  child: Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: _coverImage != null
                            ? FileImage(_coverImage!)
                            : _profileData['coverPhoto_url'] != null
                            ? NetworkImage(_profileData['coverPhoto_url'])
                            : const AssetImage('assets/pilates_cover.jpg') as ImageProvider,
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          Colors.black.withOpacity(0.3),
                          BlendMode.darken,
                        ),
                      ),
                    ),
                    child: _isEditing
                        ? Center(
                      child: Icon(
                        Icons.camera_alt,
                        color: Colors.white.withOpacity(0.8),
                        size: 40,
                      ),
                    )
                        : null,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 120),
                  child: GestureDetector(
                    onTap: _isEditing ? _pickProfileImage : null,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.white,
                          child: CircleAvatar(
                            radius: 46,
                            backgroundImage: _profileImage != null
                                ? FileImage(_profileImage!)
                                : _profileData['photo_url'] != null
                                ? NetworkImage(_profileData['photo_url'])
                                : const AssetImage('assets/yushiko.png') as ImageProvider,
                          ),
                        ),
                        if (_isEditing)
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.black.withOpacity(0.5),
                            child: Icon(
                              Icons.camera_alt,
                              color: Colors.white.withOpacity(0.8),
                              size: 30,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Name and Email
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _isEditing
                      ? Container(
                    width: 300,
                    child: TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      textAlign: TextAlign.center,
                      validator: (value) => value!.isEmpty ? 'Name is required' : null,
                    ),
                  )
                      : Text(
                    _profileData['full_name'] ?? '',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _profileData['email'] ?? '',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            // Main Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Bio Section
                    Text(
                      'Bio',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _isEditing
                        ? TextFormField(
                      controller: _bioController,
                      decoration: InputDecoration(
                        labelText: 'Bio',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      maxLines: 5,
                      validator: (value) => value!.isEmpty ? 'Bio is required' : null,
                    )
                        : Text(
                      _profileData['bio'] ?? '',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.black87,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Divider(color: Colors.grey.shade300, thickness: 1),
                    const SizedBox(height: 16),
                    // Years of Experience
                    Text(
                      'Years of Experience',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _isEditing
                        ? TextFormField(
                      controller: _experienceYearsController,
                      decoration: InputDecoration(
                        labelText: 'Years of Experience',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) => value!.isEmpty ? 'Experience is required' : null,
                    )
                        : Text(
                      '${_profileData['experienceYears'] ?? 0} Years',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Divider(color: Colors.grey.shade300, thickness: 1),
                    const SizedBox(height: 16),
                    // Certifications
                    Text(
                      'Certifications & Qualifications',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _isEditing
                        ? Column(
                      children: [
                        ..._certifications.asMap().entries.map((entry) {
                          final index = entry.key;
                          final cert = entry.value;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(cert),
                            trailing: IconButton(
                              icon: Icon(Icons.delete, color: Theme.of(context).primaryColor),
                              onPressed: () {
                                setState(() => _certifications.removeAt(index));
                              },
                            ),
                          );
                        }),
                        TextFormField(
                          controller: _certificationController,
                          decoration: InputDecoration(
                            labelText: 'Add Certification',
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () {
                                if (_certificationController.text.trim().isNotEmpty) {
                                  _addCertification(_certificationController.text.trim());
                                }
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onFieldSubmitted: (value) {
                            if (value.trim().isNotEmpty) {
                              _addCertification(value.trim());
                            }
                          },
                        ),
                      ],
                    )
                        : Column(
                      children: _certifications.map((cert) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.verified, size: 18, color: Colors.green),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  cert,
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Divider(color: Colors.grey.shade300, thickness: 1),
                    const SizedBox(height: 16),
                    // Specializations
                    Text(
                      'Specializations & Focus Areas',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _isEditing
                        ? Column(
                      children: [
                        ..._specializations.asMap().entries.map((entry) {
                          final index = entry.key;
                          final spec = entry.value;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(spec),
                            trailing: IconButton(
                              icon: Icon(Icons.delete, color: Theme.of(context).primaryColor),
                              onPressed: () {
                                setState(() => _specializations.removeAt(index));
                              },
                            ),
                          );
                        }),
                        TextFormField(
                          controller: _specializationController,
                          decoration: InputDecoration(
                            labelText: 'Add Specialization',
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () {
                                if (_specializationController.text.trim().isNotEmpty) {
                                  _addSpecialization(_specializationController.text.trim());
                                }
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onFieldSubmitted: (value) {
                            if (value.trim().isNotEmpty) {
                              _addSpecialization(value.trim());
                            }
                          },
                        ),
                      ],
                    )
                        : Column(
                      children: _specializations.map((spec) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.star_border,
                                size: 10,
                                color: Color(0xFFBDA25B),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  spec,
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    if (!_isEditing)
                      Center(
                        child: ElevatedButton(
                          onPressed: _logout,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(200, 48),
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                            shadowColor: Colors.black.withOpacity(0.2),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.logout, size: 20),
                              SizedBox(width: 8),
                              Text('Log Out'),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: widget.bottomNavBar ?? const InstructorBottomNavBar(currentIndex: 2),
    );
  }
}
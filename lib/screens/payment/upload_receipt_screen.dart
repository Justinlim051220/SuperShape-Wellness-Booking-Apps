import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class UploadReceiptScreen extends StatefulWidget {
  final double amount;
  final String packageId;
  final String? title;
  final Map<String, dynamic>? additionalData;

  const UploadReceiptScreen({
    super.key,
    required this.amount,
    required this.packageId,
    this.title,
    this.additionalData,
  });

  @override
  _UploadReceiptScreenState createState() => _UploadReceiptScreenState();
}

class _UploadReceiptScreenState extends State<UploadReceiptScreen>
    with SingleTickerProviderStateMixin {
  File? _selectedFile;
  String? _fileName;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  late AnimationController _animationController;
  late Animation<Color?> _colorAnimation;
  final String _userId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Uuid _uuid = Uuid();
  String? _transactionId;

  @override
  void initState() {
    super.initState();
    print('UploadReceiptScreen init: amount=${widget.amount}, packageId=${widget.packageId}, title=${widget.title}, additionalData=${widget.additionalData}');
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _colorAnimation = ColorTween(
      begin: Colors.red,
      end: Colors.red.withOpacity(0.2),
    ).animate(_animationController);
    _setupPaymentListener();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    Permission permission;
    if (source == ImageSource.camera) {
      permission = Permission.camera;
    } else {
      permission = Permission.photos;
    }

    var status = await permission.request();
    if (status.isGranted) {
      try {
        final XFile? pickedFile = await _picker.pickImage(source: source);
        if (pickedFile != null) {
          setState(() {
            _selectedFile = File(pickedFile.path);
            _fileName = pickedFile.name;
            _transactionId = _uuid.v4();
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error picking image: $e')),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission denied')),
        );
      }
    }
  }

  Future<void> _pickDocument() async {
    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.request().isDenied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Storage permission denied')),
          );
        }
        return;
      }
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
          _fileName = result.files.single.name;
          _transactionId = _uuid.v4();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking document: $e')),
        );
      }
    }
  }

  Future<void> _uploadFile() async {
    if (_selectedFile == null || _transactionId == null) {
      print('UploadReceiptScreen: No file or transactionId selected');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an image or document first')),
        );
      }
      return;
    }

    // Safely extract type, bookingId, and classId, handling nested additionalData
    String? type;
    String? bookingId;
    String? classId;
    if (widget.additionalData != null) {
      type = (widget.additionalData!['type'] as String?)?.toLowerCase();
      bookingId = widget.additionalData!['bookingId'] as String?;
      classId = widget.additionalData!['classId'] as String?;
      if ((type == null || bookingId == null || classId == null) && widget.additionalData!.containsKey('additionalData')) {
        print('UploadReceiptScreen: Warning - Nested additionalData detected');
        final nestedData = widget.additionalData!['additionalData'] as Map<String, dynamic>?;
        if (nestedData != null) {
          type ??= (nestedData['type'] as String?)?.toLowerCase();
          bookingId ??= nestedData['bookingId'] as String?;
          classId ??= nestedData['classId'] as String?;
          if ((type == null || bookingId == null || classId == null) && nestedData.containsKey('additionalData')) {
            final innerData = nestedData['additionalData'] as Map<String, dynamic>?;
            type ??= (innerData?['type'] as String?)?.toLowerCase();
            bookingId ??= innerData?['bookingId'] as String?;
            classId ??= innerData?['classId'] as String?;
          }
        }
      }
    }
    final isEvent = type == 'event';
    print('UploadReceiptScreen _uploadFile: isEvent=$isEvent, bookingId=$bookingId, classId=$classId, packageId=${widget.packageId}');

    // Validate inputs
    if (isEvent) {
      if (bookingId == null || bookingId.isEmpty) {
        print('UploadReceiptScreen: Invalid event booking data - bookingId=$bookingId');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid event booking data: Missing booking ID')),
          );
        }
        return;
      }
      final bookingDoc = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('bookings')
          .doc(bookingId)
          .get();
      if (!bookingDoc.exists) {
        print('UploadReceiptScreen: Booking $bookingId does not exist');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Booking does not exist')),
          );
        }
        return;
      }
    } else if (widget.packageId.isEmpty) {
      print('UploadReceiptScreen: Invalid package ID');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid package ID')),
        );
      }
      return;
    }

    // Check for existing pending payment
    final paymentQuery = _firestore
        .collection('Payment')
        .where('userid', isEqualTo: _userId)
        .where('Status', isEqualTo: 'Pending')
        .where('transactionId', isEqualTo: _transactionId);

    final existingPaymentsSnapshot = await paymentQuery.limit(1).get();
    if (existingPaymentsSnapshot.docs.isNotEmpty) {
      print('UploadReceiptScreen: Existing pending payment found for transactionId=$_transactionId');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This payment is already pending.')),
        );
      }
      return;
    }

    // Skip trial package check for events
    if (!isEvent && widget.packageId.isNotEmpty) {
      final packageDoc = await _firestore.collection('Credit_Packages').doc(widget.packageId).get();
      if (packageDoc.exists) {
        final packageData = packageDoc.data() as Map<String, dynamic>;
        final isTrial = packageData['type'] as String? ?? 'unknown';
        if (isTrial.toLowerCase() == 'trial') {
          final creditRemainsSnapshot = await _firestore
              .collection('users')
              .doc(_userId)
              .collection('Credit_Remains')
              .where('packageId', isEqualTo: widget.packageId)
              .limit(1)
              .get();
          if (creditRemainsSnapshot.docs.isNotEmpty) {
            print('UploadReceiptScreen: Trial package already purchased');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('You can only purchase this trial package once.')),
              );
            }
            return;
          }
        }
      } else {
        print('UploadReceiptScreen: Package ${widget.packageId} not found');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid package ID')),
          );
        }
        return;
      }
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('payment/${DateTime.now().millisecondsSinceEpoch}_${_fileName}');
      final metadata = SettableMetadata(
        cacheControl: 'public, max-age=3600',
        contentType: _fileName!.toLowerCase().endsWith('.pdf')
            ? 'application/pdf'
            : 'image/jpeg',
      );
      final uploadTask = storageRef.putFile(_selectedFile!, metadata);

      final snapshot = await uploadTask.whenComplete(() {});
      final downloadURL = await snapshot.ref.getDownloadURL();

      final paymentData = {
        'Status': 'Pending',
        'UploadedReceiptURL': downloadURL,
        'amount': widget.amount,
        'approveby': '',
        'createdAt': FieldValue.serverTimestamp(),
        'userid': _userId,
        'processed': false,
        'transactionId': _transactionId,
      };

      if (!isEvent && widget.packageId.isNotEmpty) {
        paymentData['PackageID'] = widget.packageId;
        print('UploadReceiptScreen: Adding Payment with PackageID=${widget.packageId}');
      }

      final paymentRef = await _firestore.collection('Payment').add(paymentData);
      print('UploadReceiptScreen: Payment document created with ID=${paymentRef.id}, data=$paymentData');

      if (isEvent && bookingId != null) {
        await _firestore
            .collection('users')
            .doc(_userId)
            .collection('bookings')
            .doc(bookingId)
            .update({
          'paymentId': paymentRef.id,
        });
        print('UploadReceiptScreen: Updated booking $bookingId with paymentId=${paymentRef.id}');
      }

      if (mounted) {
        Navigator.pushNamed(context, '/payment_confirmation');
      }
    } catch (e) {
      print('UploadReceiptScreen: Error uploading receipt: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading receipt: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _selectedFile = null;
          _fileName = null;
          _transactionId = null;
        });
      }
    }
  }

  void _setupPaymentListener() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    _firestore
        .collection('Payment')
        .where('userid', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docChanges) {
        if (doc.type == DocumentChangeType.modified) {
          final newData = doc.doc.data() as Map<String, dynamic>;
          final currentStatus = newData['Status'] as String? ?? 'Unknown';
          final isProcessed = newData['processed'] as bool? ?? false;
          final paymentId = doc.doc.id;

          if (currentStatus == 'Approved' && !isProcessed) {
            print('UploadReceiptScreen: Processing approved payment ID=$paymentId, data=$newData');
            _processApprovedPayment(paymentId, newData);
          }
        }
      }
    }, onError: (error) {
      print('UploadReceiptScreen: Error listening to payments: $error');
    });
  }

  Future<void> _processApprovedPayment(String paymentId, Map<String, dynamic> paymentData) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        print('UploadReceiptScreen: No user ID for processing payment $paymentId');
        return;
      }

      await _firestore.runTransaction((transaction) async {
        final paymentDoc = _firestore.collection('Payment').doc(paymentId);
        final paymentSnapshot = await transaction.get(paymentDoc);
        if (paymentSnapshot.exists) {
          final currentProcessed = paymentSnapshot.data()?['processed'] ?? false;
          if (!currentProcessed) {
            transaction.update(paymentDoc, {'processed': true});
            print('UploadReceiptScreen: Marked payment $paymentId as processed');
          }
        }
      });

      if (paymentData.containsKey('PackageID') && paymentData['PackageID'].isNotEmpty) {
        final packageId = paymentData['PackageID'] as String;
        final userDocRef = _firestore.collection('users').doc(userId);
        final creditRemainsCollection = userDocRef.collection('Credit_Remains');

        final existingSnapshot = await creditRemainsCollection
            .where('paymentId', isEqualTo: paymentId)
            .limit(1)
            .get();

        if (existingSnapshot.docs.isNotEmpty) {
          print('UploadReceiptScreen: Credit already exists for payment $paymentId');
          return;
        }

        final packageDoc = await _firestore.collection('Credit_Packages').doc(packageId).get();
        if (!packageDoc.exists) {
          print('UploadReceiptScreen: Package $packageId not found');
          return;
        }

        final packageData = packageDoc.data() as Map<String, dynamic>;
        final classType = packageData['class_type'] as String? ?? 'Unknown Class';
        final credits = packageData['credits'] as num? ?? 0;
        final title = packageData['title'] as String? ?? 'Unknown Title';
        final validity = packageData['validity'] as num? ?? 0;
        final type = packageData['type'] as String? ?? 'Unknown Type';

        final approvedDate = paymentData['createdAt'] as Timestamp? ?? Timestamp.now();
        final validUntil = approvedDate.toDate().add(Duration(days: validity.toInt()));

        await creditRemainsCollection.add({
          'classType': classType,
          'credits_total': credits,
          'is_active': true,
          'credits_remaining': credits,
          'title': title,
          'validUntil': validUntil,
          'packageId': packageId,
          'paymentId': paymentId,
          'type': type,
          'createdAt': FieldValue.serverTimestamp(),
        });
        print('UploadReceiptScreen: Added Credit_Remains for package $packageId');
      } else {
        final bookingSnapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('bookings')
            .where('paymentId', isEqualTo: paymentId)
            .where('type', isEqualTo: 'event')
            .limit(1)
            .get();
        if (bookingSnapshot.docs.isNotEmpty) {
          final bookingId = bookingSnapshot.docs.first.id;
          final bookingData = bookingSnapshot.docs.first.data();
          if (bookingData['Status'] == 'Pending') {
            await _firestore
                .collection('users')
                .doc(userId)
                .collection('bookings')
                .doc(bookingId)
                .update({'Status': 'Booked'});
            print('UploadReceiptScreen: Updated booking $bookingId to Booked');
          } else {
            print('UploadReceiptScreen: Booking $bookingId not Pending, current status: ${bookingData['Status']}');
          }
        } else {
          print('UploadReceiptScreen: No event booking found with paymentId=$paymentId');
        }
      }
    } catch (e) {
      print('UploadReceiptScreen: Error processing approved payment $paymentId: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    const themeColor = Color(0xFFBDA25B);

    return WillPopScope(
      onWillPop: () async {
        setState(() {
          _selectedFile = null;
          _fileName = null;
          _transactionId = null;
        });
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Upload Receipt',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          backgroundColor: themeColor,
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedBuilder(
                animation: _colorAnimation,
                builder: (context, child) => Text(
                  'Upload Your Payment Receipt',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _colorAnimation.value,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Center(
                  child: _selectedFile == null
                      ? const Text('No image or document selected.')
                      : _fileName != null && _fileName!.toLowerCase().endsWith('.pdf')
                      ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.description,
                        size: 80,
                        color: themeColor,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _fileName!,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )
                      : Image.file(
                    _selectedFile!,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Text('Error loading image.');
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: themeColor, width: 1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library, color: themeColor),
                        label: const Text(
                          'Gallery',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: themeColor,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          side: const BorderSide(color: themeColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickImage(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt, color: themeColor),
                        label: const Text(
                          'Camera',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: themeColor,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          side: const BorderSide(color: themeColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickDocument,
                        icon: const Icon(Icons.description, color: themeColor),
                        label: const Text(
                          'Document',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: themeColor,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          side: const BorderSide(color: themeColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _uploadFile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: _isUploading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                    'Upload Receipt',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
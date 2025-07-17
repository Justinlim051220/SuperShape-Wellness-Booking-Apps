import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'Instructor_part/Instructor_screen/instructor_course_details.dart';
import 'Instructor_part/Instructor_screen/instructor_notification_screen.dart';
import 'Instructor_part/Instructor_screen/performance_screen.dart';
import 'Instructor_part/Instructor_screen/profile_screen.dart';
import 'Instructor_part/Instuctor_model/class_model.dart';
import 'Instructor_part/timetable_screen.dart';
import 'auth/forgot_screen.dart';
import 'firebase_options.dart';

// Theme & Widgets
import '../../utils/theme.dart';
import 'widgets/no_glow_scroll_behavior.dart';

// Core Screens
import 'screens/splash_screen.dart';
import 'auth/login_screen.dart';
import 'auth/declaration_screen.dart';
import 'auth/profile_setup_screen.dart';

// Student Screens
import 'screens/timetable_screen.dart';
import 'screens/event_cancellation_screen.dart';
import 'screens/payment/payment_options_screen.dart';
import 'screens/payment/payment_method_screen.dart';
import 'screens/payment/upload_receipt_screen.dart';
import 'screens/payment/payment_confirmation_screen.dart';
import 'screens/course/course_details_screen.dart';
import 'screens/course/class_confirmation_screen.dart';
import 'screens/course/cancellation_confirmation_screen.dart';
import 'screens/course/waiting_list_confirmation_screen.dart';
import 'screens/course/course_cancellation_screen.dart';
import 'screens/course/waiting_list_screen.dart';
import 'screens/purchase/credit_screen.dart';
import 'screens/purchase/payment_history_screen.dart';
import 'screens/profile/my_booking_screen.dart';
import 'screens/profile/my_profile_screen.dart';
import 'screens/profile/account_settings_screen.dart';
import 'screens/profile/change_password_screen.dart';
import 'screens/profile/terms_conditions_screen.dart';
import 'screens/profile/notifications_screen.dart';

import 'Instructor_part/Instructor_widgets/bottom_nav_bar.dart';
import 'screens/instructor/instructor_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirebaseFirestore.instance.enablePersistence();
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.light,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  runApp(const SuperShapeWellnessApp());
}

class SuperShapeWellnessApp extends StatelessWidget {
  const SuperShapeWellnessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        return ScrollConfiguration(
          behavior: const NoGlowScrollBehavior(),
          child: MaterialApp(
            title: 'SuperShape Wellness',
            debugShowCheckedModeBanner: false,
            theme: myTheme,
            initialRoute: '/splash',
            routes: {
              '/splash': (context) => const SplashScreen(),
              '/login': (context) => const LoginScreen(),
              '/register': (context) => const RegistrationScreen(),
              '/declarartion_screen': (context) => const DeclarationScreen(),
              '/forgot_password': (_) => const ForgotPasswordScreen(),
              '/profile_setup': (context) => const MyProfileScreen(),
              '/timetable': (context) => const TimetableScreen(),
              '/instructor_notifications':(context) => const InstructorNotificationsScreen(),
              '/payment_options': (context) {
                final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
                print('Main: Navigating to /payment_options with args=$args');
                final navigator = Navigator.of(context);
                final routeNames = <String>[];
                navigator.popUntil((route) {
                  routeNames.add(route.settings.name ?? 'unknown');
                  return true;
                });
                print('Main: Navigation stack: ${routeNames.reversed.join(' -> ')}');
                final additionalData = args?['additionalData'] as Map<String, dynamic>? ?? args ?? {};
                final packageId = args?['packageId'] ?? additionalData['id'] ?? '';
                final amount = (args?['amount'] as num?)?.toDouble() ?? (additionalData['price'] as num?)?.toDouble() ?? 0.0;
                if (packageId.isEmpty) {
                  print('Main: Error - packageId is empty, args=$args');
                }
                return PaymentOptionsScreen(
                  amount: amount,
                  packageId: packageId,
                  title: args?['title'] ?? additionalData['title'] ?? 'Unknown',
                  additionalData: args ?? additionalData,
                );
              },
              '/payment_method': (context) {
                final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
                print('Main: Navigating to /payment_method with args=$args');
                final additionalData = args?['additionalData'] as Map<String, dynamic>? ?? args ?? {};
                final packageId = args?['packageId'] ?? additionalData['id'] ?? '';
                final amount = (args?['amount'] as num?)?.toDouble() ?? (additionalData['price'] as num?)?.toDouble() ?? 0.0;
                return PaymentMethodScreen(
                  method: args?['method'] ?? 'Unknown',
                  amount: amount,
                  packageId: packageId,
                  title: args?['title'] ?? additionalData['title'] ?? 'Unknown',
                  additionalData: args ?? additionalData,
                );
              },
              '/upload_receipt': (context) {
                final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
                print('Main: Navigating to /upload_receipt with args=$args');
                final additionalData = args?['additionalData'] as Map<String, dynamic>? ?? args ?? {};
                final packageId = args?['packageId'] ?? additionalData['id'] ?? '';
                final amount = (args?['amount'] as num?)?.toDouble() ?? (additionalData['price'] as num?)?.toDouble() ?? 0.0;
                return UploadReceiptScreen(
                  amount: amount,
                  packageId: packageId,
                  title: args?['title'] ?? additionalData['title'] ?? 'Unknown',
                  additionalData: args ?? additionalData,
                );
              },
              '/payment_confirmation': (context) => const PaymentConfirmationScreen(),
              '/course_details': (context) {
                final args = ModalRoute.of(context)?.settings.arguments;
                print('Main: Navigating to /course_details with args=$args (type: ${args.runtimeType})');
                String? classId;
                if (args is String) {
                  classId = args;
                } else if (args is Map) {
                  classId = args['id'] as String?;
                } else if (args is ClassModel) {
                  classId = args.id;
                } else if (args == null) {
                  print('Main: Warning - No arguments provided for /course_details');
                } else {
                  print('Main: Error - Unsupported argument type ${args.runtimeType} for /course_details');
                }
                if (classId == null || classId.isEmpty) {
                  print('Main: Using default classId due to null or empty value');
                  return const CourseDetailsScreen(
                    bookingData: {'id': '', 'title': 'Unknown Title'},
                    fromBooking: false,
                  );
                }
                return CourseDetailsScreen(
                  bookingData: {'id': classId, 'title': 'Unknown Title'},
                  fromBooking: false,
                );
              },
              '/class_confirmation': (context) => const ClassConfirmationScreen(),
              '/cancellation_confirmation': (context) => const CancellationConfirmationScreen(),
              '/waiting_list_confirmation': (context) => const WaitingListConfirmationScreen(),
              '/course_cancellation': (context) => const CourseCancellationScreen(),
              '/waiting_list': (context) => const WaitingListScreen(),
              '/event_cancellation': (context) => const EventCancellationScreen(),
              '/my_booking': (context) => const MyBookingScreen(),
              '/my_profile': (context) => const MyProfileScreen(),
              '/account_settings': (context) => const AccountSettingsScreen(),
              '/change_password': (context) => const ChangePasswordScreen(),
              '/terms_conditions': (context) => const TermsConditionScreen(),
              '/notifications': (context) => const NotificationsScreen(),
              '/payment_history': (context) => const CreditScreen(),
              '/credit_history': (context) => const PaymentHistoryScreen(),
              '/instructors': (context) => InstructorPage(),
              '/instructor_profile_Page': (context) => ProfileScreen(),
              '/Performance': (context) => PerformanceScreen(),
              '/Instructor_Timetable': (context) => InstructorTimetableScreen(
                insbottomNavBar: InstructorBottomNavBar(currentIndex: 0),
              ),
              // Redirect /event_details to /course_details
              '/event_details': (context) {
                final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
                print('Main: Redirecting /event_details to /course_details with args=$args');
                return CourseDetailsScreen(
                  bookingData: args ?? {'id': '', 'title': 'Unknown Title'},
                  fromBooking: false,
                );
              },
            },
            onGenerateRoute: (settings) {
              if (settings.name == '/instructor_course_details') {
                String? classId;
                if (settings.arguments is String) {
                  classId = settings.arguments as String?;
                } else if (settings.arguments is Map) {
                  final args = settings.arguments as Map;
                  classId = args['id'] as String?;
                } else if (settings.arguments is ClassModel) {
                  classId = (settings.arguments as ClassModel).id;
                }
                if (classId != null && classId.isNotEmpty) {
                  print('Navigating to /instructor_course_details with classId: $classId');
                  return MaterialPageRoute(
                    builder: (context) => InstructorCourseDetailsScreen(classId: classId!),
                  );
                } else {
                  print('Error: Invalid or missing classId in /instructor_course_details, arguments: ${settings.arguments}');
                  return MaterialPageRoute(
                    builder: (context) => const Scaffold(
                      body: Center(child: Text('Error: classId is required')),
                    ),
                  );
                }
              }
              if (settings.name == '/course_details' && settings.arguments == null) {
                return MaterialPageRoute(
                  builder: (_) => const CourseDetailsScreen(
                    bookingData: {'id': '', 'title': 'Unknown Title'},
                    fromBooking: false,
                  ),
                );
              }
              if (settings.name == '/payment_options' && settings.arguments != null) {
                final args = settings.arguments as Map<String, dynamic>;
                print('Main: onGenerateRoute /payment_options with args=$args');
                final additionalData = args['additionalData'] as Map<String, dynamic>? ?? args;
                final packageId = args['packageId'] ?? additionalData['id'] ?? '';
                final amount = (args['amount'] as num?)?.toDouble() ?? (additionalData['price'] as num?)?.toDouble() ?? 0.0;
                return MaterialPageRoute(
                  builder: (_) => PaymentOptionsScreen(
                    amount: amount,
                    packageId: packageId,
                    title: args['title'] ?? additionalData['title'] ?? 'Unknown',
                    additionalData: args,
                  ),
                );
              }
              return null;
            },
          ),
        );
      },
    );
  }
}
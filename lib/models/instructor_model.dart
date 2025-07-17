import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class UpcomingClass {
  final String title;
  final String date;
  final String time;

  UpcomingClass({
    required this.title,
    required this.date,
    required this.time,
  });

  factory UpcomingClass.fromJson(Map<String, dynamic> json) {
    final timestamp = json['start_date_time'] as Timestamp?;
    final dateTime = timestamp?.toDate() ?? DateTime.now();
    final adjustedDateTime = dateTime.toUtc().add(const Duration(hours: 8)); // UTC+08:00
    return UpcomingClass(
      title: json['title'] as String? ?? 'Untitled Class',
      date: DateFormat('yyyy-MM-dd').format(adjustedDateTime),
      time: DateFormat('h:mm a').format(adjustedDateTime),
    );
  }
}

class Instructor {
  final String? userId;
  final String? name;
  final List<String>? specializations;
  final String? bio;
  final String? photo;
  final String? email;
  final String? coverPhoto;
  final int? experienceYears;
  final List<String>? certifications;
  final String? phoneNumber;

  Instructor({
    this.userId,
    this.name,
    this.specializations,
    this.bio,
    this.photo,
    this.email,
    this.coverPhoto,
    this.experienceYears,
    this.certifications,
    this.phoneNumber,
  });

  factory Instructor.fromJson(Map<String, dynamic> json, {String? userId}) {
    return Instructor(
      userId: userId ?? json['userId'] as String?,
      name: json['full_name'] as String?,
      specializations: (json['classType'] as List<dynamic>?)?.cast<String>(),
      bio: json['bio'] as String?,
      photo: json['photo_url'] as String?,
      email: json['email'] as String?,
      coverPhoto: json['coverPhoto_url'] as String?, // Updated to coverPhoto_url
      experienceYears: json['experienceYears'] as int?,
      certifications: (json['certifications'] as List<dynamic>?)?.cast<String>(),
      phoneNumber: json['phone'] as String?,
    );
  }
}
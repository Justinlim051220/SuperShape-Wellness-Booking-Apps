import 'package:cloud_firestore/cloud_firestore.dart';

class Student {
  final String id;
  final String name;

  Student({required this.id, required this.name});

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Student &&
              runtimeType == other.runtimeType &&
              id == other.id &&
              name == other.name;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;
}

class ClassModel {
  final String id;
  final String title;
  final String date;
  final String time;
  final String duration;
  final String instructor;
  final String status;
  final String image;
  final String description;
  final String type;
  final int credit;
  final double price;
  final double booked;
  final double slots;
  final String? remarks; // Nullable to handle absence in Firestore

  ClassModel({
    required this.id,
    required this.title,
    required this.date,
    required this.time,
    required this.duration,
    required this.instructor,
    required this.status,
    required this.image,
    required this.description,
    required this.type,
    required this.credit,
    required this.price,
    required this.booked,
    required this.slots,
    this.remarks, String? instructorImage, // Not required since it’s nullable
  });

  factory ClassModel.fromJson(Map<String, dynamic> json) {
    return ClassModel(
      id: json['id'] as String,
      title: json['title'] as String,
      date: json['date'] as String,
      time: json['time'] as String,
      duration: json['duration'] as String,
      instructor: json['instructor'] as String,
      status: json['status'] as String,
      image: json['image'] as String,
      description: json['description'] as String,
      type: json['type'] as String,
      credit: json['credit'] as int,
      price: (json['price'] as num).toDouble(),
      booked: (json['booked'] as num).toDouble(),
      slots: (json['slots'] as num).toDouble(),
      remarks: json['remarks'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'date': date,
    'time': time,
    'duration': duration,
    'instructor': instructor,
    'status': status,
    'image': image,
    'description': description,
    'type': type,
    'credit': credit,
    'price': price,
    'booked': booked,
    'slots': slots,
    'remarks': remarks,
  };
}
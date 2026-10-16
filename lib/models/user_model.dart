import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an authenticated application user (Student or Teacher) in Cloud Firestore.
class User {
  final String id; // Firebase Auth UID
  final String name; // maps to fullName in Firestore
  final String email;
  final String phone;
  final String role; // 'Student' or 'Teacher'
  final DateTime? createdAt;

  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.createdAt,
  });

  bool get isTeacher => role == 'Teacher';
  bool get isStudent => role == 'Student';

  Map<String, dynamic> toMap() {
    return {
      'fullName': name,
      'email': email,
      'phone': phone,
      'role': role,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory User.fromMap(Map<String, dynamic> map, String uid) {
    DateTime? parsedCreatedAt;
    final rawDate = map['createdAt'];
    if (rawDate is Timestamp) {
      parsedCreatedAt = rawDate.toDate();
    } else if (rawDate is String) {
      parsedCreatedAt = DateTime.tryParse(rawDate);
    }

    return User(
      id: uid,
      name: (map['fullName'] ?? map['name'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      phone: (map['phone'] ?? '') as String,
      role: (map['role'] ?? 'Student') as String,
      createdAt: parsedCreatedAt,
    );
  }

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? role,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

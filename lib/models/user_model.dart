/// Represents an authenticated application user (Student or Teacher).
class User {
  final int? id;
  final String name;
  final String email;
  final String phone;
  final String role; // 'Student' or 'Teacher'
  final String passwordHash;
  final String salt;
  final String createdAt;

  const User({
    this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.passwordHash,
    required this.salt,
    required this.createdAt,
  });

  bool get isTeacher => role == 'Teacher';
  bool get isStudent => role == 'Student';

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'password_hash': passwordHash,
      'salt': salt,
      'created_at': createdAt,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as int?,
      name: map['name'] as String,
      email: map['email'] as String,
      phone: map['phone'] as String,
      role: map['role'] as String,
      passwordHash: map['password_hash'] as String,
      salt: map['salt'] as String,
      createdAt: map['created_at'] as String,
    );
  }

  User copyWith({
    int? id,
    String? name,
    String? email,
    String? phone,
    String? role,
    String? passwordHash,
    String? salt,
    String? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      passwordHash: passwordHash ?? this.passwordHash,
      salt: salt ?? this.salt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}


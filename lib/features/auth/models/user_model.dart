import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String? university;
  final String? photoUrl;
  final String? photoBase64;
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.university,
    this.photoUrl,
    this.photoBase64,
    required this.createdAt,
  });

  factory UserModel.fromMap(String uid, Map<String, dynamic> map) {
    return UserModel(
      uid: uid,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      university: map['university'],
      photoUrl: map['photoUrl'],
      photoBase64: map['photoBase64'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'university': university,
        'photoUrl': photoUrl,
        'photoBase64': photoBase64,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  static const Object _unset = Object();

  UserModel copyWith({
    String? name,
    String? email,
    Object? university = _unset,
    Object? photoUrl = _unset,
    Object? photoBase64 = _unset,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      university:
          university == _unset ? this.university : university as String?,
      photoUrl: photoUrl == _unset ? this.photoUrl : photoUrl as String?,
      photoBase64: photoBase64 == _unset
          ? this.photoBase64
          : photoBase64 as String?,
      createdAt: createdAt,
    );
  }

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

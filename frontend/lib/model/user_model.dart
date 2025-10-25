class User {
  final int id;
  final String name;
  final DateTime createdAt;

  User({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  // BEFORE (causing error):
  // factory User.fromJson(Map<String, dynamic> json) {
  //   return User(
  //     id: json['id'],
  //     name: json['name'],
  //     createdAt: json['createdAt'], // ← Might be string now
  //   );
  // }

  // AFTER (safe version):
  factory User.fromJson(dynamic json) {
    if (json is String) {
      // Handle case where response is just a string/timestamp
      return User(
        id: 0,
        name: 'Unknown',
        createdAt: DateTime.parse(json),
      );
    } else if (json is Map<String, dynamic>) {
      // Handle JSON object
      return User(
        id: (json['id'] is int) ? json['id'] : int.parse(json['id'].toString()),
        name: json['name'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
    } else {
      throw Exception('Invalid JSON type: ${json.runtimeType}');
    }
  }

  // Convert User object to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'User(id: $id, name: $name, createdAt: $createdAt)';
  }
}
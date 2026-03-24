enum UserRole { admin, operario }

class User {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final DateTime? confirmedAt;

  bool get isPending => confirmedAt == null;

  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.confirmedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'],
        name: json['name'],
        email: json['email'],
        role: json['role'] == 'admin' ? UserRole.admin : UserRole.operario,
        confirmedAt: json['confirmed_at'] != null
            ? DateTime.parse(json['confirmed_at'])
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role.name,
      };

  User copyWith({String? name}) => User(
        id: id,
        name: name ?? this.name,
        email: email,
        role: role,
        confirmedAt: confirmedAt,
      );
}

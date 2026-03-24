class DeliveryRoute {
  final String id;
  final String name;
  final String status;
  final List<String> userIds;

  bool get isActive => status == 'active';

  const DeliveryRoute({
    required this.id,
    required this.name,
    required this.status,
    required this.userIds,
  });

  factory DeliveryRoute.fromJson(Map<String, dynamic> json) => DeliveryRoute(
        id: json['id'],
        name: json['name'],
        status: json['status'] ?? 'active',
        userIds: (json['route_users'] as List? ?? [])
            .map((e) => e['user_id'] as String)
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'status': status,
      };

  DeliveryRoute copyWith({String? name, String? status, List<String>? userIds}) =>
      DeliveryRoute(
        id: id,
        name: name ?? this.name,
        status: status ?? this.status,
        userIds: userIds ?? this.userIds,
      );
}

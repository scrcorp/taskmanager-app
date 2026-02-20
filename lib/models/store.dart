class Store {
  final String id;
  final String name;
  final String? address;
  final bool isActive;

  const Store({
    required this.id,
    required this.name,
    this.address,
    this.isActive = true,
  });

  factory Store.fromJson(Map<String, dynamic> json) {
    return Store(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      isActive: json['is_active'] ?? true,
    );
  }
}

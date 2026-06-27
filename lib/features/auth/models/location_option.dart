class LocationOption {
  const LocationOption({required this.id, required this.name, this.code});

  final String id;
  final String name;
  final String? code;

  factory LocationOption.fromJson(Map<String, dynamic> json) {
    return LocationOption(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String?,
    );
  }
}

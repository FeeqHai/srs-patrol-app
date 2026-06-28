class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.relatedId,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final bool isRead;
  final String createdAt;
  final String? relatedId;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      relatedId: json['related_id']?.toString(),
      isRead: json['is_read'] == 1 || json['is_read'] == true,
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

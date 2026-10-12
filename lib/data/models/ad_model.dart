// ============================================================
// AD & PUBLIC BANNER MODEL (نموذج الإعلانات والبيانات العامة)
// ============================================================
class Ad {
  final String id;
  final String title;
  final String? description;
  final String? imageUrl;
  final String? targetUrl;
  final String placement;
  final bool isActive;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? createdBy;
  final DateTime createdAt;

  const Ad({
    required this.id,
    required this.title,
    this.description,
    this.imageUrl,
    this.targetUrl,
    this.placement = 'home_banner',
    this.isActive = true,
    this.startDate,
    this.endDate,
    this.createdBy,
    required this.createdAt,
  });

  /// التحقق الفعلي من أن الإعلان نشط وفي النطاق الزمني الصالح
  bool get isValidNow {
    if (!isActive) return false;
    final now = DateTime.now();
    if (startDate != null && now.isBefore(startDate!)) return false;
    if (endDate != null && now.isAfter(endDate!)) return false;
    return true;
  }

  bool get hasImage => imageUrl != null && imageUrl!.trim().isNotEmpty;

  factory Ad.fromJson(Map<String, dynamic> json) {
    return Ad(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'إعلان عام',
      description: json['description']?.toString(),
      imageUrl: json['image_url']?.toString(),
      targetUrl: json['target_url']?.toString(),
      placement: json['placement']?.toString() ?? 'home_banner',
      isActive: json['is_active'] == true,
      startDate: json['start_date'] != null ? DateTime.tryParse(json['start_date'].toString()) : null,
      endDate: json['end_date'] != null ? DateTime.tryParse(json['end_date'].toString()) : null,
      createdBy: json['created_by']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'].toString()) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'image_url': imageUrl,
      'target_url': targetUrl,
      'placement': placement,
      'is_active': isActive,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Ad copyWith({
    String? id,
    String? title,
    String? description,
    String? imageUrl,
    String? targetUrl,
    String? placement,
    bool? isActive,
    DateTime? startDate,
    DateTime? endDate,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return Ad(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      targetUrl: targetUrl ?? this.targetUrl,
      placement: placement ?? this.placement,
      isActive: isActive ?? this.isActive,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

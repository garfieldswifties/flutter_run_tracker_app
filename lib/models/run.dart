class Run {
  const Run({
    this.id,
    this.createdAt,
    required this.runWhere,
    required this.runPerson,
    required this.runDistance,
    this.runImageUrl,
  });

  final String? id;
  final DateTime? createdAt;
  final String runWhere;
  final String runPerson;
  final int runDistance;
  final String? runImageUrl;

  String? get imageUrl {
    final value = runImageUrl?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  factory Run.fromJson(Map<String, dynamic> json) {
    return Run(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      runWhere: json['runWhere'] as String,
      runPerson: json['runPerson'] as String,
      runDistance: json['runDistance'] as int,
      runImageUrl: json['runImageUrl'] as String?,
    );
  }

  // ฐานข้อมูลสร้าง id และ created_at เอง
  Map<String, dynamic> toJson() => {
    'runWhere': runWhere,
    'runPerson': runPerson,
    'runDistance': runDistance,
    'runImageUrl': runImageUrl,
  };
}

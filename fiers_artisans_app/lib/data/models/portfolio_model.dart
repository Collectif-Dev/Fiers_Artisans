class PortfolioModel {
  final String id;
  final String artisanId;
  final String title;
  final String? description;
  final List<String> imageUrls;
  final double? price;
  final DateTime? createdAt;

  PortfolioModel({
    required this.id,
    required this.artisanId,
    required this.title,
    this.description,
    this.imageUrls = const [],
    this.price,
    this.createdAt,
  });

  factory PortfolioModel.fromJson(Map<String, dynamic> json) {
    return PortfolioModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      artisanId: json['artisanProfileId']?.toString() ?? json['artisanId']?.toString() ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      imageUrls: (json['imageUrls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      price: (json['priceFcfa'] as num?)?.toDouble() ?? (json['price'] as num?)?.toDouble(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : json['created_at'] != null
              ? DateTime.tryParse(json['created_at'])
              : null,
    );
  }
}

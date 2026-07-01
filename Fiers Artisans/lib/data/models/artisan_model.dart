class ArtisanModel {
  final String id;
  final String userId;
  final String firstName;
  final String lastName;
  final String phone;
  final String? email;
  final String profession;
  final String? businessName;
  final String? description;
  final String? address;
  final String? whatsappNumber;
  final int experienceYears;
  final String city;
  final String commune;
  final double? latitude;
  final double? longitude;
  final double averageRating;
  final int totalReviews;
  final String? profilePhotoUrl;
  final bool isVerified;
  final bool isCertified;
  final bool isAvailable;
  final bool hasActiveSubscription;
  final String? categoryId;
  final String? categoryName;
  final String? subcategoryId;
  final String? subcategoryName;
  final double? distance; // Calculated by backend search
  final DateTime? locationUpdatedAt;
  final DateTime? createdAt;

  ArtisanModel({
    required this.id,
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.phone,
    this.email,
    required this.profession,
    this.businessName,
    this.description,
    this.address,
    this.whatsappNumber,
    this.experienceYears = 0,
    required this.city,
    required this.commune,
    this.latitude,
    this.longitude,
    this.averageRating = 0.0,
    this.totalReviews = 0,
    this.profilePhotoUrl,
    this.isVerified = false,
    this.isCertified = false,
    this.isAvailable = true,
    this.hasActiveSubscription = false,
    this.categoryId,
    this.categoryName,
    this.subcategoryId,
    this.subcategoryName,
    this.distance,
    this.locationUpdatedAt,
    this.createdAt,
  });

  factory ArtisanModel.fromJson(Map<String, dynamic> json) {
    // Handle nested profile object from backend
    final profile =
        json['artisan_profile'] ??
        json['artisanProfile'] ??
        json['profile'] ??
        json;
    final user = json['user'] ?? json;
    final resolvedSubcategoryName =
        _extractNamedValue(profile['subcategory']) ??
        profile['subcategory_name']?.toString() ??
        profile['subcategoryName']?.toString() ??
        _extractNamedValue(json['subcategory']) ??
        json['subcategory_name']?.toString() ??
        json['subcategoryName']?.toString();
    final resolvedCategoryName =
        _extractNamedValue(profile['category']) ??
        profile['category_name']?.toString() ??
        profile['categoryName']?.toString() ??
        _extractNamedValue(json['category']) ??
        json['category_name']?.toString() ??
        json['categoryName']?.toString();
    final resolvedBusinessName =
        profile['business_name']?.toString() ??
        profile['businessName']?.toString() ??
        json['business_name']?.toString() ??
        json['businessName']?.toString();

    return ArtisanModel(
      id: profile['id']?.toString() ?? json['id']?.toString() ?? '',
      userId:
          user['id']?.toString() ??
          json['user_id']?.toString() ??
          json['userId']?.toString() ??
          '',
      firstName:
          profile['first_name'] ??
          profile['firstName'] ??
          user['first_name'] ??
          '',
      lastName:
          profile['last_name'] ??
          profile['lastName'] ??
          user['last_name'] ??
          '',
      phone:
          user['phone_number'] ?? user['phone'] ?? json['phone_number'] ?? '',
      email: user['email'] ?? json['email'],
      profession:
          resolvedSubcategoryName ??
          profile['profession'] ??
          resolvedBusinessName ??
          resolvedCategoryName ??
          '',
      businessName: resolvedBusinessName,
      description:
          profile['bio'] ??
          profile['description'] ??
          json['bio'] ??
          json['description'],
      address: profile['address']?.toString() ?? json['address']?.toString(),
      whatsappNumber:
          profile['whatsapp_number']?.toString() ??
          profile['whatsappNumber']?.toString() ??
          user['whatsapp_number']?.toString() ??
          json['whatsapp_number']?.toString(),
      experienceYears:
          _toInt(
            profile['years_experience'] ??
                profile['experienceYears'] ??
                json['years_experience'],
          ) ??
          0,
      city: profile['city'] ?? json['city'] ?? '',
      commune: profile['commune'] ?? json['commune'] ?? '',
      latitude: _toDouble(profile['latitude'] ?? json['latitude']),
      longitude: _toDouble(profile['longitude'] ?? json['longitude']),
      averageRating:
          _toDouble(
            profile['rating_avg'] ??
                profile['averageRating'] ??
                json['rating_avg'],
          ) ??
          0.0,
      totalReviews:
          _toInt(
            profile['total_reviews'] ??
                profile['totalReviews'] ??
                json['total_reviews'],
          ) ??
          0,
      profilePhotoUrl:
          profile['profile_photo_url'] ??
          profile['profilePhotoUrl'] ??
          json['profilePhotoUrl'],
      isVerified:
          (user['verification_status'] ?? json['verification_status']) ==
              'VERIFIED' ||
          (user['verification_status'] ?? json['verification_status']) ==
              'CERTIFIED' ||
          (profile['isVerified'] ?? json['isVerified'] ?? false) == true,
      isCertified:
          (user['verification_status'] ?? json['verification_status']) ==
              'CERTIFIED' ||
          (profile['isCertified'] ?? json['isCertified'] ?? false) == true,
      isAvailable:
          profile['is_available'] ??
          profile['isAvailable'] ??
          json['is_available'] ??
          true,
      hasActiveSubscription:
          profile['is_subscription_active'] ??
          profile['hasActiveSubscription'] ??
          json['is_subscription_active'] ??
          false,
      categoryId:
          profile['category_id']?.toString() ??
          profile['categoryId']?.toString() ??
          json['category_id']?.toString(),
      categoryName: resolvedCategoryName,
      subcategoryId:
          profile['subcategory_id']?.toString() ??
          profile['subcategoryId']?.toString() ??
          json['subcategory_id']?.toString(),
      subcategoryName: resolvedSubcategoryName,
      distance: _toDouble(json['distance']),
      locationUpdatedAt: json['location_updated_at'] != null
          ? DateTime.tryParse(json['location_updated_at'].toString())
          : json['locationUpdatedAt'] != null
          ? DateTime.tryParse(json['locationUpdatedAt'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : null,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static String? _extractNamedValue(dynamic value) {
    if (value == null) return null;

    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    if (value is Map<String, dynamic>) {
      final raw = value['name'] ?? value['label'] ?? value['title'];
      if (raw == null) return null;
      final trimmed = raw.toString().trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    if (value is Map) {
      final raw = value['name'] ?? value['label'] ?? value['title'];
      if (raw == null) return null;
      final trimmed = raw.toString().trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    return null;
  }

  String get fullName => '$firstName $lastName';

  String get displayTrade {
    final trade = subcategoryName?.trim();
    if (trade != null && trade.isNotEmpty) return trade;
    return profession;
  }

  String? get displayCategory {
    final category = categoryName?.trim();
    if (category == null || category.isEmpty) return null;
    return category;
  }

  String? get displayBusinessName {
    final business = businessName?.trim();
    if (business == null || business.isEmpty) return null;
    return business;
  }

  ArtisanModel copyWith({
    String? id,
    String? userId,
    String? firstName,
    String? lastName,
    String? phone,
    String? email,
    String? profession,
    String? businessName,
    String? description,
    String? address,
    String? whatsappNumber,
    int? experienceYears,
    String? city,
    String? commune,
    double? latitude,
    double? longitude,
    double? averageRating,
    int? totalReviews,
    String? profilePhotoUrl,
    bool? isVerified,
    bool? isCertified,
    bool? isAvailable,
    bool? hasActiveSubscription,
    String? categoryId,
    String? categoryName,
    String? subcategoryId,
    String? subcategoryName,
    double? distance,
    DateTime? locationUpdatedAt,
    DateTime? createdAt,
  }) {
    return ArtisanModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      profession: profession ?? this.profession,
      businessName: businessName ?? this.businessName,
      description: description ?? this.description,
      address: address ?? this.address,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      experienceYears: experienceYears ?? this.experienceYears,
      city: city ?? this.city,
      commune: commune ?? this.commune,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      averageRating: averageRating ?? this.averageRating,
      totalReviews: totalReviews ?? this.totalReviews,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      isVerified: isVerified ?? this.isVerified,
      isCertified: isCertified ?? this.isCertified,
      isAvailable: isAvailable ?? this.isAvailable,
      hasActiveSubscription:
          hasActiveSubscription ?? this.hasActiveSubscription,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      subcategoryId: subcategoryId ?? this.subcategoryId,
      subcategoryName: subcategoryName ?? this.subcategoryName,
      distance: distance ?? this.distance,
      locationUpdatedAt: locationUpdatedAt ?? this.locationUpdatedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

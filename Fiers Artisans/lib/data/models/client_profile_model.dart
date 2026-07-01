class ClientProfileModel {
  final String id;
  final String userId;
  final String firstName;
  final String lastName;
  final String phone;
  final String? email;
  final String? city;
  final String? commune;
  final String? profilePhotoUrl;
  final double? latitude;
  final double? longitude;
  final DateTime? locationUpdatedAt;
  final DateTime? createdAt;
  final bool isPhoneVerified;
  final bool isActive;
  final String? verificationStatus;

  const ClientProfileModel({
    required this.id,
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.phone,
    this.email,
    this.city,
    this.commune,
    this.profilePhotoUrl,
    this.latitude,
    this.longitude,
    this.locationUpdatedAt,
    this.createdAt,
    this.isPhoneVerified = false,
    this.isActive = true,
    this.verificationStatus,
  });

  factory ClientProfileModel.fromJson(Map<String, dynamic> json) {
    final profile =
        json['client_profile'] ??
        json['clientProfile'] ??
        json['profile'] ??
        json;
    final user = json['user'] ?? profile['user'] ?? json;

    return ClientProfileModel(
      id: profile['id']?.toString() ?? json['id']?.toString() ?? '',
      userId:
          profile['user_id']?.toString() ??
          profile['userId']?.toString() ??
          user['id']?.toString() ??
          '',
      firstName:
          profile['first_name']?.toString() ??
          profile['firstName']?.toString() ??
          user['first_name']?.toString() ??
          '',
      lastName:
          profile['last_name']?.toString() ??
          profile['lastName']?.toString() ??
          user['last_name']?.toString() ??
          '',
      phone:
          user['phone_number']?.toString() ??
          user['phone']?.toString() ??
          json['phone_number']?.toString() ??
          '',
      email: user['email']?.toString() ?? json['email']?.toString(),
      city: profile['city']?.toString() ?? json['city']?.toString(),
      commune: profile['commune']?.toString() ?? json['commune']?.toString(),
      profilePhotoUrl:
          profile['profile_photo_url']?.toString() ??
          profile['profilePhotoUrl']?.toString() ??
          json['profile_photo_url']?.toString() ??
          json['profilePhotoUrl']?.toString(),
      latitude: _toDouble(profile['latitude'] ?? json['latitude']),
      longitude: _toDouble(profile['longitude'] ?? json['longitude']),
      locationUpdatedAt: _parseDate(
        profile['location_updated_at'] ??
            profile['locationUpdatedAt'] ??
            json['location_updated_at'] ??
            json['locationUpdatedAt'],
      ),
      createdAt: _parseDate(
        profile['created_at'] ?? profile['createdAt'] ?? json['created_at'],
      ),
      isPhoneVerified:
          user['is_phone_verified'] == true || user['isPhoneVerified'] == true,
      isActive: user['is_active'] != false && user['isActive'] != false,
      verificationStatus:
          user['verification_status']?.toString() ??
          user['verificationStatus']?.toString(),
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  String get fullName => '$firstName $lastName'.trim();

  bool get hasCoordinates => latitude != null && longitude != null;
}

class ProviderProfileModel {
  const ProviderProfileModel({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    this.role,
    this.businessName,
    this.providerType,
    this.address,
    this.onboardingCompleted = false,
    this.onboardingStep,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final String fullName;
  final String email;
  final String? phone;
  final String? role;
  final String? businessName;
  final String? providerType;
  final String? address;
  final bool onboardingCompleted;
  final int? onboardingStep;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ProviderProfileModel.fromJson(Map<String, dynamic> json) {
    return ProviderProfileModel(
      id: json['id'] as int?,
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      role: json['role'] as String?,
      businessName: json['businessName'] as String?,
      providerType: json['providerType'] as String?,
      address: json['address'] as String?,
      onboardingCompleted:
          json['onboardingCompleted'] as bool? ?? false,
      onboardingStep: json['onboardingStep'] as int?,
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is! String) return null;
    return DateTime.tryParse(value);
  }

  Map<String, dynamic> toJson() {
    return {
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'role': role,
      'businessName': businessName,
      'providerType': providerType,
      'address': address,
    };
  }
}
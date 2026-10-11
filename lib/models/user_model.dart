class UserModel {
  final int id;
  final String username;
  final String? email;
  final String? firstName;
  final String? lastName;
  
  UserModel({
    required this.id,
    required this.username,
    this.email,
    this.firstName,
    this.lastName,
  });
  
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? 0,
      username: json['username']?.toString() ?? 'غير معروف',
      email: json['email']?.toString(),
      firstName: json['first_name']?.toString(),
      lastName: json['last_name']?.toString(),
    );
  }
}

class UserProfileModel {
  final int id;
  final UserModel user;
  final String address;
  final String? address2;
  final String city;
  final String state;
  final String phone;
  final double balance;
  final String level;
  final String currency;
  final bool hasPin;
  
  UserProfileModel({
    required this.id,
    required this.user,
    required this.address,
    this.address2,
    required this.city,
    required this.state,
    required this.phone,
    required this.balance,
    required this.level,
    required this.currency,
    this.hasPin = false,
  });
  
  UserProfileModel copyWith({
    int? id,
    UserModel? user,
    String? address,
    String? address2,
    String? city,
    String? state,
    String? phone,
    double? balance,
    String? level,
    String? currency,
    bool? hasPin,
  }) {
    return UserProfileModel(
      id: id ?? this.id,
      user: user ?? this.user,
      address: address ?? this.address,
      address2: address2 ?? this.address2,
      city: city ?? this.city,
      state: state ?? this.state,
      phone: phone ?? this.phone,
      balance: balance ?? this.balance,
      level: level ?? this.level,
      currency: currency ?? this.currency,
      hasPin: hasPin ?? this.hasPin,
    );
  }
  
  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    // Helper function to parse balance safely
    double parseBalance(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        return double.tryParse(value) ?? 0.0;
      }
      return 0.0;
    }
    
    // Parse user safely
    UserModel parseUser(dynamic userData) {
      if (userData == null || userData is! Map) {
        return UserModel(
          id: 0,
          username: 'غير معروف',
        );
      }
      try {
        return UserModel.fromJson(Map<String, dynamic>.from(userData));
      } catch (e) {
        final userMap = Map<String, dynamic>.from(userData);
        return UserModel(
          id: userMap['id'] ?? 0,
          username: userMap['username']?.toString() ?? 'غير معروف',
          email: userMap['email']?.toString(),
        );
      }
    }
    
    return UserProfileModel(
      id: json['id'] ?? 0,
      user: parseUser(json['user']),
      address: json['address']?.toString() ?? '---',
      address2: json['address2']?.toString(),
      city: json['city']?.toString() ?? '---',
      state: json['state']?.toString() ?? '---',
      phone: json['phone']?.toString() ?? '0000000000',
      balance: parseBalance(json['balance']),
      level: json['level']?.toString() ?? 'vip1',
      currency: json['currency']?.toString() ?? 'USD',
      hasPin: json['has_pin'] == true,
    );
  }
}




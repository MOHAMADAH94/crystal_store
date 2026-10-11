import 'package:my_app/models/product_model.dart';
import 'package:my_app/models/user_model.dart';

class OrderDetailModel {
  final int id;
  final PackageModel package;
  final double price;
  final double finalPrice;
  final String gamerId;
  final int quantity;
  final String status;
  final String? response;
  
  OrderDetailModel({
    required this.id,
    required this.package,
    required this.price,
    required this.finalPrice,
    required this.gamerId,
    required this.quantity,
    required this.status,
    this.response,
  });
  
  factory OrderDetailModel.fromJson(Map<String, dynamic> json) {
    // طباعة البيانات الواردة للتصحيح
    print('OrderDetailModel.fromJson - Full JSON: $json');
    print('OrderDetailModel.fromJson - Package data: ${json['package']}');
    print('OrderDetailModel.fromJson - Package type: ${json['package']?.runtimeType}');
    
    // Helper function to parse numeric values safely
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        return double.tryParse(value) ?? 0.0;
      }
      return 0.0;
    }
    
    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) {
        // يدعم "2700" و "2700.0000" من الـ API
        final asInt = int.tryParse(value);
        if (asInt != null) return asInt;
        final asDouble = double.tryParse(value);
        if (asDouble != null) return asDouble.toInt();
        return 0;
      }
      return 0;
    }
    
    // Parse package safely
    PackageModel parsePackage(dynamic packageData) {
      print('parsePackage - packageData: $packageData');
      print('parsePackage - packageData type: ${packageData?.runtimeType}');
      
      // محاولة استخراج اسم الباقة من json مباشرة أولاً
      String? packageName;
      dynamic packageId;
      
      // محاولة استخراج البيانات من json['package']
      if (json['package'] != null) {
        if (json['package'] is Map) {
          final packageMap = json['package'] as Map;
          packageName = packageMap['name']?.toString();
          packageId = packageMap['id'];
          print('parsePackage - Extracted from json[package]: name=$packageName, id=$packageId');
        } else if (json['package'] is String) {
          packageName = json['package'].toString();
          print('parsePackage - json[package] is String: $packageName');
        } else if (json['package'] is int) {
          packageId = json['package'];
          print('parsePackage - json[package] is int (ID only): $packageId');
        }
      }
      
      // محاولة استخراج من packageData
      if (packageData != null && packageData is Map) {
        final packageMap = Map<String, dynamic>.from(packageData);
        if (packageName == null || packageName.isEmpty) {
          packageName = packageMap['name']?.toString();
        }
        if (packageId == null) {
          packageId = packageMap['id'];
        }
        print('parsePackage - Extracted from packageData: name=$packageName, id=$packageId');
      }
      
      if (packageData == null || packageData is! Map || packageData.isEmpty) {
        print('parsePackage - packageData is null or empty, creating default package');
        // Return a default package if parsing fails, but try to preserve the name
        final defaultPackage = PackageModel(
          id: packageId ?? json['package_id'] ?? 0,
          product: ProductModel(
            id: 0,
            category: CategoryModel(
              id: 0,
              name: 'غير محدد',
              ordering: 0,
            ),
            name: 'غير محدد',
            description: '',
            isActive: true,
            packagesCount: 0,
          ),
          name: packageName ?? json['package_name']?.toString() ?? 'غير محدد',
          quantity: 0,
          isActive: true,
          isCustom: false,
          calculatedPrice: 0.0,
        );
        print('parsePackage - Default package created with name: ${defaultPackage.name}');
        return defaultPackage;
      }
      
      try {
        final packageMap = Map<String, dynamic>.from(packageData);
        print('parsePackage - Attempting to parse packageMap: $packageMap');
        
        // التأكد من وجود اسم الباقة
        if (packageMap['name'] == null || packageMap['name'].toString().isEmpty) {
          print('parsePackage - name is missing in packageMap, using fallback: $packageName');
          packageMap['name'] = packageName ?? 'غير محدد';
        } else {
          print('parsePackage - name found in packageMap: ${packageMap['name']}');
        }
        
        final parsedPackage = PackageModel.fromJson(packageMap);
        print('parsePackage - Successfully parsed package with name: ${parsedPackage.name}');
        return parsedPackage;
      } catch (e, stackTrace) {
        print('Error parsing package in OrderDetailModel: $e');
        print('Stack trace: $stackTrace');
        print('Package data: $packageData');
        
        // Try to extract at least the name and other basic info
        final packageMap = Map<String, dynamic>.from(packageData);
        final fallbackName = packageMap['name']?.toString() ?? 
                            packageName ?? 
                            json['package_name']?.toString() ?? 
                            'غير محدد';
        
        print('parsePackage - Creating fallback package with name: $fallbackName');
        
        return PackageModel(
          id: packageMap['id'] ?? packageId ?? json['package_id'] ?? 0,
          product: ProductModel(
            id: packageMap['product']?['id'] ?? 0,
            category: CategoryModel(
              id: packageMap['product']?['category']?['id'] ?? 0,
              name: packageMap['product']?['category']?['name']?.toString() ?? 'غير محدد',
              ordering: 0,
            ),
            name: packageMap['product']?['name']?.toString() ?? 'غير محدد',
            description: packageMap['product']?['description']?.toString() ?? '',
            isActive: true,
            packagesCount: 0,
          ),
          name: fallbackName,
          quantity: packageMap['quantity'] ?? 0,
          isActive: true,
          isCustom: packageMap['is_custom'] ?? false,
          calculatedPrice: parseDouble(packageMap['calculated_price']),
        );
      }
    }
    
    final parsedPackage = parsePackage(json['package']);
    print('OrderDetailModel.fromJson - Final package name: ${parsedPackage.name}');
    
    return OrderDetailModel(
      id: json['id'] ?? 0,
      package: parsedPackage,
      price: parseDouble(json['price']),
      finalPrice: parseDouble(json['final_price']),
      gamerId: json['gamer_id']?.toString() ?? '',
      quantity: parseInt(json['quantity']),
      status: json['status']?.toString() ?? 'pending',
      response: json['response']?.toString(),
    );
  }
}

class OrderModel {
  final int id;
  final UserModel user;
  final DateTime orderDate;
  final bool isFinished;
  final List<OrderDetailModel> details;
  
  OrderModel({
    required this.id,
    required this.user,
    required this.orderDate,
    required this.isFinished,
    required this.details,
  });
  
  factory OrderModel.fromJson(Map<String, dynamic> json) {
    // Helper function to parse date safely
    DateTime parseDate(dynamic dateValue) {
      if (dateValue == null) return DateTime.now();
      if (dateValue is DateTime) return dateValue;
      if (dateValue is String) {
        try {
          return DateTime.parse(dateValue);
        } catch (e) {
          return DateTime.now();
        }
      }
      return DateTime.now();
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
        );
      }
    }
    
    // Parse details safely
    List<OrderDetailModel> parseDetails(dynamic detailsData) {
      if (detailsData == null) return [];
      if (detailsData is! List) return [];
      
      return detailsData.map((detail) {
        try {
          if (detail is Map) {
            return OrderDetailModel.fromJson(Map<String, dynamic>.from(detail));
          }
          return null;
        } catch (e) {
          print('Error parsing order detail: $e');
          return null;
        }
      }).whereType<OrderDetailModel>().toList();
    }
    
    return OrderModel(
      id: json['id'] ?? 0,
      user: parseUser(json['user']),
      orderDate: parseDate(json['order_date']),
      isFinished: json['is_finished'] == true || json['is_finished'] == 1,
      details: parseDetails(json['details']),
    );
  }
}




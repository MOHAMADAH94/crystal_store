import '../config/api_config.dart';

class CategoryModel {
  final int id;
  final String name;
  final int ordering;
  final String? imageUrl;
  final String? inputLabel;
  final String? inputPlaceholder;
  final int? parentCategoryId;
  final List<CategoryModel>? subcategories;
  
  CategoryModel({
    required this.id,
    required this.name,
    required this.ordering,
    this.imageUrl,
    this.inputLabel,
    this.inputPlaceholder,
    this.parentCategoryId,
    this.subcategories,
  });
  
  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    List<CategoryModel>? parseSubcategories(dynamic subcategoriesData) {
      if (subcategoriesData == null) return null;
      if (subcategoriesData is List) {
        return subcategoriesData.map((item) => CategoryModel.fromJson(item)).toList();
      }
      return null;
    }
    
    return CategoryModel(
      id: json['id'] ?? 0,
      name: json['name']?.toString() ?? 'غير محدد',
      ordering: json['ordering'] ?? 0,
      imageUrl: ApiConfig.resolveMediaUrl(
        (json['image_url'] ?? json['image'])?.toString(),
      ),
      inputLabel: json['input_label']?.toString(),
      inputPlaceholder: json['input_placeholder']?.toString(),
      parentCategoryId: json['parent_category'] is int ? json['parent_category'] : json['parent_category']?['id'],
      subcategories: parseSubcategories(json['subcategories']),
    );
  }
  
  bool get isParent => parentCategoryId == null;
  bool get isSubcategory => parentCategoryId != null;
}

class ProductModel {
  final int id;
  final CategoryModel category;
  final String name;
  final String description;
  final double? coinsPrice;
  final String? imageUrl;
  final bool isActive;
  final int packagesCount;
  final int? minCustomQuantity;
  final int? maxCustomQuantity;
  final bool allowDecimalQty;
  
  ProductModel({
    required this.id,
    required this.category,
    required this.name,
    required this.description,
    this.coinsPrice,
    this.imageUrl,
    required this.isActive,
    required this.packagesCount,
    this.minCustomQuantity,
    this.maxCustomQuantity,
    this.allowDecimalQty = false,
  });
  
  factory ProductModel.fromJson(Map<String, dynamic> json) {
    // Parse category safely
    CategoryModel parseCategory(dynamic categoryData) {
      if (categoryData == null || categoryData is! Map) {
        return CategoryModel(
          id: 0,
          name: 'غير محدد',
          ordering: 0,
        );
      }
      try {
        return CategoryModel.fromJson(Map<String, dynamic>.from(categoryData));
      } catch (e) {
        return CategoryModel(
          id: 0,
          name: 'غير محدد',
          ordering: 0,
        );
      }
    }
    
    return ProductModel(
      id: json['id'] ?? 0,
      category: parseCategory(json['category']),
      name: json['name']?.toString() ?? 'غير محدد',
      description: json['description']?.toString() ?? '',
      coinsPrice: json['coins_price'] != null 
          ? double.tryParse(json['coins_price'].toString()) 
          : null,
      imageUrl: ApiConfig.resolveMediaUrl(
        (json['image_url'] ?? json['image'])?.toString(),
      ),
      isActive: json['is_active'] ?? true,
      packagesCount: json['packages_count'] ?? 0,
      minCustomQuantity: json['min_custom_quantity'],
      maxCustomQuantity: json['max_custom_quantity'],
      allowDecimalQty: json['allow_decimal_qty'] ?? false,
    );
  }
}

class PackageModel {
  final int id;
  final ProductModel product;
  final String name;
  final String? description;
  final int quantity;
  final double? price;
  final String? imageUrl;
  final bool isActive;
  final bool isCustom;
  final int? denominationId;
  final double calculatedPrice;
  
  PackageModel({
    required this.id,
    required this.product,
    required this.name,
    this.description,
    required this.quantity,
    this.price,
    this.imageUrl,
    required this.isActive,
    required this.isCustom,
    this.denominationId,
    required this.calculatedPrice,
  });
  
  factory PackageModel.fromJson(Map<String, dynamic> json) {
    // Helper function to parse numeric values safely
    double? parseDoubleNullable(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        return double.tryParse(value);
      }
      return null;
    }
    
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        return double.tryParse(value) ?? 0.0;
      }
      return 0.0;
    }
    
    // Parse product safely
    ProductModel parseProduct(dynamic productData) {
      if (productData == null || productData is! Map) {
        // Return a default product if parsing fails
        return ProductModel(
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
        );
      }
      try {
        return ProductModel.fromJson(Map<String, dynamic>.from(productData));
      } catch (e) {
        print('Error parsing product: $e');
        final productMap = Map<String, dynamic>.from(productData);
        return ProductModel(
          id: productMap['id'] ?? 0,
          category: CategoryModel(
            id: productMap['category']?['id'] ?? 0,
            name: productMap['category']?['name']?.toString() ?? 'غير محدد',
            ordering: 0,
          ),
          name: productMap['name']?.toString() ?? 'غير محدد',
          description: productMap['description']?.toString() ?? '',
          isActive: productMap['is_active'] ?? true,
          packagesCount: 0,
        );
      }
    }
    
    // استخراج اسم الباقة مع معالجة أفضل للقيم الفارغة
    String extractName(dynamic nameValue) {
      if (nameValue == null) return 'غير محدد';
      final nameStr = nameValue.toString().trim();
      if (nameStr.isEmpty) return 'غير محدد';
      return nameStr;
    }
    
    final packageName = extractName(json['name']);
    print('PackageModel.fromJson - Extracted name: $packageName from: ${json['name']}');
    
    return PackageModel(
      id: json['id'] ?? 0,
      product: parseProduct(json['product']),
      name: packageName,
      description: json['description']?.toString(),
      quantity: json['quantity'] ?? 0,
      price: parseDoubleNullable(json['price']),
      imageUrl: ApiConfig.resolveMediaUrl(
        (json['image_url'] ?? json['image'])?.toString(),
      ),
      isActive: json['is_active'] ?? true,
      isCustom: json['is_custom'] ?? false,
      denominationId: json['denomination_id'],
      calculatedPrice: parseDouble(json['calculated_price']),
    );
  }
}




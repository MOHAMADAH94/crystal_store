import 'package:flutter/foundation.dart';
import '../models/product_model.dart';
import '../services/api_service.dart';

class ProductProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<CategoryModel> _categories = [];
  List<ProductModel> _products = [];
  List<PackageModel> _packages = [];

  bool _isLoadingCategories = false;
  bool _isLoadingProducts = false;
  bool _isLoadingPackages = false;
  String? _categoriesError;
  String? _productsError;
  String? _packagesError;

  List<CategoryModel> get categories => _categories;
  List<ProductModel> get products => _products;
  List<PackageModel> get packages => _packages;

  bool get isLoadingCategories => _isLoadingCategories;
  bool get isLoadingProducts => _isLoadingProducts;
  bool get isLoadingPackages => _isLoadingPackages;
  bool get isLoading =>
      _isLoadingCategories || _isLoadingProducts || _isLoadingPackages;

  String? get categoriesError => _categoriesError;
  String? get productsError => _productsError;
  String? get packagesError => _packagesError;
  String? get error => _categoriesError ?? _productsError ?? _packagesError;

  Future<void> loadCategories({bool parentOnly = true}) async {
    _isLoadingCategories = true;
    _categoriesError = null;
    notifyListeners();

    try {
      final data = await _apiService.getCategories(parentOnly: parentOnly);
      _categories = data.map((json) => CategoryModel.fromJson(json)).toList();
    } catch (e) {
      _categoriesError = e.toString();
    } finally {
      _isLoadingCategories = false;
      notifyListeners();
    }
  }

  Future<void> loadProducts({int? categoryId}) async {
    _isLoadingProducts = true;
    _productsError = null;
    _products = [];
    notifyListeners();

    try {
      final data = await _apiService.getProducts(categoryId: categoryId);
      _products = data.map((json) => ProductModel.fromJson(json)).toList();
    } catch (e) {
      _productsError = e.toString();
      _products = [];
    } finally {
      _isLoadingProducts = false;
      notifyListeners();
    }
  }

  Future<void> loadPackages({int? productId}) async {
    _isLoadingPackages = true;
    _packagesError = null;
    _packages = [];
    notifyListeners();

    try {
      final data = await _apiService.getPackages(productId: productId);
      _packages = data
          .map((json) => PackageModel.fromJson(json))
          .where((package) => package.isActive)
          .toList();
    } catch (e) {
      _packagesError = e.toString();
      _packages = [];
    } finally {
      _isLoadingPackages = false;
      notifyListeners();
    }
  }

  void clearError() {
    _categoriesError = null;
    _productsError = null;
    _packagesError = null;
    notifyListeners();
  }
}

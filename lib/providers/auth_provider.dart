import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  UserProfileModel? _userProfile;
  bool _isLoading = false;
  String? _error;
  bool _hasToken = false;
  double _exchangeRate = 15000.0; // Default value
  
  UserProfileModel? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _hasToken || _userProfile != null;
  double get exchangeRate => _exchangeRate;

  Future<void> waitUntilReady() => _initFuture;
  late final Future<void> _initFuture;

  AuthProvider() {
    _initFuture = _init();
  }
  
  Future<void> _init() async {
    // التحقق من وجود token محفوظ
    await _apiService.ensureTokenLoaded();
    _hasToken = _apiService.hasToken();
    // تحميل سعر الصرف دائماً
    await loadExchangeRate();
    if (_hasToken) {
      // محاولة تحميل الملف الشخصي
      await loadProfile();
    }
  }
  
  Future<void> loadExchangeRate() async {
    try {
      _exchangeRate = await _apiService.getExchangeRate();
      notifyListeners();
    } catch (e) {
      print('Error loading exchange rate: $e');
      // Keep default value
    }
  }
  
  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await _apiService.login(username, password);
      if (response['token'] != null) {
        _hasToken = true;
        await loadProfile();
        if (_userProfile != null) {
          return true;
        }
        // التوكن نجح لكن البروفايل فشل — نبقي التوكن ونعتبر الدخول ناجحاً لطلبات أهلا
        _error = null;
        return true;
      }
      _error = 'فشل تسجيل الدخول';
      return false;
    } catch (e) {
      String msg = e.toString();
      if (msg.startsWith('Exception: ')) {
        msg = msg.substring('Exception: '.length);
      }
      _error = msg;
      _hasToken = false;
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<bool> register(String username, String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await _apiService.register(username, email, password);
      if (response['token'] != null) {
        _hasToken = true;
        await loadProfile();
        return _userProfile != null;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      _hasToken = false;
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<bool> updateProfile({
    String? address,
    String? address2,
    String? city,
    String? state,
    String? phone,
    String? firstName,
    String? lastName,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      await _apiService.ensureTokenLoaded();
      if (!_apiService.hasToken()) {
        _error = 'لا يوجد token للمصادقة';
        _hasToken = false;
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      final data = await _apiService.updateProfile(
        address: address,
        address2: address2,
        city: city,
        state: state,
        phone: phone,
        firstName: firstName,
        lastName: lastName,
      );
      
      // تحديث الملف الشخصي بعد التعديل
      _userProfile = UserProfileModel.fromJson(Map<String, dynamic>.from(data));
      _hasToken = true;
      _error = null;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> loadProfile() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // Ensure token is loaded before getting profile
      await _apiService.ensureTokenLoaded();
      if (!_apiService.hasToken()) {
        _error = 'لا يوجد token للمصادقة';
        _hasToken = false;
        _isLoading = false;
        notifyListeners();
        return;
      }
      
      final data = await _apiService.getProfile();
      _userProfile = UserProfileModel.fromJson(Map<String, dynamic>.from(data));
      _hasToken = true;
      _error = null;
    } catch (e) {
      _error = e.toString();
      if (_isAuthFailure(e.toString())) {
        await logout();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> logout() async {
    await _apiService.clearToken();
    _userProfile = null;
    _hasToken = false;
    _error = null;
    notifyListeners();
  }
  
  bool _isAuthFailure(String message) {
    final lower = message.toLowerCase();
    return lower.contains('401') ||
        lower.contains('token') ||
        lower.contains('مصادقة') ||
        lower.contains('credentials') ||
        lower.contains('غير مصرح');
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}



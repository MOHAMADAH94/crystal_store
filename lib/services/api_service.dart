import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../config/api_config.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late Dio _dio;
  String? _token;
  Future<void>? _initFuture;
  static const String _siteUrlPrefsKey = 'api_site_url';

  ApiService._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        headers: {
          ...ApiConfig.getHeaders(),
          'User-Agent': 'CrystalStoreApp/1.0 (Flutter)',
        },
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        followRedirects: true,
        maxRedirects: 5,
        validateStatus: (status) => status != null && status >= 200 && status < 300,
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) async {
          final options = error.requestOptions;

          if (_isDnsError(error) && options.extra['dnsFallbackTried'] != true) {
            final switched = await _switchToNextBaseUrl();
            if (switched) {
              options.extra['dnsFallbackTried'] = true;
              try {
                final response = await _dio.fetch(options);
                return handler.resolve(response);
              } catch (_) {
                // continue to generic retry / error handling
              }
            }
          }

          final retryCount = (options.extra['retryCount'] as int?) ?? 0;
          final isRetryable = error.type == DioExceptionType.connectionError ||
              error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.receiveTimeout ||
              error.type == DioExceptionType.sendTimeout;

          if (isRetryable && retryCount < 2) {
            await Future.delayed(Duration(seconds: retryCount + 1));
            options.extra['retryCount'] = retryCount + 1;
            try {
              final response = await _dio.fetch(options);
              return handler.resolve(response);
            } catch (_) {
              // fall through to default error handling
            }
          }
          handler.next(error);
        },
      ),
    );

    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          error: true,
          logPrint: (object) => print('[Dio] $object'),
        ),
      );
    }

    _initFuture = _initialize();
  }

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final savedSiteUrl = prefs.getString(_siteUrlPrefsKey);
    if (savedSiteUrl != null &&
        ApiConfig.candidateSiteUrls.contains(savedSiteUrl)) {
      ApiConfig.setActiveSiteUrl(savedSiteUrl);
    } else {
      // ابدأ دائماً بالنطاق بدون www — أكثر استقراراً على المحاكي
      ApiConfig.setActiveSiteUrl(ApiConfig.candidateSiteUrls.first);
    }
    _dio.options.baseUrl = ApiConfig.baseUrl;

    await _loadToken();
  }

  bool _isDnsError(DioException error) {
    final message = '${error.message ?? ''} ${error.error ?? ''}'.toLowerCase();
    return message.contains('failed host lookup') ||
        message.contains('no address associated with hostname') ||
        message.contains('getaddrinfo failed') ||
        message.contains('errno = 7');
  }

  Future<bool> _switchToNextBaseUrl() async {
    final nextSiteUrl = ApiConfig.nextSiteUrl();
    if (nextSiteUrl == null) return false;

    ApiConfig.setActiveSiteUrl(nextSiteUrl);
    _dio.options.baseUrl = ApiConfig.baseUrl;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_siteUrlPrefsKey, nextSiteUrl);

    if (kDebugMode) {
      print('[Dio] DNS fallback -> ${ApiConfig.baseUrl}');
    }
    return true;
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    if (_token != null) {
      _dio.options.headers['Authorization'] = 'Token $_token';
    }
  }

  // Ensure token is loaded before making authenticated requests
  Future<void> ensureTokenLoaded() async {
    await (_initFuture ??= _initialize());
  }

  Future<void> setToken(String token) async {
    _token = token;
    _dio.options.headers['Authorization'] = 'Token $token';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<void> clearToken() async {
    _token = null;
    _dio.options.headers.remove('Authorization');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  bool hasToken() {
    return _token != null && _token!.isNotEmpty;
  }

  // Get token synchronously (may return null if not loaded yet)
  String? get token => _token;

  // Authentication
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await _dio.post(
        ApiConfig.login,
        data: {'username': username, 'password': password},
      );
      if (response.data['token'] != null) {
        await setToken(response.data['token']);
      }
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> register(
    String username,
    String email,
    String password,
  ) async {
    try {
      final response = await _dio.post(
        ApiConfig.register,
        data: {'username': username, 'email': email, 'password': password},
      );
      if (response.data['token'] != null) {
        await setToken(response.data['token']);
      }
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Categories
  Future<List<dynamic>> getCategories({bool parentOnly = false}) async {
    try {
      final Map<String, dynamic> queryParams = parentOnly ? {'parent_only': 'true'} : <String, dynamic>{};
      final response = await _dio.get(ApiConfig.categories, queryParameters: queryParams);
      return _parseList(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Products
  Future<List<dynamic>> getProducts({int? categoryId}) async {
    try {
      final queryParams = categoryId != null ? {'category': categoryId} : null;
      final response = await _dio.get(
        ApiConfig.products,
        queryParameters: queryParams,
      );
      return _parseList(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Packages
  Future<List<dynamic>> getPackages({int? productId}) async {
    try {
      final queryParams = productId != null ? {'product': productId} : null;
      final response = await _dio.get(
        ApiConfig.packages,
        queryParameters: queryParams,
      );
      return _parseList(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Exchange Rate
  Future<double> getExchangeRate() async {
    try {
      final response = await _dio.get('/exchange-rate/');
      if (response.data is Map && response.data.containsKey('rate')) {
        return (response.data['rate'] as num).toDouble();
      }
      return 15000.0; // Default value
    } on DioException catch (e) {
      print('Error getting exchange rate: ${_handleError(e)}');
      return 15000.0; // Default value on error
    }
  }

  // PIN Management
  Future<bool> checkPinStatus() async {
    try {
      await ensureTokenLoaded();
      if (!hasToken()) {
        throw Exception('لا يوجد token للمصادقة');
      }
      final response = await _dio.get('/pin/check/');
      if (response.data is Map && response.data.containsKey('has_pin')) {
        return response.data['has_pin'] == true;
      }
      return false;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<bool> setPin(String pin) async {
    try {
      await ensureTokenLoaded();
      if (!hasToken()) {
        throw Exception('لا يوجد token للمصادقة');
      }
      final response = await _dio.post(
        '/pin/set/',
        data: {'pin': pin},
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<bool> verifyPin(String pin) async {
    try {
      await ensureTokenLoaded();
      if (!hasToken()) {
        throw Exception('لا يوجد token للمصادقة');
      }
      final response = await _dio.post(
        '/pin/verify/',
        data: {'pin': pin},
      );
      if (response.data is Map && response.data.containsKey('verified')) {
        return response.data['verified'] == true;
      }
      return false;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<bool> updatePin(String oldPin, String newPin) async {
    try {
      await ensureTokenLoaded();
      if (!hasToken()) {
        throw Exception('لا يوجد token للمصادقة');
      }
      final response = await _dio.post(
        '/pin/update/',
        data: {
          'old_pin': oldPin,
          'new_pin': newPin,
        },
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Orders
  Future<List<dynamic>> getOrders() async {
    try {
      await ensureTokenLoaded();
      final response = await _dio.get(ApiConfig.orders);
      // Handle paginated response
      if (response.data is Map && response.data.containsKey('results')) {
        return response.data['results'];
      } else if (response.data is List) {
        return response.data;
      }
      return [];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> createOrder({
    required int packageId,
    required double quantity,
    required String gamerId,
    double? customQuantity,
  }) async {
    try {
      await ensureTokenLoaded();
      final response = await _dio.post(
        '${ApiConfig.orders}create_order/',
        data: {
          'package_id': packageId,
          'quantity': quantity,
          'gamer_id': gamerId,
          if (customQuantity != null) 'custom_quantity': customQuantity,
        },
      );

      // التحقق من status code - يجب أن يكون 201 للنجاح
      if (response.statusCode == 201 || response.statusCode == 200) {
        // التأكد من أن response.data هو Map
        if (response.data is Map) {
          return Map<String, dynamic>.from(response.data);
        } else {
          // إذا كان response.data ليس Map، إرجاع map بسيط
          return {'message': 'تم إنشاء الطلب بنجاح'};
        }
      } else {
        // إذا كان status code ليس 200 أو 201، استخراج الرسالة من response.data
        if (response.data is Map) {
          final data = response.data as Map;
          String errorMsg = 'فشل إنشاء الطلب';

          // محاولة استخراج رسالة الخطأ من Django
          if (data.containsKey('error')) {
            errorMsg = data['error'].toString();

            // إذا كان هناك تفاصيل الرصيد، أضفها
            if (data.containsKey('required_balance') ||
                data.containsKey('available_balance') ||
                data.containsKey('shortage')) {
              errorMsg = 'الرصيد غير كافي';
              if (data.containsKey('required_balance')) {
                errorMsg += '\nالمطلوب: ${data['required_balance']}';
              }
              if (data.containsKey('available_balance')) {
                errorMsg += '\nالمتاح: ${data['available_balance']}';
              }
              if (data.containsKey('shortage')) {
                errorMsg += '\nالنقص: ${data['shortage']}';
              }
            }
          } else if (data.containsKey('detail')) {
            errorMsg = data['detail'].toString();
          }

          throw errorMsg;
        }
        // إذا لم يكن هناك data، رمي رسالة عامة
        throw 'فشل إنشاء الطلب: ${response.statusCode}';
      }
    } on DioException catch (e) {
      // معالجة أخطاء DioException
      // إذا كان status code 400 (Bad Request) أو 400+، هناك خطأ في الطلب
      if (e.response != null && e.response!.statusCode != null) {
        final statusCode = e.response!.statusCode!;
        // إذا كان status code 201 (نجح) لكن هناك خطأ في parsing، إرجاع success
        if (statusCode == 201) {
          // محاولة استخراج البيانات من response
          if (e.response?.data is Map) {
            return Map<String, dynamic>.from(e.response!.data);
          }
          return {'message': 'تم إنشاء الطلب بنجاح'};
        }
        // للرموز الأخرى (400, 401, 403, etc.)، استخراج الرسالة مباشرة
        final errorMessage = _handleError(e);
        // رمي Exception يحتوي على الرسالة مباشرة (بدون "Exception: ")
        throw errorMessage;
      }
      // إذا لم يكن هناك response، رمي الخطأ
      final errorMessage = _handleError(e);
      throw errorMessage;
    } catch (e) {
      // معالجة أي أخطاء أخرى
      print('Error in createOrder: $e');
      // إذا كان الخطأ String مباشرة، استخدمه
      if (e is String) {
        throw e;
      }
      // إذا كان الخطأ Exception، استخرج الرسالة
      String errorMsg = e.toString();
      if (errorMsg.contains('Exception: ')) {
        errorMsg = errorMsg.replaceAll('Exception: ', '');
      }
      throw errorMsg;
    }
  }

  // Profile
  Future<Map<String, dynamic>> updateProfile({
    String? address,
    String? address2,
    String? city,
    String? state,
    String? phone,
    String? firstName,
    String? lastName,
  }) async {
    try {
      await ensureTokenLoaded();
      final data = <String, dynamic>{};
      if (address != null) data['address'] = address;
      if (address2 != null) data['address2'] = address2;
      if (city != null) data['city'] = city;
      if (state != null) data['state'] = state;
      if (phone != null) data['phone'] = phone;
      if (firstName != null) data['first_name'] = firstName;
      if (lastName != null) data['last_name'] = lastName;

      final response = await _dio.patch(
        '${ApiConfig.profile}update_profile/',
        data: data,
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getProfile() async {
    try {
      await ensureTokenLoaded();
      final response = await _dio.get('${ApiConfig.profile}me/');
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<dynamic>> getBalanceHistory() async {
    try {
      await ensureTokenLoaded();
      final response = await _dio.get('${ApiConfig.profile}balance_history/');
      // Handle both list and paginated response
      if (response.data is List) {
        return response.data;
      } else if (response.data is Map && response.data.containsKey('results')) {
        return response.data['results'];
      }
      return [];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<dynamic>> getBalanceAddRequests() async {
    try {
      await ensureTokenLoaded();
      final response = await _dio.get(
        '${ApiConfig.profile}balance_add_requests/',
      );
      // Handle both list and paginated response
      if (response.data is List) {
        return response.data;
      } else if (response.data is Map && response.data.containsKey('results')) {
        return response.data['results'];
      }
      return [];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Notifications
  Future<List<dynamic>> getNotifications() async {
    try {
      await ensureTokenLoaded();
      final response = await _dio.get(ApiConfig.notifications);
      return response.data['results'] ?? response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> markNotificationAsRead(int notificationId) async {
    try {
      await ensureTokenLoaded();
      await _dio.post('${ApiConfig.notifications}$notificationId/mark_read/');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Payment Methods
  Future<List<dynamic>> getPaymentMethods() async {
    try {
      // Payment methods might not require authentication, but ensure token is loaded if needed
      await ensureTokenLoaded();
      final response = await _dio.get(ApiConfig.paymentMethods);

      // Debug: print response to understand structure
      print('Payment Methods Response: ${response.data}');
      print('Response Type: ${response.data.runtimeType}');

      // Handle paginated response
      if (response.data is Map) {
        if (response.data.containsKey('results')) {
          final results = response.data['results'];
          print('Found results key with ${results.length} items');
          return results is List ? results : [];
        } else if (response.data.containsKey('data')) {
          final data = response.data['data'];
          print('Found data key with ${data.length} items');
          return data is List ? data : [];
        } else {
          // If it's a map but no results/data, return empty
          print('Map response but no results/data key found');
          return [];
        }
      } else if (response.data is List) {
        print(
          'Direct list response with ${(response.data as List).length} items',
        );
        return response.data as List;
      }

      print('Unknown response format, returning empty list');
      return [];
    } on DioException catch (e) {
      print('DioException in getPaymentMethods: ${e.message}');
      print('Response: ${e.response?.data}');
      print('Status: ${e.response?.statusCode}');
      throw _handleError(e);
    } catch (e) {
      print('Exception in getPaymentMethods: $e');
      rethrow;
    }
  }

  // Send Money (Balance Add)
  Future<Map<String, dynamic>> sendMoney({
    required double amount,
    required int paymentMethodId,
    required File receiptFile,
  }) async {
    try {
      await ensureTokenLoaded();
      final formData = FormData.fromMap({
        'amount': amount,
        'payment_method': paymentMethodId,
        'receipt': await MultipartFile.fromFile(receiptFile.path),
      });

      final response = await _dio.post(
        '${ApiConfig.profile}send_money/',
        data: formData,
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Agents
  Future<List<dynamic>> getAgents() async {
    try {
      final response = await _dio.get(ApiConfig.agents);
      return response.data['results'] ?? response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  List<dynamic> _parseList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      if (data['results'] is List) return data['results'] as List;
      if (data['data'] is List) return data['data'] as List;
    }
    return [];
  }

  String _handleError(DioException error) {
    String errorMessage = error.message ?? '';

    // معالجة أخطاء الاتصال (Network errors)
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      // فحص أخطاء DNS و host lookup
      if (errorMessage.contains('Failed host lookup') ||
          errorMessage.contains('host lookup') ||
          errorMessage.contains('getaddrinfo failed') ||
          errorMessage.contains('No address associated with hostname')) {
        return 'تعذر الاتصال بالخادم (مشكلة DNS)\n'
            'تأكد من:\n'
            '1. اتصال الإنترنت يعمل على الجهاز أو المحاكي\n'
            '2. جرّب Wi-Fi أو بيانات الجوال\n'
            '3. على المحاكي: Settings > Network > DNS أو أعد تشغيل المحاكي\n'
            'العنوان الحالي: ${ApiConfig.baseUrl}';
      }

      // فحص أخطاء timeout
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return 'انتهت مهلة الاتصال بالخادم\n'
            'تأكد من اتصال الإنترنت وحاول مرة أخرى';
      }

      // أخطاء اتصال عامة
      return 'خطأ في الاتصال بالخادم\n'
          'تأكد من اتصال الإنترنت وحاول مرة أخرى';
    }

    // معالجة أخطاء SSL/TLS
    if (error.type == DioExceptionType.badCertificate ||
        errorMessage.contains('certificate') ||
        errorMessage.contains('SSL')) {
      return 'خطأ في شهادة الأمان (SSL)\n'
          'تأكد من أن الموقع يستخدم HTTPS بشكل صحيح';
    }

    // معالجة أخطاء الاستجابة من الخادم
    if (error.response != null) {
      final data = error.response?.data;

      // طباعة للتصحيح
      print('Error response data: $data');
      print('Error response data type: ${data.runtimeType}');

      if (data is Map) {
        // أولوية لرسالة الخطأ من Django
        if (data.containsKey('error')) {
          String errorMsg = data['error'].toString();

          // إذا كان هناك تفاصيل إضافية (مثل المبلغ المطلوب والمتاح)، أضفها
          if (data.containsKey('required_balance') ||
              data.containsKey('available_balance') ||
              data.containsKey('shortage')) {
            // بناء رسالة مفصلة للرصيد
            errorMsg = 'الرصيد غير كافي';
            if (data.containsKey('required_balance')) {
              final required = data['required_balance'].toString();
              errorMsg += '\nالمطلوب: $required';
            }
            if (data.containsKey('available_balance')) {
              final available = data['available_balance'].toString();
              errorMsg += '\nالمتاح: $available';
            }
            if (data.containsKey('shortage')) {
              final shortage = data['shortage'].toString();
              errorMsg += '\nالنقص: $shortage';
            }

            print('Balance error message: $errorMsg');
            return errorMsg;
          }

          print('Error message (no balance details): $errorMsg');
          return errorMsg;
        }
        if (data.containsKey('detail')) {
          final detailMsg = data['detail'].toString();
          print('Detail message: $detailMsg');
          return detailMsg;
        }
        // Try to parse validation errors
        if (data.isNotEmpty) {
          // محاولة استخراج رسالة الخطأ الأولى
          final firstValue = data.values.first;
          if (firstValue is List && firstValue.isNotEmpty) {
            return firstValue.first.toString();
          }
          return firstValue.toString();
        }
      }
      if (error.response?.statusCode == 500) {
        return 'الخادم متوقف حالياً (خطأ 500)\n'
            'الموقع يحتاج إعادة تشغيل بعد رفع ملفات السيرفر';
      }
      return 'حدث خطأ: ${error.response?.statusCode}';
    }

    // أخطاء أخرى
    return 'خطأ في الاتصال: $errorMessage';
  }
}

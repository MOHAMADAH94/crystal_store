import 'package:flutter/foundation.dart';
import '../models/order_model.dart';
import '../services/api_service.dart';

class OrderProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<OrderModel> _orders = [];
  bool _isLoading = false;
  String? _error;

  List<OrderModel> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// [silent] إذا true لا يظهر مؤشر التحميل (للتحديث في الخلفية)
  Future<void> loadOrders({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final data = await _apiService.getOrders();
      _orders =
          data
              .map((json) {
                try {
                  if (json is Map) {
                    return OrderModel.fromJson(Map<String, dynamic>.from(json));
                  }
                  return null;
                } catch (e) {
                  print('Error parsing order: $e');
                  print('Order data: $json');
                  return null;
                }
              })
              .whereType<OrderModel>()
              .toList();
    } catch (e) {
      if (!silent) {
        String errorMsg = e.toString();
        if (errorMsg.contains('Exception: ')) {
          errorMsg = errorMsg.replaceAll('Exception: ', '');
        }
        _error = errorMsg;
        _orders = [];
        print('Error loading orders: $e');
      }
    } finally {
      if (!silent) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  Future<bool> createOrder({
    required int packageId,
    required double quantity,
    required String gamerId,
    double? customQuantity,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _apiService.createOrder(
        packageId: packageId,
        quantity: quantity,
        gamerId: gamerId,
        customQuantity: customQuantity,
      );

      // تحميل الطلبات مرة واحدة مع إظهار النتيجة
      await loadOrders();

      // تحديث الحالة في الخلفية دون إظهار مؤشر التحميل مرة أخرى
      Future.delayed(const Duration(milliseconds: 800), () => loadOrders(silent: true));
      Future.delayed(const Duration(milliseconds: 2000), () => loadOrders(silent: true));

      return true;
    } catch (e) {
      // استخراج رسالة الخطأ من Django
      String errorMsg;

      // إذا كان الخطأ String مباشرة، استخدمه
      if (e is String) {
        errorMsg = e;
      } else {
        // إذا كان Exception، استخرج الرسالة
        errorMsg = e.toString();
        // إزالة "Exception: " إذا كان موجوداً
        if (errorMsg.contains('Exception: ')) {
          errorMsg = errorMsg.replaceAll('Exception: ', '');
        }
        // إزالة أي بادئات أخرى
        if (errorMsg.startsWith('Error: ')) {
          errorMsg = errorMsg.replaceAll('Error: ', '');
        }
      }

      // حفظ الرسالة
      _error = errorMsg;

      // طباعة للتصحيح
      print('Order creation error: $errorMsg');

      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

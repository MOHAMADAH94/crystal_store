import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/optimized_image.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _paymentMethods = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
  }

  Future<void> _loadPaymentMethods() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _apiService.getPaymentMethods();
      setState(() {
        _paymentMethods = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) => Scaffold(
        endDrawer: const AppDrawer(),
        appBar: AppBar(
          leading: const SizedBox.shrink(),
          actions: [
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openEndDrawer();
              },
            ),
          ],
          title: const Text('طرق الدفع'),
        ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('خطأ: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadPaymentMethods,
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                )
              : _paymentMethods.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.payment, size: 80, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'لا توجد طرق دفع متاحة',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadPaymentMethods,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _paymentMethods.length,
                        itemBuilder: (context, index) {
                          final method = _paymentMethods[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: method['image_url'] != null
                                  ? OptimizedImage(
                                      imageUrl: method['image_url'],
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      borderRadius: BorderRadius.circular(8),
                                      errorWidget: const Icon(Icons.payment, size: 40),
                                    )
                                  : const Icon(Icons.payment, size: 40),
                              title: Text(
                                method['name'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (method['address'] != null)
                                    Text('العنوان: ${method['address']}'),
                                  if (method['details'] != null)
                                    Text(
                                      method['details'],
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                    ),
                                  if (method['discount_percentage'] != null &&
                                      (method['discount_percentage'] as num) > 0)
                                    Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'خصم ${method['discount_percentage']}%',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
      ),
    );
  }
}


import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/optimized_image.dart';

class SendMoneyScreen extends StatefulWidget {
  const SendMoneyScreen({super.key});

  @override
  State<SendMoneyScreen> createState() => _SendMoneyScreenState();
}

class _SendMoneyScreenState extends State<SendMoneyScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  
  List<dynamic> _paymentMethods = [];
  int? _selectedPaymentMethodId;
  File? _receiptFile;
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _error;
  
  // Balance add requests
  List<dynamic> _balanceAddRequests = [];
  bool _isLoadingRequests = false;

  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
    _loadBalanceAddRequests();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadPaymentMethods() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      print('Loading payment methods...');
      final data = await _apiService.getPaymentMethods();
      print('Received ${data.length} payment methods');
      
      if (data.isEmpty) {
        print('No payment methods found');
        setState(() {
          _error = 'لا توجد طرق دفع متاحة حالياً. يرجى المحاولة لاحقاً.';
          _isLoading = false;
        });
        return;
      }
      
      // Validate and filter valid payment methods
      final validMethods = <dynamic>[];
      for (var method in data) {
        if (method is Map && method.containsKey('id') && method.containsKey('name')) {
          validMethods.add(method);
          print('Valid payment method: ${method['name']} (ID: ${method['id']})');
        } else {
          print('Invalid payment method structure: $method');
        }
      }
      
      if (validMethods.isEmpty) {
        setState(() {
          _error = 'لا توجد طرق دفع صالحة';
          _isLoading = false;
        });
        return;
      }
      
      setState(() {
        _paymentMethods = validMethods;
        // Parse payment method ID safely
        final firstMethod = validMethods[0];
        final firstMethodId = firstMethod['id'];
        if (firstMethodId != null) {
          _selectedPaymentMethodId = firstMethodId is int 
              ? firstMethodId 
              : int.tryParse(firstMethodId.toString());
          print('Selected payment method ID: $_selectedPaymentMethodId');
        }
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading payment methods: $e');
      final errorMessage = e.toString().replaceAll('Exception: ', '');
      setState(() {
        _error = errorMessage;
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل طرق الدفع: $errorMessage'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _pickReceipt() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      
      if (image != null) {
        setState(() {
          _receiptFile = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في اختيار الصورة: $e')),
      );
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      
      if (image != null) {
        setState(() {
          _receiptFile = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في التقاط الصورة: $e')),
      );
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedPaymentMethodId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار طريقة الدفع')),
      );
      return;
    }
    
    if (_receiptFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تحميل إيصال الدفع')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final amount = double.parse(_amountController.text);
      
      // Find payment method safely
      dynamic paymentMethod;
      try {
        paymentMethod = _paymentMethods.firstWhere(
          (method) {
            final methodId = method['id'];
            if (methodId is int) {
              return methodId == _selectedPaymentMethodId;
            } else if (methodId is String) {
              return int.tryParse(methodId) == _selectedPaymentMethodId;
            }
            return false;
          },
        );
      } catch (e) {
        throw Exception('طريقة الدفع المختارة غير موجودة');
      }
      
      // Parse discount percentage safely
      final discountValue = paymentMethod['discount_percentage'];
      final discountPercentage = discountValue != null
          ? (discountValue is double 
              ? discountValue 
              : discountValue is int 
                  ? discountValue.toDouble() 
                  : double.tryParse(discountValue.toString()) ?? 0.0)
          : 0.0;
      
      final discountedAmount = amount * (1 - discountPercentage / 100);

      await _apiService.sendMoney(
        amount: amount,
        paymentMethodId: _selectedPaymentMethodId!,
        receiptFile: _receiptFile!,
      );

      if (!mounted) return;

      // تحديث الملف الشخصي
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.loadProfile();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم إرسال طلب الدفعة بنجاح!\n'
            'المبلغ الأصلي: ${amount.toStringAsFixed(2)}\n'
            'المبلغ بعد الخصم: ${discountedAmount.toStringAsFixed(2)}',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );

      // إعادة تعيين النموذج
      _amountController.clear();
      setState(() {
        _receiptFile = null;
        _isSubmitting = false;
      });
    } catch (e) {
      final errorMessage = e.toString().replaceAll('Exception: ', '');
      setState(() {
        _error = errorMessage;
        _isSubmitting = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: $errorMessage'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
  
  Future<void> _loadBalanceAddRequests() async {
    setState(() {
      _isLoadingRequests = true;
    });
    
    try {
      final data = await _apiService.getBalanceAddRequests();
      setState(() {
        _balanceAddRequests = data;
        _isLoadingRequests = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingRequests = false;
      });
      // Silent fail - don't show error for requests loading
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      endDrawer: const AppDrawer(),
      appBar: AppBar(
        leading: const SizedBox.shrink(),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openEndDrawer();
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadPaymentMethods,
            tooltip: 'تحديث',
          ),
        ],
        title: const Text('إرسال دفعة'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _paymentMethods.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          style: const TextStyle(fontSize: 16, color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _loadPaymentMethods,
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    await _loadPaymentMethods();
                    await _loadBalanceAddRequests();
                  },
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                    if (_error != null && _paymentMethods.isNotEmpty)
                      Card(
                        color: Colors.red[50],
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'خطأ: $_error',
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    // عرض وسائل الدفع بشكل كامل
                    if (_paymentMethods.isNotEmpty) ...[
                      const Text(
                        'طرق الدفع المتاحة',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._paymentMethods.map((method) {
                        final methodId = method['id'];
                        final intId = methodId is int 
                            ? methodId 
                            : methodId is String 
                                ? int.tryParse(methodId) 
                                : null;
                        
                        if (intId == null) return const SizedBox.shrink();
                        
                        final imageUrl = method['image_url'];
                        final name = method['name']?.toString() ?? 'طريقة دفع';
                        final address = method['address']?.toString() ?? '';
                        final details = method['details']?.toString() ?? '';
                        final discountValue = method['discount_percentage'];
                        final discountPercentage = discountValue != null
                            ? (discountValue is double 
                                ? discountValue 
                                : discountValue is int 
                                    ? discountValue.toDouble() 
                                    : double.tryParse(discountValue.toString()) ?? 0.0)
                            : 0.0;
                        
                        final isSelected = _selectedPaymentMethodId == intId;
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: isSelected ? 4 : 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isSelected ? Colors.purple : Colors.grey.shade300,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedPaymentMethodId = intId;
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      // صورة طريقة الدفع
                                      if (imageUrl != null && imageUrl.toString().isNotEmpty)
                                        OptimizedImage(
                                          imageUrl: imageUrl.toString(),
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                          borderRadius: BorderRadius.circular(8),
                                          errorWidget: Container(
                                            width: 60,
                                            height: 60,
                                            color: Colors.grey.shade200,
                                            child: const Icon(Icons.payment, color: Colors.grey),
                                          ),
                                        )
                                      else
                                        Container(
                                          width: 60,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade200,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(Icons.payment, color: Colors.grey),
                                        ),
                                      const SizedBox(width: 12),
                                      // اسم طريقة الدفع
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    name,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                if (isSelected)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.purple,
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: const Icon(
                                                      Icons.check,
                                                      color: Colors.white,
                                                      size: 16,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            // العنوان
                                            if (address.isNotEmpty)
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      address,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey.shade700,
                                                      ),
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.copy, size: 18),
                                                    onPressed: () async {
                                                      await Clipboard.setData(ClipboardData(text: address));
                                                      if (mounted) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          const SnackBar(
                                                            content: Text('تم نسخ العنوان'),
                                                            duration: Duration(seconds: 2),
                                                          ),
                                                        );
                                                      }
                                                    },
                                                    tooltip: 'نسخ العنوان',
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(),
                                                  ),
                                                ],
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  // التفاصيل
                                  if (details.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      details,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                  // نسبة الخصم
                                  if (discountPercentage > 0) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.green.shade200),
                                      ),
                                      child: Text(
                                        'خصم ${discountPercentage.toStringAsFixed(0)}%',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.green.shade700,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                      const SizedBox(height: 24),
                    ],
                    if (_paymentMethods.isEmpty && !_isLoading)
                      Card(
                        color: Colors.orange[50],
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: Colors.orange),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'لا توجد طرق دفع متاحة حالياً. يرجى المحاولة لاحقاً.',
                                  style: TextStyle(color: Colors.orange[900]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    // حقل إدخال المبلغ
                    TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: 'المبلغ',
                        prefixIcon: Icon(Icons.attach_money),
                        hintText: 'أدخل المبلغ',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'يرجى إدخال المبلغ';
                        }
                        final amount = double.tryParse(value);
                        if (amount == null || amount <= 0) {
                          return 'يرجى إدخال مبلغ صحيح';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_selectedPaymentMethodId != null)
                      Builder(
                        builder: (context) {
                          dynamic paymentMethod;
                          try {
                            paymentMethod = _paymentMethods.firstWhere(
                              (method) {
                                final methodId = method['id'];
                                if (methodId is int) {
                                  return methodId == _selectedPaymentMethodId;
                                } else if (methodId is String) {
                                  return int.tryParse(methodId) == _selectedPaymentMethodId;
                                }
                                return false;
                              },
                            );
                          } catch (e) {
                            return const SizedBox.shrink();
                          }
                          
                          final discountValue = paymentMethod['discount_percentage'];
                          final discountPercentage = discountValue != null
                              ? (discountValue is double 
                                  ? discountValue 
                                  : discountValue is int 
                                      ? discountValue.toDouble() 
                                      : double.tryParse(discountValue.toString()) ?? 0.0)
                              : 0.0;
                          
                          final amount = double.tryParse(_amountController.text) ?? 0;
                          final discountedAmount = amount * (1 - discountPercentage / 100);

                          if (amount > 0 && discountPercentage > 0) {
                            return Card(
                              color: Colors.blue[50],
                              margin: const EdgeInsets.only(top: 16),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'المبلغ الأصلي: ${amount.toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    Text(
                                      'نسبة الخصم: ${discountPercentage.toStringAsFixed(2)}%',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    Text(
                                      'المبلغ بعد الخصم: ${discountedAmount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    const SizedBox(height: 24),
                    const Text(
                      'إيصال الدفع',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_receiptFile != null)
                      Card(
                        child: Column(
                          children: [
                            Image.file(
                              _receiptFile!,
                              height: 200,
                              fit: BoxFit.contain,
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                TextButton.icon(
                                  onPressed: _pickReceipt,
                                  icon: const Icon(Icons.photo_library),
                                  label: const Text('تغيير الصورة'),
                                ),
                                TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _receiptFile = null;
                                    });
                                  },
                                  icon: const Icon(Icons.delete),
                                  label: const Text('حذف'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                    else
                      Row(
                        children: [
                          Flexible(
                            flex: 1,
                            child: ElevatedButton.icon(
                              onPressed: _pickReceipt,
                              icon: const Icon(Icons.photo_library),
                              label: const Text('اختر من المعرض'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            flex: 1,
                            child: ElevatedButton.icon(
                              onPressed: _takePhoto,
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('التقط صورة'),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitRequest,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'إرسال طلب الدفعة',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                    // Balance Add Requests Section
                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'طلبات الدفعة السابقة',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: _loadBalanceAddRequests,
                          tooltip: 'تحديث',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _isLoadingRequests
                        ? const Center(child: CircularProgressIndicator())
                        : _balanceAddRequests.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24.0),
                                  child: Column(
                                    children: [
                                      Icon(Icons.payment, size: 64, color: Colors.grey),
                                      SizedBox(height: 16),
                                      Text(
                                        'لا توجد طلبات دفعة',
                                        style: TextStyle(fontSize: 16, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _balanceAddRequests.length,
                                itemBuilder: (context, index) {
                                  final request = _balanceAddRequests[index];
                                  return _BalanceAddCard(request: request);
                                },
                              ),
                      ],
                    ),
                  ),
                ),
              ),
    );
  }
}

class _BalanceAddCard extends StatelessWidget {
  final dynamic request;

  const _BalanceAddCard({required this.request});

  Color _getStatusColor(bool isProcessed) {
    return isProcessed ? Colors.green : Colors.orange;
  }

  String _getStatusText(bool isProcessed) {
    return isProcessed ? 'مكتمل' : 'قيد الانتظار';
  }

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return 'غير محدد';
    try {
      if (dateValue is String) {
        return DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(dateValue));
      }
      return 'غير محدد';
    } catch (e) {
      return dateValue.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isProcessed = request['is_processed'] ?? false;
    final amount = request['amount'];
    final amountValue = amount is String 
        ? double.tryParse(amount) ?? 0.0 
        : amount is double 
            ? amount 
            : amount is int 
                ? amount.toDouble() 
                : 0.0;
    final paymentMethod = request['payment_method'];
    final receiptUrl = request['receipt_url'];
    final createdAt = request['created_at'];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(isProcessed),
          child: Text(
            '#${request['id'] ?? ''}',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        title: Text(
          'طلب دفعة #${request['id'] ?? ''}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatDate(createdAt),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _getStatusColor(isProcessed).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getStatusText(isProcessed),
                style: TextStyle(
                  fontSize: 11,
                  color: _getStatusColor(isProcessed),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        children: [
          ListTile(
            leading: const Icon(Icons.payment),
            title: const Text('المبلغ'),
            trailing: Text(
              amountValue.toStringAsFixed(4),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          if (paymentMethod != null)
            ListTile(
              leading: const Icon(Icons.account_balance_wallet),
              title: const Text('طريقة الدفع'),
              trailing: Text(
                paymentMethod['name']?.toString() ?? 'غير محدد',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          if (receiptUrl != null)
            ListTile(
              leading: const Icon(Icons.receipt),
              title: const Text('إيصال الدفع'),
              trailing: IconButton(
                icon: const Icon(Icons.visibility),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => Dialog(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppBar(
                            title: const Text('إيصال الدفع'),
                            leading: IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                          Flexible(
                            child: OptimizedImage(
                              imageUrl: receiptUrl,
                              fit: BoxFit.contain,
                              errorWidget: const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text('فشل تحميل الصورة'),
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
        ],
      ),
    );
  }
}


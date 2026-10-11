import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/product_model.dart';
import '../../widgets/app_drawer.dart';
import '../../utils/profit_rates.dart';
import '../auth/login_screen.dart';
import '../orders/orders_screen.dart';

class PackageOrderScreen extends StatefulWidget {
  final PackageModel package;

  const PackageOrderScreen({super.key, required this.package});

  @override
  State<PackageOrderScreen> createState() => _PackageOrderScreenState();
}

class _PackageOrderScreenState extends State<PackageOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _gamerIdController = TextEditingController();
  final _quantityController = TextEditingController();
  double _quantity = 1.0;

  @override
  void initState() {
    super.initState();
    if (widget.package.isCustom) {
      _quantityController.text = '1';
      _quantity = 1.0;
    } else {
      _quantity = widget.package.quantity.toDouble();
      _quantityController.text = _quantity.toStringAsFixed(widget.package.product.allowDecimalQty ? 4 : 0);
    }
  }

  @override
  void dispose() {
    _gamerIdController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;

    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // محاولة تحميل الملف الشخصي إذا لم يكن محملاً
    if (authProvider.isAuthenticated && authProvider.userProfile == null) {
      await authProvider.loadProfile();
    }

    // التحقق من المصادقة
    if (!authProvider.isAuthenticated || authProvider.userProfile == null) {
      if (!mounted) return;
      final shouldLogin = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تسجيل الدخول مطلوب'),
          content: const Text('يجب تسجيل الدخول لإنشاء طلب جديد'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('تسجيل الدخول'),
            ),
          ],
        ),
      );

      if (shouldLogin == true && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const LoginScreen(),
          ),
        );
      }
      return;
    }

    // تحويل الكمية إلى double إذا كان المنتج يسمح بالكمية العشرية
    final product = widget.package.product;
    final quantity = product.allowDecimalQty 
        ? (double.tryParse(_quantityController.text) ?? _quantity)
        : (int.tryParse(_quantityController.text) ?? _quantity.toInt()).toDouble();
    
    // التحقق من الرصيد والسعر يتم في Django فقط
    // Django هو المصدر الوحيد للحقيقة ويحسب السعر النهائي مع الربح حسب المستوى

    final success = await orderProvider.createOrder(
      packageId: widget.package.id,
      quantity: quantity,
      gamerId: _gamerIdController.text.trim(),
      customQuantity: widget.package.isCustom ? quantity : null,
    );

    if (!mounted) return;
    
    if (success) {
      // تحديث الرصيد مباشرة بعد نجاح الطلب
      await authProvider.loadProfile();
      
      // عرض popup نجاح مع أيقونة علامة صح
      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 60,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'تم إنشاء الطلب بنجاح',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // الانتقال لصفحة الطلبات
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const OrdersScreen()),
                    (route) => route.isFirst,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'موافق',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // عرض رسالة الخطأ من Django مع تفاصيل الرصيد
      final errorMessage = orderProvider.error ?? 'فشل إنشاء الطلب';
      
      // طباعة للتصحيح
      print('Error message in UI: $errorMessage');
      
      // تنظيف الرسالة من أي أرقام status code في النهاية
      String cleanErrorMessage = errorMessage;
      // إزالة "400" أو أي رقم في النهاية
      cleanErrorMessage = cleanErrorMessage.replaceAll(RegExp(r'\s*\d+\s*$'), '').trim();
      
      // التحقق من أن الخطأ متعلق بالرصيد
      final isBalanceError = cleanErrorMessage.contains('الرصيد غير كافي') ||
          cleanErrorMessage.contains('المطلوب:') ||
          cleanErrorMessage.contains('المتاح:') ||
          cleanErrorMessage.contains('النقص:') ||
          cleanErrorMessage.contains('غير كافي');
      
      if (!mounted) return;
      
      // استخراج تفاصيل الرصيد من الرسالة
      String? requiredBalance;
      String? availableBalance;
      String? shortage;
      
      if (isBalanceError) {
        // محاولة استخراج القيم من الرسالة
        final lines = cleanErrorMessage.split('\n');
        for (var line in lines) {
          if (line.contains('المطلوب:')) {
            requiredBalance = line.replaceAll('المطلوب:', '').trim();
          } else if (line.contains('المتاح:')) {
            availableBalance = line.replaceAll('المتاح:', '').trim();
          } else if (line.contains('النقص:')) {
            shortage = line.replaceAll('النقص:', '').trim();
          }
        }
        
        print('Extracted balance details:');
        print('  Required: $requiredBalance');
        print('  Available: $availableBalance');
        print('  Shortage: $shortage');
      }
      
      // عرض رسالة خطأ واضحة للرصيد
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isBalanceError 
                      ? 'الرصيد غير كافي'
                      : 'فشل إنشاء الطلب',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isBalanceError) ...[
                  const Text(
                    'عذراً، لا يمكنك إتمام الطلب بسبب عدم توفر رصيد كافي.',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'تفاصيل الرصيد:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  if (requiredBalance != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'المبلغ المطلوب:',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        Text(
                          '\$$requiredBalance',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (availableBalance != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'الرصيد المتاح:',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        Text(
                          '\$$availableBalance',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (shortage != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'المبلغ الناقص:',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        Text(
                          '\$$shortage',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (requiredBalance == null && availableBalance == null && shortage == null) ...[
                    // إذا لم تكن هناك تفاصيل، اعرض الرسالة الأصلية
                    Text(
                      errorMessage,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ] else ...[
                  // للرسائل الأخرى غير الرصيد
                  Text(
                    errorMessage,
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('موافق', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      );
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
        ],
        title: const Text('إنشاء طلب'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // تحديث الملف الشخصي للحصول على الرصيد المحدث
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          await authProvider.loadProfile();
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.package.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      if (widget.package.isCustom)
                        Text('الكمية: ${widget.package.quantity} (قابلة للتعديل)')
                      else
                        Text('الكمية: ${widget.package.quantity}'),
                      // Text(
                      //   widget.package.isCustom
                      //       ? 'سعر الوحدة: ${(widget.package.product.coinsPrice ?? 0.0).toStringAsFixed(4)}'
                      //       : 'السعر: ${widget.package.calculatedPrice.toStringAsFixed(4)}',
                      //   style: TextStyle(
                      //     fontSize: 18,
                      //     fontWeight: FontWeight.bold,
                      //     color: Theme.of(context).colorScheme.primary,
                      //   ),
                      // ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (widget.package.isCustom)
                TextFormField(
                  controller: _quantityController,
                  decoration: InputDecoration(
                    labelText: widget.package.product.allowDecimalQty 
                        ? 'الكمية المطلوبة (يمكن استخدام أرقام عشرية)'
                        : 'الكمية المطلوبة',
                    prefixIcon: const Icon(Icons.numbers),
                    helperText: widget.package.product.allowDecimalQty 
                        ? 'مثال: 1.5 أو 2.75'
                        : null,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'يرجى إدخال الكمية';
                    }
                    final product = widget.package.product;
                    
                    if (product.allowDecimalQty) {
                      // السماح بالكمية العشرية
                      final qty = double.tryParse(value);
                      if (qty == null || qty <= 0) {
                        return 'يرجى إدخال كمية صحيحة';
                      }
                      // التحقق من الحد الأدنى والأقصى للكمية
                      if (product.minCustomQuantity != null && qty < product.minCustomQuantity!) {
                        return 'الكمية يجب أن تكون على الأقل ${product.minCustomQuantity}';
                      }
                      if (product.maxCustomQuantity != null && qty > product.maxCustomQuantity!) {
                        return 'الكمية يجب أن تكون على الأكثر ${product.maxCustomQuantity}';
                      }
                    } else {
                      // يجب أن تكون الكمية عدد صحيح
                      final qty = int.tryParse(value);
                      if (qty == null || qty <= 0) {
                        return 'يرجى إدخال كمية صحيحة (عدد صحيح فقط)';
                      }
                      // التحقق من الحد الأدنى والأقصى للكمية
                      if (product.minCustomQuantity != null && qty < product.minCustomQuantity!) {
                        return 'الكمية يجب أن تكون على الأقل ${product.minCustomQuantity}';
                      }
                      if (product.maxCustomQuantity != null && qty > product.maxCustomQuantity!) {
                        return 'الكمية يجب أن تكون على الأكثر ${product.maxCustomQuantity}';
                      }
                    }
                    return null;
                  },
                  onChanged: (value) {
                    setState(() {
                      final product = widget.package.product;
                      if (product.allowDecimalQty) {
                        _quantity = double.tryParse(value) ?? 1.0;
                      } else {
                        _quantity = (int.tryParse(value) ?? 1).toDouble();
                      }
                    });
                  },
                )
              else
                TextFormField(
                  controller: _quantityController,
                  decoration: const InputDecoration(
                    labelText: 'الكمية',
                    prefixIcon: Icon(Icons.numbers),
                  ),
                  enabled: false,
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _gamerIdController,
                decoration: InputDecoration(
                  labelText: widget.package.product.category.inputLabel ??
                      'معرف اللاعب',
                  hintText: widget.package.product.category.inputPlaceholder ??
                      'أدخل معرف اللاعب',
                  prefixIcon: const Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال معرف اللاعب';
                  }
                  // التحقق من أن gamer_id يحتوي على الأرقام والحروف الإنجليزية والرموز فقط
                  final pattern = RegExp(r'^[a-zA-Z0-9@._\-+]+$');
                  if (!pattern.hasMatch(value)) {
                    return 'معرف اللاعب يجب أن يحتوي على الأرقام والحروف الإنجليزية والرموز فقط (@, ., _, -, +)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Consumer<AuthProvider>(
                builder: (context, authProvider, _) {
                  final product = widget.package.product;
                  final quantity = product.allowDecimalQty 
                      ? (double.tryParse(_quantityController.text) ?? _quantity)
                      : (int.tryParse(_quantityController.text) ?? _quantity.toInt()).toDouble();
                  
                  // نفس حساب الموقع/Django (PROFIT_CHOICES — vip1 = 0%)
                  final userProfile = authProvider.userProfile;
                  double finalPrice = ProfitRates.calculateFinalPrice(
                    isCustom: widget.package.isCustom,
                    coinsPrice: widget.package.product.coinsPrice,
                    quantity: quantity,
                    packagePrice: widget.package.price,
                    level: userProfile?.level,
                    currency: userProfile?.currency,
                    exchangeRate: authProvider.exchangeRate,
                  );
                  
                  final balance = userProfile?.balance ?? 0.0;
                  
                  // تحويل الرصيد حسب عملة المستخدم
                  double convertedBalance = balance;
                  if (userProfile?.currency == 'SYP') {
                    convertedBalance = balance * authProvider.exchangeRate;
                  }
                  
                  return Card(
                    color: Colors.blue[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  'السعر النهائي (سيتم خصمه من الرصيد):',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${finalPrice.toStringAsFixed(4)} ${userProfile?.currency ?? 'USD'}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Flexible(
                                child: Text(
                                  'الرصيد المتاح:',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${convertedBalance.toStringAsFixed(4)} ${userProfile?.currency ?? 'USD'}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: balance >= (finalPrice / (userProfile?.currency == 'SYP' ? authProvider.exchangeRate : 1.0)) ? Colors.green : Colors.red,
                                ),
                              ),
                            ],
                          ),
                          if (balance < finalPrice)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                'الرصيد غير كافي. النقص: ${(finalPrice - balance).toStringAsFixed(4)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Consumer<OrderProvider>(
                builder: (context, orderProvider, _) {
                  return ElevatedButton(
                    onPressed: orderProvider.isLoading ? null : _submitOrder,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: orderProvider.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'تأكيد الطلب',
                            style: TextStyle(fontSize: 16),
                          ),
                  );
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



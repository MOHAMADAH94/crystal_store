import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/order_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/order_model.dart';
import '../../widgets/app_drawer.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatus = 'all'; // all, pending, done, rejected
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrdersWithUpdate();
    });
  }
  
  // دالة لتحميل الطلبات مع تحديث الحالة (تحميل واحد ظاهر، الباقي في الخلفية)
  Future<void> _loadOrdersWithUpdate() async {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    await orderProvider.loadOrders();
    Future.delayed(const Duration(milliseconds: 800), () => orderProvider.loadOrders(silent: true));
    Future.delayed(const Duration(milliseconds: 2000), () => orderProvider.loadOrders(silent: true));
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  List<OrderModel> _filterOrders(List<OrderModel> orders) {
    var filtered = orders;
    
    // Filter by status
    if (_selectedStatus != 'all') {
      filtered = filtered.where((order) {
        if (order.details.isEmpty) return false;
        final status = order.details.first.status.toLowerCase();
        return status == _selectedStatus.toLowerCase();
      }).toList();
    }
    
    // Filter by search query
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((order) {
        return order.id.toString().contains(query) ||
               order.details.any((detail) => 
                 detail.package.name.toLowerCase().contains(query) ||
                 detail.gamerId.toLowerCase().contains(query)
               );
      }).toList();
    }
    
    return filtered;
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
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () async {
                final orderProvider = Provider.of<OrderProvider>(context, listen: false);
                await orderProvider.loadOrders();
                Future.delayed(const Duration(milliseconds: 800), () => orderProvider.loadOrders(silent: true));
                Future.delayed(const Duration(milliseconds: 2000), () => orderProvider.loadOrders(silent: true));
              },
            ),
        ],
      ),
      body: Consumer<OrderProvider>(
        builder: (context, orderProvider, _) {
          if (orderProvider.isLoading && orderProvider.orders.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (orderProvider.error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'خطأ في تحميل الطلبات',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      orderProvider.error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => orderProvider.loadOrders(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            );
          }

          final filteredOrders = _filterOrders(orderProvider.orders);
          
          return Column(
            children: [
              // Search and Filter Bar
              Container(
                padding: const EdgeInsets.all(16),
                color: Theme.of(context).cardColor,
                child: Column(
                  children: [
                    // Search Field
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'ابحث عن طلب (رقم الطلب، اسم المنتج، معرف اللاعب)',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                  });
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    // Status Filter
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('فلترة حسب الحالة: '),
                        const SizedBox(height: 8),
                        ToggleButtons(
                          isSelected: [
                            _selectedStatus == 'all',
                            _selectedStatus == 'pending',
                            _selectedStatus == 'done',
                            _selectedStatus == 'rejected',
                          ],
                          onPressed: (index) {
                            setState(() {
                              switch (index) {
                                case 0:
                                  _selectedStatus = 'all';
                                  break;
                                case 1:
                                  _selectedStatus = 'pending';
                                  break;
                                case 2:
                                  _selectedStatus = 'done';
                                  break;
                                case 3:
                                  _selectedStatus = 'rejected';
                                  break;
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          constraints: const BoxConstraints(
                            minHeight: 40,
                            minWidth: 80,
                          ),
                          children: const [
                            Text('الكل'),
                            Text('قيد الانتظار'),
                            Text('مكتمل'),
                            Text('مرفوض'),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Orders List
              Expanded(
                child: filteredOrders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.receipt_long, size: 80, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              orderProvider.orders.isEmpty
                                  ? 'لا توجد طلبات'
                                  : 'لا توجد طلبات تطابق البحث',
                              style: const TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          await orderProvider.loadOrders();
                          Future.delayed(const Duration(milliseconds: 800), () => orderProvider.loadOrders(silent: true));
                          Future.delayed(const Duration(milliseconds: 2000), () => orderProvider.loadOrders(silent: true));
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredOrders.length,
                          itemBuilder: (context, index) {
                            final order = filteredOrders[index];
                            return _OrderCard(order: order);
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
      ),
    );
  }
}

class _OrderCard extends StatefulWidget {
  final OrderModel order;

  const _OrderCard({required this.order});

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  bool _isExpanded = false;

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'done':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'done':
        return 'مكتمل';
      case 'rejected':
        return 'مرفوض';
      case 'pending':
      default:
        return 'قيد الانتظار';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _getStatusColor(widget.order.details.firstOrNull?.status ?? 'pending'),
                    child: Text(
                      '#${widget.order.id}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'طلب #${widget.order.id}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(widget.order.orderDate),
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        if (widget.order.details.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getStatusColor(widget.order.details.first.status).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _getStatusText(widget.order.details.first.status),
                              style: TextStyle(
                                fontSize: 11,
                                color: _getStatusColor(widget.order.details.first.status),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            Consumer<AuthProvider>(
              builder: (context, authProvider, _) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: widget.order.details.map((detail) {
                      // حساب الرصيد السابق واللاحق
                      final userProfile = authProvider.userProfile;
                      final currentBalance = userProfile?.balance ?? 0.0;
                      // الطلب المرفوض: تم استرداد المبلغ فالرصيد السابق = الرصيد الحالي
                      final bool wasRefunded = detail.status == 'rejected';
                      final balanceBefore = wasRefunded ? currentBalance : (currentBalance + detail.finalPrice);
                      final balanceAfter = currentBalance;
                      
                      // تحويل القيم حسب عملة المستخدم
                      final String currency = userProfile?.currency ?? 'USD';
                      final String currencySymbol = currency == 'SYP' ? 'SYP' : 'USD';
                      final double exchangeRate = authProvider.exchangeRate;
                      
                      double convertToUserCurrency(double usdAmount) {
                        return currency == 'SYP' ? usdAmount * exchangeRate : usdAmount;
                      }
                      
                      final convertedFinalPrice = convertToUserCurrency(detail.finalPrice);
                      final convertedBalanceBefore = convertToUserCurrency(balanceBefore);
                      final convertedBalanceAfter = convertToUserCurrency(balanceAfter);
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // اسم الباقة
                            _DetailRow(
                              icon: Icons.inventory_2_rounded,
                              label: 'اسم الباقة',
                              value: detail.package.name,
                              isBold: true,
                            ),
                            const Divider(height: 24),
                            // التاريخ
                            _DetailRow(
                              icon: Icons.calendar_today_rounded,
                              label: 'تاريخ الطلب',
                              value: _formatDate(widget.order.orderDate),
                            ),
                            const Divider(height: 24),
                            // معرف اللاعب
                            _DetailRow(
                              icon: Icons.person_rounded,
                              label: 'معرف اللاعب',
                              value: detail.gamerId,
                            ),
                            const Divider(height: 24),
                            // الكمية
                            _DetailRow(
                              icon: Icons.numbers_rounded,
                              label: 'الكمية',
                              value: detail.quantity.toString(),
                            ),
                            const Divider(height: 24),
                            // المبلغ المخصوم
                            _DetailRow(
                              icon: Icons.payments_rounded,
                              label: 'المبلغ المخصوم',
                              value: '${convertedFinalPrice.toStringAsFixed(4)} $currencySymbol',
                              valueColor: Colors.red,
                              isBold: true,
                            ),
                            const Divider(height: 24),
                            // الرصيد السابق
                            _DetailRow(
                              icon: Icons.account_balance_wallet_rounded,
                              label: 'الرصيد السابق',
                              value: '${convertedBalanceBefore.toStringAsFixed(4)} $currencySymbol',
                              valueColor: Colors.blue,
                              isBold: true,
                            ),
                            const Divider(height: 24),
                            // الرصيد بعد الطلب
                            _DetailRow(
                              icon: Icons.account_balance_rounded,
                              label: 'الرصيد بعد الطلب',
                              value: '${convertedBalanceAfter.toStringAsFixed(4)} $currencySymbol',
                              valueColor: Colors.green,
                              isBold: true,
                            ),

                            const Divider(height: 24),
                            // الحالة
                            _DetailRow(
                              icon: Icons.info_outline_rounded,
                              label: 'الحالة',
                              value: _getStatusText(detail.status),
                              valueColor: _getStatusColor(detail.status),
                              isBold: true,
                            ),
                            // ملاحظات الطلب (الرد من API) إن وجدت
                            if (detail.response != null && detail.response!.isNotEmpty) ...[
                              const Divider(height: 24),
                              _DetailRow(
                                icon: detail.status == 'done' 
                                    ? Icons.check_circle_rounded 
                                    : detail.status == 'rejected'
                                        ? Icons.cancel_rounded
                                        : Icons.message_rounded,
                                label: 'ملاحظات الطلب',
                                value: detail.response!,
                                valueColor: detail.status == 'done' 
                                    ? Colors.green 
                                    : detail.status == 'rejected'
                                        ? Colors.red
                                        : Colors.blue,
                                isMultiline: true,
                                isBold: true,
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

extension ListExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

String _formatDate(DateTime date) {
  try {
    return DateFormat('yyyy-MM-dd HH:mm').format(date);
  } catch (e) {
    return date.toString();
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;
  final bool isMultiline;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.isBold = false,
    this.isMultiline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 20,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  color: valueColor ?? Colors.black87,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                ),
                maxLines: isMultiline ? null : 2,
                overflow: isMultiline ? null : TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

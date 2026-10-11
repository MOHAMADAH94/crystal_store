import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../widgets/app_drawer.dart';

class BalanceHistoryScreen extends StatefulWidget {
  const BalanceHistoryScreen({super.key});

  @override
  State<BalanceHistoryScreen> createState() => _BalanceHistoryScreenState();
}

class _BalanceHistoryScreenState extends State<BalanceHistoryScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _history = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _apiService.getBalanceHistory();
      setState(() {
        _history = List.from(data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        String errorMsg = e.toString();
        // Clean up error message
        if (errorMsg.contains('Exception: ')) {
          errorMsg = errorMsg.replaceAll('Exception: ', '');
        }
        _error = errorMsg;
        _isLoading = false;
      });
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
        title: const Text('سجل الرصيد'),
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
                        onPressed: _loadHistory,
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                )
              : _history.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history, size: 80, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'لا توجد سجلات',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadHistory,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _history.length,
                        itemBuilder: (context, index) {
                          final item = _history[index];
                          // Parse balances safely - handle both String and numeric types
                          double parseBalance(dynamic value) {
                            if (value == null) return 0.0;
                            if (value is double) return value;
                            if (value is int) return value.toDouble();
                            if (value is String) {
                              return double.tryParse(value) ?? 0.0;
                            }
                            return 0.0;
                          }
                          
                          final oldBalance = parseBalance(item['old_balance']);
                          final newBalance = parseBalance(item['new_balance']);
                          final change = newBalance - oldBalance;
                          final isPositive = change > 0;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isPositive
                                    ? Colors.green.withOpacity(0.2)
                                    : Colors.red.withOpacity(0.2),
                                child: Icon(
                                  isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                                  color: isPositive ? Colors.green : Colors.red,
                                ),
                              ),
                              title: Text(
                                item['description'] ?? 'تغيير الرصيد',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                _formatDate(item['change_date']),
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    newBalance.toStringAsFixed(4),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    '${isPositive ? '+' : ''}${change.toStringAsFixed(4)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isPositive ? Colors.green : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
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
}


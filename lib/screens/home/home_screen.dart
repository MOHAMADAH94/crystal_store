import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/optimized_image.dart';
import '../../models/product_model.dart';
import '../../utils/profit_rates.dart';
import '../products/package_order_screen.dart';
import '../orders/orders_screen.dart';
import '../profile/profile_screen.dart';
import '../profile/balance_history_screen.dart';
import '../payment/send_money_screen.dart';
import '../pages/about_screen.dart';
import '../pages/terms_screen.dart';
import '../notifications/notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const PackagesHomeScreen(), // 0: الباقات
    const SizedBox.shrink(), // 1: محجوز
    const OrdersScreen(), // 2: طلباتي
    const BalanceHistoryScreen(), // 3: رصيدي
    const SendMoneyScreen(), // 4: إرسال دفعة
    const SizedBox.shrink(), // 5
    const AboutScreen(), // 6
    const TermsScreen(), // 7
    const ProfileScreen(), // 8
    const NotificationsScreen(), // 9
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ProductProvider>(context, listen: false).loadPackages();
    });
  }

  @override
  Widget build(BuildContext context) {
    int bottomNavIndex = 0;
    if (_selectedIndex == 0) {
      bottomNavIndex = 0;
    } else if (_selectedIndex == 2) {
      bottomNavIndex = 1;
    } else if (_selectedIndex == 4) {
      bottomNavIndex = 2;
    }

    return Scaffold(
      endDrawer: AppDrawer(
        selectedIndex: _selectedIndex,
        onItemSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: Builder(
        builder: (context) => Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF7C3AED),
                Color(0xFF8B5CF6),
                Color(0xFFA78BFA),
              ],
            ),
          ),
          child: BottomNavigationBar(
            currentIndex: bottomNavIndex,
            onTap: (index) {
              if (index == 0) {
                setState(() => _selectedIndex = 0);
              } else if (index == 1) {
                setState(() => _selectedIndex = 2);
              } else if (index == 2) {
                setState(() => _selectedIndex = 4);
              } else if (index == 3) {
                Scaffold.of(context).openEndDrawer();
              }
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.white70,
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            unselectedLabelStyle: const TextStyle(fontSize: 11),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.inventory_2_rounded),
                activeIcon: Icon(Icons.inventory_2_rounded),
                label: 'الباقات',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.receipt_long_rounded),
                activeIcon: Icon(Icons.receipt_long_rounded),
                label: 'طلباتي',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.send_rounded),
                activeIcon: Icon(Icons.send_rounded),
                label: 'إرسال دفعة',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.menu_rounded),
                activeIcon: Icon(Icons.menu_rounded),
                label: 'القائمة',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// الشاشة الرئيسية: الباقات فقط — باقة واحدة بالسطر بحجم كبير
class PackagesHomeScreen extends StatelessWidget {
  const PackagesHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ProductProvider, AuthProvider>(
      builder: (context, productProvider, authProvider, _) {
        return Scaffold(
          endDrawer: const AppDrawer(),
          appBar: AppBar(
            leading: const SizedBox.shrink(),
            actions: [
              IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openEndDrawer(),
              ),
            ],
            title: const Text('الباقات'),
          ),
          body: _buildBody(context, productProvider, authProvider),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    ProductProvider productProvider,
    AuthProvider authProvider,
  ) {
    if (productProvider.isLoadingPackages && productProvider.packages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (productProvider.packagesError != null &&
        productProvider.packages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'خطأ: ${productProvider.packagesError}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => productProvider.loadPackages(),
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    if (productProvider.packages.isEmpty) {
      return const Center(child: Text('لا توجد باقات'));
    }

    return RefreshIndicator(
      onRefresh: () => productProvider.loadPackages(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: productProvider.packages.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final package = productProvider.packages[index];
          return _LargePackageCard(
            package: package,
            authProvider: authProvider,
          );
        },
      ),
    );
  }
}

class _LargePackageCard extends StatelessWidget {
  final PackageModel package;
  final AuthProvider authProvider;

  const _LargePackageCard({
    required this.package,
    required this.authProvider,
  });

  double get _displayPrice {
    final profile = authProvider.userProfile;
    // للباقات المخصصة نعرض سعر الوحدة × 1 كمرجع؛ الكمية تُحدد عند الطلب
    final qty = package.isCustom ? 1.0 : package.quantity.toDouble();
    return ProfitRates.calculateFinalPrice(
      isCustom: package.isCustom,
      coinsPrice: package.product.coinsPrice,
      quantity: qty,
      packagePrice: package.price,
      level: profile?.level,
      currency: profile?.currency,
      exchangeRate: authProvider.exchangeRate,
    );
  }

  String get _currencyLabel {
    final currency = authProvider.userProfile?.currency ?? 'USD';
    return currency == 'SYP' ? 'SYP' : 'USD';
  }

  @override
  Widget build(BuildContext context) {
    final price = _displayPrice;

    return Card(
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PackageOrderScreen(package: package),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // الصورة في الأعلى
            AspectRatio(
              aspectRatio: 16 / 10,
              child: package.imageUrl != null
                  ? OptimizedImage(
                      imageUrl: package.imageUrl!,
                      fit: BoxFit.cover,
                      placeholderColor: const Color(0xFF8B5CF6).withOpacity(0.2),
                      errorWidget: Container(
                        color: const Color(0xFF8B5CF6),
                        child: const Center(
                          child: Icon(
                            Icons.inventory_2_rounded,
                            size: 80,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    )
                  : Container(
                      color: const Color(0xFF8B5CF6),
                      child: const Center(
                        child: Icon(
                          Icons.inventory_2_rounded,
                          size: 80,
                          color: Colors.white,
                        ),
                      ),
                    ),
            ),
            // الاسم + التفاصيل + الزر
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    package.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF1F2937),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if ((package.description ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      package.description!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                        height: 1.35,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (package.isCustom)
                    Text(
                      'سعر الوحدة: ${price.toStringAsFixed(4)} $_currencyLabel',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF7C3AED),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  else if (price > 0)
                    Text(
                      'السعر: ${price.toStringAsFixed(4)} $_currencyLabel',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF7C3AED),
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  if (!package.isCustom && package.quantity > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      'الكمية: ${package.quantity}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                PackageOrderScreen(package: package),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        disabledForegroundColor: Colors.white70,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontFamily: 'AlinmaSans',
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          letterSpacing: 0.3,
                        ),
                      ),
                      child: const Text(
                        'شراء الآن',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

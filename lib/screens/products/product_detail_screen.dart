import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/product_model.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/optimized_image.dart';
import '../../utils/profit_rates.dart';
import 'package_order_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final ProductModel product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ProductProvider>(
        context,
        listen: false,
      ).loadPackages(productId: widget.product.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      endDrawer: const AppDrawer(),
      appBar: AppBar(
        leading: const SizedBox.shrink(),
        actions: [
          Builder(
            builder:
                (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () {
                    Scaffold.of(context).openEndDrawer();
                  },
                ),
          ),
        ],
        title: Text(widget.product.name),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Provider.of<ProductProvider>(
            context,
            listen: false,
          ).loadPackages(productId: widget.product.id);
        },
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.product.imageUrl != null)
                OptimizedImage(
                  imageUrl: widget.product.imageUrl!,
                  height: 250,
                  fit: BoxFit.cover,
                  errorWidget: Container(
                    height: 250,
                    color: Colors.grey[300],
                    child: const Icon(Icons.image_not_supported, size: 60),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.product.name,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.product.description,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    if (widget.product.coinsPrice != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        'سعر العملة: ${widget.product.coinsPrice} لكل دولار',
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Text(
                      'الباقات المتاحة',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Consumer<ProductProvider>(
                      builder: (context, productProvider, _) {
                        if (productProvider.isLoadingPackages &&
                            productProvider.packages.isEmpty) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (productProvider.packagesError != null &&
                            productProvider.packages.isEmpty) {
                          return Column(
                            children: [
                              Text(
                                'خطأ: ${productProvider.packagesError}',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () {
                                  productProvider.loadPackages(
                                    productId: widget.product.id,
                                  );
                                },
                                child: const Text('إعادة المحاولة'),
                              ),
                            ],
                          );
                        }

                        if (productProvider.packages.isEmpty) {
                          return const Center(
                            child: Text('لا توجد باقات متاحة'),
                          );
                        }

                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 0.72,
                          ),
                          itemCount: productProvider.packages.length,
                          itemBuilder: (context, index) {
                            final package = productProvider.packages[index];
                            return _PackageCard(package: package);
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  final PackageModel package;

  const _PackageCard({required this.package});

  double _calculateFinalPrice(AuthProvider authProvider) {
    final userProfile = authProvider.userProfile;
    final qty = package.isCustom ? 1.0 : package.quantity.toDouble();
    return ProfitRates.calculateFinalPrice(
      isCustom: package.isCustom,
      coinsPrice: package.product.coinsPrice,
      quantity: qty,
      packagePrice: package.price,
      level: userProfile?.level,
      currency: userProfile?.currency,
      exchangeRate: authProvider.exchangeRate,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PackageOrderScreen(package: package),
            ),
          );
        },
        child: Container(
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                  ),
                  child: package.imageUrl != null
                      ? OptimizedImage(
                          imageUrl: package.imageUrl!,
                          fit: BoxFit.cover,
                          placeholderColor: Colors.white.withOpacity(0.1),
                          errorWidget: const Icon(
                            Icons.inventory_2_rounded,
                            size: 48,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.inventory_2_rounded,
                          size: 48,
                          color: Colors.white,
                        ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      package.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Text(
                    //   'الكمية: ${package.quantity}',
                    //   style: TextStyle(
                    //     fontSize: 11,
                    //     color: Colors.white.withOpacity(0.9),
                    //   ),
                    // ),
                    Consumer<AuthProvider>(
                      builder: (context, authProvider, _) {
                        final finalPrice = _calculateFinalPrice(authProvider);
                        if (!package.isCustom && finalPrice <= 0) {
                          return const SizedBox.shrink();
                        }

                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'السعر: ${finalPrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 34,
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
                          backgroundColor: Colors.white,
                          foregroundColor:
                              Theme.of(context).colorScheme.primary,
                          padding: EdgeInsets.zero,
                          textStyle: const TextStyle(
                            fontFamily: 'AlinmaSans',
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        child: const Text('شراء'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

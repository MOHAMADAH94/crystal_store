import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/product_provider.dart';
import '../../models/product_model.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/optimized_image.dart';
import 'product_detail_screen.dart';

class ProductsScreen extends StatefulWidget {
  final int? categoryId;

  const ProductsScreen({super.key, this.categoryId});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ProductProvider>(context, listen: false).loadProducts(
        categoryId: widget.categoryId,
      );
    });
  }
  
  @override
  void didUpdateWidget(ProductsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // إذا تغير categoryId، قم بتحميل المنتجات الجديدة
    if (oldWidget.categoryId != widget.categoryId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Provider.of<ProductProvider>(context, listen: false).loadProducts(
          categoryId: widget.categoryId,
        );
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
          title: Text(widget.categoryId == null ? 'المنتجات' : 'منتجات الفئة'),
        ),
      body: Consumer<ProductProvider>(
        builder: (context, productProvider, _) {
          if (productProvider.isLoadingProducts && productProvider.products.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (productProvider.productsError != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('خطأ: ${productProvider.productsError}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => productProvider.loadProducts(
                      categoryId: widget.categoryId,
                    ),
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            );
          }

          if (productProvider.products.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {
                await productProvider.loadProducts(categoryId: widget.categoryId);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: const Center(child: Text('لا توجد منتجات')),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await productProvider.loadProducts(categoryId: widget.categoryId);
            },
            child: GridView.builder(
              padding: EdgeInsets.zero, // 👈 مهم

              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 1,
                mainAxisSpacing: 1,
                childAspectRatio: 0.75,
              ),
              itemCount: productProvider.products.length,
              itemBuilder: (context, index) {
                final product = productProvider.products[index];
                return _ProductCard(product: product);
              },
            ),
          );
        },
      ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ProductModel product;

  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProductDetailScreen(product: product),
            ),
          );
        },
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF7C3AED), // Purple
                Color(0xFF8B5CF6), // Light Purple
                Color(0xFFA78BFA), // Lighter Purple
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
                  child: product.imageUrl != null
                      ? OptimizedImage(
                          imageUrl: product.imageUrl!,
                          fit: BoxFit.cover,
                          placeholderColor: Colors.white.withOpacity(0.1),
                          errorWidget: const Icon(
                            Icons.image_not_supported_rounded,
                            size: 60,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.image_rounded,
                          size: 60,
                          color: Colors.white,
                        ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12.0),
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
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Text(
                    //   product.description,
                    //   style: TextStyle(
                    //     fontSize: 12,
                    //     color: Colors.white.withOpacity(0.9),
                    //   ),
                    //   maxLines: 2,
                    //   overflow: TextOverflow.ellipsis,
                    // ),
                    if (product.packagesCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Row(
                          children: [
                            // const Icon(
                            //   Icons.inventory_2_rounded,
                            //   size: 14,
                            //   color: Colors.white,
                            // ),
                            const SizedBox(width: 4),
                            // Text(
                            //   '${product.packagesCount} باقة',
                            //   style: const TextStyle(
                            //     fontSize: 11,
                            //     color: Colors.white,
                            //     fontWeight: FontWeight.w600,
                            //   ),
                            // ),
                          ],
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



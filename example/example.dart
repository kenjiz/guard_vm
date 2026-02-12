// Example demonstrating Guard VM usage patterns
// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:guard_vm/guard_vm.dart';

/// Example demonstrating Guard VM usage patterns
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Guard VM Example',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const ProductListScreen(),
    );
  }
}

// ============================================================================
// MODELS
// ============================================================================

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.price,
    this.isFavorite = false,
  });

  final String id;
  final String name;
  final double price;
  final bool isFavorite;

  Product copyWith({
    String? id,
    String? name,
    double? price,
    bool? isFavorite,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}

// ============================================================================
// REPOSITORY (Data Layer)
// ============================================================================

class ProductRepository {
  // Simulates API call with delay
  Future<PaginatedState<Product>> getProducts({int page = 1, int limit = 10}) async {
    await Future<void>.delayed(const Duration(seconds: 1));

    if (page > 3) {
      // Simulate no more data
      return PaginatedState<Product>(
        items: const [],
        currentPage: page,
        totalPages: 3,
        totalItems: 30,
        hasReachedEnd: true,
      );
    }

    // Generate mock products
    final startIndex = (page - 1) * limit;
    final products = List.generate(
      limit,
      (i) => Product(
        id: '${startIndex + i}',
        name: 'Product ${startIndex + i}',
        price: (startIndex + i) * 10.0,
      ),
    );

    return PaginatedState<Product>(
      items: products,
      currentPage: page,
      totalPages: 3,
      totalItems: 30,
    );
  }

  Future<Product> toggleFavorite(Product product) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    // Randomly fail to demonstrate error handling
    if (DateTime.now().millisecond % 5 == 0) {
      throw Exception('Failed to toggle favorite');
    }
    return product.copyWith(isFavorite: !product.isFavorite);
  }

  Stream<int> cartCountStream() async* {
    var count = 0;
    while (true) {
      await Future<void>.delayed(const Duration(seconds: 2));
      count++;
      yield count;
    }
  }
}

// ============================================================================
// VIEW MODELS
// ============================================================================

/// Example 1: PaginatedGuardVM for infinite scroll
class ProductListVM extends PaginatedGuardVM<Product> {
  ProductListVM(this._repository)
    : super(
        const AsyncValue.data(
          PaginatedState(
            items: [],
            currentPage: 0,
            totalPages: 1,
            totalItems: 0,
          ),
        ),
      );

  final ProductRepository _repository;

  /// Initial load
  Future<void> loadInitial() async {
    await guard(_repository.getProducts);
  }

  /// Load more for infinite scroll
  Future<void> loadMore() async {
    await guardLoadMore((current) async {
      final response = await _repository.getProducts(
        page: current.currentPage + 1,
      );

      return PaginatedState(
        items: [...current.items, ...response.items],
        currentPage: response.currentPage,
        totalPages: response.totalPages,
        totalItems: response.totalItems,
        hasReachedEnd: response.hasReachedEnd,
      );
    });
  }

  /// Pull to refresh
  Future<void> onRefresh() async {
    await refreshPaginated(_repository.getProducts);
  }

  /// Optimistic update with rollback on error
  Future<void> toggleFavorite(Product product) async {
    await guardUpdate((current) async {
      // Optimistically update the product in the list
      final updatedItems = current.items.map((p) {
        if (p.id == product.id) {
          return p.copyWith(isFavorite: !p.isFavorite);
        }
        return p;
      }).toList();

      final updatedProduct = await _repository.toggleFavorite(product);

      return current.copyWith(
        items: updatedItems.map((p) {
          if (p.id == updatedProduct.id) {
            return updatedProduct;
          }
          return p;
        }).toList(),
      );
    });
  }
}

/// Example 2: StreamGuardVM for real-time updates
class CartCountVM extends StreamGuardVM<int> {
  CartCountVM(this._repository) : super(const AsyncValue.data(0));

  final ProductRepository _repository;

  void startListening() {
    guardStream(
      _repository.cartCountStream(),
      (count) => print('Cart updated: $count items'),
    );
  }
}

/// Example 3: CoordinatedVM - reacts to other VMs
class TotalPriceVM extends CoordinatedVM<double> {
  TotalPriceVM(this._cartCountVM, this._productListVM) : super(const AsyncValue.data(0)) {
    // Calculate total price whenever cart or products change
    // executeImmediately is true by default, so it runs with current state
    coordinateWith(
      _cartCountVM,
      _calculateTotal,
      null, // onError - use default error propagation
      null, // onLoading - ignore loading state
    );

    coordinateWith(
      _productListVM,
      _updateProductList,
      (error) {
        // Custom error handler - reset total on error
        print('Product list error: $error');
        setData(0);
      },
      () {
        // Loading handler - show zero while loading
        setData(0);
      },
    );
  }

  final CartCountVM _cartCountVM;
  final ProductListVM _productListVM;

  void _calculateTotal(int count) {
    final currentProducts = _productListVM.value.value?.items ?? [];
    final total = currentProducts
        .take(count)
        .fold(
          0.0,
          (sum, product) => sum + product.price,
        );
    setData(total);
  }

  void _updateProductList(PaginatedState<Product> state) {
    _calculateTotal(_cartCountVM.value.value ?? 0);
  }
}

// ============================================================================
// UI
// ============================================================================

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  late final ProductRepository _repository;
  late final ProductListVM _productListVM;
  late final CartCountVM _cartCountVM;
  late final TotalPriceVM _totalPriceVM;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _repository = ProductRepository();
    _productListVM = ProductListVM(_repository);
    _cartCountVM = CartCountVM(_repository);
    _totalPriceVM = TotalPriceVM(_cartCountVM, _productListVM);
    _scrollController = ScrollController()..addListener(_onScroll);

    // Initial loads
    _productListVM.loadInitial();
    _cartCountVM.startListening();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _productListVM.dispose();
    _cartCountVM.dispose();
    _totalPriceVM.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8) {
      _productListVM.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Guard VM Example'),
        actions: [
          // Example: StreamGuardVM usage
          GuardValueListenableBuilder<int>(
            listenable: _cartCountVM,
            data: (context, count) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Cart: $count', style: const TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Example: CoordinatedVM usage
          GuardValueListenableBuilder<double>(
            listenable: _totalPriceVM,
            data: (context, total) => Container(
              padding: const EdgeInsets.all(16),
              color: Colors.blue.shade50,
              child: Text(
                'Total: \$${total.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // Example: PaginatedGuardVM usage
          Expanded(
            child: GuardValueListenableBuilder<PaginatedState<Product>>(
              listenable: _productListVM,
              data: (context, state) => RefreshIndicator(
                onRefresh: _productListVM.onRefresh,
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: state.items.length + (state.isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    // Show loading indicator at bottom
                    if (index == state.items.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final product = state.items[index];
                    return ListTile(
                      leading: CircleAvatar(child: Text(product.id)),
                      title: Text(product.name),
                      subtitle: Text('\$${product.price.toStringAsFixed(2)}'),
                      trailing: IconButton(
                        icon: Icon(
                          product.isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: product.isFavorite ? Colors.red : null,
                        ),
                        onPressed: () => _productListVM.toggleFavorite(product),
                      ),
                    );
                  },
                ),
              ),
              loading: (context) => const Center(child: CircularProgressIndicator()),
              error: (context, error) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Error: $error'),
                    ElevatedButton(
                      onPressed: _productListVM.loadInitial,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

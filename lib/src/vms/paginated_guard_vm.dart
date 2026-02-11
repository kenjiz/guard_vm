import 'package:guard_vm/src/models/models.dart';
import 'package:guard_vm/src/vms/guard_vm.dart';

/// {@template paginated_guard_vm}
/// A specialized ViewModel for managing paginated list data.
///
/// Extends [GuardVM] with built-in support for loading more items,
/// tracking pagination state, and handling end-of-list scenarios.
///
/// **Key features:**
/// - Automatic pagination state management
/// - Load more with loading indicator
/// - Prevents duplicate load-more requests
/// - End-of-list detection
/// - Built-in refresh support
///
/// **Use cases:**
/// - Infinite scroll lists
/// - Load more buttons
/// - Paginated API responses
/// - Feed-based UIs
///
/// Example usage:
/// ```dart
/// class ProductListVM extends PaginatedGuardVM<Product> {
///   ProductListVM(this._repository)
///       : super(const AsyncValue.data(PaginatedState(
///           items: [],
///           currentPage: 0,
///           totalPages: 1,
///           totalItems: 0,
///         )));
///
///   final ProductRepository _repository;
///
///   Future<void> loadInitial() async {
///     await guard(() => _repository.getProducts(page: 1));
///   }
///
///   Future<void> loadMore() async {
///     await guardLoadMore((currentState) async {
///       final response = await _repository.getProducts(
///         page: currentState.currentPage + 1,
///       );
///       return currentState.copyWith(
///         items: [...currentState.items, ...response.items],
///         currentPage: response.currentPage,
///         totalPages: response.totalPages,
///         totalItems: response.totalItems,
///       );
///     });
///   }
/// }
/// ```
/// {@endtemplate}
abstract class PaginatedGuardVM<T> extends GuardVM<PaginatedState<T>> {
  /// {@macro paginated_guard_vm}
  PaginatedGuardVM(super.initial);

  /// Loads more items for pagination without showing global loading state.
  ///
  /// Sets `isLoadingMore` flag, executes the action, then updates state.
  /// Automatically prevents concurrent load-more requests.
  ///
  /// Example:
  /// ```dart
  /// Future<void> loadMore() async {
  ///   await guardLoadMore((current) async {
  ///     final newItems = await _api.getPage(current.currentPage + 1);
  ///     return current.copyWith(
  ///       items: [...current.items, ...newItems],
  ///       currentPage: current.currentPage + 1,
  ///     );
  ///   });
  /// }
  /// ```
  Future<void> guardLoadMore(
    Future<PaginatedState<T>> Function(PaginatedState<T> currentState) action,
  ) async {
    final currentData = value.value;
    if (currentData == null) return;

    // Prevent concurrent load-more requests
    if (currentData.isLoadingMore || !currentData.canLoadMore) return;

    // Set loading more flag
    setData(currentData.copyWith(isLoadingMore: true));

    try {
      final newState = await action(currentData);
      if (!disposed) {
        setData(newState.copyWith(isLoadingMore: false));
      }
    } on Exception catch (e, s) {
      if (!disposed) {
        // Reset loading flag on error
        setData(currentData.copyWith(isLoadingMore: false));
        setError(e, s);
      }
    } catch (e, s) {
      if (!disposed) {
        // Reset loading flag on error
        setData(currentData.copyWith(isLoadingMore: false));
        final exception = Exception(e.toString());
        setError(exception, s);
      }
    }
  }

  /// Refreshes the paginated list by resetting to the first page.
  ///
  /// Use this for pull-to-refresh functionality. Maintains items during refresh
  /// to avoid flickering, then replaces with fresh data.
  ///
  /// Example:
  /// ```dart
  /// Future<void> onRefresh() => refreshPaginated(
  ///   () => _repository.getProducts(page: 1),
  /// );
  /// ```
  Future<void> refreshPaginated(
    Future<PaginatedState<T>> Function() action,
  ) async {
    await guardSilent(action);
  }
}

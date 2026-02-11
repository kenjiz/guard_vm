import 'package:freezed_annotation/freezed_annotation.dart';

part 'paginated_state.freezed.dart';

/// {@template paginated_state}
/// Opinionated representation of the state of a paginated list.
/// {@endtemplate}
@freezed
abstract class PaginatedState<T> with _$PaginatedState<T> {
  /// {@macro paginated_state}
  const factory PaginatedState({
    required List<T> items,
    required int currentPage,
    required int totalPages,
    required int totalItems,
    @Default(false) bool isLoadingMore,
    @Default(false) bool hasReachedEnd,
  }) = _PaginatedState;

  const PaginatedState._();

  /// Whether more items can be loaded based on current state.
  bool get canLoadMore => !hasReachedEnd && !isLoadingMore && currentPage < totalPages;
}

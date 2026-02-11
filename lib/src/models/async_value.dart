import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'async_value.freezed.dart';

/// An [AsyncValue] is a utility for safely manipulating asynchronous data.
///
/// By using [AsyncValue], you are guaranteed that you cannot forget to
/// handle the loading/error state of an asynchronous operation.
@freezed
sealed class AsyncValue<T> with _$AsyncValue<T> {
  /// Creates an [AsyncValue] with a data.
  const factory AsyncValue.data(T value) = AsyncData<T>;

  /// Creates an [AsyncValue] in loading state.
  ///
  /// Prefer always using this constructor with the `const` keyword.
  const factory AsyncValue.loading() = AsyncLoading<T>;

  /// Creates an [AsyncValue] in error state.
  const factory AsyncValue.error(Exception error) = AsyncError<T>;

  const AsyncValue._();

  /// Upcast [AsyncValue] into an [AsyncData], or return null if the [AsyncValue]
  /// is not an [AsyncData].
  AsyncData<T>? get asData => this is AsyncData<T> ? this as AsyncData<T> : null;

  /// Upcast [AsyncValue] into an [AsyncError], or return null if the [AsyncValue]
  /// is not an [AsyncError].
  AsyncError<T>? get asError => this is AsyncError<T> ? this as AsyncError<T> : null;

  /// Upcast [AsyncValue] into an [AsyncLoading], or return null if the [AsyncValue]
  /// is not an [AsyncLoading].
  AsyncLoading<T>? get asLoading => this is AsyncLoading<T> ? this as AsyncLoading<T> : null;

  /// Whether the associated value is in a loading state.
  bool get isLoading => this is AsyncLoading<T>;

  /// Whether the associated value is in an error state.
  bool get hasError => this is AsyncError<T>;

  /// Whether the associated value has data.
  bool get hasValue => this is AsyncData<T>;

  /// The data value, or null if in loading or error state.
  T? get value => maybeWhen(
    data: (value) => value,
    orElse: () => null,
  );

  /// The error value, or null if in loading or data state.
  Exception? get errorValue => maybeWhen(
    error: (error) => error,
    orElse: () => null,
  );
}

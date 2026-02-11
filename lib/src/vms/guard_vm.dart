import 'package:flutter/foundation.dart';
import 'package:guard_vm/src/models/models.dart';

/// {@template guard_vm}
/// Base ViewModel class that manages async state with [AsyncValue].
///
/// Provides automatic state management, error handling, and logging for async operations.
/// All state mutations happen through protected methods, ensuring discipline and traceability.
///
/// **Key features:**
/// - Automatic loading/data/error state management
/// - Multiple guard patterns for different scenarios
/// - Optimistic updates with automatic rollback
/// - Built-in error handling and logging
/// - Implements [ValueListenable] for easy observation
///
/// **Available guard patterns:**
/// - [guard]: Standard async operation with loading state
/// - [guardWithResult]: Returns a [Result] for conditional logic
/// - [guardSilent]/[refresh]: Update without showing loading
/// - [guardUpdate]: Transform current data, rollback on error
/// - [guardOptimistic]: Optimistic update with rollback on error
///
/// Example:
/// ```dart
/// class UserVM extends BaseVM<User> {
///   UserVM(this._repository) : super(const AsyncValue.loading());
///
///   final UserRepository _repository;
///
///   Future<void> loadUser(String id) => guard(
///     () => _repository.getUser(id),
///   );
///
///   Future<void> updateUser(User user) => guardOptimistic(
///     optimisticState: user,
///     action: () => _repository.updateUser(user),
///   );
/// }
/// ```
/// {@endtemplate}
abstract class GuardVM<T> extends ChangeNotifier implements ValueListenable<AsyncValue<T>> {
  /// {@macro guard_vm}
  GuardVM(AsyncValue<T> initial) : _value = initial;

  AsyncValue<T> _value;
  bool _isExecuting = false;

  /// Whether the VM is currently executing an async operation.
  bool get isExecuting => _isExecuting;

  bool _disposed = false;

  /// Whether this VM has been disposed.
  bool get disposed => _disposed;

  /// The current async state (loading, data, or error).
  ///
  /// Use this in your UI to handle different states:
  /// ```dart
  /// viewModel.value.when(
  ///   loading: () => CircularProgressIndicator(),
  ///   data: (user) => UserProfile(user),
  ///   error: (e) => ErrorWidget(e.message),
  /// );
  /// ```
  @override
  AsyncValue<T> get value => _value;

  /// Sets the state to loading.
  ///
  /// Use this when starting a long-running operation.
  /// Typically called automatically by guard methods.
  @protected
  void setLoading() {
    if (_disposed) return;
    _set(const AsyncValue.loading());
  }

  /// Sets the state to data with the provided value.
  ///
  /// Use this when an operation completes successfully.
  /// Typically called automatically by guard methods.
  @protected
  void setData(T data) {
    if (_disposed) return;
    _set(AsyncValue.data(data));
  }

  /// Sets the state to error and logs it for debugging.
  ///
  /// Use this when an operation fails.
  /// Typically called automatically by guard methods.
  @protected
  void setError(Exception error, [StackTrace? stackTrace]) {
    if (_disposed) return;
    debugPrint('GuardVM Error: $error, stackTrace: $stackTrace');
    _set(AsyncValue.error(error));
  }

  /// Wraps an async action with automatic loading state management.
  ///
  /// Shows loading state → executes action → sets data or error.
  /// This is the most common guard pattern for simple async operations.
  ///
  /// Example:
  /// ```dart
  /// Future<void> loadUser() => guard(() => repository.getUser());
  /// ```
  @protected
  Future<void> guard(Future<T> Function() action) async {
    setLoading();
    await _execute(action, onSuccess: setData);
  }

  /// Similar to [guard] but returns a [Result] for conditional logic.
  ///
  /// Use this when you need to perform different actions based on success/failure,
  /// such as navigation or showing specific error messages.
  ///
  /// Example:
  /// ```dart
  /// final result = await guardWithResult(() => repository.login(email, pass));
  /// result.when(
  ///   success: (user) => navigateToHome(),
  ///   failure: (error) => showErrorDialog(error.message),
  /// );
  /// ```
  @protected
  Future<Result<T>> guardWithResult(Future<T> Function() action) async {
    setLoading();
    Result<T>? result;
    await _execute(
      action,
      onSuccess: (data) {
        setData(data);
        result = Result.success(data);
      },
      onError: (error) {
        result = Result.failure(error);
      },
    );
    return result!;
  }

  /// Updates state silently without showing loading indicator.
  ///
  /// Use this for background updates where showing a loading state
  /// would disrupt the user experience (e.g., auto-save, background sync).
  ///
  /// Example:
  /// ```dart
  /// Future<void> autoSave() => guardSilent(
  ///   () => repository.savePreferences(prefs),
  /// );
  /// ```
  @protected
  Future<void> guardSilent(Future<T> Function() action) async {
    await _execute(action, onSuccess: setData);
  }

  /// Alias for [guardSilent]. Specifically designed for pull-to-refresh scenarios.
  ///
  /// Semantically clearer when used in refresh contexts.
  ///
  /// Example:
  /// ```dart
  /// Future<void> onRefresh() => refresh(() => repository.fetchLatestData());
  /// ```
  @protected
  Future<void> refresh(Future<T> Function() action) => guardSilent(action);

  /// Transforms current data without loading state. Rolls back on error.
  ///
  /// Only executes if current state contains valid data (not loading or error).
  /// If the action fails, automatically restores the previous state.
  ///
  /// Example:
  /// ```dart
  /// Future<void> addItem(Item item) => guardUpdate((current) async {
  ///   return [...current, item];
  /// });
  /// ```
  @protected
  Future<void> guardUpdate(Future<T> Function(T currentData) action) async {
    final currentData = _value.value;
    if (currentData == null) return;

    await _executeWithRollback(
      () => action(currentData),
      onSuccess: setData,
    );
  }

  /// Sets optimistic state immediately, then updates with real result or rolls back.
  ///
  /// Useful for providing instant feedback to users before server confirmation.
  /// If the action fails, automatically restores the previous state.
  ///
  /// Example:
  /// ```dart
  /// Future<void> loadMore() => guardOptimistic(
  ///   optimisticState: current.copyWith(isLoadingMore: true),
  ///   action: () => repository.getNextPage(),
  /// );
  /// ```
  @protected
  Future<void> guardOptimistic({
    required T optimisticState,
    required Future<T> Function() action,
  }) async {
    setData(optimisticState);
    await _executeWithRollback(action, onSuccess: setData);
  }

  /// Core execution logic with automatic error handling and state management.
  ///
  /// Catches all exceptions and converts them to [Exception] for consistent error handling.
  Future<void> _execute<R>(
    Future<R> Function() action, {
    required void Function(R) onSuccess,
    void Function(Exception)? onError,
  }) async {
    _isExecuting = true;
    try {
      final result = await action();
      if (_disposed) return;
      onSuccess(result);
    } on Exception catch (e, s) {
      if (_disposed) return;
      setError(e, s);
      onError?.call(e);
    } catch (e, s) {
      if (_disposed) return;
      final exception = Exception(e.toString());
      setError(exception, s);
      onError?.call(exception);
    } finally {
      _isExecuting = false;
    }
  }

  /// Execution logic with automatic state rollback on error.
  ///
  /// Preserves the previous state before executing the action. If the action
  /// fails, automatically restores the saved state before setting error.
  Future<void> _executeWithRollback<R>(
    Future<R> Function() action, {
    required void Function(R) onSuccess,
  }) async {
    _isExecuting = true;
    final previousState = _value;
    try {
      final result = await action();
      if (_disposed) return;
      onSuccess(result);
    } on Exception catch (e, s) {
      if (_disposed) return;
      _rollback(previousState);
      setError(e, s);
    } catch (e, s) {
      if (_disposed) return;
      _rollback(previousState);
      final exception = Exception(e.toString());
      setError(exception, s);
    } finally {
      _isExecuting = false;
    }
  }

  /// Restores a previous state without triggering error handling.
  ///
  /// Used internally by [_executeWithRollback] to revert optimistic updates.
  void _rollback(AsyncValue<T> previousState) {
    if (_disposed) return;
    _value = previousState;
    notifyListeners();
  }

  /// Sets a new state and notifies listeners if not disposed.
  ///
  /// Automatically logs state transitions in debug mode for easier debugging.
  void _set(AsyncValue<T> next) {
    if (_disposed) return;
    _logTransition(_value, next);
    _value = next;
    notifyListeners();
  }

  /// Logs state transitions in debug mode for easier debugging.
  ///
  /// Output format: [ViewModelType] PreviousState → NextState
  void _logTransition(AsyncValue<T> prev, AsyncValue<T> next) {
    if (kDebugMode) {
      debugPrint('[$runtimeType] ${_formatState(prev)} → ${_formatState(next)}');
    }
  }

  /// Formats an [AsyncValue] into a readable string for logging.
  String _formatState(AsyncValue<T> state) {
    return state.when(
      data: (d) => 'Data(${d.runtimeType})',
      loading: () => 'Loading',
      error: (e) => 'Error($e)',
    );
  }

  /// Marks the ViewModel as disposed and prevents further state updates.
  ///
  /// Must be called manually in your widget's `dispose()` method to prevent memory leaks.
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Result type for operations that need explicit success/failure handling.
///
/// Example:
/// ```dart
/// final result = await guardWithResult(() => repository.login());
/// result.when(
///   success: (user) => print('Logged in as ${user.name}'),
///   failure: (error) => print('Login failed: ${error.message}'),
/// );
/// ```
class Result<T> {
  const Result._({required this.isSuccess, this.data, this.error});

  /// Creates a successful result.
  factory Result.success(T data) => Result._(data: data, isSuccess: true);

  /// Creates a failed result.
  factory Result.failure(Exception error) => Result._(error: error, isSuccess: false);

  /// The successful data, if any. Will be null for failed results.
  final T? data;

  /// The error that occurred, if any. Will be null for successful results.
  final Exception? error;

  /// Whether the result is a success or failure.
  final bool isSuccess;

  /// Pattern matching for success/failure cases.
  R when<R>({
    required R Function(T data) success,
    required R Function(Exception error) failure,
  }) => isSuccess ? success(data as T) : failure(error!);
}

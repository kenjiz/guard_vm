import 'package:flutter/foundation.dart';
import 'package:guard_vm/src/models/models.dart';
import 'package:guard_vm/src/vms/vms.dart';

/// {@template coordinated_vm}
/// A base ViewModel class for coordinating state between multiple ViewModels.
///
/// Extends [GuardVM] to add specialized support for listening to other ViewModels
/// and reacting to their state changes. This enables complex state dependencies
/// and cascading updates across your application.
///
/// **Key features:**
/// - Listen to other ViewModels and react to their state changes
/// - Automatic cleanup of listeners on dispose
/// - Custom handlers for data, errors, and loading states
/// - Automatic error propagation if no error handler provided
/// - Executes immediately with current state by default
///
/// **Use cases:**
/// - Update UI when dependent data changes
/// - Calculate derived values from multiple sources
/// - Synchronize related features (e.g., cart total when items change)
/// - Chain dependent API calls
///
/// Example usage:
/// ```dart
/// class RideCostVM extends CoordinatedVM<double> {
///   RideCostVM(this._userLocationVM, this._pricingService)
///       : super(const AsyncValue.data(0.0)) {
///     // Recalculate cost whenever location changes
///     // By default, executes immediately with current location
///     coordinateWith(
///       _userLocationVM,
///       (location) => _calculateCost(location),
///       onError: (error) => _handleLocationError(error),
///       onLoading: () => setData(0.0), // Reset cost while loading
///     );
///   }
///
///   final UserLocationVM _userLocationVM;
///   final PricingService _pricingService;
///
///   Future<void> _calculateCost(LatLng location) async {
///     await guardSilent(() => _pricingService.estimate(location));
///   }
///
///   void _handleLocationError(Exception error) {
///     setData(0.0); // Default to zero cost on error
///   }
/// }
/// ```
/// {@endtemplate}
abstract class CoordinatedVM<T> extends GuardVM<T> {
  /// {@macro coordinated_vm}
  CoordinatedVM(super.initial);

  late final GuardVM<dynamic> _coordinatedVM;
  late final VoidCallback _listener;

  /// Coordinates with another ViewModel by listening to its state changes.
  ///
  /// Reacts to state changes from the observed VM by invoking the appropriate
  /// callback based on the state type (data, error, or loading).
  ///
  /// **Parameters:**
  /// - [vm]: The ViewModel to observe
  /// - [onData]: Callback invoked when [vm] emits data
  /// - [onError]: Optional callback invoked when [vm] emits an error.
  ///   If not provided, errors are automatically propagated to this VM's state.
  /// - [onLoading]: Optional callback invoked when [vm] transitions to loading state.
  ///   Useful for showing loading indicators or resetting dependent state.
  /// - [executeImmediately]: If `true` (default), immediately invokes the appropriate
  ///   callback with the current state of [vm]. This ensures you don't miss the initial
  ///   state. Set to `false` if you only want to react to future state changes.
  ///
  /// **Note:** The listener is automatically cleaned up when this VM is disposed.
  ///
  /// Example:
  /// ```dart
  /// void init() {
  ///   coordinateWith(
  ///     _settingsVM,
  ///     (settings) => _applySettings(settings),
  ///     onError: (error) => _handleSettingsError(error),
  ///     onLoading: () => setLoading(),
  ///   );
  /// }
  /// ```
  @protected
  void coordinateWith<D>(
    GuardVM<D> vm,
    void Function(D data) onData,
    void Function(Exception error)? onError,
    void Function()? onLoading, {
    bool executeImmediately = true,
  }) {
    _coordinatedVM = vm;
    _listener = () => _handleCoordinatedVMChange(vm, onData, onError, onLoading);

    // Execute immediately if requested and VM has data
    if (executeImmediately) {
      _listener();
    }

    // Listen to the other ViewModel and store references for cleanup
    vm.addListener(_listener);
  }

  void _handleCoordinatedVMChange<D>(
    GuardVM<D> vm,
    void Function(D data) onData,
    void Function(Exception error)? onError,
    void Function()? onLoading,
  ) {
    final asyncValue = vm.value;

    if (asyncValue is AsyncData<D>) {
      onData(asyncValue.value);
    } else if (asyncValue is AsyncError<D>) {
      if (onError != null) {
        onError(asyncValue.error);
      } else {
        // Propagate error to this VM if no custom handler
        setError(asyncValue.error);
      }
    } else if (asyncValue is AsyncLoading<D> && onLoading != null) {
      onLoading();
    }
  }

  /// Removes all coordination listeners when the ViewModel is disposed.
  ///
  @override
  void dispose() {
    _coordinatedVM.removeListener(_listener);
    super.dispose();
  }
}

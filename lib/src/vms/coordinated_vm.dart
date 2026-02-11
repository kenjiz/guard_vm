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
/// - Listen to one or more other ViewModels
/// - Automatic cleanup of listeners on dispose
/// - Propagate errors from coordinated VMs
/// - Optional immediate execution with current state
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
///     coordinateWith(
///       _userLocationVM,
///       (location) => _calculateCost(location),
///       executeImmediately: true,
///     );
///   }
///
///   final UserLocationVM _userLocationVM;
///   final PricingService _pricingService;
///
///   Future<void> _calculateCost(LatLng location) async {
///     await guardSilent(() => _pricingService.estimate(location));
///   }
/// }
/// ```
/// {@endtemplate}
abstract class CoordinatedVM<T> extends GuardVM<T> {
  /// {@macro coordinated_vm}
  CoordinatedVM(super.initial);

  final _coordinatedVMs = <ValueListenable<AsyncValue<dynamic>>>[];
  final _listeners = <VoidCallback>[];

  /// Coordinates with another ViewModel by listening to its state changes.
  ///
  /// When the observed VM emits new data, [onData] is called with that data.
  /// If the observed VM emits an error, this VM's state is set to that error.
  ///
  /// **Parameters:**
  /// - [vm]: The ViewModel to observe
  /// - [onData]: Callback invoked when [vm] emits data
  /// - [executeImmediately]: If true and [vm] has data, calls [onData] immediately
  ///
  /// **Note:** The listener is automatically cleaned up when this VM is disposed.
  ///
  /// Example:
  /// ```dart
  /// void init() {
  ///   coordinateWith(
  ///     _settingsVM,
  ///     (settings) => _applySettings(settings),
  ///     executeImmediately: true, // Apply current settings immediately
  ///   );
  /// }
  /// ```
  @protected
  void coordinateWith<D>(
    ValueListenable<AsyncValue<D>> vm,
    void Function(D data) onData, {
    bool executeImmediately = false,
  }) {
    void listener() {
      final asyncValue = vm.value;
      if (asyncValue is AsyncData<D>) {
        onData(asyncValue.value);
      } else if (asyncValue is AsyncError<D>) {
        setError(asyncValue.error);
      }
    }

    // Execute immediately if requested and VM has data
    if (executeImmediately) {
      listener();
    }

    // Listen to the other ViewModel and store references for cleanup
    vm.addListener(listener);
    _coordinatedVMs.add(vm);
    _listeners.add(listener);
  }

  /// Removes all coordination listeners when the ViewModel is disposed.
  ///
  @override
  void dispose() {
    for (var i = 0; i < _coordinatedVMs.length; i++) {
      _coordinatedVMs[i].removeListener(_listeners[i]);
    }
    _coordinatedVMs.clear();
    _listeners.clear();
    super.dispose();
  }
}

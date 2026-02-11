import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:guard_vm/src/vms/guard_vm.dart';

/// {@template stream_guard_vm}
/// A base ViewModel class for managing state from real-time streams.
///
/// Extends [GuardVM] to add specialized support for stream subscriptions,
/// including automatic lifecycle management, error handling, and cleanup.
///
/// **Key features:**
/// - Automatic subscription management with cleanup on dispose
/// - Built-in error handling for stream errors
/// - Support for multiple concurrent stream subscriptions
/// - Optional callbacks for reacting to data updates
///
/// **Use cases:**
/// - Real-time location tracking
/// - Live chat messages
/// - WebSocket data streams
/// - Server-sent events (SSE)
/// - Database change listeners
///
/// Example usage:
/// ```dart
/// class DriverLocationVM extends StreamGuardVM<LatLng> {
///   DriverLocationVM(this._locationService) : super(const AsyncValue.loading());
///
///   final LocationService _locationService;
///
///   void startTracking(String driverId) {
///     guardStream(
///       _locationService.trackDriver(driverId),
///       (location) => print('Driver moved to: $location'),
///     );
///   }
/// }
/// ```
/// {@endtemplate}
abstract class StreamGuardVM<T> extends GuardVM<T> {
  /// {@macro stream_guard_vm}
  StreamGuardVM(super.initial);

  final _subscriptions = <StreamSubscription<T>>[];

  /// Guards a stream by listening to it and automatically managing its lifecycle.
  ///
  /// Sets state to loading initially, then updates with emitted data or errors.
  /// The subscription is automatically tracked and cancelled when the VM is disposed.
  ///
  /// **Parameters:**
  /// - [stream]: The stream to listen to
  /// - [onData]: Optional callback invoked after each data emission (after state update)
  ///
  /// Example:
  /// ```dart
  /// void trackDriver(String id) {
  ///   guardStream(
  ///     _service.trackDriver(id),
  ///     (location) => _updateMap(location),
  ///   );
  /// }
  /// ```
  @protected
  void guardStream(
    Stream<T> stream, [
    void Function(T data)? onData,
  ]) {
    setLoading();

    final sub = stream.listen(
      (data) {
        setData(data);
        onData?.call(data);
      },
      onError: (Object error, StackTrace st) => setError(error as Exception, st),
    );
    _subscriptions.add(sub);
  }

  /// Cancels all active stream subscriptions when the ViewModel is disposed.
  ///
  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    super.dispose();
  }
}

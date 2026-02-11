import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:guard_vm/guard_vm.dart';

/// {@template guard_value_listenable_builder}
/// A widget that listens to a [ValueListenable] of [AsyncValue] and builds
/// different UI based on the current state (loading, data, error).
/// This is a convenient way to connect your UI to a [GuardVM] or any other
/// [ValueListenable] that emits [AsyncValue]s.
/// {@endtemplate}
class GuardValueListenableBuilder<T> extends StatelessWidget {
  /// {@macro guard_value_listenable_builder}
  const GuardValueListenableBuilder({
    required this.listenable,
    required this.data,
    this.loading,
    this.error,
    this.child,
    super.key,
  });

  /// The ValueListenable that provides the AsyncValue&lt;T&gt; to listen to.
  final ValueListenable<AsyncValue<T>> listenable;

  /// Called when state has data available
  final Widget Function(BuildContext context, T data) data;

  /// Optional loading widget
  final Widget Function(BuildContext context)? loading;

  /// Optional error widget
  final Widget Function(BuildContext context, Exception error)? error;

  /// Optional child widget that can be passed to the builder for optimization.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AsyncValue<T>>(
      valueListenable: listenable,
      builder: (context, value, child) => value.when(
        data: (d) => data(context, d),
        loading: () => loading != null ? loading!(context) : const AdaptiveCircularProgressIndicator(),
        error: (e) => error != null ? error!(context, e) : FailedMessage(message: e.toString()),
      ),
      child: child,
    );
  }
}

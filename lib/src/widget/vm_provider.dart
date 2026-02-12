import 'package:flutter/material.dart';

/// {@template vm_provider}
/// A provider widget that creates and provides a ViewModel to its descendants.
///
/// Similar to BlocProvider, this widget manages the lifecycle of a ViewModel
/// and makes it accessible to all descendant widgets via [BuildContext].
///
/// **Two usage patterns:**
///
/// 1. **Create mode** - VMProvider creates and owns the VM:
/// ```dart
/// VMProvider<UserVM>(
///   create: (context) => UserVM(repository),
///   child: UserScreen(),
/// )
/// ```
///
/// 2. **Value mode** - VMProvider receives an existing VM:
/// ```dart
/// VMProvider<UserVM>.value(
///   value: existingUserVM,
///   child: UserScreen(),
/// )
/// ```
///
/// **Accessing the VM:**
///
/// ```dart
/// // With state updates (rebuilds on change)
/// final vm = VMProvider.of<UserVM>(context);
///
/// // Without state updates (doesn't rebuild)
/// final vm = VMProvider.of<UserVM>(context, listen: false);
///
/// // Or using extension methods (if available)
/// final vm = context.watch<UserVM>(); // rebuilds on change
/// final vm = context.read<UserVM>();  // doesn't rebuild
/// ```
/// {@endtemplate}
class VMProvider<VM extends ChangeNotifier> extends StatefulWidget {
  /// {@macro vm_provider}
  ///
  /// Creates a VMProvider that creates and manages the lifecycle of the VM.
  const VMProvider({
    required this.create,
    required this.child,
    this.lazy = false,
    super.key,
  }) : value = null;

  /// Creates a VMProvider that provides an existing VM instance.
  ///
  /// The VM will NOT be disposed when this provider is removed from the tree.
  /// Use this when the VM is managed elsewhere.
  const VMProvider.value({
    required VM this.value,
    required this.child,
    super.key,
  }) : create = null,
       lazy = false;

  /// Function that creates the ViewModel.
  final VM Function(BuildContext context)? create;

  /// An existing ViewModel instance to provide.
  final VM? value;

  /// The widget below this widget in the tree.
  final Widget child;

  /// Whether to lazily create the VM (only when first accessed).
  /// Defaults to false (VM is created immediately).
  final bool lazy;

  /// Retrieves the nearest [VM] instance up the widget tree.
  ///
  /// If [listen] is true (default), the calling widget will rebuild
  /// when the VM's state changes. Set to false for one-time access.
  ///
  /// Throws a [ProviderNotFoundException] if no [VMProvider] is found.
  static VM of<VM extends ChangeNotifier>(
    BuildContext context, {
    bool listen = true,
  }) {
    final provider = listen
        ? context.dependOnInheritedWidgetOfExactType<_InheritedVMProvider<VM>>()
        : context.getElementForInheritedWidgetOfExactType<_InheritedVMProvider<VM>>()?.widget
              as _InheritedVMProvider<VM>?;

    if (provider == null) {
      throw ProviderNotFoundException(VM, context.widget.runtimeType);
    }

    // Use vmGetter which will create the VM lazily if needed
    return provider.vmGetter();
  }

  @override
  State<VMProvider<VM>> createState() => _VMProviderState<VM>();
}

class _VMProviderState<VM extends ChangeNotifier> extends State<VMProvider<VM>> {
  VM? _vm;
  bool _shouldDispose = false;

  @override
  void initState() {
    super.initState();
    _initVM();
  }

  void _initVM() {
    if (widget.value != null) {
      // Value mode - use provided VM
      _vm = widget.value;
      _shouldDispose = false;
    } else if (widget.create != null && !widget.lazy) {
      // Create mode, eager - create immediately
      _vm = widget.create!(context);
      _shouldDispose = true;
    }
    // Lazy mode will create on first access
  }

  VM get vm {
    if (_vm == null && widget.create != null) {
      // Lazy creation
      _vm = widget.create!(context);
      _shouldDispose = true;
      // Trigger rebuild to set up InheritedNotifier properly
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {});
          }
        });
      }
    }
    return _vm!;
  }

  @override
  void didUpdateWidget(VMProvider<VM> oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle switching between create and value modes
    if (oldWidget.value != widget.value && widget.value != null) {
      if (_shouldDispose) {
        _vm?.dispose();
      }
      _vm = widget.value;
      _shouldDispose = false;
    }
  }

  @override
  void dispose() {
    if (_shouldDispose) {
      _vm?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _InheritedVMProvider<VM>(
      vm: _vm,
      vmGetter: () => vm,
      child: widget.child,
    );
  }
}

class _InheritedVMProvider<VM extends ChangeNotifier> extends InheritedNotifier<VM> {
  const _InheritedVMProvider({
    required VM? vm,
    required this.vmGetter,
    required super.child,
  }) : super(notifier: vm);

  final VM Function() vmGetter;

  @override
  bool updateShouldNotify(_InheritedVMProvider<VM> oldWidget) {
    return oldWidget.notifier != notifier;
  }
}

/// {@template provider_not_found_exception}
/// Exception thrown when a ViewModel cannot be found in the widget tree.
/// {@endtemplate}
class ProviderNotFoundException implements Exception {
  /// {@macro provider_not_found_exception}
  const ProviderNotFoundException(this.vmType, this.widgetType);

  /// The type of the ViewModel that was not found.
  final Type vmType;

  /// The type of the widget from which the lookup was attempted.
  final Type widgetType;

  @override
  String toString() {
    return '''
VMProvider.of() called with a context that does not contain a $vmType.

No ancestor could be found starting from $widgetType.

Make sure that:
1. You have a VMProvider<$vmType> above $widgetType in your widget tree
2. The context you're using is a descendant of the VMProvider

Example:
  VMProvider<$vmType>(
    create: (context) => $vmType(...),
    child: YourWidget(),
  )
''';
  }
}

/// Extension on [BuildContext] to provide convenient access to ViewModels.
extension VMProviderExtension on BuildContext {
  /// Watches the ViewModel and rebuilds when it changes.
  ///
  /// Equivalent to `VMProvider.of<VM>(context)`.
  VM watch<VM extends ChangeNotifier>() => VMProvider.of<VM>(this);

  /// Reads the ViewModel without listening to changes.
  ///
  /// Equivalent to `VMProvider.of<VM>(context, listen: false)`.
  VM read<VM extends ChangeNotifier>() => VMProvider.of<VM>(this, listen: false);
}

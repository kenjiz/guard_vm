// lib/src/widget/vm_scope.dart

import 'package:flutter/material.dart';

/// {@template vm_scope}
/// Provides a ViewModel to descendant widgets without creating or managing it.
///
/// **Philosophy:** VMScope follows Guard VM's principle of discipline and explicitness.
/// Unlike provider patterns that create and dispose VMs automatically, VMScope requires
/// you to explicitly manage the VM lifecycle in a State class. This makes ownership
/// clear and prevents "magic" behavior.
///
/// **Use VMScope when:**
/// - You want to avoid prop drilling without giving up lifecycle control
/// - The VM is scoped to a specific screen/feature
/// - You want explicit, visible VM creation and disposal
///
/// **Don't use VMScope when:**
/// - VM is truly app-wide (use a singleton or service locator instead)
/// - Only 1-2 widgets need the VM (just pass it as a parameter)
/// - You prefer automatic lifecycle management (consider VMProvider instead)
///
/// **Example:**
/// ```dart
/// class UserScreen extends StatefulWidget {
///   const UserScreen({super.key});
///
///   @override
///   State<UserScreen> createState() => _UserScreenState();
/// }
///
/// class _UserScreenState extends State<UserScreen> {
///   // Explicit VM creation - you own it, you control it
///   late final _userVM = UserVM(context.read<UserRepository>());
///
///   @override
///   void dispose() {
///     // Explicit disposal - clear lifecycle management
///     _userVM.dispose();
///     super.dispose();
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return VMScope<UserVM>(
///       vm: _userVM,
///       child: Scaffold(
///         appBar: AppBar(title: const Text('User Profile')),
///         body: const UserProfileContent(), // Can access VM without prop drilling
///       ),
///     );
///   }
/// }
///
/// class UserProfileContent extends StatelessWidget {
///   const UserProfileContent({super.key});
///
///   @override
///   Widget build(BuildContext context) {
///     final userVM = VMScope.of<UserVM>(context);
///
///     return GuardValueListenableBuilder<User>(
///       listenable: userVM,
///       data: (context, user) => Column(
///         children: [
///           Text(user.name),
///           ElevatedButton(
///             onPressed: () => userVM.updateProfile(user.copyWith(name: 'New Name')),
///             child: const Text('Update'),
///           ),
///         ],
///       ),
///     );
///   }
/// }
/// ```
///
/// **Multiple VMs:**
/// ```dart
/// @override
/// Widget build(BuildContext context) {
///   return VMScope<UserVM>(
///     vm: _userVM,
///     child: VMScope<SettingsVM>(
///       vm: _settingsVM,
///       child: Scaffold(
///         body: const MyWidget(), // Can access both VMs
///       ),
///     ),
///   );
/// }
/// ```
/// {@endtemplate}
class VMScope<VM> extends InheritedWidget {
  /// {@macro vm_scope}
  const VMScope({
    required this.vm,
    required super.child,
    super.key,
  });

  /// The ViewModel instance provided to descendants.
  ///
  /// This VM is NOT owned by VMScope - it's owned by the widget that created it.
  /// VMScope only makes it accessible to descendant widgets.
  final VM vm;

  /// Retrieves the nearest [VM] from the widget tree.
  ///
  /// This method will throw an assertion error in debug mode if no [VMScope]
  /// of the requested type is found in the widget tree.
  ///
  /// **Usage:**
  /// ```dart
  /// final userVM = VMScope.of<UserVM>(context);
  /// ```
  ///
  /// **Common mistakes:**
  /// ```dart
  /// // ❌ Wrong: Using wrong context
  /// class _MyScreenState extends State<MyScreen> {
  ///   @override
  ///   Widget build(BuildContext context) {
  ///     return VMScope<UserVM>(
  ///       vm: _vm,
  ///       child: Builder(
  ///         builder: (context) {
  ///           // ✅ Correct: Use child context, not parent
  ///           final vm = VMScope.of<UserVM>(context);
  ///           return Text('...');
  ///         },
  ///       ),
  ///     );
  ///   }
  /// }
  /// ```
  static VM of<VM>(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<VMScope<VM>>();
    assert(
      scope != null,
      'No VMScope<$VM> found in context. '
      'Make sure you have a VMScope<$VM> widget above this widget in the tree. '
      'Example:\n'
      '  VMScope<$VM>(\n'
      '    vm: myVM,\n'
      '    child: YourWidget(),\n'
      '  )',
    );
    return scope!.vm;
  }

  /// Attempts to retrieve the nearest [VM] from the widget tree.
  ///
  /// Returns `null` if no [VMScope] of the requested type is found.
  /// Use this when the VM might not be available and you want to handle that case.
  ///
  /// **Example:**
  /// ```dart
  /// final userVM = VMScope.maybeOf<UserVM>(context);
  /// if (userVM != null) {
  ///   // Use the VM
  /// } else {
  ///   // Fallback behavior
  /// }
  /// ```
  static VM? maybeOf<VM>(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<VMScope<VM>>();
    return scope?.vm;
  }

  @override
  bool updateShouldNotify(VMScope<VM> oldWidget) => vm != oldWidget.vm;
}

/// Extension on [BuildContext] for convenient VM access.
///
/// Provides a shorter syntax for accessing VMs from VMScope.
extension VMScopeExtension on BuildContext {
  /// Retrieves the nearest [VM] from the widget tree.
  ///
  /// Equivalent to `VMScope.of<VM>(context)`.
  ///
  /// **Example:**
  /// ```dart
  /// final userVM = context.vm<UserVM>();
  /// ```
  VM vm<VM>() => VMScope.of<VM>(this);

  /// Attempts to retrieve the nearest [VM] from the widget tree.
  ///
  /// Returns `null` if not found.
  /// Equivalent to `VMScope.maybeOf<VM>(context)`.
  ///
  /// **Example:**
  /// ```dart
  /// final userVM = context.maybeVm<UserVM>();
  /// if (userVM != null) {
  ///   // Use it
  /// }
  /// ```
  VM? maybeVm<VM>() => VMScope.maybeOf<VM>(this);
}

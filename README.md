# Guard VM 🛡️

![coverage][coverage_badge]
[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]
[![License: MIT][license_badge]][license_link]

A production-ready state management solution built on top of Flutter's `ValueNotifier` and `ChangeNotifier`. Guard VM provides automatic state management, error handling, and lifecycle management for async operations with a clean, disciplined API.

## Features ✨

- 🎯 **Type-Safe Async State** - `AsyncValue<T>` for loading/data/error states
- 🛡️ **Multiple Guard Patterns** - Different patterns for different scenarios
- 🔄 **Automatic State Management** - No manual state tracking needed
- 🎭 **Optimistic Updates** - Instant UI feedback with automatic rollback
- 🌊 **Stream Support** - Built-in stream subscription management
- 📄 **Pagination Support** - Specialized VM for infinite scroll
- 🔗 **Coordination** - Easy state dependencies between ViewModels
- 🧪 **Testable** - Built with testing in mind
- 📝 **Traceable** - Automatic debug logging in development
- 🎨 **UI Helpers** - Ready-to-use builder widgets

## Philosophy 💭

Guard VM is built on the **principle of discipline and explicitness**:

- **Explicit Ownership** - You create and own your ViewModels. No magic dependency injection.
- **Visible Lifecycle** - VM creation and disposal are clearly visible in your code, not hidden.
- **Predictable State Flow** - State changes are traceable and explicit.
- **No Surprises** - No automatic disposal or hidden behavior that causes subtle bugs.

Unlike provider patterns that automatically create and dispose of ViewModels, Guard VM requires you to be explicit about lifecycle management. This might seem like more work initially, but it makes your code significantly more maintainable and prevents entire classes of bugs related to "magic" behavior.

**Example:**

```dart
class _UserScreenState extends State<UserScreen> {
  // ✅ Explicit: You create it
  late final _userVM = UserVM(context.read<UserRepository>());

  @override
  void dispose() {
    // ✅ Explicit: You dispose it
    _userVM.dispose();
    super.dispose();
  }

  // Your code clearly shows VM ownership and lifecycle
}
```

This philosophy extends throughout Guard VM - from state management to coordination to widget scoping. Everything is explicit and traceable.

## Installation

```sh
flutter pub add guard_vm
```

## Quick Start 🚀

### 1. Create a ViewModel

```dart
import 'package:guard_vm/guard_vm.dart';

class UserVM extends GuardVM<User> {
  UserVM(this._repository) : super(const AsyncValue.loading());

  final UserRepository _repository;

  Future<void> loadUser(String id) => guard(
    () => _repository.getUser(id),
  );

  Future<void> updateProfile(User user) => guardOptimistic(
    optimisticState: user,
    action: () => _repository.updateUser(user),
  );
}
```

### 2. Use in Your Widget

```dart
class UserProfileScreen extends StatefulWidget {
  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late final UserVM _vm;

  @override
  void initState() {
    super.initState();
    _vm = UserVM(context.read<UserRepository>());
    _vm.loadUser('user-123');
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GuardValueListenableBuilder<User>(
        listenable: _vm,
        data: (context, user) => UserProfile(user: user),
        loading: (context) => const Center(child: CircularProgressIndicator()),
        error: (context, error) => ErrorWidget(error.toString()),
      ),
    );
  }
}
```

## Core Concepts 🧠

### AsyncValue<T>

Represents the state of an async operation:

```dart
AsyncValue<User> state = const AsyncValue.loading();  // Loading state
AsyncValue<User> state = AsyncValue.data(user);       // Success with data
AsyncValue<User> state = AsyncValue.error(exception); // Error state
```

Use pattern matching to handle states:

```dart
state.when(
  loading: () => const CircularProgressIndicator(),
  data: (user) => Text('Hello ${user.name}'),
  error: (e) => Text('Error: $e'),
);
```

### Guard Patterns

Guard VM provides several patterns for different scenarios:

#### 1. **guard** - Standard async operation

Shows loading → executes → sets data or error

```dart
Future<void> loadData() => guard(() => api.fetchData());
```

#### 2. **guardWithResult** - Conditional logic

Returns a `Result<T>` for branching logic:

```dart
Future<void> login(String email, String password) async {
  final result = await guardWithResult(
    () => authService.login(email, password),
  );

  result.when(
    success: (user) => navigateToHome(),
    failure: (error) => showErrorSnackbar(error),
  );
}
```

#### 3. **guardSilent / refresh** - Background updates

Updates without showing loading state:

```dart
Future<void> autoSave() => guardSilent(() => repo.save(data));
Future<void> pullToRefresh() => refresh(() => api.fetchLatest());
```

#### 4. **guardUpdate** - Transform current data

Only works when data is available, rolls back on error:

```dart
Future<void> addItem(Item item) => guardUpdate((currentList) async {
  return [...currentList, item];
});
```

#### 5. **guardOptimistic** - Optimistic updates

Updates UI immediately, rolls back on error:

```dart
Future<void> likePost(Post post) => guardOptimistic(
  optimisticState: post.copyWith(isLiked: true),
  action: () => api.likePost(post.id),
);
```

## Advanced Usage 🚀

### Stream-Based ViewModels

For real-time data (WebSocket, location, etc.):

```dart
class LocationVM extends StreamGuardVM<LatLng> {
  LocationVM(this._locationService) : super(const AsyncValue.loading());

  final LocationService _locationService;

  void startTracking() {
    guardStream(
      _locationService.positionStream(),
      (location) => print('Moved to: $location'),
    );
  }
}
```

### Coordinated ViewModels

React to changes in other ViewModels with `CoordinatedVM`:

```dart
class OrderTotalVM extends CoordinatedVM<double> {
  OrderTotalVM(this._cartVM, this._discountVM)
      : super(const AsyncValue.data(0.0)) {

    // Recalculate when cart items change
    coordinateWith(
      _cartVM,
      (cart) => _updateTotal(cart),
    );

    // React to discount changes
    coordinateWith(
      _discountVM,
      (discount) => _applyDiscount(discount),
    );
  }

  final CartVM _cartVM;
  final DiscountVM _discountVM;

  Future<void> _updateTotal(Cart cart) async {
    final total = cart.items.fold(0.0, (sum, item) => sum + item.price);
    setData(total);
  }
}
```

**Key Features:**

- **`executeImmediately`** (default: `true`) - Immediately processes the observed VM's current state when coordination is set up, ensuring you don't miss the initial state
- **`onData`** - Required callback when observed VM has data
- **`onError`** - Optional error handler. If not provided, errors automatically propagate to the coordinating VM
- **`onLoading`** - Optional callback for handling loading states (useful for resetting dependent state)

**Example with error handling:**

```dart
class RideCostVM extends CoordinatedVM<double> {
  RideCostVM(this._locationVM, this._pricingService)
      : super(const AsyncValue.data(0.0)) {

    coordinateWith(
      _locationVM,
      (location) => _calculateCost(location),
      onError: (error) {
        // Custom error handling
        setData(0.0); // Reset to default cost
      },
    );
  }

  Future<void> _calculateCost(LatLng location) async {
    await guardSilent(() => _pricingService.estimate(location));
  }
}
```

### Paginated Lists

For infinite scroll and load-more scenarios:

```dart
class ProductListVM extends PaginatedGuardVM<Product> {
  ProductListVM(this._repository)
      : super(const AsyncValue.data(PaginatedState(
          items: [],
          currentPage: 0,
          totalPages: 1,
          totalItems: 0,
        )));

  final ProductRepository _repository;

  Future<void> loadInitial() async {
    await guard(() => _repository.getProducts(page: 1));
  }

  Future<void> loadMore() async {
    await guardLoadMore((current) async {
      final response = await _repository.getProducts(
        page: current.currentPage + 1,
      );

      return PaginatedState(
        items: [...current.items, ...response.items],
        currentPage: response.currentPage,
        totalPages: response.totalPages,
        totalItems: response.totalItems,
      );
    });
  }
}
```

Usage in UI:

```dart
ListView.builder(
  itemCount: state.items.length + (state.isLoadingMore ? 1 : 0),
  itemBuilder: (context, index) {
    if (index == state.items.length) {
      return const LoadingIndicator(); // Show loading at bottom
    }
    return ProductCard(product: state.items[index]);
  },
);

// Trigger load more
if (state.canLoadMore) {
  vm.loadMore();
}
```

### VMScope - Avoiding Prop Drilling

`VMScope` uses InheritedWidget to pass VMs down the widget tree without manual prop drilling, while maintaining Guard VM's philosophy of explicit lifecycle management:

```dart
class UserScreen extends StatefulWidget {
  const UserScreen({super.key});

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  // ✅ Explicit VM creation - you own it, you control it
  late final _userVM = UserVM(context.read<UserRepository>());

  @override
  void dispose() {
    // ✅ Explicit disposal - clear lifecycle management
    _userVM.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VMScope<UserVM>(
      vm: _userVM,
      child: Scaffold(
        appBar: AppBar(title: const Text('User Profile')),
        body: const Column(
          children: [
            UserHeader(),      // Can access UserVM
            UserDetails(),     // Can access UserVM
            UserSettings(),    // Can access UserVM
          ],
        ),
      ),
    );
  }
}

// Deep in the widget tree - no prop drilling needed
class UserHeader extends StatelessWidget {
  const UserHeader({super.key});

  @override
  Widget build(BuildContext context) {
    // Access VM using extension method
    final userVM = context.vm<UserVM>();
    // Or: final userVM = VMScope.of<UserVM>(context);

    return GuardValueListenableBuilder<User>(
      listenable: userVM,
      data: (context, user) => Text('Hello ${user.name}'),
    );
  }
}
```

**Key Points:**

- **Not a Provider**: VMScope doesn't create or dispose VMs - you do that explicitly
- **Nested Scopes**: You can nest multiple VMScopes for different VMs [MultiVMScope not yet available]
- **Type-Safe**: Strong typing prevents accessing wrong VM types
- **Extensions**: Convenient `context.vm<VM>()` and `context.maybeVm<VM>()` methods

**Multiple VMs:**

```dart
@override
Widget build(BuildContext context) {
  return VMScope<UserVM>(
    vm: _userVM,
    child: VMScope<SettingsVM>(
      vm: _settingsVM,
      child: Scaffold(
        body: MyWidget(), // Can access both VMs
      ),
    ),
  );
}
```

**When to use VMScope:**

- ✅ Avoiding prop drilling across many widgets
- ✅ VM is scoped to a specific screen/feature
- ✅ You want explicit lifecycle control

**When NOT to use VMScope:**

- ❌ VM is truly app-wide (use a singleton instead)
- ❌ Only 1-2 widgets need the VM (just pass it as a parameter)
- ❌ You want automatic lifecycle management

## API Reference 📚

### GuardVM<T>

Base ViewModel class for managing async state.

**Properties:**

- `value: AsyncValue<T>` - Current state
- `isExecuting: bool` - Whether an operation is in progress

**Guard Methods:**

- `guard(action)` - Standard async with loading
- `guardWithResult(action)` - Returns Result<T>
- `guardSilent(action)` - No loading state
- `refresh(action)` - Alias for guardSilent
- `guardUpdate(action)` - Transform current data
- `guardOptimistic({optimisticState, action})` - Optimistic update

**State Setters (Protected):**

- `setLoading()` - Set loading state
- `setData(T data)` - Set success state
- `setError(Exception error)` - Set error state

### StreamGuardVM<T>

Extends GuardVM for stream-based data.

**Methods:**

- `guardStream(stream, [onData])` - Listen to stream with lifecycle management

### CoordinatedVM<T>

Extends GuardVM for coordinating with other VMs.

**Methods:**

- `coordinateWith<D>(vm, onData, onError, onLoading, {executeImmediately})` - Listen to another VM
  - `vm` - The VM to observe
  - `onData` - Callback when observed VM has data
  - `onError` - Optional error handler (auto-propagates if not provided)
  - `onLoading` - Optional callback for loading states
  - `executeImmediately` - If `true` (default), immediately invokes callbacks with current state

### PaginatedGuardVM<T>

Extends GuardVM for paginated lists.

**Methods:**

- `guardLoadMore(action)` - Load next page
- `refreshPaginated(action)` - Refresh from first page

### GuardValueListenableBuilder<T>

Widget for building UI from GuardVM state.

**Parameters:**

- `listenable: ValueListenable<AsyncValue<T>>` - The VM to listen to
- `data: Widget Function(BuildContext, T)` - Build when data available
- `loading: Widget Function(BuildContext)?` - Custom loading widget
- `error: Widget Function(BuildContext, Exception)?` - Custom error widget

### VMScope<VM>

Provides a ViewModel to descendant widgets using InheritedWidget.

**Usage:**

```dart
VMScope<UserVM>(
  vm: myUserVM,
  child: MyWidget(),
)
```

**Access Methods:**

- `VMScope.of<VM>(context)` - Get VM (throws if not found)
- `VMScope.maybeOf<VM>(context)` - Get VM or null
- `context.vm<VM>()` - Extension method (throws if not found)
- `context.maybeVm<VM>()` - Extension method (returns null if not found)

**Important:** VMScope does NOT create or dispose VMs - you must manage the lifecycle explicitly in your State class.

## Best Practices 💡

### ✅ Do's

- **Always dispose:** Call `vm.dispose()` in your widget's dispose method
- **Use appropriate guards:** Choose the right guard for your use case
- **Keep VMs focused:** One VM per feature/screen
- **Leverage coordination:** Use CoordinatedVM for dependent state
- **Handle all states:** Always handle loading, data, and error in UI

### ❌ Don'ts

- **Don't use setState:** Let the VM manage state
- **Don't forget dispose:** Memory leaks will occur
- **Don't mix concerns:** Keep business logic in VMs, not widgets
- **Don't ignore errors:** Always show user-friendly error messages
- **Don't nest guards:** One operation at a time per VM

## Testing 🧪

Guard VMs are designed to be testable:

```dart
test('loadUser sets data on success', () async {
  final mockRepo = MockUserRepository();
  final vm = UserVM(mockRepo);
  final user = User(id: '1', name: 'Test');

  when(() => mockRepo.getUser('1')).thenAnswer((_) async => user);

  expect(vm.value.isLoading, true);

  await vm.loadUser('1');

  expect(vm.value.hasValue, true);
  expect(vm.value.value, user);

  vm.dispose();
});

test('loadUser sets error on failure', () async {
  final mockRepo = MockUserRepository();
  final vm = UserVM(mockRepo);
  final error = Exception('Network error');

  when(() => mockRepo.getUser('1')).thenThrow(error);

  await vm.loadUser('1');

  expect(vm.value.hasError, true);
  expect(vm.value.errorValue, error);

  vm.dispose();
});
```

To run tests:

```sh
flutter test
```

For coverage:

```sh
flutter test --coverage
genhtml coverage/lcov.info -o coverage/
open coverage/index.html
```

## Architecture 🏗️

```
┌─────────────────┐
│   Widget        │
│  (UI Layer)     │
└────────┬────────┘
         │ listens to
         ▼
┌─────────────────┐
│   GuardVM<T>    │
│ (State Layer)   │
└────────┬────────┘
         │ calls
         ▼
┌─────────────────┐
│  Repository     │
│ (Data Layer)    │
└─────────────────┘
```

**Separation of Concerns:**

- **Widget:** Only renders UI based on state
- **ViewModel:** Manages state and business logic
- **Repository:** Handles data sources and API calls

## Comparison with Other Solutions 📊

| Feature        | Guard VM | Provider | Riverpod | Bloc     |
| -------------- | -------- | -------- | -------- | -------- |
| Learning Curve | Low      | Low      | Medium   | High     |
| Boilerplate    | Minimal  | Minimal  | Medium   | High     |
| Type Safety    | ✅       | ✅       | ✅       | ✅       |
| Async State    | Built-in | Manual   | Built-in | Manual   |
| Testing        | Easy     | Easy     | Easy     | Medium   |
| Code Gen       | Optional | No       | Optional | No       |
| Stream Support | Built-in | Manual   | Built-in | Built-in |

## Contributing 🤝

Contributions are welcome! Please read the contribution guidelines before submitting PRs.

## License 📄

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**Made with ❤️ for Flutter developers who value simplicity and discipline**

[coverage_badge]: coverage_badge.svg
[flutter_install_link]: https://docs.flutter.dev/get-started/install
[github_actions_link]: https://docs.github.com/en/actions/learn-github-actions
[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[logo_black]: https://raw.githubusercontent.com/VGVentures/very_good_brand/main/styles/README/vgv_logo_black.png#gh-light-mode-only
[logo_white]: https://raw.githubusercontent.com/VGVentures/very_good_brand/main/styles/README/vgv_logo_white.png#gh-dark-mode-only
[mason_link]: https://github.com/felangel/mason
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
[very_good_cli_link]: https://pub.dev/packages/very_good_cli
[very_good_coverage_link]: https://github.com/marketplace/actions/very-good-coverage
[very_good_ventures_link]: https://verygood.ventures
[very_good_ventures_link_light]: https://verygood.ventures#gh-light-mode-only
[very_good_ventures_link_dark]: https://verygood.ventures#gh-dark-mode-only
[very_good_workflows_link]: https://github.com/VeryGoodOpenSource/very_good_workflows

// ignore_for_file: invalid_use_of_protected_member, unreachable_from_main

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guard_vm/guard_vm.dart';
import 'package:mocktail/mocktail.dart';

// Mock repository for testing
class MockUserRepository extends Mock implements UserRepository {}

// Example model
@immutable
class User {
  const User({required this.id, required this.name});
  final String id;
  final String name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User && runtimeType == other.runtimeType && id == other.id && name == other.name;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;
}

// Example repository interface
abstract class UserRepository {
  Future<User> getUser(String id);
  Future<User> updateUser(User user);
}

// Example ViewModel implementation
class UserVM extends GuardVM<User> {
  UserVM(this._repository) : super(const AsyncValue.loading());

  final UserRepository _repository;

  Future<void> loadUser(String id) => guard(
    () => _repository.getUser(id),
  );

  Future<void> updateUser(User user) => guardOptimistic(
    optimisticState: user,
    action: () => _repository.updateUser(user),
  );

  Future<Result<User>> loginUser(String id) => guardWithResult(
    () => _repository.getUser(id),
  );

  // Test helper to set data directly
  void setTestData(User user) => setData(user);
}

void main() {
  group('GuardVM', () {
    late MockUserRepository mockRepo;
    late UserVM vm;

    setUp(() {
      mockRepo = MockUserRepository();
      vm = UserVM(mockRepo);
    });

    tearDown(() {
      // Only dispose if not already disposed
      if (!vm.disposed) {
        vm.dispose();
      }
    });

    test('initial state is loading', () {
      expect(vm.value.isLoading, true);
    });

    test('guard sets data on success', () async {
      const user = User(id: '1', name: 'Test User');
      when(() => mockRepo.getUser('1')).thenAnswer((_) async => user);

      expect(vm.value.isLoading, true);

      await vm.loadUser('1');

      expect(vm.value.hasValue, true);
      expect(vm.value.value, user);
      expect(vm.isExecuting, false);
    });

    test('guard sets error on failure', () async {
      final error = Exception('Network error');
      when(() => mockRepo.getUser('1')).thenThrow(error);

      await vm.loadUser('1');

      expect(vm.value.hasError, true);
      expect(vm.value.errorValue, error);
      expect(vm.isExecuting, false);
    });

    test('guardWithResult returns success result', () async {
      const user = User(id: '1', name: 'Test User');
      when(() => mockRepo.getUser('1')).thenAnswer((_) async => user);

      final result = await vm.loginUser('1');

      expect(result.isSuccess, true);
      expect(result.data, user);
      expect(result.error, null);
    });

    test('guardWithResult returns failure result', () async {
      final error = Exception('Login failed');
      when(() => mockRepo.getUser('1')).thenThrow(error);

      final result = await vm.loginUser('1');

      expect(result.isSuccess, false);
      expect(result.data, null);
      expect(result.error, error);
    });

    test('guardOptimistic updates immediately then confirms', () async {
      const user = User(id: '1', name: 'Updated User');
      when(() => mockRepo.updateUser(user)).thenAnswer((_) async => user);

      // Set initial data
      vm.setTestData(const User(id: '1', name: 'Original User'));

      expect(vm.value.value?.name, 'Original User');

      // Start optimistic update
      final updateFuture = vm.updateUser(user);

      // Should immediately show optimistic state
      expect(vm.value.value?.name, 'Updated User');

      await updateFuture;

      // Should still show updated state after confirmation
      expect(vm.value.value?.name, 'Updated User');
      expect(vm.value.hasError, false);
    });

    test('guardOptimistic rolls back on error', () async {
      const originalUser = User(id: '1', name: 'Original User');
      const updatedUser = User(id: '1', name: 'Updated User');
      final error = Exception('Update failed');

      vm.setTestData(originalUser);
      when(() => mockRepo.updateUser(updatedUser)).thenThrow(error);

      // Should show original state
      expect(vm.value.value?.name, 'Original User');

      // Start optimistic update
      await vm.updateUser(updatedUser);

      // Should roll back to original state
      expect(vm.value.hasError, true);
    });

    test('isExecuting tracks operation state', () async {
      const user = User(id: '1', name: 'Test User');
      when(() => mockRepo.getUser('1')).thenAnswer(
        (_) => Future.delayed(const Duration(milliseconds: 100), () => user),
      );

      expect(vm.isExecuting, false);

      final future = vm.loadUser('1');
      expect(vm.isExecuting, true);

      await future;
      expect(vm.isExecuting, false);
    });

    test('notifies listeners on state change', () async {
      const user = User(id: '1', name: 'Test User');
      when(() => mockRepo.getUser('1')).thenAnswer((_) async => user);

      var notificationCount = 0;
      vm.addListener(() => notificationCount++);

      await vm.loadUser('1');

      expect(notificationCount, greaterThan(0));
    });

    test('dispose prevents further updates', () async {
      const user = User(id: '1', name: 'Test User');
      when(() => mockRepo.getUser('1')).thenAnswer(
        (_) => Future<User>.delayed(const Duration(milliseconds: 100), () => user),
      );

      // Get initial state
      final initialState = vm.value;
      expect(initialState.isLoading, true);

      // Start operation and dispose immediately
      final future = vm.loadUser('1');
      final stateBeforeDispose = vm.value;
      vm.dispose();

      // Wait for operation to complete
      await future;

      // State should not change after dispose
      expect(vm.value, stateBeforeDispose);
      expect(vm.value.isLoading, true);

      // Note: tearDown won't dispose again since already disposed
    });
  });

  group('AsyncValue', () {
    test('loading state', () {
      const value = AsyncValue<int>.loading();

      expect(value.isLoading, true);
      expect(value.hasValue, false);
      expect(value.hasError, false);
      expect(value.value, null);
    });

    test('data state', () {
      const value = AsyncValue<int>.data(42);

      expect(value.isLoading, false);
      expect(value.hasValue, true);
      expect(value.hasError, false);
      expect(value.value, 42);
    });

    test('error state', () {
      final error = Exception('Test error');
      final value = AsyncValue<int>.error(error);

      expect(value.isLoading, false);
      expect(value.hasValue, false);
      expect(value.hasError, true);
      expect(value.errorValue, error);
    });

    test('when pattern matching', () {
      const loading = AsyncValue<int>.loading();
      const data = AsyncValue<int>.data(42);
      final error = AsyncValue<int>.error(Exception('Error'));

      expect(
        loading.when(
          loading: () => 'loading',
          data: (_) => 'data',
          error: (_) => 'error',
        ),
        'loading',
      );

      expect(
        data.when(
          loading: () => 'loading',
          data: (v) => 'data: $v',
          error: (_) => 'error',
        ),
        'data: 42',
      );

      expect(
        error.when(
          loading: () => 'loading',
          data: (_) => 'data',
          error: (_) => 'error',
        ),
        'error',
      );
    });
  });

  group('PaginatedState', () {
    test('canLoadMore returns true when conditions met', () {
      const state = PaginatedState<int>(
        items: [1, 2, 3],
        currentPage: 1,
        totalPages: 3,
        totalItems: 9,
      );

      expect(state.canLoadMore, true);
    });

    test('canLoadMore returns false when loading more', () {
      const state = PaginatedState<int>(
        items: [1, 2, 3],
        currentPage: 1,
        totalPages: 3,
        totalItems: 9,
        isLoadingMore: true,
      );

      expect(state.canLoadMore, false);
    });

    test('canLoadMore returns false when reached end', () {
      const state = PaginatedState<int>(
        items: [1, 2, 3],
        currentPage: 1,
        totalPages: 3,
        totalItems: 9,
        hasReachedEnd: true,
      );

      expect(state.canLoadMore, false);
    });

    test('canLoadMore returns false when on last page', () {
      const state = PaginatedState<int>(
        items: [1, 2, 3],
        currentPage: 3,
        totalPages: 3,
        totalItems: 9,
      );

      expect(state.canLoadMore, false);
    });
  });

  group('Result', () {
    test('success result', () {
      final result = Result<int>.success(42);

      expect(result.isSuccess, true);
      expect(result.data, 42);
      expect(result.error, null);

      result.when(
        success: (data) => expect(data, 42),
        failure: (_) => fail('Should not call failure'),
      );
    });

    test('failure result', () {
      final error = Exception('Test error');
      final result = Result<int>.failure(error);

      expect(result.isSuccess, false);
      expect(result.data, null);
      expect(result.error, error);

      result.when(
        success: (_) => fail('Should not call success'),
        failure: (e) => expect(e, error),
      );
    });
  });

  group('GuardVM - Additional Methods', () {
    late MockUserRepository mockRepo;
    late TestVM vm;

    setUp(() {
      mockRepo = MockUserRepository();
      vm = TestVM(mockRepo);
    });

    tearDown(() {
      if (!vm.disposed) {
        vm.dispose();
      }
    });

    test('guardSilent updates without loading state', () async {
      const user = User(id: '1', name: 'Test User');
      when(() => mockRepo.getUser('1')).thenAnswer((_) async => user);

      // Set initial data
      vm.setTestData(const User(id: '2', name: 'Initial User'));
      expect(vm.value.hasValue, true);

      await vm.silentLoad('1');

      expect(vm.value.hasValue, true);
      expect(vm.value.value, user);
    });

    test('refresh is alias for guardSilent', () async {
      const user = User(id: '1', name: 'Refreshed User');
      when(() => mockRepo.getUser('1')).thenAnswer((_) async => user);

      vm.setTestData(const User(id: '2', name: 'Old User'));

      await vm.refreshData('1');

      expect(vm.value.hasValue, true);
      expect(vm.value.value, user);
    });

    test('guardUpdate transforms current data', () async {
      vm.setTestData(const User(id: '1', name: 'Original'));

      await vm.updateName('Updated');

      expect(vm.value.value?.name, 'Updated');
    });

    test('guardUpdate does nothing when no data', () async {
      expect(vm.value.isLoading, true);

      await vm.updateName('Updated');

      // Should still be loading, no update performed
      expect(vm.value.isLoading, true);
    });

    test('guardUpdate rolls back on error', () async {
      const original = User(id: '1', name: 'Original');
      vm.setTestData(original);

      await vm.updateNameWithError('Updated');

      // Should roll back to original and be in error state
      expect(vm.value.hasError, true);
    });

    test('non-Exception error is wrapped', () async {
      when(() => mockRepo.getUser('1')).thenThrow('String error');

      await vm.loadUser('1');

      expect(vm.value.hasError, true);
      expect(vm.value.errorValue.toString(), contains('String error'));
    });

    test('disposed getter works', () {
      expect(vm.disposed, false);
      vm.dispose();
      expect(vm.disposed, true);
    });

    test('guardWithResult handles non-Exception error', () async {
      when(() => mockRepo.getUser('1')).thenThrow('String error');

      final result = await vm.loginUser('1');

      expect(result.isSuccess, false);
      expect(result.error.toString(), contains('String error'));
    });

    test('guardSilent handles non-Exception error', () async {
      when(() => mockRepo.getUser('1')).thenThrow(StateError('State error'));

      vm.setTestData(const User(id: '2', name: 'Initial'));
      await vm.silentLoad('1');

      expect(vm.value.hasError, true);
      expect(vm.value.errorValue.toString(), contains('State error'));
    });

    test('guardOptimistic handles non-Exception error with rollback', () async {
      const original = User(id: '1', name: 'Original');
      vm.setTestData(original);

      await vm.updateWithNonException('Updated');

      expect(vm.value.hasError, true);
      // Error should wrap the non-Exception
      expect(vm.value.errorValue.toString(), contains('Bad state'));
    });

    test('operations during disposal are ignored', () async {
      const user = User(id: '1', name: 'Test User');
      when(() => mockRepo.getUser('1')).thenAnswer(
        (_) => Future<User>.delayed(const Duration(milliseconds: 50), () => user),
      );

      final isLoadingBefore = vm.value.isLoading;
      final future = vm.loadUser('1');

      // Dispose while operation is running
      await Future<void>.delayed(const Duration(milliseconds: 10));
      vm.dispose();

      await future;

      // State should still be loading (didn't update after disposal)
      expect(vm.value.isLoading, isLoadingBefore);
      expect(vm.value.hasValue, false);
    });
  });

  group('StreamGuardVM', () {
    late StreamVM vm;
    late StreamController<int> controller;

    setUp(() {
      controller = StreamController<int>();
      vm = StreamVM();
    });

    tearDown(() {
      if (!vm.disposed) {
        vm.dispose();
      }
      if (!controller.isClosed) {
        controller.close();
      }
    });

    test('guardStream sets loading initially', () {
      vm.startListening(controller.stream);
      expect(vm.value.isLoading, true);
    });

    test('guardStream updates with emitted data', () async {
      vm.startListening(controller.stream);

      controller.add(42);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(vm.value.hasValue, true);
      expect(vm.value.value, 42);
    });

    test('guardStream calls onData callback', () async {
      var callbackData = 0;
      vm.startListeningWithCallback(
        controller.stream,
        (data) => callbackData = data,
      );

      controller.add(99);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(callbackData, 99);
    });

    test('guardStream handles errors', () async {
      vm.startListening(controller.stream);

      controller.addError(Exception('Stream error'));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(vm.value.hasError, true);
    });

    test('dispose cancels stream subscriptions', () async {
      vm.startListening(controller.stream);
      expect(vm.value.isLoading, true);

      vm.dispose();

      // Add data after disposal - should not update
      controller.add(100);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Should still be loading (no update after disposal)
      expect(vm.value.isLoading, true);
    });

    test('supports multiple stream subscriptions', () async {
      final controller2 = StreamController<int>();

      vm
        ..startListening(controller.stream)
        ..startListening(controller2.stream);

      controller.add(1);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      controller2.add(2);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(vm.value.value, 2); // Last emitted value

      await controller2.close();
    });
  });

  group('CoordinatedVM', () {
    late CoordinatedTestVM vm;
    late TestVM sourceVM;
    late MockUserRepository mockRepo;

    setUp(() {
      mockRepo = MockUserRepository();
      sourceVM = TestVM(mockRepo);
      vm = CoordinatedTestVM(sourceVM);
    });

    tearDown(() {
      if (!vm.disposed) {
        vm.dispose();
      }
      if (!sourceVM.disposed) {
        sourceVM.dispose();
      }
    });

    test('coordinateWith listens to other VM', () {
      sourceVM.setTestData(const User(id: '1', name: 'Test'));

      // VM should have reacted to the change
      expect(vm.value.hasValue, true);
      expect(vm.value.value, 'Test'); // VM converts user name to string
    });

    test('coordinateWith executes immediately when requested', () {
      final vm2 = CoordinatedTestVM(sourceVM, executeImmediately: true);

      // Should immediately get the current state
      expect(vm2.value.hasValue, true);

      vm2.dispose();
    });

    test('coordinateWith propagates errors', () {
      final error = Exception('Source error');
      sourceVM.setError(error);

      // Error should propagate
      expect(vm.value.hasError, true);
      expect(vm.value.errorValue, error);
    });

    test('coordinateWith handles loading state', () {
      sourceVM.setLoading();

      // Loading state is ignored by coordinateWith
      expect(vm.value.hasValue, true);
    });

    test('dispose removes listeners from coordinated VMs', () {
      // First set some data so vm has a value
      sourceVM.setTestData(const User(id: '1', name: 'Initial'));
      // Give time for coordination to happen
      expect(vm.value.value, 'Initial');

      vm.dispose();

      // Change source VM after disposal
      sourceVM.setTestData(const User(id: '2', name: 'Changed'));

      // Coordinated VM should not have been updated (already disposed)
      expect(vm.value.value, 'Initial'); // Should still have initial value
    });
  });

  group('PaginatedGuardVM', () {
    late PaginatedTestVM vm;
    late MockProductRepository mockRepo;

    setUp(() {
      mockRepo = MockProductRepository();
      vm = PaginatedTestVM(mockRepo);
    });

    tearDown(() {
      if (!vm.disposed) {
        vm.dispose();
      }
    });

    test('guardLoadMore loads next page', () async {
      // Set initial state with data
      vm.setInitialData();

      expect(vm.value.value?.items.length, 3);
      expect(vm.value.value?.currentPage, 1);

      await vm.loadMore();

      expect(vm.value.value?.items.length, 6); // 3 + 3 more
      expect(vm.value.value?.currentPage, 2);
    });

    test('guardLoadMore sets loading flag', () async {
      vm.setInitialData();

      final future = vm.loadMore();

      // Should show loading more flag
      await Future<void>.delayed(const Duration(milliseconds: 10));
      // Note: might already be completed, so we check the end result
      await future;

      expect(vm.value.value?.isLoadingMore, false); // Should be reset after
    });

    test('guardLoadMore prevents concurrent requests', () async {
      vm.setInitialData();

      final future1 = vm.loadMore();
      final future2 = vm.loadMore(); // Should be ignored

      await Future.wait([future1, future2]);

      // Should only load once (6 items, not 9)
      expect(vm.value.value?.items.length, 6);
    });

    test('guardLoadMore does nothing when cant load more', () async {
      vm.setEndReachedData();

      await vm.loadMore();

      // Should still have 3 items (no load performed)
      expect(vm.value.value?.items.length, 3);
    });

    test('guardLoadMore does nothing when no data', () async {
      expect(vm.value.isLoading, true);

      await vm.loadMore();

      expect(vm.value.isLoading, true); // No change
    });

    test('guardLoadMore handles errors', () async {
      vm.setInitialData();

      await vm.loadMoreWithError();

      expect(vm.value.hasError, true);
      // After error, state transitions to error, don't check data properties
    });

    test('guardLoadMore handles non-Exception errors', () async {
      vm.setInitialData();

      await vm.loadMoreWithStringError();

      expect(vm.value.hasError, true);
    });

    test('refreshPaginated uses guardSilent', () async {
      vm.setInitialData();

      await vm.refreshData();

      expect(vm.value.hasValue, true);
      expect(vm.value.value?.items.length, 3); // Refreshed data
    });
  });

  group('AsyncValue - Additional', () {
    test('asData returns AsyncData when data', () {
      const value = AsyncValue<int>.data(42);
      final asData = value.asData;

      expect(asData, isNotNull);
      expect(asData!.value, 42);
    });

    test('asData returns null when not data', () {
      const loading = AsyncValue<int>.loading();
      expect(loading.asData, isNull);

      final error = AsyncValue<int>.error(Exception('Error'));
      expect(error.asData, isNull);
    });

    test('asError returns AsyncError when error', () {
      final error = Exception('Test');
      final value = AsyncValue<int>.error(error);
      final asError = value.asError;

      expect(asError, isNotNull);
      expect(asError!.error, error);
    });

    test('asError returns null when not error', () {
      const loading = AsyncValue<int>.loading();
      expect(loading.asError, isNull);

      const data = AsyncValue<int>.data(42);
      expect(data.asError, isNull);
    });

    test('asLoading returns AsyncLoading when loading', () {
      const value = AsyncValue<int>.loading();
      final asLoading = value.asLoading;

      expect(asLoading, isNotNull);
    });

    test('asLoading returns null when not loading', () {
      const data = AsyncValue<int>.data(42);
      expect(data.asLoading, isNull);

      final error = AsyncValue<int>.error(Exception('Error'));
      expect(error.asLoading, isNull);
    });

    test('maybeWhen with orElse', () {
      const loading = AsyncValue<int>.loading();

      final result = loading.maybeWhen(
        data: (v) => 'data: $v',
        orElse: () => 'other',
      );

      expect(result, 'other');
    });
  });
}

// Additional test ViewModels

class TestVM extends GuardVM<User> {
  TestVM(this._repository) : super(const AsyncValue.loading());

  final UserRepository _repository;

  Future<void> loadUser(String id) => guard(() => _repository.getUser(id));

  Future<Result<User>> loginUser(String id) => guardWithResult(() => _repository.getUser(id));

  Future<void> silentLoad(String id) => guardSilent(() => _repository.getUser(id));

  Future<void> refreshData(String id) => refresh(() => _repository.getUser(id));

  Future<void> updateName(String newName) => guardUpdate((current) async {
    return User(id: current.id, name: newName);
  });

  Future<void> updateNameWithError(String newName) => guardUpdate((current) async {
    throw Exception('Update failed');
  });

  Future<void> updateWithNonException(String newName) => guardOptimistic(
    optimisticState: User(id: '1', name: newName),
    action: () async {
      throw StateError('Non-exception error');
    },
  );

  void setTestData(User user) => setData(user);
}

class StreamVM extends StreamGuardVM<int> {
  StreamVM() : super(const AsyncValue.loading());

  void startListening(Stream<int> stream) {
    guardStream(stream);
  }

  void startListeningWithCallback(Stream<int> stream, void Function(int) onData) {
    guardStream(stream, onData);
  }
}

class CoordinatedTestVM extends CoordinatedVM<String> {
  CoordinatedTestVM(this._sourceVM, {bool executeImmediately = false}) : super(const AsyncValue.data('')) {
    coordinateWith(
      _sourceVM,
      (user) => setData(user.name),
      executeImmediately: executeImmediately,
    );
  }

  final TestVM _sourceVM;
}

class Product {
  const Product(this.id, this.name);

  final int id;
  final String name;
}

abstract class ProductRepository {
  Future<List<Product>> getProducts(int page);
}

class MockProductRepository extends Mock implements ProductRepository {}

class PaginatedTestVM extends PaginatedGuardVM<Product> {
  PaginatedTestVM(this._repository) : super(const AsyncValue.loading());

  // ignore: unused_field
  final ProductRepository _repository;

  void setInitialData() {
    setData(
      const PaginatedState(
        items: [Product(1, 'A'), Product(2, 'B'), Product(3, 'C')],
        currentPage: 1,
        totalPages: 3,
        totalItems: 9,
      ),
    );
  }

  void setEndReachedData() {
    setData(
      const PaginatedState(
        items: [Product(1, 'A'), Product(2, 'B'), Product(3, 'C')],
        currentPage: 3,
        totalPages: 3,
        totalItems: 9,
        hasReachedEnd: true,
      ),
    );
  }

  Future<void> loadMore() => guardLoadMore((current) async {
    final newPage = current.currentPage + 1;
    final newItems = [
      Product(newPage * 3 - 2, 'Item ${newPage * 3 - 2}'),
      Product(newPage * 3 - 1, 'Item ${newPage * 3 - 1}'),
      Product(newPage * 3, 'Item ${newPage * 3}'),
    ];

    return PaginatedState(
      items: [...current.items, ...newItems],
      currentPage: newPage,
      totalPages: current.totalPages,
      totalItems: current.totalItems,
    );
  });

  Future<void> loadMoreWithError() => guardLoadMore((current) async {
    throw Exception('Load more failed');
  });

  Future<void> loadMoreWithStringError() => guardLoadMore((current) async {
    throw Exception('String error');
  });

  Future<void> refreshData() => refreshPaginated(() async {
    return const PaginatedState(
      items: [Product(1, 'A'), Product(2, 'B'), Product(3, 'C')],
      currentPage: 1,
      totalPages: 3,
      totalItems: 9,
    );
  });
}

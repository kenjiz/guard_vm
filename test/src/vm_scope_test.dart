// ignore_for_file: unreachable_from_main

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guard_vm/guard_vm.dart';

// Test VMs
class CounterVM extends GuardVM<int> {
  CounterVM() : super(const AsyncValue.data(0));

  void increment() {
    final current = value.value ?? 0;
    setData(current + 1);
  }
}

class UserVM extends GuardVM<String> {
  UserVM() : super(const AsyncValue.data('John'));

  void updateName(String name) => setData(name);
}

void main() {
  group('VMScope', () {
    testWidgets('provides VM to descendants', (tester) async {
      final vm = CounterVM();

      await tester.pumpWidget(
        VMScope<CounterVM>(
          vm: vm,
          child: Builder(
            builder: (context) {
              final counterVM = VMScope.of<CounterVM>(context);
              return Directionality(
                textDirection: TextDirection.ltr,
                child: Text('${counterVM.value.value}'),
              );
            },
          ),
        ),
      );

      expect(find.text('0'), findsOneWidget);
      vm.dispose();
    });

    testWidgets('context.vm() extension works', (tester) async {
      final vm = CounterVM();

      await tester.pumpWidget(
        VMScope<CounterVM>(
          vm: vm,
          child: Builder(
            builder: (context) {
              final counterVM = context.vm<CounterVM>();
              return Directionality(
                textDirection: TextDirection.ltr,
                child: Text('${counterVM.value.value}'),
              );
            },
          ),
        ),
      );

      expect(find.text('0'), findsOneWidget);
      vm.dispose();
    });

    testWidgets('VM is NOT disposed by VMScope', (tester) async {
      final vm = CounterVM();

      await tester.pumpWidget(
        VMScope<CounterVM>(vm: vm, child: const SizedBox()),
      );

      expect(vm.disposed, false);

      // Remove VMScope from tree
      await tester.pumpWidget(const SizedBox());

      // VM should NOT be disposed - that's the parent's responsibility
      expect(vm.disposed, false);

      vm.dispose();
    });

    testWidgets('supports multiple nested VMScopes', (tester) async {
      final counterVM = CounterVM();
      final userVM = UserVM();

      await tester.pumpWidget(
        VMScope<CounterVM>(
          vm: counterVM,
          child: VMScope<UserVM>(
            vm: userVM,
            child: Builder(
              builder: (context) {
                final counter = context.vm<CounterVM>();
                final user = context.vm<UserVM>();
                return Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text('${counter.value.value} ${user.value.value}'),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('0 John'), findsOneWidget);

      counterVM.dispose();
      userVM.dispose();
    });

    testWidgets('maybeOf returns null when not found', (tester) async {
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            final vm = VMScope.maybeOf<CounterVM>(context);
            return Directionality(
              textDirection: TextDirection.ltr,
              child: Text(vm == null ? 'null' : 'found'),
            );
          },
        ),
      );

      expect(find.text('null'), findsOneWidget);
    });

    testWidgets('context.maybeVm() returns null when not found', (tester) async {
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            final vm = context.maybeVm<CounterVM>();
            return Directionality(
              textDirection: TextDirection.ltr,
              child: Text(vm == null ? 'null' : 'found'),
            );
          },
        ),
      );

      expect(find.text('null'), findsOneWidget);
    });

    testWidgets('throws assertion when VM not found', (tester) async {
      await tester.pumpWidget(
        Builder(builder: (context) => const SizedBox()),
      );

      expect(
        () => VMScope.of<CounterVM>(tester.element(find.byType(SizedBox))),
        throwsAssertionError,
      );
    });
  });
}

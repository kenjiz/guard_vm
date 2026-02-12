import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guard_vm/guard_vm.dart';

// Test VM
class CounterVM extends GuardVM<int> {
  CounterVM() : super(const AsyncValue.data(0));

  void increment() {
    final current = value.value ?? 0;
    setData(current + 1);
  }

  void decrement() {
    final current = value.value ?? 0;
    setData(current - 1);
  }
}

void main() {
  group('VMProvider', () {
    testWidgets('provides VM to descendants with create', (tester) async {
      late CounterVM vm;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: VMProvider<CounterVM>(
            create: (context) {
              vm = CounterVM();
              return vm;
            },
            child: Builder(
              builder: (context) {
                final counterVM = VMProvider.of<CounterVM>(context, listen: false);
                return Text('${counterVM.value.value}');
              },
            ),
          ),
        ),
      );

      expect(find.text('0'), findsOneWidget);
      expect(vm.disposed, false);
    });

    testWidgets('provides VM to descendants with value', (tester) async {
      final vm = CounterVM();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: VMProvider<CounterVM>.value(
            value: vm,
            child: Builder(
              builder: (context) {
                final counterVM = VMProvider.of<CounterVM>(context, listen: false);
                return Text('${counterVM.value.value}');
              },
            ),
          ),
        ),
      );

      expect(find.text('0'), findsOneWidget);
      expect(vm.disposed, false);

      // Clean up
      vm.dispose();
    });

    testWidgets('rebuilds descendants when VM state changes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: VMProvider<CounterVM>(
            create: (context) => CounterVM(),
            child: Builder(
              builder: (context) {
                final vm = context.watch<CounterVM>();
                return Scaffold(
                  body: Center(
                    child: Text('${vm.value.value}'),
                  ),
                  floatingActionButton: FloatingActionButton(
                    onPressed: vm.increment,
                    child: const Icon(Icons.add),
                  ),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('0'), findsOneWidget);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();

      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('does not rebuild when using read', (tester) async {
      var buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: VMProvider<CounterVM>(
            create: (context) => CounterVM(),
            child: Builder(
              builder: (context) {
                buildCount++;
                final vm = context.read<CounterVM>();
                return Scaffold(
                  body: Center(
                    child: Text('build: $buildCount'),
                  ),
                  floatingActionButton: FloatingActionButton(
                    onPressed: vm.increment,
                    child: const Icon(Icons.add),
                  ),
                );
              },
            ),
          ),
        ),
      );

      expect(buildCount, 1);
      expect(find.text('build: 1'), findsOneWidget);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();

      // Build count should not increase because we used read() instead of watch()
      expect(buildCount, 1);
      expect(find.text('build: 1'), findsOneWidget);
    });

    testWidgets('disposes VM when provider is removed (create mode)', (tester) async {
      late CounterVM vm;

      await tester.pumpWidget(
        VMProvider<CounterVM>(
          create: (context) {
            vm = CounterVM();
            return vm;
          },
          child: const SizedBox(),
        ),
      );

      expect(vm.disposed, false);

      await tester.pumpWidget(const SizedBox());

      expect(vm.disposed, true);
    });

    testWidgets('does not dispose VM in value mode', (tester) async {
      final vm = CounterVM();

      await tester.pumpWidget(
        VMProvider<CounterVM>.value(
          value: vm,
          child: const SizedBox(),
        ),
      );

      expect(vm.disposed, false);

      await tester.pumpWidget(const SizedBox());

      expect(vm.disposed, false);

      // Clean up
      vm.dispose();
    });

    testWidgets('throws ProviderNotFoundException when VM not found', (tester) async {
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            return const SizedBox();
          },
        ),
      );

      expect(
        () => VMProvider.of<CounterVM>(
          tester.element(find.byType(SizedBox)),
          listen: false,
        ),
        throwsA(isA<ProviderNotFoundException>()),
      );
    });

    testWidgets('supports lazy creation', (tester) async {
      var createCalled = false;

      await tester.pumpWidget(
        VMProvider<CounterVM>(
          lazy: true,
          create: (context) {
            createCalled = true;
            return CounterVM();
          },
          child: const SizedBox(),
        ),
      );

      // VM should not be created yet
      expect(createCalled, false);

      await tester.pumpWidget(
        VMProvider<CounterVM>(
          lazy: true,
          create: (context) {
            createCalled = true;
            return CounterVM();
          },
          child: Builder(
            builder: (context) {
              // Access the VM
              VMProvider.of<CounterVM>(context, listen: false);
              return const SizedBox();
            },
          ),
        ),
      );

      // Now VM should be created
      expect(createCalled, true);
    });

    testWidgets('can nest multiple providers', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: VMProvider<CounterVM>(
            create: (context) => CounterVM()..increment(),
            child: VMProvider<CounterVM>(
              create: (context) => CounterVM()..decrement(),
              child: Builder(
                builder: (context) {
                  final vm = context.watch<CounterVM>();
                  return Text('${vm.value.value}');
                },
              ),
            ),
          ),
        ),
      );

      // Should get the inner (nearest) provider
      expect(find.text('-1'), findsOneWidget);
    });
  });
}

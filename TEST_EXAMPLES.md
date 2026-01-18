# Example Tests for Flutter Automation

This document provides example test cases you can add to your test suite.

## Running Examples

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run specific test file
flutter test test/examples/button_widget_test.dart

# Run tests matching pattern
flutter test -k "Button"
```

## Example 1: Button Widget Test

**File**: `test/examples/button_widget_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Button Widget Tests', () {
    testWidgets('Button displays text correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {},
                child: const Text('Click Me'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Click Me'), findsOneWidget);
    });

    testWidgets('Button responds to tap', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  tapped = true;
                },
                child: const Text('Tap Me'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(tapped, true);
    });
  });
}
```

## Example 2: Text Field Test

**File**: `test/examples/text_field_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TextField Tests', () {
    testWidgets('TextField accepts text input', (WidgetTester tester) async {
      const testValue = 'Hello World';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(
              key: const Key('input-field'),
            ),
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('input-field')),
        testValue,
      );

      expect(find.text(testValue), findsOneWidget);
    });

    testWidgets('TextField clears on clear button', (WidgetTester tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(
              controller: controller,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Test Text');
      expect(controller.text, 'Test Text');

      controller.clear();
      await tester.pumpAndSettle();

      expect(controller.text, isEmpty);
      controller.dispose();
    });
  });
}
```

## Example 3: List Widget Test

**File**: `test/examples/list_widget_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ListView Tests', () {
    testWidgets('ListView displays items', (WidgetTester tester) async {
      const items = ['Item 1', 'Item 2', 'Item 3'];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                return Text(items[index]);
              },
            ),
          ),
        ),
      );

      for (final item in items) {
        expect(find.text(item), findsOneWidget);
      }
    });

    testWidgets('ListView scrolls to item', (WidgetTester tester) async {
      final items = List.generate(50, (i) => 'Item $i');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                return ListTile(title: Text(items[index]));
              },
            ),
          ),
        ),
      );

      // Scroll to find item
      await tester.scrollUntilVisible(
        find.text('Item 49'),
        500.0,
      );

      expect(find.text('Item 49'), findsOneWidget);
    });
  });
}
```

## Example 4: Navigation Test

**File**: `test/examples/navigation_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Navigation Tests', () {
    testWidgets('Navigate between screens', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const FirstScreen(),
          routes: {
            '/second': (context) => const SecondScreen(),
          },
        ),
      );

      expect(find.text('First Screen'), findsOneWidget);

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(find.text('Second Screen'), findsOneWidget);
    });

    testWidgets('Navigate back', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const FirstScreen(),
          routes: {
            '/second': (context) => const SecondScreen(),
          },
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('First Screen'), findsOneWidget);
    });
  });
}

class FirstScreen extends StatelessWidget {
  const FirstScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('First')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => Navigator.pushNamed(context, '/second'),
          child: const Text('Go to Second'),
        ),
      ),
    );
  }
}

class SecondScreen extends StatelessWidget {
  const SecondScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Second')),
      body: const Center(child: Text('Second Screen')),
    );
  }
}
```

## Example 5: Form Validation Test

**File**: `test/examples/form_validation_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Form Validation Tests', () {
    testWidgets('Form validates email', (WidgetTester tester) async {
      final formKey = GlobalKey<FormState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: TextFormField(
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Email required';
                  }
                  if (!value!.contains('@')) {
                    return 'Invalid email';
                  }
                  return null;
                },
              ),
            ),
          ),
        ),
      );

      // Test empty validation
      formKey.currentState?.validate();
      await tester.pumpAndSettle();
      expect(find.text('Email required'), findsOneWidget);

      // Test invalid email
      await tester.enterText(find.byType(TextFormField), 'notanemail');
      formKey.currentState?.validate();
      await tester.pumpAndSettle();
      expect(find.text('Invalid email'), findsOneWidget);

      // Test valid email
      await tester.enterText(find.byType(TextFormField), 'test@email.com');
      formKey.currentState?.validate();
      await tester.pumpAndSettle();
      expect(find.text('Invalid email'), findsNothing);
    });
  });
}
```

## Example 6: Async Operation Test

**File**: `test/examples/async_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Async Operation Tests', () {
    test('Async function returns expected value', () async {
      final result = await fetchData();
      expect(result, 'data');
    });

    test('Async function handles errors', () async {
      expect(
        () => fetchDataError(),
        throwsException,
      );
    });

    test('Multiple async operations', () async {
      final results = await Future.wait([
        fetchData(),
        fetchData(),
        fetchData(),
      ]);

      expect(results.length, 3);
      expect(results.every((r) => r == 'data'), true);
    });
  });
}

Future<String> fetchData() async {
  await Future.delayed(const Duration(milliseconds: 100));
  return 'data';
}

Future<String> fetchDataError() async {
  await Future.delayed(const Duration(milliseconds: 100));
  throw Exception('Error');
}
```

## Example 7: Provider/State Management Test

**File**: `test/examples/provider_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

void main() {
  group('Provider Tests', () {
    testWidgets('Provider updates value', (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => CounterNotifier(),
          child: MaterialApp(
            home: Scaffold(
              body: Consumer<CounterNotifier>(
                builder: (context, counter, _) {
                  return Text(counter.count.toString());
                },
              ),
              floatingActionButton: Consumer<CounterNotifier>(
                builder: (context, counter, _) {
                  return FloatingActionButton(
                    onPressed: counter.increment,
                    child: const Icon(Icons.add),
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('0'), findsOneWidget);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);
    });
  });
}

class CounterNotifier extends ChangeNotifier {
  int _count = 0;

  int get count => _count;

  void increment() {
    _count++;
    notifyListeners();
  }
}
```

## Test Best Practices

1. **Use Descriptive Names**: `testWidgets('Button shows error when email invalid', ...)`
2. **Arrange-Act-Assert**: Setup → Action → Verify
3. **One Assertion Focus**: Test one thing per test
4. **Clean Up**: Dispose controllers and listeners
5. **Use Keys**: Add `key` parameter for easier widget finding
6. **Mock External Services**: Use `mockito` package
7. **Test Edge Cases**: Empty states, errors, loading states
8. **Avoid Test Interdependencies**: Each test should be independent

## Running Tests with CI/CD

The automated workflows will run all tests in:
- `test/` directory
- `integration_test/` directory

Results appear in:
- GitHub Actions logs
- Coverage reports on Codecov
- Test artifacts on Actions page

## Resources

- [Flutter Testing Docs](https://flutter.dev/docs/testing)
- [Widget Testing Guide](https://flutter.dev/docs/testing/overview)
- [Integration Testing](https://flutter.dev/docs/testing/integration-tests)

// Global Flutter test configuration. Automatically discovered by `flutter test`.
// Used for one-time setup/teardown across all widget tests.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Ensure a WidgetsBinding exists before tests run.
  TestWidgetsFlutterBinding.ensureInitialized();

  // Keep focus highlight visuals consistent for widget tests.
  final prev = FocusManager.instance.highlightStrategy;
  FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;

  try {
    await testMain();
  } finally {
    // Restore highlight strategy after the suite.
    FocusManager.instance.highlightStrategy = prev;
  }
}

// Basic smoke test: verifies the app boots and shows the home screen title.
//
// Note: ShaktiApp reads from storageServiceProvider, which is normally
// overridden in main.dart after StorageService.init() (Hive setup) resolves.
// For widget tests we provide the same override with a fresh in-memory-backed
// StorageService so the widget tree can build without touching main().

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:shakti_bluetooth_chat/app.dart';
import 'package:shakti_bluetooth_chat/core/providers/core_providers.dart';
import 'package:shakti_bluetooth_chat/core/services/storage_service.dart';

void main() {
  setUpAll(() async {
    // Use a temp in-memory-like Hive instance for tests.
    Hive.init('./.test_hive');
  });

  testWidgets('App boots and shows the home screen', (WidgetTester tester) async {
    final storageService = await StorageService.init();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storageService),
        ],
        child: const ShaktiApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Shakti Chat'), findsOneWidget);
  });
}

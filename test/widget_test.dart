import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:progression_tracker/core/database/app_database.dart';
import 'package:progression_tracker/features/tasks/presentation/providers/task_providers.dart';
import 'package:progression_tracker/main.dart';

void main() {
  testWidgets('ProgressionTrackerApp loads successfully on desktop resolution', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final inMemoryDb = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(inMemoryDb),
        ],
        child: const ProgressionTrackerApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify app bar title
    expect(find.text('Progression Tracker'), findsOneWidget);
    // Verify Task Baru button
    expect(find.text('Task Baru'), findsOneWidget);

    // Cleanly unmount and drain stream timers
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
    await inMemoryDb.close();
  });
}

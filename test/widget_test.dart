import 'package:flutter_test/flutter_test.dart';
import 'package:cross_platform_utility_app/main.dart';

void main() {
  test('UtilityEntry saves and retrieves its data', () {
    final entry = UtilityEntry(
      id: '1',
      title: 'My First Note',
      description: 'Testing encrypted utility app',
      type: 'Note',
      isCompleted: false,
      createdAt: DateTime(2026, 11, 5),
    );

    final restoredEntry = UtilityEntry.fromMap(entry.toMap());

    expect(restoredEntry.title, 'My First Note');
    expect(restoredEntry.description, 'Testing encrypted utility app');
    expect(restoredEntry.type, 'Note');
    expect(restoredEntry.isCompleted, false);
  });
}
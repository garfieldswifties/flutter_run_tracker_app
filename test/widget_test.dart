import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_run_tracker_app/main.dart';
import 'package:flutter_run_tracker_app/models/run.dart';
import 'package:flutter_run_tracker_app/models/run_photo.dart';
import 'package:flutter_run_tracker_app/services/run_service.dart';

void main() {
  const where = ValueKey('run-where');
  const person = ValueKey('run-person');
  const distance = ValueKey('run-distance');
  const save = ValueKey('save-run');
  const add = ValueKey('add-run');

  Future<void> launch(WidgetTester tester, MockRunService service) async {
    await tester.pumpWidget(RunTrackerApp(service: service));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  }

  testWidgets('Splash replaces route and list handles an empty result', (
    tester,
  ) async {
    final service = MockRunService();
    await tester.pumpWidget(RunTrackerApp(service: service));
    expect(find.text('RUN TRACKER'), findsOneWidget);
    expect(find.textContaining('Developed by garfieldswifties'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2999));
    expect(find.byKey(add), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(service.fetches, 1);
    expect(find.text('วิ่งกันเถอะ'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
    expect(Navigator.of(tester.element(find.byKey(add))).canPop(), isFalse);
  });

  testWidgets('validates, resets and refreshes create, edit and delete', (
    tester,
  ) async {
    final service = MockRunService();
    await launch(tester, service);
    await tester.tap(find.byKey(add));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(save));
    await tester.tap(find.byKey(save));
    await tester.pumpAndSettle();
    expect(find.text('กรุณากรอกข้อมูลให้ครบทั้ง 3 ช่อง'), findsOneWidget);
    expect(service.rows, isEmpty);

    await tester.enterText(find.byKey(where), '   สวนทดสอบ   ');
    await tester.enterText(find.byKey(person), 'วิ่งคนเดียว');
    for (final invalid in ['0', '-1', '3.5', '2147483648']) {
      await tester.enterText(find.byKey(distance), invalid);
      await tester.ensureVisible(find.byKey(save));
      await tester.tap(find.byKey(save));
      await tester.pumpAndSettle();
      expect(service.rows, isEmpty);
    }
    await tester.ensureVisible(find.byKey(const ValueKey('clear-run')));
    await tester.tap(find.byKey(const ValueKey('clear-run')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(where)).controller!.text, '');

    await tester.enterText(find.byKey(where), '  สวนทดสอบ  ');
    await tester.enterText(find.byKey(person), '  วิ่งคนเดียว  ');
    await tester.enterText(find.byKey(distance), '5');
    await tester.ensureVisible(find.byKey(save));
    await tester.tap(find.byKey(save));
    await tester.pumpAndSettle();
    expect(service.rows.single.runWhere, 'สวนทดสอบ');
    expect(service.rows.single.runPerson, 'วิ่งคนเดียว');
    expect(service.rows.single.runImageUrl, isNull);
    expect(service.fetches, 2);
    expect(find.text('วิ่งไปเท่าไหร่: 5 กม.'), findsOneWidget);

    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byKey(distance)).controller!.text,
      '5',
    );
    await tester.enterText(find.byKey(distance), '6');
    await tester.ensureVisible(find.byKey(save));
    await tester.tap(find.byKey(save));
    await tester.pumpAndSettle();
    expect(service.fetches, 3);
    expect(find.text('วิ่งไปเท่าไหร่: 6 กม.'), findsOneWidget);

    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    const remove = ValueKey('delete-run');
    await tester.ensureVisible(find.byKey(remove));
    await tester.tap(find.byKey(remove));
    await tester.pumpAndSettle();
    expect(service.fetches, 4);
    expect(find.byType(ListTile), findsNothing);
    expect(service.rows, isEmpty);
  });

  testWidgets('read error offers retry and small form scrolls', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = MockRunService()..failRead = true;
    await launch(tester, service);
    expect(find.text('ลองอีกครั้ง'), findsOneWidget);
    service.failRead = false;
    await tester.tap(find.text('ลองอีกครั้ง'));
    await tester.pumpAndSettle();
    expect(find.text('ลองอีกครั้ง'), findsNothing);
    await tester.tap(find.byKey(add));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(save));
    expect(tester.takeException(), isNull);
  });

  testWidgets('blocks duplicate or uncertain submissions until refresh', (
    tester,
  ) async {
    final pending = Completer<RunChange>();
    final service = MockRunService()..pendingInsert = pending;
    await launch(tester, service);
    await tester.tap(find.byKey(add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(where), 'สวนทดสอบ');
    await tester.enterText(find.byKey(person), 'วิ่งคนเดียว');
    await tester.enterText(find.byKey(distance), '5');
    await tester.ensureVisible(find.byKey(save));
    await tester.tap(find.byKey(save));
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byKey(save)).onPressed, isNull);
    expect(service.inserts, 1);
    pending.completeError(
      const RunActionException('ยืนยันผลไม่ได้', requiresRefresh: true),
    );
    await tester.pumpAndSettle();
    expect(find.text('กลับไปหน้ารายการเพื่อตรวจสถานะล่าสุด'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(save)).onPressed, isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(service.fetches, 2);
    expect(service.inserts, 1);
  });
}

class MockRunService implements RunService {
  final List<Run> rows = [];
  int fetches = 0;
  int inserts = 0;
  bool failRead = false;
  Completer<RunChange>? pendingInsert;

  @override
  Future<List<Run>> fetchRuns() async {
    fetches++;
    if (failRead) throw const RunActionException('test');
    return List.of(rows);
  }

  @override
  Future<RunChange> insertRun(Run input, RunPhoto? photo) async {
    inserts++;
    if (pendingInsert case final pending?) return pending.future;
    final run = Run(
      id: 'test-$inserts',
      createdAt: DateTime.utc(2026, 11, 26),
      runWhere: input.runWhere,
      runPerson: input.runPerson,
      runDistance: input.runDistance,
    );
    rows.insert(0, run);
    return RunChange(run);
  }

  @override
  Future<RunChange> updateRun(Run original, Run input, RunPhoto? photo) async {
    final index = rows.indexWhere((row) => row.id == original.id);
    final run = Run(
      id: original.id,
      createdAt: original.createdAt,
      runWhere: input.runWhere,
      runPerson: input.runPerson,
      runDistance: input.runDistance,
      runImageUrl: original.runImageUrl,
    );
    rows[index] = run;
    return RunChange(run);
  }

  @override
  Future<RunChange> deleteRun(Run original) async {
    rows.removeWhere((row) => row.id == original.id);
    return RunChange(original);
  }
}

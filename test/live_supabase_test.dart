import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_run_tracker_app/models/run.dart';
import 'package:flutter_run_tracker_app/models/run_photo.dart';
import 'package:flutter_run_tracker_app/services/run_service.dart';
import 'package:flutter_run_tracker_app/services/supabase_service.dart';

void main() {
  test(
    'anonymous Supabase CRUD, image replacement and scoped cleanup',
    () async {
      final config = jsonDecode(
        await File('.local/supabase.json').readAsString(),
      ) as Map<String, dynamic>;
      final project = Uri.parse(config['SUPABASE_URL'] as String);
      final key = config['SUPABASE_PUBLISHABLE_KEY'] as String;
      for (final valid in [
        project.scheme == 'https',
        project.host.endsWith('.supabase.co'),
        key.startsWith('sb_publishable_'),
      ]) {
        expect(valid, isTrue, reason: 'ตรวจ config ของโปรเจกต์การศึกษาก่อนรัน');
      }

      final trace = TestStorageClient(project);
      final client = SupabaseClient(project.origin, key, httpClient: trace);
      final service = SupabaseService(client, project);
      final bucket = client.storage.from('run_bk');
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final tag = 'A08-TEST-$stamp-${Random.secure().nextInt(1 << 24)}';
      final names = [
        '$tag-no-image',
        '$tag-image',
        '$tag-edited',
        '$tag-replaced',
        '$tag-invalid',
      ];

      Run input(int name, int distance) => Run(
        runWhere: names[name],
        runPerson: 'ผู้ทดสอบสังเคราะห์',
        runDistance: distance,
      );

      final initial = await client
          .from('run_tb')
          .select('id')
          .inFilter('runWhere', names);
      expect(initial, isEmpty, reason: 'พื้นที่ชื่อทดสอบต้องยังว่าง');
      debugPrint(
        'LIVE preflight target ref matched local owner-supplied config',
      );
      debugPrint('LIVE synthetic tag $tag');

      Future<void> checkStored(String path, {required bool present}) async {
        final list = await bucket.list(
          path: 'runs',
          searchOptions: SearchOptions(search: path.split('/').last, limit: 5),
        );
        expect(
          list.any((object) => object.name == path.split('/').last),
          present,
        );
      }

      final blue = RunPhoto.fromBytes(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAEklEQVR4nGMIWPo+YOl7BggFADKCB5EBnNNCAAAAAElFTkSuQmCC',
        ),
      );
      final green = RunPhoto.fromBytes(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAEklEQVR4nGPwWR/gsz6AAUIBACQyBS0TyzOPAAAAAElFTkSuQmCC',
        ),
      );

      try {
        final plain = (await service.insertRun(input(0, 4), null)).run;
        expect(plain.id, isNotNull);
        expect(plain.createdAt, isNotNull);
        expect(plain.runImageUrl, isNull);
        debugPrint('LIVE insert without image UUID ${plain.id}');

        final first = (await service.insertRun(input(1, 5), blue)).run;
        expect(first.id, isNotNull);
        final firstPath = trace.uploads.single;
        debugPrint('LIVE insert with image UUID ${first.id} path $firstPath');

        final selected = await client
            .from('run_tb')
            .select('id,created_at,runWhere,runPerson,runDistance,runImageUrl')
            .inFilter('id', [plain.id!, first.id!])
            .order('created_at', ascending: false)
            .order('id', ascending: false);
        expect(selected.map((row) => row['id']), [first.id, plain.id]);
        expect(selected.first['runImageUrl'], bucket.getPublicUrl(firstPath));
        expect(selected.first['runPerson'], 'ผู้ทดสอบสังเคราะห์');
        await checkStored(firstPath, present: true);
        final firstImage = await http.get(Uri.parse(first.imageUrl!));
        expect(firstImage.statusCode, 200);
        expect(firstImage.bodyBytes, orderedEquals(blue.bytes));
        debugPrint(
          'LIVE rows, order, Storage and public image HTTP 200 verified',
        );

        final edit = await service.updateRun(first, input(2, 7), null);
        expect(edit.run.id, first.id);
        expect(edit.run.runDistance, 7);
        expect(edit.run.imageUrl, first.imageUrl);
        expect(trace.uploads, hasLength(1));
        await checkStored(firstPath, present: true);
        debugPrint('LIVE edit preserved original URL and object');

        final changed = await service.updateRun(edit.run, input(3, 8), green);
        expect(changed.run.id, first.id);
        final nextPath = trace.uploads.last;
        expect(nextPath, isNot(firstPath));
        debugPrint('LIVE replacement path $nextPath');
        expect(changed.run.imageUrl, bucket.getPublicUrl(nextPath));
        expect(changed.imageCleanupPending, isFalse);
        await checkStored(firstPath, present: false);
        await checkStored(nextPath, present: true);
        final nextImage = await http.get(Uri.parse(changed.run.imageUrl!));
        expect(nextImage.statusCode, 200);
        expect(nextImage.bodyBytes, orderedEquals(green.bytes));

        await expectLater(
          service.insertRun(input(4, 0), blue),
          throwsA(isA<RunActionException>()),
        );
        final rejectedPath = trace.uploads.last;
        expect(trace.uploads, hasLength(3));
        await checkStored(rejectedPath, present: false);
        debugPrint(
          'LIVE DB constraint rejected row and removed upload $rejectedPath',
        );

        final deleted = await service.deleteRun(changed.run);
        expect(deleted.run.id, first.id);
        expect(deleted.imageCleanupPending, isFalse);
        await checkStored(nextPath, present: false);
        expect((await service.deleteRun(plain)).run.id, plain.id);
        debugPrint(
          'LIVE deletion verified for both records and replacement file',
        );
      } on RunActionException catch (error) {
        fail(error.message);
      } on PostgrestException catch (error) {
        fail('Data API error code ${error.code}');
      } on StorageException catch (error) {
        fail('Storage API error status ${error.statusCode}');
      } finally {
        // ค้นเฉพาะชื่อสังเคราะห์ชุดนี้ แล้วลบด้วย UUID และชื่อที่ตรงกัน
        final owned = await client
            .from('run_tb')
            .select('id,runWhere')
            .inFilter('runWhere', names);
        for (final row in owned) {
          await client
              .from('run_tb')
              .delete()
              .eq('id', row['id'] as String)
              .eq('runWhere', row['runWhere'] as String);
        }

        for (final path in trace.uploads) {
          final url = bucket.getPublicUrl(path);
          final references = await client
              .from('run_tb')
              .select('id')
              .eq('runImageUrl', url)
              .limit(1);
          expect(references, isEmpty, reason: 'ตรวจว่าไม่มีแถวอ้างอิงก่อนลบ');
          final list = await bucket.list(
            path: 'runs',
            searchOptions: SearchOptions(
              search: path.split('/').last,
              limit: 5,
            ),
          );
          if (list.any((file) => file.name == path.split('/').last)) {
            await bucket.remove([path]);
          }
          await checkStored(path, present: false);
        }
        final remaining = await client
            .from('run_tb')
            .select('id')
            .inFilter('runWhere', names);
        expect(remaining, isEmpty);
        debugPrint(
          'LIVE cleanup verified: no matching rows; ${trace.uploads.length} checked object paths',
        );
        await client.dispose();
        trace.close();
      }
    },
    skip: Platform.environment['RUN_TRACKER_LIVE_TEST'] != '1',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

class TestStorageClient extends http.BaseClient {
  TestStorageClient(this.project);

  final Uri project;
  final _client = http.Client();
  final uploads = <String>[];
  static final _uploadPath = RegExp(
    r'^/storage/v1/object/run_bk/(runs/[0-9]+-[0-9a-f]+\.png)$',
  );

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (request.url.origin == project.origin && request.method == 'POST') {
      final match = _uploadPath.firstMatch(request.url.path);
      if (match != null) uploads.add(match[1]!);
    }
    return _client.send(request);
  }

  @override
  void close() => _client.close();
}

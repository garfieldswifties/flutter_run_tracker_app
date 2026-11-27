import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_run_tracker_app/models/run.dart';
import 'package:flutter_run_tracker_app/models/run_photo.dart';

void main() {
  test('preserves JSON case and handles NULL and an empty legacy URL', () {
    for (final url in [null, '', ' ']) {
      final data = {
        'id': '753ba6df-2a81-45c7-94ae-5d45c6638c56',
        'created_at': '2026-11-26T05:00:00Z',
        'runWhere': 'สวนทดสอบ',
        'runPerson': 'วิ่งคนเดียว',
        'runDistance': 5,
        'runImageUrl': url,
      };
      final run = Run.fromJson(data);
      expect(run.imageUrl, isNull);
      expect(run.createdAt, DateTime.utc(2026, 11, 26, 5));
      expect(
        run.toJson(),
        Map.of(data)
          ..remove('id')
          ..remove('created_at'),
      );
    }
  });

  test('detects JPEG, PNG and WebP by bytes and rejects other formats', () {
    expect(
      RunPhoto.fromBytes(Uint8List.fromList([255, 216, 255])).mimeType,
      'image/jpeg',
    );
    expect(
      RunPhoto.fromBytes(Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]))
          .extension,
      'png',
    );
    expect(
      RunPhoto.fromBytes(
        Uint8List.fromList([82, 73, 70, 70, 0, 0, 0, 0, 87, 69, 66, 80]),
      ).mimeType,
      'image/webp',
    );
    expect(() => RunPhoto.fromBytes(Uint8List(5)), throwsFormatException);
    expect(
      () => RunPhoto.fromBytes(Uint8List(RunPhoto.maxBytes + 1)),
      throwsFormatException,
    );
  });
}

import 'dart:async';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/run.dart';
import '../models/run_photo.dart';
import 'run_service.dart';

class SupabaseService implements RunService {
  SupabaseService(this._supabase, this._projectUrl);

  final SupabaseClient _supabase;
  final Uri _projectUrl;
  static const _table = 'run_tb';
  static const _bucket = 'run_bk';
  static const _columns =
      'id,created_at,runWhere,runPerson,runDistance,runImageUrl';
  static const _timeout = Duration(seconds: 15);
  static final _uuid = RegExp(
    r'^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$',
    caseSensitive: false,
  );

  @override
  Future<List<Run>> fetchRuns() async {
    final rows = await _supabase
        .from(_table)
        .select(_columns)
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .timeout(_timeout);
    return rows.map(Run.fromJson).toList();
  }

  @override
  Future<RunChange> insertRun(Run input, RunPhoto? photo) async {
    final imageUrl = photo == null ? null : await _upload(photo);
    final values = input.toJson()..['runImageUrl'] = imageUrl;
    final saved = await _save(
      () => _supabase.from(_table).insert(values).select(_columns),
      uploadedUrl: imageUrl,
      verify: imageUrl == null
          ? null
          : () async {
              final row = await _findImage(imageUrl);
              return row != null && _matches(row, values) ? row : null;
            },
    );
    return RunChange(saved);
  }

  @override
  Future<RunChange> updateRun(Run original, Run input, RunPhoto? photo) async {
    final id = _idOf(original);
    final imageUrl = photo == null ? null : await _upload(photo);
    final values = input.toJson();
    if (imageUrl == null) {
      values.remove('runImageUrl');
    } else {
      values['runImageUrl'] = imageUrl;
    }

    final saved = await _save(
      () {
        final query = _supabase.from(_table).update(values).eq('id', id);
        return _matchOriginal(query, original).select(_columns);
      },
      uploadedUrl: imageUrl,
      verify: () async {
        final row = await _findRun(id);
        return row != null && _matches(row, values) ? row : null;
      },
    );

    return RunChange(
      saved,
      imageCleanupPending:
          imageUrl != null && !await _removeIfUnreferenced(original.imageUrl),
    );
  }

  @override
  Future<RunChange> deleteRun(Run original) async {
    final id = _idOf(original);
    Run? removed;
    try {
      final query = _supabase.from(_table).delete().eq('id', id);
      final rows = await _matchOriginal(
        query,
        original,
      ).select(_columns).timeout(_timeout);
      if (rows.length == 1) removed = Run.fromJson(rows.single);
    } on PostgrestException catch (error) {
      if (_definitelyRejected(error)) {
        throw const RunActionException('ฐานข้อมูลปฏิเสธการลบรายการ');
      }
      if (await _verifyDeleted(id)) removed = original;
    } on Exception {
      if (await _verifyDeleted(id)) removed = original;
    }
    if (removed == null) {
      throw const RunActionException(
        'ยืนยันการลบไม่ได้ กรุณากลับไปตรวจรายการล่าสุด',
        requiresRefresh: true,
      );
    }
    return RunChange(
      removed,
      imageCleanupPending: !await _removeIfUnreferenced(removed.imageUrl),
    );
  }

  String _idOf(Run run) {
    final id = run.id;
    if (id == null || !_uuid.hasMatch(id)) {
      throw const RunActionException('ไม่พบรหัสรายการที่ถูกต้อง');
    }
    return id;
  }

  // ตรวจข้อมูลเดิมพร้อม UUID เพื่อจับการแก้ไขจากอีกหน้าหรืออีกเครื่อง
  PostgrestFilterBuilder<T> _matchOriginal<T>(
    PostgrestFilterBuilder<T> query,
    Run original,
  ) {
    final textMatched = query
        .eq('runWhere', original.runWhere)
        .eq('runPerson', original.runPerson)
        .eq('runDistance', original.runDistance);
    final url = original.runImageUrl;
    return url == null
        ? textMatched.isFilter('runImageUrl', null)
        : textMatched.eq('runImageUrl', url);
  }

  Future<Run> _save(
    Future<List<Map<String, dynamic>>> Function() write, {
    String? uploadedUrl,
    Future<Run?> Function()? verify,
  }) async {
    List<Map<String, dynamic>> rows;
    try {
      rows = await write().timeout(_timeout);
    } on PostgrestException catch (error) {
      if (!_definitelyRejected(error)) return _verifySave(verify);
      final cleaned = await _removeIfUnreferenced(uploadedUrl);
      throw RunActionException(
        cleaned
            ? 'ฐานข้อมูลปฏิเสธการบันทึก'
            : 'บันทึกไม่ได้และยังลบรูปที่อัปโหลดไว้ไม่สำเร็จ',
      );
    } on Exception {
      return _verifySave(verify);
    }

    if (rows.length == 1) {
      try {
        return Run.fromJson(rows.single);
      } on FormatException {
        return _verifySave(verify);
      } on TypeError {
        return _verifySave(verify);
      }
    }
    if (rows.isEmpty) {
      final cleaned = await _removeIfUnreferenced(uploadedUrl);
      throw RunActionException(
        cleaned
            ? 'รายการเปลี่ยนไปแล้ว กรุณากลับไปตรวจรายการล่าสุด'
            : 'รายการเปลี่ยนไปแล้ว และยังลบรูปที่อัปโหลดไว้ไม่สำเร็จ',
        requiresRefresh: true,
      );
    }
    return _verifySave(verify);
  }

  bool _definitelyRejected(PostgrestException error) {
    // Class 22/23/42 เป็นการปฏิเสธจาก PostgreSQL ไม่ใช่ผลลัพธ์ที่ขาดหาย
    return RegExp(r'^(22|23|42)[A-Z0-9]{3}$').hasMatch(error.code ?? '');
  }

  Future<Run> _verifySave(Future<Run?> Function()? verify) async {
    if (verify != null) {
      try {
        final row = await verify();
        if (row != null) return row;
      } on Exception {
        // คงรูปที่อาจถูกอ้างอยู่จนกว่าจะทราบผล
      } on TypeError {
        // การแปลผลที่ผิดรูปแบบไม่ยืนยันสถานะการบันทึก
      }
    }
    throw const RunActionException(
      'ยืนยันการบันทึกไม่ได้ กรุณากลับไปตรวจรายการก่อนบันทึกซ้ำ',
      requiresRefresh: true,
    );
  }

  Future<Run?> _findRun(String id) async {
    final row = await _supabase
        .from(_table)
        .select(_columns)
        .eq('id', id)
        .maybeSingle()
        .timeout(_timeout);
    return row == null ? null : Run.fromJson(row);
  }

  Future<Run?> _findImage(String url) async {
    final rows = await _supabase
        .from(_table)
        .select(_columns)
        .eq('runImageUrl', url)
        .limit(2)
        .timeout(_timeout);
    return rows.length == 1 ? Run.fromJson(rows.single) : null;
  }

  bool _matches(Run run, Map<String, dynamic> values) {
    final current = run.toJson();
    return values.entries.every((entry) => current[entry.key] == entry.value);
  }

  Future<bool> _verifyDeleted(String id) async {
    try {
      return await _findRun(id) == null;
    } on Exception {
      return false;
    } on TypeError {
      return false;
    }
  }

  Future<String> _upload(RunPhoto photo) async {
    final random = Random.secure();
    final suffix = List.generate(
      12,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final path = 'runs/$stamp-$suffix.${photo.extension}';
    final bucket = _supabase.storage.from(_bucket);
    final url = bucket.getPublicUrl(path);
    try {
      await bucket
          .uploadBinary(
            path,
            photo.bytes,
            fileOptions: FileOptions(
              contentType: photo.mimeType,
              upsert: false,
            ),
            retryAttempts: 0,
          )
          .timeout(_timeout);
      return url;
    } on TimeoutException {
      // ระบุพาธให้เจ้าของตรวจได้หลังคำขอจบ โดยยังไม่ส่ง INSERT หรือ UPDATE
      throw RunActionException('อัปโหลดรูปหมดเวลา กรุณาตรวจไฟล์ $path');
    } on StorageException {
      throw const RunActionException('Storage ปฏิเสธการอัปโหลดรูป');
    } on Exception {
      throw RunActionException('ตรวจผลอัปโหลดไม่ได้ กรุณาตรวจไฟล์ $path');
    }
  }

  String? _objectPath(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.origin != _projectUrl.origin) {
      return null;
    }
    final segments = uri.pathSegments;
    if (segments.length != 7 ||
        segments.take(6).join('/') != 'storage/v1/object/public/run_bk/runs') {
      return null;
    }
    final name = segments.last;
    if (name.isEmpty ||
        name == '.' ||
        name == '..' ||
        name.contains('/') ||
        name.contains(r'\')) {
      return null;
    }
    return 'runs/$name';
  }

  Future<bool> _removeIfUnreferenced(String? url) async {
    if (url == null) return true;
    final path = _objectPath(url);
    if (path == null) return false;
    try {
      final rows = await _supabase
          .from(_table)
          .select('id')
          .eq('runImageUrl', url)
          .limit(1)
          .timeout(_timeout);
      if (rows.isNotEmpty) return true;
      final deleted = await _supabase.storage
          .from(_bucket)
          .remove([path])
          .timeout(_timeout);
      return deleted.any((file) => file.name == path);
    } on Exception {
      return false;
    }
  }
}

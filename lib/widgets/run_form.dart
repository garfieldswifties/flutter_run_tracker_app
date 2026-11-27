import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:image_picker/image_picker.dart';

import '../models/run.dart';
import '../models/run_photo.dart';
import '../services/run_service.dart';
import 'run_visuals.dart';

class RunForm extends StatefulWidget {
  const RunForm({super.key, required this.service, this.original});

  final RunService service;
  final Run? original;

  @override
  State<RunForm> createState() => _RunFormState();
}

class _RunFormState extends State<RunForm> {
  late final TextEditingController _whereController;
  late final TextEditingController _personController;
  late final TextEditingController _distanceController;
  final _picker = ImagePicker();
  RunPhoto? _photo;
  bool _picking = false;
  bool _busy = false;
  bool _requiresRefresh = false;

  bool get _editing => widget.original != null;

  @override
  void initState() {
    super.initState();
    final original = widget.original;
    _whereController = TextEditingController(text: original?.runWhere);
    _personController = TextEditingController(text: original?.runPerson);
    _distanceController = TextEditingController(
      text: original?.runDistance.toString(),
    );
  }

  @override
  void dispose() {
    _whereController.dispose();
    _personController.dispose();
    _distanceController.dispose();
    super.dispose();
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickPhoto() async {
    if (_picking || _busy) return;
    setState(() => _picking = true);
    try {
      // เว็บและเดสก์ท็อปใช้ตัวเลือกไฟล์ ส่วน Android เปิดกล้องตามโจทย์
      final source = !kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? ImageSource.camera
          : ImageSource.gallery;
      final file = await _picker.pickImage(source: source);
      if (file == null || !mounted) return;
      if (await file.length() > RunPhoto.maxBytes) {
        throw const FormatException('ขนาดรูปต้องไม่เกิน 5 MB');
      }
      final photo = RunPhoto.fromBytes(await file.readAsBytes());
      // ตรวจว่า Flutter อ่านข้อมูลรูปได้ก่อนเก็บเป็นภาพตัวอย่าง
      final codec = await ui.instantiateImageCodec(
        photo.bytes,
        targetWidth: 144,
        allowUpscaling: false,
      );
      try {
        final frame = await codec.getNextFrame();
        frame.image.dispose();
      } finally {
        codec.dispose();
      }
      if (!mounted) return;
      setState(() => _photo = photo);
    } on FormatException catch (error) {
      if (mounted) _notify(error.message);
    } catch (_) {
      if (mounted) _notify('เปิดหรืออ่านรูปไม่สำเร็จ กรุณาลองใหม่');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Run? _readForm() {
    final where = _whereController.text.trim();
    final person = _personController.text.trim();
    final distanceText = _distanceController.text.trim();
    if (where.isEmpty || person.isEmpty || distanceText.isEmpty) {
      _notify('กรุณากรอกข้อมูลให้ครบทั้ง 3 ช่อง');
      return null;
    }
    final distance = int.tryParse(distanceText, radix: 10);
    if (distance == null ||
        !RegExp(r'^[0-9]+$').hasMatch(distanceText) ||
        distance <= 0 ||
        distance > 2147483647) {
      _notify('ระยะทางต้องเป็นจำนวนเต็ม 1 ถึง 2,147,483,647 กม.');
      return null;
    }
    return Run(runWhere: where, runPerson: person, runDistance: distance);
  }

  Future<void> _save() async {
    if (_busy || _picking || _requiresRefresh) return;
    final input = _readForm();
    if (input == null) return;
    final original = widget.original;
    await _submit(
      () => original == null
          ? widget.service.insertRun(input, _photo)
          : widget.service.updateRun(original, input, _photo),
      original == null ? 'บันทึกข้อมูลแล้ว' : 'บันทึกแก้ไขข้อมูลแล้ว',
    );
  }

  Future<void> _delete() async {
    final original = widget.original;
    if (original == null || _busy || _picking || _requiresRefresh) return;
    await _submit(() => widget.service.deleteRun(original), 'ลบข้อมูลแล้ว');
  }

  Future<void> _submit(
    Future<RunChange> Function() action,
    String successMessage,
  ) async {
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    RunChange? change;
    try {
      change = await action();
    } on RunActionException catch (error) {
      if (!mounted) return;
      setState(() => _requiresRefresh = error.requiresRefresh);
      _notify(error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _requiresRefresh = true);
      _notify('ยืนยันผลไม่ได้ กรุณากลับไปตรวจรายการล่าสุด');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (change == null || !mounted) return;
    _notify(
      change.imageCleanupPending
          ? '$successMessage แต่ยังลบรูปเดิมไม่สำเร็จ'
          : successMessage,
    );
    Navigator.of(context).pop();
  }

  void _clear() {
    _whereController.clear();
    _personController.clear();
    _distanceController.clear();
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() => _photo = null);
  }

  Widget _field({
    required String keyName,
    required String label,
    required String hint,
    required TextEditingController controller,
    bool numeric = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 17)),
          TextField(
            key: ValueKey(keyName),
            controller: controller,
            enabled: !_busy && !_requiresRefresh,
            keyboardType: numeric ? TextInputType.number : TextInputType.text,
            textInputAction: numeric
                ? TextInputAction.done
                : TextInputAction.next,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 14),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _button(
    String keyName,
    String label,
    Color color,
    VoidCallback? action,
  ) {
    return FilledButton(
      key: ValueKey(keyName),
      onPressed: action,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 640;
    final disabled = _busy || _picking || _requiresRefresh;
    return PopScope(
      canPop: !_busy,
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              key: const ValueKey('run-form'),
              padding: EdgeInsets.fromLTRB(36, compact ? 20 : 39, 36, 32),
              child: Column(
                children: [
                  Semantics(
                    button: true,
                    label: _editing ? 'เปลี่ยนรูป' : 'เพิ่มรูป',
                    child: InkWell(
                      key: const ValueKey('pick-run-image'),
                      onTap: disabled ? null : _pickPhoto,
                      borderRadius: BorderRadius.circular(10),
                      child: RunImage(
                        size: compact ? 96 : 146,
                        bytes: _photo?.bytes,
                        url: widget.original?.imageUrl,
                        cameraPlaceholder: !_editing,
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 18 : 40),
                  _field(
                    keyName: 'run-where',
                    label: 'วิ่งที่ไหน',
                    hint: 'เช่น สวนสาธารณะ, สนามกีฬา หรือ อื่นๆ',
                    controller: _whereController,
                  ),
                  _field(
                    keyName: 'run-person',
                    label: 'วิ่งกับใคร',
                    hint: 'เช่น เพื่อน 3 คน, แฟน หรือ อื่นๆ',
                    controller: _personController,
                  ),
                  _field(
                    keyName: 'run-distance',
                    label: 'ระยะทาง',
                    hint: 'เช่น 1, 5, 11 หรือ อื่นๆ',
                    controller: _distanceController,
                    numeric: true,
                  ),
                  const SizedBox(height: 20),
                  _button(
                    'save-run',
                    _editing ? 'บันทึกแก้ไขข้อมูล' : 'บันทึกข้อมูล',
                    runGreen,
                    disabled ? null : _save,
                  ),
                  const SizedBox(height: 16),
                  _button(
                    _editing ? 'delete-run' : 'clear-run',
                    _editing ? 'ลบข้อมูล' : 'ยกเลิก',
                    runRed,
                    disabled ? null : (_editing ? _delete : _clear),
                  ),
                  if (_busy || _picking)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: LinearProgressIndicator(),
                    ),
                  if (_requiresRefresh)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Text('กลับไปหน้ารายการเพื่อตรวจสถานะล่าสุด'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:typed_data';

class RunPhoto {
  const RunPhoto._(this.bytes, this.mimeType, this.extension);

  static const maxBytes = 5 * 1024 * 1024;
  final Uint8List bytes;
  final String mimeType;
  final String extension;

  factory RunPhoto.fromBytes(Uint8List bytes) {
    if (bytes.length > maxBytes) {
      throw const FormatException('ขนาดรูปต้องไม่เกิน 5 MB');
    }

    // ตรวจชนิดจากข้อมูลจริง เพราะชื่อไฟล์และ MIME จาก picker อาจคลาดเคลื่อน
    bool matches(List<int> signature, [int offset = 0]) {
      if (bytes.length < offset + signature.length) return false;
      for (var i = 0; i < signature.length; i++) {
        if (bytes[offset + i] != signature[i]) return false;
      }
      return true;
    }

    if (matches(const [0xff, 0xd8, 0xff])) {
      return RunPhoto._(bytes, 'image/jpeg', 'jpg');
    }
    if (matches(const [0x89, 0x50, 0x4e, 0x47, 13, 10, 26, 10])) {
      return RunPhoto._(bytes, 'image/png', 'png');
    }
    if (matches(const [0x52, 0x49, 0x46, 0x46]) &&
        matches(const [0x57, 0x45, 0x42, 0x50], 8)) {
      return RunPhoto._(bytes, 'image/webp', 'webp');
    }
    throw const FormatException('เลือกรูป JPEG, PNG หรือ WebP');
  }
}

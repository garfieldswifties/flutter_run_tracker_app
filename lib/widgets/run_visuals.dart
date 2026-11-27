import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

const runNavy = Color(0xff060844);
const runSplashNavy = Color(0xff041449);
const runBackground = Color(0xfffaf4fc);
const runGreen = Color(0xff4caf50);
const runRed = Color(0xfff44336);

class RunLogo extends StatelessWidget {
  const RunLogo({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    // ใช้ไอคอน Material และจัดองค์ประกอบตามธีมงาน
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            right: size * 0.02,
            bottom: size * 0.08,
            child: Icon(
              Icons.chevron_right_rounded,
              size: size * 0.62,
              color: const Color(0xffffc42b),
            ),
          ),
          Positioned(
            right: size * 0.15,
            bottom: size * 0.08,
            child: Icon(
              Icons.chevron_right_rounded,
              size: size * 0.62,
              color: const Color(0xffff676f),
            ),
          ),
          Positioned(
            left: size * 0.03,
            child: Icon(
              Icons.directions_run_rounded,
              size: size * 0.87,
              color: const Color(0xff5eb6ef),
            ),
          ),
        ],
      ),
    );
  }
}

class RunImage extends StatelessWidget {
  const RunImage({
    super.key,
    required this.size,
    this.bytes,
    this.url,
    this.cameraPlaceholder = false,
  });

  final double size;
  final Uint8List? bytes;
  final String? url;
  final bool cameraPlaceholder;

  Widget _placeholder() {
    if (cameraPlaceholder) {
      return Icon(
        Icons.add_a_photo_rounded,
        size: size * 0.86,
        color: const Color(0xffd4d4d4),
      );
    }
    return RunLogo(size: size);
  }

  @override
  Widget build(BuildContext context) {
    final Widget image;
    if (bytes case final imageBytes?) {
      image = Image.memory(
        imageBytes,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder(),
      );
    } else if (url case final imageUrl?) {
      image = Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder(),
      );
    } else {
      image = _placeholder();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox.square(dimension: size, child: image),
    );
  }
}

import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../services/run_service.dart';
import '../widgets/run_visuals.dart';
import 'show_all_run_ui.dart';

class SplashScreenUi extends StatefulWidget {
  const SplashScreenUi({super.key, this.service, this.setupError});

  final RunService? service;
  final String? setupError;

  @override
  State<SplashScreenUi> createState() => _SplashScreenUiState();
}

class _SplashScreenUiState extends State<SplashScreenUi> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ShowAllRunUi(
            service: widget.service,
            setupError: widget.setupError,
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: runSplashNavy,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const RunLogo(size: 154),
                  const SizedBox(height: 12),
                  const Text(
                    'RUN TRACKER',
                    style: TextStyle(
                      fontSize: 29,
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.italic,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 30),
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      color: Color(0xffaabaff),
                      strokeWidth: 3,
                      semanticsLabel: 'กำลังเปิด Run Tracker',
                    ),
                  ),
                ],
              ),
            ),
            const Positioned(
              left: 12,
              right: 12,
              bottom: 43,
              child: Text(
                '© 2026 RUN TRACKER\nDeveloped by garfieldswifties',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xffaab2cd), fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

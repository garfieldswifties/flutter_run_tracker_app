import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/run_service.dart';
import 'services/supabase_service.dart';
import 'views/splash_screen_ui.dart';
import 'widgets/run_visuals.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  final project = Uri.tryParse(url);
  RunService? service;
  String? setupError;

  if (project == null ||
      project.scheme != 'https' ||
      !project.host.endsWith('.supabase.co') ||
      project.userInfo.isNotEmpty ||
      project.hasPort ||
      (project.path.isNotEmpty && project.path != '/') ||
      project.hasQuery ||
      project.hasFragment ||
      !key.startsWith('sb_publishable_')) {
    setupError = 'กรุณาตั้งค่า Supabase ตามวิธีใน README';
  } else {
    try {
      await Supabase.initialize(url: project.origin, publishableKey: key);
      service = SupabaseService(Supabase.instance.client, project);
    } on Exception {
      setupError = 'เริ่มการเชื่อมต่อ Supabase ไม่สำเร็จ กรุณาตรวจการตั้งค่า';
    }
  }

  runApp(RunTrackerApp(service: service, setupError: setupError));
}

class RunTrackerApp extends StatelessWidget {
  const RunTrackerApp({super.key, this.service, this.setupError});

  final RunService? service;
  final String? setupError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Run Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Kanit',
        colorScheme: ColorScheme.fromSeed(seedColor: runNavy),
        scaffoldBackgroundColor: runBackground,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: runNavy,
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          toolbarHeight: 52,
          titleTextStyle: TextStyle(
            fontFamily: 'Kanit',
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
      home: SplashScreenUi(service: service, setupError: setupError),
    );
  }
}

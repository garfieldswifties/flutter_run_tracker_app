import 'package:material_ui/material_ui.dart';

import '../models/run.dart';
import '../services/run_service.dart';
import '../widgets/run_form.dart';

class UpdateDeleteRunUi extends StatefulWidget {
  const UpdateDeleteRunUi({
    super.key,
    required this.service,
    required this.run,
  });

  final RunService service;
  final Run run;

  @override
  State<UpdateDeleteRunUi> createState() => _UpdateDeleteRunUiState();
}

class _UpdateDeleteRunUiState extends State<UpdateDeleteRunUi> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Run Tracker (แก้ไข/ลบ)')),
      body: RunForm(service: widget.service, original: widget.run),
    );
  }
}

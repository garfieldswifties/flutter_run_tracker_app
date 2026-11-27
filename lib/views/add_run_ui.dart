import 'package:material_ui/material_ui.dart';

import '../services/run_service.dart';
import '../widgets/run_form.dart';

class AddRunUi extends StatefulWidget {
  const AddRunUi({super.key, required this.service});

  final RunService service;

  @override
  State<AddRunUi> createState() => _AddRunUiState();
}

class _AddRunUiState extends State<AddRunUi> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Run Tracker (เพิ่ม)')),
      body: RunForm(service: widget.service),
    );
  }
}

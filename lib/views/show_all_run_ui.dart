import 'package:material_ui/material_ui.dart';

import '../models/run.dart';
import '../services/run_service.dart';
import '../widgets/run_visuals.dart';
import 'add_run_ui.dart';
import 'update_delete_run_ui.dart';

class ShowAllRunUi extends StatefulWidget {
  const ShowAllRunUi({super.key, this.service, this.setupError});

  final RunService? service;
  final String? setupError;

  @override
  State<ShowAllRunUi> createState() => _ShowAllRunUiState();
}

class _ShowAllRunUiState extends State<ShowAllRunUi> {
  List<Run> _runs = [];
  bool _loading = false;
  bool _hasError = false;
  int _fetchRequest = 0;

  @override
  void initState() {
    super.initState();
    _fetchRuns();
  }

  // ดึงครั้งแรกและดึงใหม่หลังกลับจากหน้าเพิ่มหรือหน้าแก้ไข
  Future<void> _fetchRuns() async {
    final service = widget.service;
    if (service == null) return;
    final request = ++_fetchRequest;
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final runs = await service.fetchRuns();
      if (!mounted || request != _fetchRequest) return;
      setState(() {
        _runs = runs;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || request != _fetchRequest) return;
      setState(() {
        _loading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) await _fetchRuns();
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final compact = MediaQuery.sizeOf(context).height < 640;

    return Scaffold(
      appBar: AppBar(title: const Text('Run Tracker')),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: service == null
          ? null
          : SizedBox.square(
              dimension: 48,
              child: FloatingActionButton(
                key: const ValueKey('add-run'),
                tooltip: 'เพิ่มข้อมูล',
                onPressed: () => _open(AddRunUi(service: service)),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                backgroundColor: runNavy,
                foregroundColor: Colors.white,
                child: const Icon(Icons.add),
              ),
            ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: CustomScrollView(
              key: const ValueKey('run-list'),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: compact ? 24 : 52,
                      bottom: 12,
                    ),
                    child: Column(
                      children: [
                        RunLogo(size: compact ? 110 : 151),
                        const SizedBox(height: 15),
                        const Text(
                          'วิ่งกันเถอะ',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (service == null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        widget.setupError ?? 'กรุณาตั้งค่า Supabase',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else if (_loading && _runs.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(
                        child: CircularProgressIndicator(
                          semanticsLabel: 'กำลังโหลดรายการวิ่ง',
                        ),
                      ),
                    ),
                  )
                else if (_hasError)
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        const Text('โหลดรายการไม่สำเร็จ กรุณาตรวจการเชื่อมต่อ'),
                        TextButton(
                          onPressed: _fetchRuns,
                          child: const Text('ลองอีกครั้ง'),
                        ),
                      ],
                    ),
                  ),
                if (service != null)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(17, 0, 17, 80),
                    sliver: SliverList.builder(
                      itemCount: _runs.length,
                      itemBuilder: (context, index) {
                        final run = _runs[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Material(
                            borderRadius: BorderRadius.circular(12),
                            clipBehavior: Clip.antiAlias,
                            color: index.isEven
                                ? const Color(0xffe6f3e7)
                                : const Color(0xfff4f4f4),
                            child: ListTile(
                              key: ValueKey('run-${run.id}'),
                              minTileHeight: 84,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 18,
                              ),
                              onTap: () => _open(
                                UpdateDeleteRunUi(service: service, run: run),
                              ),
                              leading: RunImage(size: 44, url: run.imageUrl),
                              title: Text(
                                'วิ่งที่ไหน: ${run.runWhere}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                'วิ่งไปเท่าไหร่: ${run.runDistance} กม.',
                              ),
                              trailing: const Icon(
                                Icons.info,
                                color: runRed,
                                size: 20,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

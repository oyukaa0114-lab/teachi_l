// admin_report_dialog.dart
// Admin-ын тайлан гаргах dialog — сургуулиар шүүсэн Excel татна
// Байрлал: lib/features/admin/admin_report_dialog.dart
import 'package:flutter/material.dart';
import 'package:teachi_l/core/services/admin_report_generator_service.dart';

class AdminReportDialog extends StatefulWidget {
  final String? school;
  final String? department;
  final bool isDepartmentHead;

  const AdminReportDialog({
    super.key,
    required this.school,
    required this.department,
    required this.isDepartmentHead,
  });

  static Future<void> show(
    BuildContext context, {
    required String? school,
    required String? department,
    required bool isDepartmentHead,
  }) {
    return showDialog(
      context: context,
      builder: (_) => AdminReportDialog(
        school: school,
        department: department,
        isDepartmentHead: isDepartmentHead,
      ),
    );
  }

  @override
  State<AdminReportDialog> createState() => _AdminReportDialogState();
}

class _AdminReportDialogState extends State<AdminReportDialog> {
  final _service = AdminReportGeneratorService();
  List<Map<String, dynamic>> _periods = [];
  int? _selectedPeriodId;
  String _selectedPeriodName = '';
  bool _isLoading = true;
  bool _isGenerating = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _loadPeriods();
  }

  Future<void> _loadPeriods() async {
    final data = await _service.getEvaluationPeriods();
    setState(() {
      _periods = data;
      _isLoading = false;
      if (data.isNotEmpty) {
        _selectedPeriodId = data[0]['id'] as int?;
        _selectedPeriodName = data[0]['name'] as String? ?? '';
      }
    });
  }

  Future<void> _generate() async {
    if (_selectedPeriodId == null) return;
    setState(() {
      _isGenerating = true;
      _status = 'Эхэлж байна...';
    });

    final path = await _service.generateReport(
      periodId: _selectedPeriodId!,
      periodName: _selectedPeriodName,
      school: widget.school,
      department: widget.department,
      isDepartmentHead: widget.isDepartmentHead,
      onStatus: (s) {
        if (mounted) setState(() => _status = s);
      },
    );

    if (!mounted) return;

    if (path != null) {
      setState(() {
        _isGenerating = false;
        _status = '';
      });
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Тайлан амжилттай үүсгэгдлээ ✅'),
          backgroundColor: Color(0xFF5B8DEF),
        ),
      );
    } else {
      setState(() {
        _isGenerating = false;
        _status = 'Алдаа гарлаа';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A2240),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Гарчиг ──
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF5B8DEF).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.table_chart_outlined,
                    color: Color(0xFF5B8DEF),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Тайлан татах',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Excel файлаар татах',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFF64748B),
                    size: 22,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Сургуулийн мэдээлэл ──
            if (widget.school != null && widget.school!.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF5B8DEF).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF5B8DEF).withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.school_rounded,
                          color: Color(0xFF5B8DEF),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.school!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (widget.isDepartmentHead &&
                        widget.department != null &&
                        widget.department!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.account_balance,
                            color: Color(0xFF64748B),
                            size: 14,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Тэнхим: ${widget.department}',
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

            // ── Үе сонгох ──
            const Text(
              'Үнэлгээний үе сонгох',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(color: Color(0xFF5B8DEF)),
                ),
              )
            else if (_periods.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Үнэлгээний үе бүртгэгдээгүй байна',
                  style: TextStyle(color: Color(0xFF64748B)),
                  textAlign: TextAlign.center,
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedPeriodId,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1E2A4A),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF64748B),
                    ),
                    items: _periods.map((p) {
                      final id = p['id'] as int;
                      final name = p['name'] as String? ?? '';
                      final year = p['academic_year'] as String? ?? '';
                      final status = p['status'] as String? ?? '';
                      return DropdownMenuItem<int>(
                        value: id,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '$name ($year)',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (status == 'active')
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF34D399,
                                  ).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Идэвхтэй',
                                  style: TextStyle(
                                    color: Color(0xFF34D399),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: _isGenerating
                        ? null
                        : (val) {
                            setState(() {
                              _selectedPeriodId = val;
                              final p = _periods.firstWhere(
                                (p) => p['id'] == val,
                                orElse: () => {},
                              );
                              _selectedPeriodName = p['name'] as String? ?? '';
                            });
                          },
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // ── Тайлангийн агуулга ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Тайлангийн агуулга:',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _contentItem(
                    Icons.dashboard_rounded,
                    'Ерөнхий мэдээлэл',
                    'Нийт тоо, дундаж, тархалт',
                  ),
                  _contentItem(
                    Icons.school_rounded,
                    'Багш нарын үнэлгээ',
                    'Багш бүрийн дундаж, тэнхим',
                  ),
                  _contentItem(
                    Icons.list_alt_rounded,
                    'Үнэлгээний жагсаалт',
                    'Бүх үнэлгээ, сэтгэгдэл',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Статус ──
            if (_isGenerating) ...[
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF5B8DEF),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _status,
                    style: const TextStyle(
                      color: Color(0xFF5B8DEF),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // ── Товч ──
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: (_isGenerating || _selectedPeriodId == null)
                    ? null
                    : _generate,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.download_rounded, size: 20),
                label: Text(
                  _isGenerating ? 'Үүсгэж байна...' : 'Excel тайлан татах',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5B8DEF),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(
                    0xFF5B8DEF,
                  ).withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contentItem(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF5B8DEF), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: title,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: ' — $subtitle',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

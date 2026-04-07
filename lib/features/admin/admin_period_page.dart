import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminPeriodPage extends StatefulWidget {
  const AdminPeriodPage({super.key});

  @override
  State<AdminPeriodPage> createState() => _AdminPeriodPageState();
}

class _AdminPeriodPageState extends State<AdminPeriodPage> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _periods = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPeriods();
  }

  Future<void> _loadPeriods() async {
    setState(() => _isLoading = true);
    try {
      final data = await _client
          .from('evaluation_periods')
          .select()
          .order('start_date', ascending: false);
      setState(() {
        _periods = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  bool _isActive(Map<String, dynamic> p) {
    try {
      final now = DateTime.now();
      final start = DateTime.parse(p['start_date']);
      final end = DateTime.parse(p['end_date']);
      return now.isAfter(start) && now.isBefore(end);
    } catch (_) {
      return false;
    }
  }

  Future<void> _deletePeriod(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A2847),
        title: const Text('Устгах уу?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Энэ периодийг устгахад бэлэн үү?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Болих', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Устгах',
              style: TextStyle(color: Color(0xFFF44336)),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _client.from('evaluation_periods').delete().eq('id', id);
      _loadPeriods();
    }
  }

  void _showPeriodForm({Map<String, dynamic>? period}) {
    final nameController = TextEditingController(text: period?['name'] ?? '');
    DateTime startDate = period != null
        ? DateTime.parse(period['start_date'])
        : DateTime.now();
    DateTime endDate = period != null
        ? DateTime.parse(period['end_date'])
        : DateTime.now().add(const Duration(days: 14));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A2847),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    period == null ? 'Период нэмэх' : 'Период засах',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Name
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Нэр (жишээ: 2025 хавар)',
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Start date
                  _datePickerTile(
                    label: 'Эхлэх огноо',
                    date: startDate,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: startDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        builder: (context, child) =>
                            Theme(data: ThemeData.dark(), child: child!),
                      );
                      if (picked != null) {
                        setModalState(() => startDate = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // End date
                  _datePickerTile(
                    label: 'Дуусах огноо',
                    date: endDate,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: endDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        builder: (context, child) =>
                            Theme(data: ThemeData.dark(), child: child!),
                      );
                      if (picked != null) {
                        setModalState(() => endDate = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (nameController.text.trim().isEmpty) return;
                        final payload = {
                          'name': nameController.text.trim(),
                          'start_date': startDate.toIso8601String(),
                          'end_date': endDate.toIso8601String(),
                        };
                        if (period == null) {
                          await _client
                              .from('evaluation_periods')
                              .insert(payload);
                        } else {
                          await _client
                              .from('evaluation_periods')
                              .update(payload)
                              .eq('id', period['id']);
                        }
                        if (mounted) Navigator.pop(context);
                        _loadPeriods();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B5BDB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        period == null ? 'Нэмэх' : 'Хадгалах',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _datePickerTile({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: Colors.white54, size: 18),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const Spacer(),
            const Icon(Icons.edit_outlined, color: Colors.white38, size: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1C3F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1C3F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Үнэлгээний период',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _loadPeriods,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPeriodForm(),
        backgroundColor: const Color(0xFF3B5BDB),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Нэмэх',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4C6EF5)),
            )
          : _periods.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_month_outlined,
                    color: Colors.white24,
                    size: 52,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Период байхгүй байна',
                    style: TextStyle(color: Colors.white38),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showPeriodForm(),
                    icon: const Icon(Icons.add),
                    label: const Text('Период нэмэх'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B5BDB),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: _periods.length,
              itemBuilder: (context, index) {
                final p = _periods[index];
                final active = _isActive(p);
                final name = p['name'] as String? ?? 'Период';
                final start = (p['start_date'] as String? ?? '')
                    .substring(0, 10)
                    .replaceAll('-', '.');
                final end = (p['end_date'] as String? ?? '')
                    .substring(0, 10)
                    .replaceAll('-', '.');

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2847),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: active
                          ? const Color(0xFF4CAF50).withOpacity(0.5)
                          : Colors.white.withOpacity(0.07),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: active
                              ? const Color(0xFF4CAF50).withOpacity(0.15)
                              : Colors.white10,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.calendar_month,
                          color: active
                              ? const Color(0xFF4CAF50)
                              : Colors.white38,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                if (active) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF4CAF50,
                                      ).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      'Идэвхтэй',
                                      style: TextStyle(
                                        color: Color(0xFF4CAF50),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$start — $end',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        color: const Color(0xFF1A2847),
                        icon: const Icon(
                          Icons.more_vert,
                          color: Colors.white38,
                        ),
                        onSelected: (v) {
                          if (v == 'edit') _showPeriodForm(period: p);
                          if (v == 'delete') {
                            _deletePeriod(((p['id'] as num?)?.toInt()) ?? 0);
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.edit_outlined,
                                  color: Colors.white70,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Засах',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline,
                                  color: Color(0xFFF44336),
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Устгах',
                                  style: TextStyle(color: Color(0xFFF44336)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

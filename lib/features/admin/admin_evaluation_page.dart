import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_teacher_detail_page.dart';
import 'admin_period_page.dart';
import 'admin_stats_page.dart';

class AdminEvaluationPage extends StatefulWidget {
  const AdminEvaluationPage({super.key});

  @override
  State<AdminEvaluationPage> createState() => _AdminEvaluationPageState();
}

class _AdminEvaluationPageState extends State<AdminEvaluationPage> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _teachers = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final teachers = await _client
          .from('Teachers')
          .select('id, last_name, first_name, rank, department')
          .order('id');

      final evaluations = await _client
          .from('evaluations')
          .select('teacher_id, rating');

      final List<Map<String, dynamic>> result = [];
      for (final t in teachers) {
        final tid = t['id'];
        final related = (evaluations as List)
            .where((e) => e['teacher_id'] == tid)
            .toList();
        final count = related.length;
        final avg = count == 0
            ? 0.0
            : related.fold<int>(
                    0,
                    (s, e) => s + ((e['rating'] as num).toInt()),
                  ) /
                  count;
        result.add({...t, 'avg': avg, 'count': count});
      }

      result.sort((a, b) => (b['avg'] as double).compareTo(a['avg'] as double));

      setState(() {
        _teachers = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_searchQuery.isEmpty) return _teachers;
    final q = _searchQuery.toLowerCase();
    return _teachers.where((t) {
      final name = '${t['last_name'] ?? ''} ${t['first_name'] ?? ''}'
          .toLowerCase();
      return name.contains(q);
    }).toList();
  }

  Color _ratingColor(double avg) {
    if (avg >= 4.0) return const Color(0xFF4CAF50);
    if (avg >= 3.0) return const Color(0xFFFFD700);
    if (avg >= 2.0) return const Color(0xFFFF9800);
    if (avg > 0) return const Color(0xFFF44336);
    return Colors.white24;
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
          'Багш нарын үнэлгээ',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.bar_chart_rounded,
              color: Colors.white70,
              size: 24,
            ),
            tooltip: 'Статистик',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminStatsPage()),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.calendar_month_outlined,
              color: Colors.white70,
              size: 24,
            ),
            tooltip: 'Период',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminPeriodPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary bar
          if (!_isLoading && _teachers.isNotEmpty) _buildSummaryBar(),

          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Багш хайх...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Colors.white38,
                  size: 20,
                ),
                filled: true,
                fillColor: const Color(0xFF1A2847),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          // List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF4C6EF5)),
                  )
                : _filtered.isEmpty
                ? const Center(
                    child: Text(
                      'Багш олдсонгүй',
                      style: TextStyle(color: Colors.white38),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) =>
                        _buildTeacherCard(_filtered[index], index),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar() {
    final totalEvals = _teachers.fold<int>(
      0,
      (s, t) => s + (t['count'] as int),
    );
    final evaluated = _teachers.where((t) => (t['count'] as int) > 0).length;
    final overallAvg = _teachers.isEmpty || totalEvals == 0
        ? 0.0
        : _teachers.fold<double>(
                0,
                (s, t) => s + (t['avg'] as double) * (t['count'] as int),
              ) /
              totalEvals;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2847),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _summaryItem('Нийт багш', '${_teachers.length}', Colors.white),
          _divider(),
          _summaryItem('Үнэлэгдсэн', '$evaluated', const Color(0xFF4CAF50)),
          _divider(),
          _summaryItem('Нийт үнэлгээ', '$totalEvals', const Color(0xFF4C6EF5)),
          _divider(),
          _summaryItem(
            'Дундаж',
            overallAvg.toStringAsFixed(1),
            const Color(0xFFFFD700),
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }

  Widget _divider() => Container(width: 1, height: 36, color: Colors.white12);

  Widget _buildTeacherCard(Map<String, dynamic> t, int index) {
    final name = '${t['last_name'] ?? ''} ${t['first_name'] ?? ''}'.trim();
    final avg = t['avg'] as double;
    final count = t['count'] as int;
    final rank = t['rank'] as String? ?? '';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final color = _ratingColor(avg);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AdminTeacherDetailPage(
            teacherName: name,
            teacherId: ((t['id'] as num?)?.toInt()) ?? 0,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2847),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Row(
          children: [
            // Rank badge
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index == 0
                    ? const Color(0xFFFFD700).withOpacity(0.15)
                    : index == 1
                    ? Colors.white.withOpacity(0.08)
                    : index == 2
                    ? const Color(0xFFCD7F32).withOpacity(0.15)
                    : Colors.white.withOpacity(0.05),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: index == 0
                        ? const Color(0xFFFFD700)
                        : index == 1
                        ? Colors.white70
                        : index == 2
                        ? const Color(0xFFCD7F32)
                        : Colors.white38,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Avatar
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFF3B5BDB).withOpacity(0.3),
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  if (rank.isNotEmpty)
                    Text(
                      rank,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  Text(
                    '$count үнэлгээ',
                    style: const TextStyle(color: Colors.white30, fontSize: 11),
                  ),
                ],
              ),
            ),

            // Rating
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Icon(Icons.star, color: color, size: 16),
                    const SizedBox(width: 3),
                    Text(
                      avg == 0 ? '—' : avg.toStringAsFixed(1),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                // Mini star row
                Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < avg.round() ? Icons.star : Icons.star_border,
                      color: color.withOpacity(0.6),
                      size: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }
}

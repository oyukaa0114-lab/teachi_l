import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminStatsPage extends StatefulWidget {
  const AdminStatsPage({super.key});

  @override
  State<AdminStatsPage> createState() => _AdminStatsPageState();
}

class _AdminStatsPageState extends State<AdminStatsPage> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;

  List<Map<String, dynamic>> _teachers = [];
  List<Map<String, dynamic>> _evaluations = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final teachers = await _client
          .from('Teachers')
          .select('id, last_name, first_name, rank');
      final evaluations = await _client
          .from('evaluations')
          .select('teacher_id, rating, created_at');

      setState(() {
        _teachers = List<Map<String, dynamic>>.from(teachers);
        _evaluations = List<Map<String, dynamic>>.from(evaluations);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  double get _overallAvg {
    if (_evaluations.isEmpty) return 0;
    final sum = _evaluations.fold<int>(
      0,
      (s, e) => s + ((e['rating'] as num?)?.toInt() ?? 0),
    );
    return sum / _evaluations.length;
  }

  Map<int, int> get _ratingDistribution {
    final map = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    for (final e in _evaluations) {
      final r = (e['rating'] as num?)?.toInt() ?? 0;
      if (r >= 1 && r <= 5) map[r] = map[r]! + 1;
    }
    return map;
  }

  List<Map<String, dynamic>> get _topTeachers {
    final result = <Map<String, dynamic>>[];
    for (final t in _teachers) {
      final tid = t['id'];
      final related = _evaluations
          .where((e) => e['teacher_id'] == tid)
          .toList();
      if (related.isEmpty) continue;
      final avg =
          related.fold<int>(
            0,
            (s, e) => s + ((e['rating'] as num?)?.toInt() ?? 0),
          ) /
          related.length;
      result.add({...t, 'avg': avg, 'count': related.length});
    }
    result.sort((a, b) => (b['avg'] as double).compareTo(a['avg'] as double));
    return result.take(5).toList();
  }

  List<Map<String, dynamic>> get _bottomTeachers {
    final result = <Map<String, dynamic>>[];
    for (final t in _teachers) {
      final tid = t['id'];
      final related = _evaluations
          .where((e) => e['teacher_id'] == tid)
          .toList();
      if (related.isEmpty) continue;
      final avg =
          related.fold<int>(
            0,
            (s, e) => s + ((e['rating'] as num?)?.toInt() ?? 0),
          ) /
          related.length;
      result.add({...t, 'avg': avg, 'count': related.length});
    }
    result.sort((a, b) => (a['avg'] as double).compareTo(b['avg'] as double));
    return result.take(3).toList();
  }

  int get _evaluatedCount => _teachers.where((t) {
    final tid = t['id'];
    return _evaluations.any((e) => e['teacher_id'] == tid);
  }).length;

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
          'Статистик тайлан',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _loadStats,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4C6EF5)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildOverviewCards(),
                  const SizedBox(height: 16),
                  _buildDistributionChart(),
                  const SizedBox(height: 16),
                  _buildTopTeachersCard(),
                  const SizedBox(height: 16),
                  _buildBottomTeachersCard(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildOverviewCards() {
    final unevaluated = _teachers.length - _evaluatedCount;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _metricCard(
                icon: Icons.people_outline,
                label: 'Нийт багш',
                value: '${_teachers.length}',
                color: const Color(0xFF4C6EF5),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _metricCard(
                icon: Icons.star_outline,
                label: 'Нийт үнэлгээ',
                value: '${_evaluations.length}',
                color: const Color(0xFFFFD700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _metricCard(
                icon: Icons.check_circle_outline,
                label: 'Үнэлэгдсэн',
                value: '$_evaluatedCount',
                color: const Color(0xFF4CAF50),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _metricCard(
                icon: Icons.show_chart,
                label: 'Нийт дундаж',
                value: _overallAvg == 0 ? '—' : _overallAvg.toStringAsFixed(2),
                color: const Color(0xFFFF9800),
              ),
            ),
          ],
        ),
        if (unevaluated > 0) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF44336).withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFF44336).withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_outlined,
                  color: Color(0xFFF44336),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  '$unevaluated багш үнэлгээгүй байна',
                  style: const TextStyle(
                    color: Color(0xFFF44336),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _metricCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2847),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionChart() {
    final dist = _ratingDistribution;
    final total = _evaluations.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2847),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Үнэлгээний тархалт',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Нийт $total үнэлгээ',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 20),
          ...List.generate(5, (i) {
            final star = 5 - i;
            final count = dist[star] ?? 0;
            final pct = total == 0 ? 0.0 : count / total;

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Row(
                        children: List.generate(
                          star,
                          (j) => const Icon(
                            Icons.star,
                            color: Color(0xFFFFD700),
                            size: 12,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$count (${(pct * 100).round()}%)',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 10,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        star == 5
                            ? const Color(0xFF4CAF50)
                            : star == 4
                            ? const Color(0xFF8BC34A)
                            : star == 3
                            ? const Color(0xFFFFD700)
                            : star == 2
                            ? const Color(0xFFFF9800)
                            : const Color(0xFFF44336),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTopTeachersCard() {
    final top = _topTeachers;
    if (top.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2847),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.emoji_events_outlined,
                color: Color(0xFFFFD700),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Шилдэг 5 багш',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...top.asMap().entries.map((entry) {
            final idx = entry.key;
            final t = entry.value;
            final name = '${t['last_name'] ?? ''} ${t['first_name'] ?? ''}'
                .trim();
            final avg = (t['avg'] as double);
            final count = t['count'] as int;
            return _teacherRankRow(
              idx,
              name,
              avg,
              count,
              medalColors[idx] ?? Colors.white38,
            );
          }),
        ],
      ),
    );
  }

  static const medalColors = {
    0: Color(0xFFFFD700),
    1: Color(0xFFBBBBBB),
    2: Color(0xFFCD7F32),
  };

  Widget _buildBottomTeachersCard() {
    final bottom = _bottomTeachers;
    if (bottom.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2847),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF44336).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.trending_down,
                color: Color(0xFFF44336),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Анхаарал шаардсан багш нар',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...bottom.asMap().entries.map((entry) {
            final t = entry.value;
            final name = '${t['last_name'] ?? ''} ${t['first_name'] ?? ''}'
                .trim();
            final avg = (t['avg'] as double);
            final count = t['count'] as int;
            return _teacherRankRow(
              entry.key,
              name,
              avg,
              count,
              const Color(0xFFF44336),
            );
          }),
        ],
      ),
    );
  }

  Widget _teacherRankRow(
    int idx,
    String name,
    double avg,
    int count,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '${idx + 1}.',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withOpacity(0.15),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '$count үнэлгээ',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Icon(Icons.star, color: color, size: 14),
              const SizedBox(width: 3),
              Text(
                avg.toStringAsFixed(1),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

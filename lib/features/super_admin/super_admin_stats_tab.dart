// Super Admin - Статистик
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'report_dialog.dart';

class SuperAdminStatsTab extends StatefulWidget {
  const SuperAdminStatsTab({super.key});

  @override
  State<SuperAdminStatsTab> createState() => _SuperAdminStatsTabState();
}

class _SuperAdminStatsTabState extends State<SuperAdminStatsTab> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;

  int _totalTeachers = 0;
  int _totalStudents = 0;
  int _totalAdmins = 0;
  int _totalEvaluations = 0;
  double _avgRating = 0;
  List<int> _ratingDist = [0, 0, 0, 0, 0];
  List<Map<String, dynamic>> _topTeachers = [];
  List<Map<String, dynamic>> _recentEvals = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      // Тоо баримтууд
      final teachers = await _client.from('Teachers').select('id');
      final students = await _client.from('Students').select('id');
      final admins = await _client.from('admins').select('id');
      final evals = await _client
          .from('evaluations')
          .select('rating, teacher_id');

      _totalTeachers = (teachers as List).length;
      _totalStudents = (students as List).length;
      _totalAdmins = (admins as List).length;
      _totalEvaluations = (evals as List).length;

      // Дундаж + Distribution
      List<int> dist = [0, 0, 0, 0, 0];
      double sum = 0;
      for (final e in evals) {
        final r = ((e['rating'] as num?)?.toInt() ?? 0).clamp(1, 5);
        dist[r - 1]++;
        sum += r;
      }
      _avgRating = evals.isEmpty ? 0 : sum / evals.length;
      _ratingDist = dist;

      // Шилдэг багш нар (дундаж үнэлгээгээр)
      final teacherRatings = <int, List<int>>{};
      for (final e in evals) {
        final tid = (e['teacher_id'] as num?)?.toInt() ?? 0;
        final r = ((e['rating'] as num?)?.toInt() ?? 0);
        teacherRatings.putIfAbsent(tid, () => []).add(r);
      }

      final teacherAvgs =
          teacherRatings.entries.map((entry) {
            final avg =
                entry.value.reduce((a, b) => a + b) / entry.value.length;
            return {
              'teacher_id': entry.key,
              'avg': avg,
              'count': entry.value.length,
            };
          }).toList()..sort(
            (a, b) => (b['avg'] as double).compareTo(a['avg'] as double),
          );

      // Шилдэг 5 багшийн нэр авах
      List<Map<String, dynamic>> topTeachers = [];
      for (final ta in teacherAvgs.take(5)) {
        try {
          final t = await _client
              .from('Teachers')
              .select('last_name, first_name, rank')
              .eq('id', ta['teacher_id'] as Object)
              .single();
          final lastName = t['last_name'] as String? ?? '';
          final firstName = t['first_name'] as String? ?? '';
          topTeachers.add({
            'name': '${lastName.isNotEmpty ? '$lastName.' : ''} $firstName'
                .trim(),
            'rank': t['rank'] ?? '',
            'avg': ta['avg'],
            'count': ta['count'],
          });
        } catch (_) {}
      }

      // Сүүлийн үнэлгээнүүд
      List<Map<String, dynamic>> recentEvals = [];
      try {
        final recent = await _client
            .from('evaluations')
            .select('*, Teachers(last_name, first_name)')
            .order('created_at', ascending: false)
            .limit(5);
        recentEvals = List<Map<String, dynamic>>.from(recent);
      } catch (_) {}

      setState(() {
        _topTeachers = topTeachers;
        _recentEvals = recentEvals;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Stats error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF5B8DEF)),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadStats,
      color: const Color(0xFF5B8DEF),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Статистик',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),

          ElevatedButton.icon(
            onPressed: () => ReportDialog.show(context),
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Тайлан гаргах'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF34D399),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),

          // ===== Тоо баримтууд =====
          Row(
            children: [
              _StatCard(
                icon: Icons.school_rounded,
                label: 'Багш',
                value: '$_totalTeachers',
                color: const Color(0xFF5B8DEF),
              ),
              const SizedBox(width: 12),
              _StatCard(
                icon: Icons.people_rounded,
                label: 'Оюутан',
                value: '$_totalStudents',
                color: const Color(0xFF34D399),
              ),
              const SizedBox(width: 12),
              _StatCard(
                icon: Icons.admin_panel_settings_rounded,
                label: 'Админ',
                value: '$_totalAdmins',
                color: const Color(0xFF8B5CF6),
              ),
              const SizedBox(width: 12),
              _StatCard(
                icon: Icons.star_rounded,
                label: 'Нийт үнэлгээ',
                value: '$_totalEvaluations',
                color: const Color(0xFFFFBF47),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ===== Дундаж + Distribution =====
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Дундаж үнэлгээ
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF12182B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.04)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Нийт дундаж',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _avgRating.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Color(0xFFFFBF47),
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          5,
                          (i) => Icon(
                            i < _avgRating.round()
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: const Color(0xFFFFBF47),
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$_totalEvaluations үнэлгээ',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Distribution
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF12182B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.04)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Үнэлгээний тархалт',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...List.generate(5, (index) {
                        final star = 5 - index;
                        final count = _ratingDist[star - 1];
                        final total = _totalEvaluations.clamp(1, 99999);
                        final pct = count / total;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 20,
                                child: Text(
                                  '$star',
                                  style: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.star_rounded,
                                color: Color(0xFFFFBF47),
                                size: 16,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: pct,
                                    minHeight: 8,
                                    backgroundColor: Colors.white.withOpacity(
                                      0.06,
                                    ),
                                    valueColor: AlwaysStoppedAnimation(
                                      Color.lerp(
                                        const Color(0xFFF87171),
                                        const Color(0xFF34D399),
                                        (star - 1) / 4,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 30,
                                child: Text(
                                  '$count',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ===== Шилдэг багш нар =====
          if (_topTeachers.isNotEmpty) ...[
            const Text(
              'Шилдэг багш нар',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF12182B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.04)),
              ),
              child: Column(
                children: _topTeachers.asMap().entries.map((entry) {
                  final index = entry.key;
                  final t = entry.value;
                  final avg = (t['avg'] as double);

                  Color medalColor;
                  if (index == 0) {
                    medalColor = const Color(0xFFFFBF47);
                  } else if (index == 1) {
                    medalColor = const Color(0xFFC0C0C0);
                  } else if (index == 2) {
                    medalColor = const Color(0xFFCD7F32);
                  } else {
                    medalColor = const Color(0xFF64748B);
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: index < _topTeachers.length - 1
                          ? Border(
                              bottom: BorderSide(
                                color: Colors.white.withOpacity(0.04),
                              ),
                            )
                          : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: medalColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: medalColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t['name'] as String,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if ((t['rank'] as String).isNotEmpty)
                                Text(
                                  t['rank'] as String,
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Row(
                          children: List.generate(
                            5,
                            (i) => Icon(
                              i < avg.round()
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: const Color(0xFFFFBF47),
                              size: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          avg.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Color(0xFFFFBF47),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${t['count']})',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF12182B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 14),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

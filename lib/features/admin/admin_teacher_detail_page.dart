import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminTeacherDetailPage extends StatefulWidget {
  const AdminTeacherDetailPage({
    super.key,
    required this.teacherName,
    required this.teacherId,
  });
  final String teacherName;
  final int teacherId;

  @override
  State<AdminTeacherDetailPage> createState() => _AdminTeacherDetailPageState();
}

class _AdminTeacherDetailPageState extends State<AdminTeacherDetailPage> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() => _isLoading = true);
    try {
      final data = await _client
          .from('evaluations')
          .select()
          .eq('teacher_id', widget.teacherId)
          .order('created_at', ascending: false);
      setState(() {
        _reviews = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  double get _avg => _reviews.isEmpty
      ? 0.0
      : _reviews.fold<int>(
              0,
              (s, r) => s + ((r['rating'] as num?)?.toInt() ?? 0),
            ) /
            _reviews.length;

  Map<int, int> get _distribution {
    final map = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    for (final r in _reviews) {
      final rating = (r['rating'] as num?)?.toInt() ?? 0;
      if (rating >= 1 && rating <= 5) map[rating] = map[rating]! + 1;
    }
    return map;
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
        title: Text(
          widget.teacherName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _loadReviews,
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
                  _buildStatsCard(),
                  const SizedBox(height: 16),
                  _buildDistributionCard(),
                  const SizedBox(height: 16),
                  _buildReviewsSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A4AC4), Color(0xFF1A3480)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white24,
            child: Text(
              widget.teacherName.isNotEmpty
                  ? widget.teacherName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.teacherName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _statItem(
                _avg == 0 ? '—' : _avg.toStringAsFixed(1),
                'Дундаж',
                const Color(0xFFFFD700),
              ),
              Container(width: 1, height: 48, color: Colors.white24),
              _statItem('${_reviews.length}', 'Нийт үнэлгээ', Colors.white),
              Container(width: 1, height: 48, color: Colors.white24),
              _statItem(
                _reviews.isEmpty
                    ? '—'
                    : '${(_reviews.where((r) => ((r['rating'] as num?)?.toInt() ?? 0) >= 4).length * 100 / _reviews.length).round()}%',
                'Эерэг',
                const Color(0xFF4CAF50),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              return Icon(
                i < _avg.round() ? Icons.star : Icons.star_border,
                color: const Color(0xFFFFD700),
                size: 22,
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildDistributionCard() {
    final dist = _distribution;
    final max = dist.values.fold(0, (a, b) => a > b ? a : b);

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
          const SizedBox(height: 16),
          ...List.generate(5, (i) {
            final star = 5 - i;
            final count = dist[star] ?? 0;
            final pct = max == 0 ? 0.0 : count / max;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(Icons.star, color: const Color(0xFFFFD700), size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '$star',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 8,
                        backgroundColor: Colors.white10,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          star >= 4
                              ? const Color(0xFF4CAF50)
                              : star == 3
                              ? const Color(0xFFFFD700)
                              : const Color(0xFFF44336),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 28,
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.end,
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

  Widget _buildReviewsSection() {
    if (_reviews.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 16),
          child: Text(
            'Үнэлгээ байхгүй байна',
            style: TextStyle(color: Colors.white38),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Бүх сэтгэгдэл (${_reviews.length})',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ..._reviews.map((review) {
          final rating = ((review['rating'] as num?)?.toInt()) ?? 0;
          final comment = review['comment'] as String? ?? '';
          final date = ((review['created_at'] as String?) ?? '2025.01.01')
              .substring(0, 10)
              .replaceAll('-', '.');
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 14,
                          backgroundColor: Color(0xFFEEEEEE),
                          child: Icon(
                            Icons.person,
                            size: 16,
                            color: Colors.black45,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Нэргүй',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      date,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black38,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < rating ? Icons.star : Icons.star_border,
                      color: const Color(0xFFFFD700),
                      size: 16,
                    ),
                  ),
                ),
                if (comment.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    comment,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }
}

//bagsh ugsun vnelgee harah
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/auth_controller.dart';

class TeacherEvaluationPage extends StatefulWidget {
  const TeacherEvaluationPage({
    super.key,
    required this.teacherName,
    required this.teacherId,
  });
  final String teacherName;
  final int teacherId;

  @override
  State<TeacherEvaluationPage> createState() => _TeacherEvaluationPageState();
}

class _TeacherEvaluationPageState extends State<TeacherEvaluationPage> {
  int _rating = 0;
  bool _isLoading = false;
  final _commentController = TextEditingController();
  final _client = Supabase.instance.client;

  List<Map<String, dynamic>> _reviews = [];

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadReviews() async {
    try {
      final data = await _client
          .from('evaluations')
          .select()
          .eq('teacher_id', widget.teacherId)
          .order('created_at', ascending: false);
      setState(() => _reviews = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      // чимээгүй алдаа
    }
  }

  Future<void> _submitEvaluation() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Одны үнэлгээ өгнө үү')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final studentId = context.read<AuthController>().currentUser?['id'];

      final now = DateTime.now();
      final period = await _client
          .from('evaluation_periods')
          .select()
          .lte('start_date', now.toIso8601String())
          .gte('end_date', now.toIso8601String())
          .maybeSingle();

      await _client.from('evaluations').insert({
        'student_id': studentId,
        'teacher_id': widget.teacherId,
        'rating': _rating,
        'comment': _commentController.text.trim(),
        'is_anonymous': true,
        'period_id': period?['id'],
      });
      _commentController.clear();
      setState(() => _rating = 0);
      await _loadReviews();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Үнэлгээ амжилттай илгээгдлээ!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Алдаа гарлаа: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1C3F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1C3F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Үнэлгээ өгөх',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Teacher info card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF2A4AC4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: Colors.white24,
                    child: Text(
                      widget.teacherName[0],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.teacherName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Хичээл заах үнэлгээ',
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Stats card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Үнэлгээний дүгнэлт',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Average score
                      Column(
                        children: [
                          Text(
                            _reviews.isEmpty
                                ? '0.0'
                                : (_reviews.fold<int>(
                                            0,
                                            (sum, r) =>
                                                sum +
                                                ((r['rating'] as num?)
                                                        ?.toInt() ??
                                                    0),
                                          ) /
                                          _reviews.length)
                                      .toStringAsFixed(1),
                            style: const TextStyle(
                              color: Color(0xFFFFD700),
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Row(
                            children: List.generate(5, (i) {
                              final avg = _reviews.isEmpty
                                  ? 0.0
                                  : _reviews.fold<int>(
                                          0,
                                          (s, r) =>
                                              s +
                                              ((r['rating'] as num?)?.toInt() ??
                                                  0),
                                        ) /
                                        _reviews.length;
                              return Icon(
                                i < avg.round()
                                    ? Icons.star
                                    : Icons.star_border,
                                color: const Color(0xFFFFD700),
                                size: 16,
                              );
                            }),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Дундаж',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Container(width: 1, height: 60, color: Colors.white12),
                      // Total count
                      Column(
                        children: [
                          Text(
                            '${_reviews.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Нийт үнэлгээ',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Rating & comment card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Үнэлгээ өгөх',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return GestureDetector(
                        onTap: () => setState(() => _rating = index + 1),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(
                            index < _rating ? Icons.star : Icons.star_border,
                            color: const Color(0xFFFFD700),
                            size: 36,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _commentController,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Санал шүүмж бичих...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _submitEvaluation,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.send, size: 18),
                      label: Text(_isLoading ? 'Илгээж байна...' : 'Илгээх'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B5BDB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Reviews
            if (_reviews.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Center(
                  child: Text(
                    'Үнэлгээ байхгүй байна',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ),
              )
            else
              ..._reviews.map((review) {
                final rating = ((review['rating'] as num?)?.toInt()) ?? 0;
                final comment = review['comment'] as String? ?? '';
                final date = ((review['created_at'] as String?) ?? '2025.01.01')
                    .substring(0, 10)
                    .replaceAll('-', '.');
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Anonymous',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            date,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black38,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: List.generate(
                          5,
                          (i) => Icon(
                            i < rating ? Icons.star : Icons.star_border,
                            color: const Color(0xFFFFD700),
                            size: 18,
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
        ),
      ),
    );
  }
}

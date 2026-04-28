// Сурагч - Багшид үнэлгээ өгөх дэлгэц (имэйлтэй)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/auth_controller.dart';

class StudentTeacherEvaluationPage extends StatefulWidget {
  const StudentTeacherEvaluationPage({
    super.key,
    required this.teacherName,
    required this.teacherId,
  });

  final String teacherName;
  final int teacherId;

  @override
  State<StudentTeacherEvaluationPage> createState() =>
      _StudentTeacherEvaluationPageState();
}

class _StudentTeacherEvaluationPageState
    extends State<StudentTeacherEvaluationPage> {
  int _rating = 0;
  bool _isLoading = false;
  bool _isAnonymous = false;
  final _commentController = TextEditingController();
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _reviews = [];
  String? _teacherEmail;

  @override
  void initState() {
    super.initState();
    _loadReviews();
    _loadTeacherEmail();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadTeacherEmail() async {
    try {
      final teacherData = await _client
          .from('Teachers')
          .select('user_id')
          .eq('id', widget.teacherId)
          .single();

      final userId = teacherData['user_id'];
      if (userId == null) return;

      final userData = await _client
          .from('Users')
          .select('email')
          .eq('id', userId)
          .single();

      setState(() {
        _teacherEmail = userData['email'] as String?;
      });
    } catch (e) {
      debugPrint('Email load error: $e');
    }
  }

  Future<void> _loadReviews() async {
    try {
      final data = await _client
          .from('evaluations')
          .select('*, Students(first_name, last_name, email)')
          .eq('teacher_id', widget.teacherId)
          .order('created_at', ascending: false);
      setState(() => _reviews = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      try {
        final data = await _client
            .from('evaluations')
            .select()
            .eq('teacher_id', widget.teacherId)
            .order('created_at', ascending: false);
        setState(() => _reviews = List<Map<String, dynamic>>.from(data));
      } catch (e2) {
        debugPrint('Review load error: $e2');
      }
    }
  }

  double get _avgRating {
    if (_reviews.isEmpty) return 0;
    return _reviews.fold<double>(
          0,
          (s, r) => s + ((r['rating'] as num?)?.toDouble() ?? 0),
        ) /
        _reviews.length;
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
      final userId = context.read<AuthController>().currentUser?['id'];
      if (userId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final studentData = await _client
          .from('Students')
          .select('id')
          .eq('user_id', userId)
          .single();
      final studentId = studentData['id'];
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
        'is_anonymous': _isAnonymous,
        'period_id': period?['id'],
      });
      _commentController.clear();
      setState(() => _rating = 0);
      await _loadReviews();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Үнэлгээ амжилттай илгээгдлээ!'),
            backgroundColor: Color.fromARGB(255, 120, 240, 124),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Алдаа: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1C3F),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  _buildStatsCard(),
                  const SizedBox(height: 16),
                  _buildRatingCard(),
                  const SizedBox(height: 20),
                  if (_reviews.isNotEmpty) ...[
                    _buildReviewsHeader(),
                    const SizedBox(height: 12),
                    ..._reviews.map((r) => _buildReviewCard(r)),
                  ] else
                    _buildEmptyReviews(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A3A6B), Color(0xFF0F1C3F)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios,
                      color: Colors.white70,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  const Text(
                    'Үнэлгээ өгөх',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B5BDB), Color(0xFF4C6EF5)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3B5BDB).withOpacity(0.4),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: Center(
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
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                          style: TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                        if (_teacherEmail != null &&
                            _teacherEmail!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.email_outlined,
                                color: Colors.white38,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _teacherEmail!,
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: List.generate(
                            5,
                            (i) => Icon(
                              i < _avgRating.round()
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: const Color(0xFFFFD700),
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
        color: const Color(0xFF1A2847),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Column(
            children: [
              Text(
                _avgRating.toStringAsFixed(1),
                style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < _avgRating.round()
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: const Color(0xFFFFD700),
                    size: 14,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Дундаж',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          Container(width: 1, height: 60, color: Colors.white12),
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
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRatingCard() {
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
            'Үнэлгээ өгөх',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                5,
                (i) => GestureDetector(
                  onTap: () => setState(() => _rating = i + 1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      i < _rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: i < _rating
                          ? const Color(0xFFFFD700)
                          : Colors.white24,
                      size: 44,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_rating > 0) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                [
                  '',
                  'Муу',
                  'Дунд зэрэг',
                  'Сайн',
                  'Маш сайн',
                  'Гайхалтай',
                ][_rating],
                style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _commentController,
            maxLines: 4,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Санал шүүмж бичих...',
              hintStyle: const TextStyle(color: Colors.white30),
              filled: true,
              fillColor: Colors.white.withOpacity(0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF4C6EF5),
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.visibility_off_outlined,
                  color: Colors.white54,
                  size: 18,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Нэргүй илгээх',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Switch(
                  value: _isAnonymous,
                  onChanged: (val) => setState(() => _isAnonymous = val),
                  activeColor: const Color(0xFF4C6EF5),
                  inactiveThumbColor: Colors.white38,
                  inactiveTrackColor: Colors.white12,
                ),
              ],
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
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(_isLoading ? 'Илгээж байна...' : 'Илгээх'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B5BDB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsHeader() {
    return Row(
      children: [
        const Text(
          'СЭТГЭГДЛҮҮД',
          style: TextStyle(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF4C6EF5).withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '${_reviews.length}',
            style: const TextStyle(
              color: Color(0xFF4C6EF5),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final rating = ((review['rating'] as num?)?.toInt()) ?? 0;
    final comment = review['comment'] as String? ?? '';
    final rawDate = review['created_at'] as String? ?? '';
    final date = rawDate.length >= 10
        ? rawDate.substring(0, 10).replaceAll('-', '.')
        : '';
    final isAnon = review['is_anonymous'] as bool? ?? false;

    final st = review['Students'];
    final lastName = st?['last_name'] as String? ?? '';
    final firstName = st?['first_name'] as String? ?? '';
    final email = st?['email'] as String? ?? '';
    final fullName = isAnon
        ? 'Нэргүй'
        : (lastName.isNotEmpty || firstName.isNotEmpty)
        ? '${lastName.isNotEmpty ? '$lastName.' : ''} $firstName'.trim()
        : 'Суралцагч';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2847),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4C6EF5).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isAnon
                          ? Icons.visibility_off_outlined
                          : Icons.person_outline,
                      color: const Color(0xFF4C6EF5),
                      size: 15,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (!isAnon && email.isNotEmpty)
                        Text(
                          email,
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              Flexible(
                child: Text(
                  date,
                  style: const TextStyle(fontSize: 10, color: Colors.white30),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(
              5,
              (i) => Icon(
                i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                color: i < rating ? const Color(0xFFFFD700) : Colors.white12,
                size: 20,
              ),
            ),
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                comment,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white60,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyReviews() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2847),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          Icon(Icons.rate_review_outlined, color: Colors.white24, size: 48),
          SizedBox(height: 12),
          Text(
            'Үнэлгээ байхгүй байна',
            style: TextStyle(color: Colors.white38),
          ),
          SizedBox(height: 4),
          Text(
            'Анхны үнэлгээ өгөх хүн бай!',
            style: TextStyle(color: Colors.white24, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

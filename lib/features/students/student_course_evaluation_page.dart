// bagshiin hicheeld vnelgee uguh
// Сурагч - Тухайн багшийн тухайн хичээлд үнэлгээ өгөх дэлгэц
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/auth_controller.dart';

class StudentCourseEvaluationPage extends StatefulWidget {
  final String teacherName;
  final int teacherId;
  final int courseId;
  final String courseName;
  final String courseCode;

  const StudentCourseEvaluationPage({
    super.key,
    required this.teacherName,
    required this.teacherId,
    required this.courseId,
    required this.courseName,
    required this.courseCode,
  });

  @override
  State<StudentCourseEvaluationPage> createState() =>
      _StudentCourseEvaluationPageState();
}

class _StudentCourseEvaluationPageState
    extends State<StudentCourseEvaluationPage> {
  final _client = Supabase.instance.client;
  bool _isSubmitting = false;
  bool _alreadyEvaluated = false;
  bool _isLoading = true;
  String? _successMessage;
  String? _errorMessage;

  // Үнэлгээний шалгуурууд
  final List<Map<String, dynamic>> _criteria = [
    {
      'key': 'teaching_quality',
      'label': 'Хичээл заах чадвар',
      'description':
          'Хичээлийн агуулгыг ойлгомжтой, тодорхой тайлбарлах чадвар',
      'icon': Icons.school_outlined,
      'rating': 0,
    },
    {
      'key': 'communication',
      'label': 'Харилцааны ур чадвар',
      'description': 'Оюутнуудтай хүндэтгэлтэй, нээлттэй харилцах',
      'icon': Icons.chat_bubble_outline,
      'rating': 0,
    },
    {
      'key': 'preparation',
      'label': 'Хичээлийн бэлтгэл',
      'description': 'Хичээлийн материал, агуулга бэлтгэсэн байдал',
      'icon': Icons.auto_stories_outlined,
      'rating': 0,
    },
    {
      'key': 'punctuality',
      'label': 'Цаг баримтлал',
      'description': 'Хичээлийг цагтаа эхлүүлж, дуусгах',
      'icon': Icons.access_time_outlined,
      'rating': 0,
    },
    {
      'key': 'assessment_fairness',
      'label': 'Үнэлгээний шударга байдал',
      'description': 'Шалгалт, даалгаврын үнэлгээ шударга эсэх',
      'icon': Icons.balance_outlined,
      'rating': 0,
    },
  ];

  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkExistingEvaluation();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _checkExistingEvaluation() async {
    try {
      final studentId = context.read<AuthController>().currentUser?['id'];
      if (studentId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final existing = await _client
          .from('evaluations')
          .select('id')
          .eq('student_id', studentId)
          .eq('teacher_id', widget.teacherId)
          .eq('course_id', widget.courseId)
          .maybeSingle();

      setState(() {
        _alreadyEvaluated = existing != null;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  double get _averageRating {
    final ratings = _criteria.map((c) => c['rating'] as int).toList();
    if (ratings.every((r) => r == 0)) return 0;
    final sum = ratings.reduce((a, b) => a + b);
    return sum / ratings.length;
  }

  bool get _canSubmit {
    return _criteria.every((c) => (c['rating'] as int) > 0);
  }

  Future<void> _submitEvaluation() async {
    if (!_canSubmit || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final studentId = context.read<AuthController>().currentUser?['id'];
      if (studentId == null) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'Хэрэглэгчийн мэдээлэл олдсонгүй.';
        });
        return;
      }

      final Map<String, dynamic> evaluationData = {
        'student_id': studentId,
        'teacher_id': widget.teacherId,
        'course_id': widget.courseId,
        'rating': _averageRating,
        'comment': _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
      };

      // Шалгуур бүрийн үнэлгээг нэмэх
      for (final c in _criteria) {
        evaluationData[c['key']] = c['rating'];
      }

      await _client.from('evaluations').insert(evaluationData);

      setState(() {
        _isSubmitting = false;
        _successMessage = 'Үнэлгээ амжилттай илгээгдлээ!';
      });

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Үнэлгээ илгээхэд алдаа гарлаа. Дахин оролдоно уу.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1C3F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A3A6B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Хичээлийн үнэлгээ',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _alreadyEvaluated
          ? _buildAlreadyEvaluated()
          : _successMessage != null
          ? _buildSuccess()
          : _buildEvaluationForm(),
    );
  }

  Widget _buildAlreadyEvaluated() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF4C6EF5).withOpacity(0.15),
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: Color(0xFF4C6EF5),
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Та энэ хичээлд аль хэдийн\nүнэлгээ өгсөн байна',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.courseName} • ${widget.teacherName}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Буцах',
                style: TextStyle(color: Color(0xFF4C6EF5), fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF40C057).withOpacity(0.15),
            ),
            child: const Icon(
              Icons.check_circle,
              color: Color(0xFF40C057),
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _successMessage!,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvaluationForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- Багш + Хичээлийн мэдээлэл ----
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2847),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B5BDB), Color(0xFF4C6EF5)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3B5BDB).withOpacity(0.3),
                        blurRadius: 8,
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
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.teacherName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4C6EF5).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${widget.courseCode.isNotEmpty ? '${widget.courseCode} • ' : ''}${widget.courseName}',
                          style: const TextStyle(
                            color: Color(0xFF748FFC),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ---- Дундаж үнэлгээ ----
          if (_averageRating > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2847),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.07)),
              ),
              child: Column(
                children: [
                  const Text(
                    'Нийт дундаж',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _averageRating.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Color(0xFFFFD43B),
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      if (i < _averageRating.floor()) {
                        return const Icon(
                          Icons.star,
                          color: Color(0xFFFFD43B),
                          size: 20,
                        );
                      } else if (i < _averageRating) {
                        return const Icon(
                          Icons.star_half,
                          color: Color(0xFFFFD43B),
                          size: 20,
                        );
                      } else {
                        return const Icon(
                          Icons.star_border,
                          color: Color(0xFFFFD43B),
                          size: 20,
                        );
                      }
                    }),
                  ),
                ],
              ),
            ),

          // ---- Шалгуурууд ----
          const Text(
            'Үнэлгээний шалгуурууд',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Шалгуур бүрийг 1-5 оноогоор үнэлнэ үү',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 14),

          ...List.generate(_criteria.length, (index) {
            final criterion = _criteria[index];
            final rating = criterion['rating'] as int;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2847),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: rating > 0
                      ? const Color(0xFF4C6EF5).withOpacity(0.2)
                      : Colors.white.withOpacity(0.05),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: rating > 0
                              ? const Color(0xFF4C6EF5).withOpacity(0.15)
                              : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          criterion['icon'] as IconData,
                          color: rating > 0
                              ? const Color(0xFF4C6EF5)
                              : Colors.white24,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              criterion['label'] as String,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              criterion['description'] as String,
                              style: const TextStyle(
                                color: Colors.white30,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (starIndex) {
                      final starNum = starIndex + 1;
                      final isSelected = starNum <= rating;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _criteria[index]['rating'] = starNum;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              isSelected ? Icons.star : Icons.star_border,
                              color: isSelected
                                  ? const Color(0xFFFFD43B)
                                  : Colors.white24,
                              size: 32,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 8),

          // ---- Сэтгэгдэл ----
          const Text(
            'Нэмэлт сэтгэгдэл (заавал биш)',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A2847),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            child: TextField(
              controller: _commentController,
              maxLines: 4,
              maxLength: 500,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Багшийн хичээлийн талаар сэтгэгдлээ бичнэ үү...',
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(14),
                counterStyle: const TextStyle(color: Colors.white24),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ---- Алдааны мессеж ----
          if (_errorMessage != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE03131).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Color(0xFFFF6B6B),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Color(0xFFFF6B6B),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ---- Илгээх товч ----
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _canSubmit && !_isSubmitting
                  ? _submitEvaluation
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _canSubmit
                    ? const Color(0xFF4C6EF5)
                    : const Color(0xFF4C6EF5).withOpacity(0.3),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: _canSubmit ? 4 : 0,
                shadowColor: const Color(0xFF4C6EF5).withOpacity(0.4),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      _canSubmit ? 'Үнэлгээ илгээх' : 'Бүх шалгуурыг үнэлнэ үү',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

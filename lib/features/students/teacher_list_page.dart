// Багшийн жагсаалт (тэнхимээр шүүгдсэн) - имэйл, rank харуулна
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'student_teacher_evaluation_page.dart';

class TeacherListPage extends StatefulWidget {
  final String school;
  final String department;

  const TeacherListPage({
    super.key,
    required this.school,
    required this.department,
  });

  @override
  State<TeacherListPage> createState() => _TeacherListPageState();
}

class _TeacherListPageState extends State<TeacherListPage> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _teachers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }

  String _normalize(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ');

  bool _matches(Map<String, dynamic> t) {
    final s = _normalize((t['school'] as String?) ?? '');
    final d = _normalize((t['department'] as String?) ?? '');
    return s == widget.school && d == widget.department;
  }

  Future<void> _loadTeachers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // DB дээр зайтай хувилбар байж болохоор бүх багшийг авч клиент талд
      // normalize-оор шүүнэ.
      final data = await _client
          .from('Teachers')
          .select(
            'id, user_id, last_name, first_name, rank, school, faculty, department, Users(email)',
          )
          .order('last_name');

      setState(() {
        _teachers = List<Map<String, dynamic>>.from(
          data,
        ).where(_matches).toList();
        _isLoading = false;
      });
    } catch (e) {
      // Join алдаа гарвал имэйлгүйгээр
      try {
        final data = await _client
            .from('Teachers')
            .select(
              'id, user_id, last_name, first_name, rank, school, faculty, department',
            )
            .order('last_name');

        setState(() {
          _teachers = List<Map<String, dynamic>>.from(
            data,
          ).where(_matches).toList();
          _isLoading = false;
        });
      } catch (e2) {
        setState(() {
          _error = 'Багш нарыг ачааллахад алдаа гарлаа';
          _isLoading = false;
        });
      }
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
          'Багшийн жагсаалт',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _loadTeachers,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.white54,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: _loadTeachers,
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    label: const Text(
                      'Дахин оролдох',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            )
          : _teachers.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person_off_outlined,
                    color: Colors.white24,
                    size: 52,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Багш олдсонгүй',
                    style: TextStyle(color: Colors.white38),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _teachers.length,
              itemBuilder: (context, index) {
                final teacher = _teachers[index];
                final lastName = teacher['last_name'] as String? ?? '';
                final firstName = teacher['first_name'] as String? ?? '';
                final name =
                    '${lastName.isNotEmpty ? '$lastName.' : ''} $firstName'
                        .trim();
                final id = ((teacher['id'] as num?)?.toInt()) ?? 0;
                final rank = teacher['rank'] as String? ?? '';
                final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

                // Users join-оос имэйл авах
                final usersData = teacher['Users'];
                final email = usersData is Map
                    ? usersData['email'] as String? ?? ''
                    : '';

                return GestureDetector(
                  onTap: () {
                    if (id == 0) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StudentTeacherEvaluationPage(
                          teacherName: name,
                          teacherId: id,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A2847),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.07)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
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
                              initials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
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
                                name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              if (rank.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  rank,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white54,
                                  ),
                                ),
                              ],
                              if (email.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.email_outlined,
                                      color: Colors.white30,
                                      size: 13,
                                    ),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        email,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.white30,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4C6EF5).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Үнэлэх',
                            style: TextStyle(
                              color: Color(0xFF4C6EF5),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

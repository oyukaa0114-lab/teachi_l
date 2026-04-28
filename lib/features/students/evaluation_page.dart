// Сурагч - Салбар сургууль → Тэнхим (dropdown) → Багшийн жагсаалт (шинэ хуудас)
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'teacher_list_page.dart';

class EvaluationPage extends StatefulWidget {
  const EvaluationPage({super.key});

  @override
  State<EvaluationPage> createState() => _EvaluationPageState();
}

class _EvaluationPageState extends State<EvaluationPage> {
  final _client = Supabase.instance.client;

  List<String> _schools = [];
  bool _isLoadingSchools = true;
  String? _error;

  // Аль сургууль нээгдсэн
  String? _expandedSchool;
  List<String> _departments = [];
  bool _isLoadingDepartments = false;

  @override
  void initState() {
    super.initState();
    _loadSchools();
  }

  Future<void> _loadSchools() async {
    setState(() {
      _isLoadingSchools = true;
      _error = null;
    });
    try {
      final data = await _client
          .from('Teachers')
          .select('school')
          .not('school', 'is', null);

      final schools = <String>{};
      for (final row in data) {
        final s = row['school'] as String?;
        if (s != null && s.isNotEmpty) schools.add(s);
      }

      setState(() {
        _schools = schools.toList()..sort();
        _isLoadingSchools = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Салбар сургуулиудыг ачааллахад алдаа гарлаа';
        _isLoadingSchools = false;
      });
    }
  }

  Future<void> _loadDepartments(String school) async {
    setState(() {
      _isLoadingDepartments = true;
      _departments = [];
    });
    try {
      final data = await _client
          .from('Teachers')
          .select('department')
          .eq('school', school)
          .not('department', 'is', null);

      final departments = <String>{};
      for (final row in data) {
        final d = row['department'] as String?;
        if (d != null && d.isNotEmpty) departments.add(d);
      }

      setState(() {
        _departments = departments.toList()..sort();
        _isLoadingDepartments = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingDepartments = false;
      });
    }
  }

  void _onSchoolTap(String school) {
    if (_expandedSchool == school) {
      setState(() {
        _expandedSchool = null;
        _departments = [];
      });
    } else {
      setState(() {
        _expandedSchool = school;
      });
      _loadDepartments(school);
    }
  }

  void _onDepartmentTap(String department) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            TeacherListPage(school: _expandedSchool!, department: department),
      ),
    );
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
          'Салбар сургууль',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: () {
              setState(() {
                _expandedSchool = null;
                _departments = [];
              });
              _loadSchools();
            },
          ),
        ],
      ),
      body: _isLoadingSchools
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
                    onPressed: _loadSchools,
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    label: const Text(
                      'Дахин оролдох',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            )
          : _schools.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.school_outlined, color: Colors.white24, size: 52),
                  SizedBox(height: 12),
                  Text(
                    'Салбар сургууль олдсонгүй',
                    style: TextStyle(color: Colors.white38),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _schools.length,
              itemBuilder: (context, index) {
                final school = _schools[index];
                final isExpanded = _expandedSchool == school;

                return Column(
                  children: [
                    // ---- Сургууль ----
                    GestureDetector(
                      onTap: () => _onSchoolTap(school),
                      child: Container(
                        margin: EdgeInsets.only(bottom: isExpanded ? 0 : 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A2847),
                          borderRadius: isExpanded
                              ? const BorderRadius.vertical(
                                  top: Radius.circular(16),
                                )
                              : BorderRadius.circular(16),
                          border: Border.all(
                            color: isExpanded
                                ? const Color(0xFF4C6EF5).withOpacity(0.3)
                                : Colors.white.withOpacity(0.07),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                school,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isExpanded
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            AnimatedRotation(
                              turns: isExpanded ? 0.5 : 0,
                              duration: const Duration(milliseconds: 200),
                              child: const Icon(
                                Icons.arrow_drop_down,
                                color: Colors.white38,
                                size: 24,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ---- Тэнхимүүд (dropdown) ----
                    if (isExpanded)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E2D52),
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(16),
                          ),
                          border: Border.all(
                            color: const Color(0xFF4C6EF5).withOpacity(0.2),
                          ),
                        ),
                        child: _isLoadingDepartments
                            ? const Padding(
                                padding: EdgeInsets.all(20),
                                child: Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white38,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              )
                            : _departments.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  'Тэнхим олдсонгүй',
                                  style: TextStyle(
                                    color: Colors.white30,
                                    fontSize: 13,
                                  ),
                                ),
                              )
                            : Column(
                                children: _departments.asMap().entries.map((
                                  entry,
                                ) {
                                  final idx = entry.key;
                                  final dept = entry.value;
                                  final isLast = idx == _departments.length - 1;

                                  return GestureDetector(
                                    onTap: () => _onDepartmentTap(dept),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 14,
                                      ),
                                      decoration: BoxDecoration(
                                        border: isLast
                                            ? null
                                            : Border(
                                                bottom: BorderSide(
                                                  color: Colors.white
                                                      .withOpacity(0.06),
                                                ),
                                              ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              dept,
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w400,
                                              ),
                                            ),
                                          ),
                                          const Icon(
                                            Icons.arrow_forward_ios,
                                            color: Colors.white24,
                                            size: 14,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                      ),
                  ],
                );
              },
            ),
    );
  }
}

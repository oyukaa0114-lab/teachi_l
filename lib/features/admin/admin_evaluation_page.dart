// admin_evaluation_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../auth/auth_controller.dart';
import 'admin_teacher_detail_page.dart';
import 'admin_period_page.dart';
import 'admin_stats_page.dart';

class AdminEvaluationPage extends StatefulWidget {
  final Map<String, dynamic>? adminData;
  const AdminEvaluationPage({super.key, this.adminData});

  @override
  State<AdminEvaluationPage> createState() => _AdminEvaluationPageState();
}

class _AdminEvaluationPageState extends State<AdminEvaluationPage> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _teachers = [];
  bool _isLoading = true;
  String _searchQuery = '';

  String? _adminSchool;
  String? _adminPosition;
  String? _adminDepartment;

  bool get _isTenhimiinErkhlegt =>
      (_adminPosition ?? '').contains('Тэнхимийн эрхлэгч');

  List<String> _departments = [];
  String _selectedDepartment = 'all';

  @override
  void initState() {
    super.initState();
    _loadAdminInfo();
  }

  Future<void> _loadAdminInfo() async {
    try {
      if (widget.adminData != null) {
        _adminSchool = widget.adminData!['school'] as String?;
        _adminPosition = widget.adminData!['position'] as String?;
        _adminDepartment = widget.adminData!['department'] as String?;
      } else {
        final userId = context.read<AuthController>().currentUser?['id'];
        if (userId == null) return;
        final adminData = await _client
            .from('admins')
            .select('school, position, department')
            .eq('user_id', userId)
            .maybeSingle();
        if (adminData != null) {
          _adminSchool = adminData['school'] as String?;
          _adminPosition = adminData['position'] as String?;
          _adminDepartment = adminData['department'] as String?;
        }
      }
    } catch (e) {
      debugPrint('Admin info error: $e');
    }
    await _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      var query = _client
          .from('Teachers')
          .select(
            'id, last_name, first_name, rank, department, school, teacher_code',
          );

      if (_adminSchool != null && _adminSchool!.isNotEmpty) {
        query = query.eq('school', _adminSchool!);
      }
      if (_isTenhimiinErkhlegt &&
          _adminDepartment != null &&
          _adminDepartment!.isNotEmpty) {
        query = query.eq('department', _adminDepartment!);
      }

      final teachers = await query.order('id');
      final teacherIds = (teachers as List).map((t) => t['id']).toList();

      List<dynamic> evaluations = [];
      if (teacherIds.isNotEmpty) {
        evaluations = await _client
            .from('evaluations')
            .select('teacher_id, rating')
            .inFilter('teacher_id', teacherIds);
      }

      final List<Map<String, dynamic>> result = [];
      final deptSet = <String>{};

      for (final t in teachers) {
        final tid = t['id'];
        final related = evaluations
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
        final dept = t['department'] as String? ?? '';
        if (dept.isNotEmpty) deptSet.add(dept);
      }

      result.sort((a, b) => (b['avg'] as double).compareTo(a['avg'] as double));

      setState(() {
        _teachers = result;
        _departments = deptSet.toList()..sort();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Load data error: $e');
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _teachers;
    if (_selectedDepartment != 'all') {
      list = list.where((t) => t['department'] == _selectedDepartment).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((t) {
        final name = '${t['last_name'] ?? ''} ${t['first_name'] ?? ''}'
            .toLowerCase();
        final code = (t['teacher_code'] ?? '').toString().toLowerCase();
        return name.contains(q) || code.contains(q);
      }).toList();
    }
    return list;
  }

  Color _ratingColor(double avg) {
    if (avg >= 4.0) return const Color(0xFF34D399);
    if (avg >= 3.0) return const Color(0xFFFFBF47);
    if (avg >= 2.0) return const Color(0xFFFF8E53);
    if (avg > 0) return const Color(0xFFF87171);
    return const Color(0xFF64748B);
  }

  @override
  Widget build(BuildContext context) {
    final isEmbedded = widget.adminData != null;
    final body = Column(
      children: [
        if (_adminSchool != null && _adminSchool!.isNotEmpty)
          _buildSchoolBanner(),
        if (!_isLoading && _teachers.isNotEmpty) _buildSummaryBar(),
        if (_isTenhimiinErkhlegt &&
            _adminDepartment != null &&
            _adminDepartment!.isNotEmpty)
          _buildDepartmentBanner(),
        if (_departments.isNotEmpty && !_isTenhimiinErkhlegt)
          _buildDepartmentFilter(),
        _buildSearchBar(),
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF5B8DEF)),
                )
              : _filtered.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: const Color(0xFF5B8DEF),
                  backgroundColor: const Color(0xFF12182B),
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) => _buildTeacherCard(_filtered[i], i),
                  ),
                ),
        ),
      ],
    );

    if (isEmbedded) return body;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: _buildAppBar(),
      body: body,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0A0E1A),
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
          onPressed: _loadAdminInfo,
        ),
      ],
    );
  }

  Widget _buildSchoolBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A2847), Color(0xFF162040)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF5B8DEF).withOpacity(0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.school_rounded, color: Color(0xFF5B8DEF), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _adminSchool!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (_adminPosition != null && _adminPosition!.isNotEmpty)
                  Text(
                    _adminPosition!,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF4C6EF5).withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF4C6EF5).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance, color: Color(0xFF4C6EF5), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Тэнхим: $_adminDepartment',
              style: const TextStyle(
                color: Color(0xFF4C6EF5),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            '${_teachers.length} багш',
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
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
    final overallAvg = totalEvals == 0
        ? 0.0
        : _teachers.fold<double>(
                0,
                (s, t) => s + (t['avg'] as double) * (t['count'] as int),
              ) /
              totalEvals;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF12182B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _summaryItem('Багш', '${_teachers.length}', Colors.white),
          _divider(),
          _summaryItem('Үнэлэгдсэн', '$evaluated', const Color(0xFF34D399)),
          _divider(),
          _summaryItem('Үнэлгээ', '$totalEvals', const Color(0xFF5B8DEF)),
          _divider(),
          _summaryItem(
            'Дундаж',
            overallAvg.toStringAsFixed(1),
            const Color(0xFFFFBF47),
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
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
        ),
      ],
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 32, color: Colors.white.withOpacity(0.06));

  Widget _buildDepartmentFilter() {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _filterChip('Бүгд', 'all'),
          ..._departments.map((d) => _filterChip(d, d)),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final isActive = _selectedDepartment == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedDepartment = value),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF5B8DEF).withOpacity(0.15)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? const Color(0xFF5B8DEF).withOpacity(0.4)
                : Colors.white.withOpacity(0.06),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? const Color(0xFF5B8DEF) : const Color(0xFF64748B),
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Багш хайх (нэр, код)...',
          hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
          prefixIcon: const Icon(
            Icons.search,
            color: Color(0xFF64748B),
            size: 20,
          ),
          filled: true,
          fillColor: const Color(0xFF12182B),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.school_outlined,
            color: Colors.white.withOpacity(0.1),
            size: 56,
          ),
          const SizedBox(height: 12),
          const Text(
            'Багш олдсонгүй',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherCard(Map<String, dynamic> t, int index) {
    final name = '${t['last_name'] ?? ''} ${t['first_name'] ?? ''}'.trim();
    final avg = t['avg'] as double;
    final count = t['count'] as int;
    final rank = t['rank'] as String? ?? '';
    final dept = t['department'] as String? ?? '';
    final code = t['teacher_code']?.toString() ?? '';
    final color = _ratingColor(avg);
    final teacherId = ((t['id'] as num?)?.toInt()) ?? 0;

    Color? medalColor;
    if (index == 0 && count > 0) medalColor = const Color(0xFFFFD700);
    if (index == 1 && count > 0) medalColor = const Color(0xFFC0C0C0);
    if (index == 2 && count > 0) medalColor = const Color(0xFFCD7F32);

    return GestureDetector(
      onTap: () {
        if (teacherId == 0) return;
        if (_isTenhimiinErkhlegt) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _TeacherDetailWithRequestsPage(
                teacherName: name,
                teacherId: teacherId,
                teacherData: t,
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminTeacherDetailPage(
                teacherName: name,
                teacherId: teacherId,
              ),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF12182B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                medalColor?.withOpacity(0.2) ?? Colors.white.withOpacity(0.04),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    medalColor?.withOpacity(0.15) ??
                    Colors.white.withOpacity(0.04),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: medalColor ?? const Color(0xFF64748B),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
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
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (rank.isNotEmpty) ...[
                        Text(
                          rank,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (code.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            code,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (dept.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        dept,
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 10,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (_isTenhimiinErkhlegt) ...[
              _RequestBadge(teacherId: teacherId),
              const SizedBox(width: 8),
            ],
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Icon(Icons.star_rounded, color: color, size: 18),
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
                Text(
                  '$count үнэлгээ',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Color(0xFF475569), size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Badge ────────────────────────────────────────────────────────────────────
class _RequestBadge extends StatefulWidget {
  final int teacherId;
  const _RequestBadge({required this.teacherId});
  @override
  State<_RequestBadge> createState() => _RequestBadgeState();
}

class _RequestBadgeState extends State<_RequestBadge> {
  final _client = Supabase.instance.client;
  int _feedbackCount = 0;
  int _complaintCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _client
          .from('requests')
          .select('type')
          .eq('teacher_id', widget.teacherId)
          .inFilter('type', ['feedback', 'gomdol']);
      final list = List<Map<String, dynamic>>.from(data);
      if (mounted) {
        setState(() {
          _feedbackCount = list.where((r) => r['type'] == 'feedback').length;
          _complaintCount = list.where((r) => r['type'] == 'gomdol').length;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_feedbackCount == 0 && _complaintCount == 0)
      return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_feedbackCount > 0)
          Container(
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.thumb_up_outlined,
                  size: 10,
                  color: Colors.blue,
                ),
                const SizedBox(width: 3),
                Text(
                  '$_feedbackCount',
                  style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        if (_complaintCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.warning_amber_outlined,
                  size: 10,
                  color: Colors.redAccent,
                ),
                const SizedBox(width: 3),
                Text(
                  '$_complaintCount',
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Detail page (Үнэлгээ + Санал/Гомдол tabs) ───────────────────────────────
class _TeacherDetailWithRequestsPage extends StatefulWidget {
  final String teacherName;
  final int teacherId;
  final Map<String, dynamic> teacherData;
  const _TeacherDetailWithRequestsPage({
    required this.teacherName,
    required this.teacherId,
    required this.teacherData,
  });
  @override
  State<_TeacherDetailWithRequestsPage> createState() =>
      _TeacherDetailWithRequestsPageState();
}

class _TeacherDetailWithRequestsPageState
    extends State<_TeacherDetailWithRequestsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rank = widget.teacherData['rank'] as String? ?? '';
    final dept = widget.teacherData['department'] as String? ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.teacherName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            if (rank.isNotEmpty || dept.isNotEmpty)
              Text(
                [
                  if (rank.isNotEmpty) rank,
                  if (dept.isNotEmpty) dept,
                ].join(' · '),
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            decoration: BoxDecoration(
              color: const Color(0xFF12182B),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: const Color(0xFF4C6EF5),
                borderRadius: BorderRadius.circular(10),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white38,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Үнэлгээ'),
                Tab(text: 'Санал / Гомдол'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                AdminTeacherDetailPage(
                  teacherName: widget.teacherName,
                  teacherId: widget.teacherId,
                  embedded: true,
                ),
                _TeacherRequestsView(teacherId: widget.teacherId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// _TeacherRequestsView — Admin зөвхөн харна, үйлдэл хийхгүй + файл харуулна
// ════════════════════════════════════════════════════════════════════════════
class _TeacherRequestsView extends StatefulWidget {
  final int teacherId;
  const _TeacherRequestsView({required this.teacherId});
  @override
  State<_TeacherRequestsView> createState() => _TeacherRequestsViewState();
}

class _TeacherRequestsViewState extends State<_TeacherRequestsView>
    with SingleTickerProviderStateMixin {
  final _client = Supabase.instance.client;
  late TabController _innerTabController;
  List<Map<String, dynamic>> _feedbacks = [];
  List<Map<String, dynamic>> _complaints = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _innerTabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _innerTabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _client
          .from('requests')
          .select(
            '*, Students!fk_requests_student(first_name, last_name, email)',
          )
          .eq('teacher_id', widget.teacherId)
          .inFilter('type', ['feedback', 'gomdol'])
          .order('created_at', ascending: false);

      final list = List<Map<String, dynamic>>.from(data);
      setState(() {
        _feedbacks = list.where((r) => r['type'] == 'feedback').toList();
        _complaints = list.where((r) => r['type'] == 'gomdol').toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1C3F),
            borderRadius: BorderRadius.circular(10),
          ),
          child: TabBar(
            controller: _innerTabController,
            indicator: BoxDecoration(
              color: const Color(0xFF1A2847),
              borderRadius: BorderRadius.circular(8),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white38,
            dividerColor: Colors.transparent,
            tabs: [
              Tab(text: 'Санал (${_feedbacks.length})'),
              Tab(text: 'Гомдол (${_complaints.length})'),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF4C6EF5)),
                )
              : TabBarView(
                  controller: _innerTabController,
                  children: [
                    _list(_feedbacks, Colors.blue),
                    _list(_complaints, Colors.red),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _list(List<Map<String, dynamic>> items, Color accent) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox_outlined, size: 48, color: Colors.white24),
            const SizedBox(height: 12),
            Text(
              accent == Colors.blue
                  ? 'Санал байхгүй байна'
                  : 'Гомдол байхгүй байна',
              style: const TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: items.length,
        itemBuilder: (_, i) => _buildCard(items[i], accent),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> item, Color accent) {
    final status = item['status'] as String? ?? 'pending';
    final title = item['title'] as String? ?? '';
    final content = item['content'] as String? ?? '';
    final fileUrl = item['file_url'] as String? ?? '';
    final date = ((item['created_at'] as String?) ?? '')
        .substring(0, 10)
        .replaceAll('-', '.');
    final isAnon = item['is_anonymous'] == true;
    final st = item['Students'];
    final stName = isAnon
        ? 'Нэргүй'
        : (st != null
              ? '${st['last_name'] ?? ''} ${st['first_name'] ?? ''}'.trim()
              : 'Суралцагч');
    final stEmail = isAnon ? null : st?['email'] as String?;

    // ── Статус: зөвхөн харуулах badge, dropdown байхгүй ─────────────────
    Color statusColor;
    String statusLabel;
    IconData statusIcon;
    switch (status) {
      case 'reviewing':
        statusColor = Colors.orange;
        statusLabel = 'Хянагдсан';
        statusIcon = Icons.hourglass_empty;
        break;
      case 'resolved':
        statusColor = const Color(0xFF34D399);
        statusLabel = 'Шийдвэрлэгдсэн';
        statusIcon = Icons.check_circle_outline;
        break;
      default:
        statusColor = Colors.white38;
        statusLabel = 'Хүлээгдэж байна';
        statusIcon = Icons.circle_outlined;
    }

    // ── Файл ─────────────────────────────────────────────────────────────
    final hasFile = fileUrl.isNotEmpty;
    final isImage =
        hasFile &&
        RegExp(
          r'\.(jpg|jpeg|png|gif|webp)(\?|$)',
          caseSensitive: false,
        ).hasMatch(fileUrl);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF12182B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: status == 'resolved'
              ? const Color(0xFF34D399).withOpacity(0.25)
              : accent.withOpacity(0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Үндсэн агуулга ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Статус badge + огноо
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 12, color: statusColor),
                          const SizedBox(width: 5),
                          Text(
                            statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      date,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Оюутны мэдээлэл
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: isAnon
                          ? Colors.white.withOpacity(0.06)
                          : accent.withOpacity(0.15),
                      child: Icon(
                        isAnon ? Icons.visibility_off : Icons.person,
                        size: 14,
                        color: isAnon ? Colors.white30 : accent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (stEmail != null)
                            Text(
                              stEmail,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Гарчиг
                if (title.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],

                // Агуулга
                if (content.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    content,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Хавсаргасан файл / зураг ───────────────────────────────────
          if (hasFile) ...[
            Divider(color: Colors.white.withOpacity(0.06), height: 1),
            if (isImage)
              // Зураг: дээр нь preview, доор нь нээх мөр
              Column(
                children: [
                  GestureDetector(
                    onTap: () => _openUrl(fileUrl),
                    child: ClipRRect(
                      borderRadius: BorderRadius.zero,
                      child: Image.network(
                        fileUrl,
                        width: double.infinity,
                        height: 180,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _imageError(),
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            height: 180,
                            color: Colors.white.withOpacity(0.04),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF4C6EF5),
                                strokeWidth: 2,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  // Файлын нэр мөр — зургийн доор
                  _fileRow(fileUrl, accent),
                ],
              )
            else
              _fileRow(fileUrl, accent),
          ],
        ],
      ),
    );
  }

  // ── Файлын нэр мөр (багшийн app-тай адил загвар) ──────────────────────────
  Widget _fileRow(String url, Color accent) {
    return GestureDetector(
      onTap: () => _openUrl(url),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_fileIcon(url), color: Colors.white54, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _fileName(url),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.open_in_new, color: Colors.white38, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _imageError() => Container(
    height: 80,
    color: Colors.white.withOpacity(0.04),
    child: const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, color: Colors.white24, size: 24),
          SizedBox(height: 4),
          Text(
            'Зураг ачаалагдсангүй',
            style: TextStyle(color: Colors.white24, fontSize: 11),
          ),
        ],
      ),
    ),
  );

  IconData _fileIcon(String url) {
    if (url.contains('.pdf')) return Icons.picture_as_pdf_outlined;
    if (url.contains('.doc')) return Icons.description_outlined;
    if (url.contains('.xls')) return Icons.table_chart_outlined;
    return Icons.attach_file;
  }

  String _fileName(String url) {
    try {
      return Uri.parse(url).pathSegments.last;
    } catch (_) {
      return 'Хавсаргасан файл';
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

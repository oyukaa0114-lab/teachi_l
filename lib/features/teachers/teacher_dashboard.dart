import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/auth_controller.dart';
import '../auth/login_page.dart';
import 'request_chat_page.dart';
import 'teacher_profile_page.dart';
import '../../widgets/notification_bell.dart';
import 'package:url_launcher/url_launcher.dart';

// ════════════════════════════════════════════
// Color Palette & Theme Constants
// ════════════════════════════════════════════
class _AppColors {
  // Base backgrounds
  static const Color bgDark = Color(0xFF0A0E1A);
  static const Color bgCard = Color(0xFF12182B);
  static const Color bgCardLight = Color(0xFF1A2240);

  // Accent colors
  static const Color accentBlue = Color(0xFF5B8DEF);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color accentCyan = Color(0xFF22D3EE);
  static const Color accentAmber = Color(0xFFFFBF47);
  static const Color accentGreen = Color(0xFF34D399);
  static const Color accentOrange = Color(0xFFFB923C);
  static const Color accentRed = Color(0xFFF87171);

  // Text
  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF5B8DEF), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGlow = LinearGradient(
    colors: [Color(0x205B8DEF), Color(0x108B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient ratingGradient = LinearGradient(
    colors: [Color(0xFFFFBF47), Color(0xFFFB923C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ════════════════════════════════════════════
// TeacherDashboard
// ════════════════════════════════════════════
class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().currentUser;
    final name = user?['username'] ?? 'Багш';

    final List<Widget> pages = [const _EvaluationsTab(), const _FeedbackTab()];

    return Scaffold(
      backgroundColor: _AppColors.bgDark,
      appBar: _buildAppBar(name),
      body: pages[_selectedIndex],
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  PreferredSizeWidget _buildAppBar(String name) {
    return AppBar(
      backgroundColor: _AppColors.bgDark,
      elevation: 0,
      automaticallyImplyLeading: false,
      toolbarHeight: 72,
      title: Row(
        children: [
          // Avatar with gradient border
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _AppColors.primaryGradient,
            ),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: _AppColors.bgCard,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'Б',
                style: const TextStyle(
                  color: _AppColors.accentBlue,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Сайн байна уу 👋',
                style: TextStyle(
                  color: _AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                name,
                style: const TextStyle(
                  color: _AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        if (context.watch<AuthController>().currentUser?['id'] != null)
          NotificationBell(
            userId: context.watch<AuthController>().currentUser!['id'] as int,
          ),
        const SizedBox(width: 4),
        _GlassIconButton(
          icon: Icons.logout_rounded,
          onTap: () {
            context.read<AuthController>().logout();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginPage()),
            );
          },
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: _AppColors.bgCard,
        border: const Border(
          top: BorderSide(color: Color(0xFF1E2A4A), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.star_rounded,
                label: 'Үнэлгээ',
                isActive: _selectedIndex == 0,
                onTap: () => setState(() => _selectedIndex = 0),
              ),
              _NavItem(
                icon: Icons.forum_rounded,
                label: 'Санал/Гомдол',
                isActive: _selectedIndex == 1,
                onTap: () => setState(() => _selectedIndex = 1),
              ),
              _NavItem(
                icon: Icons.person_rounded,
                label: 'Профайл',
                isActive: false,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TeacherProfilePage(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════
// Custom Nav Item
// ════════════════════════════════════════════
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isActive ? 16 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? _AppColors.accentBlue.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isActive ? _AppColors.accentBlue : _AppColors.textMuted,
            ),
            if (isActive) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: _AppColors.accentBlue,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════
// Glass Icon Button
// ════════════════════════════════════════════
class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Icon(icon, color: _AppColors.textSecondary, size: 20),
      ),
    );
  }
}

// ════════════════════════════════════════════
// TAB 1: Үнэлгээ (Evaluations)
// ════════════════════════════════════════════
class _EvaluationsTab extends StatefulWidget {
  const _EvaluationsTab();
  @override
  State<_EvaluationsTab> createState() => _EvaluationsTabState();
}

class _EvaluationsTabState extends State<_EvaluationsTab> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _evaluations = [];
  bool _isLoading = true;
  double _avgRating = 0;

  // Rating distribution for the visual bar chart
  List<int> _ratingDistribution = [0, 0, 0, 0, 0];

  @override
  void initState() {
    super.initState();
    _loadEvaluations();
  }

  Future<void> _loadEvaluations() async {
    setState(() => _isLoading = true);
    try {
      final userId = context.read<AuthController>().currentUser?['id'];
      final teacherData = await _client
          .from('Teachers')
          .select('id')
          .eq('user_id', userId)
          .single();
      final teacherId = teacherData['id'];

      final data = await _client
          .from('evaluations')
          .select('*, Students(first_name, last_name, email)')
          .eq('teacher_id', teacherId)
          .order('created_at', ascending: false);

      final list = List<Map<String, dynamic>>.from(data);
      double avg = 0;
      List<int> dist = [0, 0, 0, 0, 0];
      if (list.isNotEmpty) {
        for (var ev in list) {
          final r = ((ev['rating'] as num?)?.toInt() ?? 0).clamp(1, 5);
          dist[r - 1]++;
        }
        avg =
            list.fold<int>(
              0,
              (s, r) => s + ((r['rating'] as num?)?.toInt() ?? 0),
            ) /
            list.length;
      }
      setState(() {
        _evaluations = list;
        _avgRating = avg;
        _ratingDistribution = dist;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(_AppColors.accentBlue),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Үнэлгээ ачааллаж байна...',
              style: TextStyle(color: _AppColors.textMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _AppColors.accentBlue,
      backgroundColor: _AppColors.bgCard,
      onRefresh: _loadEvaluations,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _buildRatingHeader(),
          const SizedBox(height: 8),
          _buildRatingDistribution(),
          const SizedBox(height: 24),

          // Section title
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 16,
                  decoration: BoxDecoration(
                    gradient: _AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Сүүлийн үнэлгээнүүд',
                  style: TextStyle(
                    color: _AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_evaluations.length} үнэлгээ',
                  style: const TextStyle(
                    color: _AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          if (_evaluations.isEmpty)
            _emptyState('Үнэлгээ байхгүй байна', Icons.star_outline)
          else
            ..._evaluations.asMap().entries.map(
              (entry) => _buildEvaluationCard(entry.value, entry.key),
            ),
        ],
      ),
    );
  }

  Widget _buildRatingHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF1A2240), Color(0xFF162040)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: _AppColors.accentAmber.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: _AppColors.accentAmber.withOpacity(0.06),
            blurRadius: 30,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          // Big rating number with glow
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _AppColors.ratingGradient,
              boxShadow: [
                BoxShadow(
                  color: _AppColors.accentAmber.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Center(
              child: Text(
                _avgRating.toStringAsFixed(1),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Дундаж үнэлгээ',
                  style: TextStyle(
                    color: _AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: List.generate(5, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 2),
                      child: Icon(
                        i < _avgRating.round()
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: _AppColors.accentAmber,
                        size: 20,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_evaluations.length} суралцагчийн үнэлгээ',
                  style: const TextStyle(
                    color: _AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingDistribution() {
    final total = _ratingDistribution
        .fold<int>(0, (a, b) => a + b)
        .clamp(1, 99999);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        children: List.generate(5, (index) {
          final star = 5 - index;
          final count = _ratingDistribution[star - 1];
          final pct = count / total;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  child: Text(
                    '$star',
                    style: const TextStyle(
                      color: _AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(
                  Icons.star_rounded,
                  size: 14,
                  color: _AppColors.accentAmber,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 6,
                      backgroundColor: Colors.white.withOpacity(0.06),
                      valueColor: AlwaysStoppedAnimation(
                        Color.lerp(
                          _AppColors.accentRed,
                          _AppColors.accentAmber,
                          (star - 1) / 4,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 24,
                  child: Text(
                    '$count',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: _AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildEvaluationCard(Map<String, dynamic> ev, int index) {
    final rating = ((ev['rating'] as num?)?.toInt()) ?? 0;
    final comment = ev['comment'] as String? ?? '';
    final isAnon = ev['is_anonymous'] == true;
    final date = ((ev['created_at'] as String?) ?? '')
        .substring(0, 10)
        .replaceAll('-', '.');

    // Get student name
    String studentName = 'Суралцагч';
    String? studentEmail;
    if (!isAnon && ev['Students'] != null) {
      final st = ev['Students'];
      final last = st['last_name'] ?? '';
      final first = st['first_name'] ?? '';
      studentName = '${last.isNotEmpty ? '$last.' : ''} $first'.trim();
      studentEmail = st['email'];
    } else if (isAnon) {
      studentName = 'Нэргүй';
    }

    // Color for rating
    Color ratingColor;
    if (rating >= 4) {
      ratingColor = _AppColors.accentGreen;
    } else if (rating >= 3) {
      ratingColor = _AppColors.accentAmber;
    } else {
      ratingColor = _AppColors.accentRed;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              // Student avatar
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isAnon
                      ? Colors.white.withOpacity(0.06)
                      : _AppColors.accentBlue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isAnon ? Icons.visibility_off_rounded : Icons.person_rounded,
                  size: 18,
                  color: isAnon ? _AppColors.textMuted : _AppColors.accentBlue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      studentName,
                      style: const TextStyle(
                        color: _AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (studentEmail != null)
                      Text(
                        studentEmail,
                        style: const TextStyle(
                          color: _AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              // Date
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  date,
                  style: const TextStyle(
                    color: _AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Rating display
          Row(
            children: [
              ...List.generate(5, (i) {
                return Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Icon(
                    i < rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: _AppColors.accentAmber,
                    size: 18,
                  ),
                );
              }),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: ratingColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$rating/5',
                  style: TextStyle(
                    color: ratingColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          // Comment
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.04)),
              ),
              child: Text(
                comment,
                style: const TextStyle(
                  color: _AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════
// TAB 2: Санал / Гомдол (Feedback)
// ════════════════════════════════════════════
class _FeedbackTab extends StatefulWidget {
  const _FeedbackTab();
  @override
  State<_FeedbackTab> createState() => _FeedbackTabState();
}

class _FeedbackTabState extends State<_FeedbackTab>
    with SingleTickerProviderStateMixin {
  final _client = Supabase.instance.client;
  late TabController _tabController;
  List<Map<String, dynamic>> _feedbacks = [];
  List<Map<String, dynamic>> _complaints = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final userId = context.read<AuthController>().currentUser?['id'];
      final teacherData = await _client
          .from('Teachers')
          .select('id')
          .eq('user_id', userId)
          .single();
      final teacherId = teacherData['id'];

      final feedbackData = await _client
          .from('requests')
          .select(
            '*, Students!fk_requests_student(first_name, last_name, email)',
          )
          .eq('teacher_id', teacherId)
          .eq('type', 'feedback')
          .order('created_at', ascending: false);

      final complaintData = await _client
          .from('requests')
          .select(
            '*, Students!fk_requests_student(first_name, last_name, email)',
          )
          .eq('teacher_id', teacherId)
          .eq('type', 'gomdol')
          .order('created_at', ascending: false);

      setState(() {
        _feedbacks = List<Map<String, dynamic>>.from(feedbackData);
        _complaints = List<Map<String, dynamic>>.from(complaintData);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('=== FEEDBACK ERROR: $e ===');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Custom Tab Bar
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _AppColors.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.04)),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              gradient: _AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: _AppColors.accentBlue.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: Colors.white,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            unselectedLabelColor: _AppColors.textMuted,
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
            dividerColor: Colors.transparent,
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lightbulb_outline_rounded, size: 16),
                    const SizedBox(width: 6),
                    Text('Санал (${_feedbacks.length})'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.flag_outlined, size: 16),
                    const SizedBox(width: 6),
                    Text('Гомдол (${_complaints.length})'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: _AppColors.accentBlue,
                    strokeWidth: 3,
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _feedbackList(_feedbacks, isFeedback: true),
                    _feedbackList(_complaints, isFeedback: false),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _feedbackList(
    List<Map<String, dynamic>> items, {
    required bool isFeedback,
  }) {
    if (items.isEmpty) {
      return _emptyState(
        isFeedback ? 'Санал байхгүй байна' : 'Гомдол байхгүй байна',
        isFeedback ? Icons.lightbulb_outline : Icons.flag_outlined,
      );
    }
    return RefreshIndicator(
      color: _AppColors.accentBlue,
      backgroundColor: _AppColors.bgCard,
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        itemBuilder: (_, i) => _buildFeedbackCard(items[i], isFeedback),
      ),
    );
  }

  Widget _buildFeedbackCard(Map<String, dynamic> item, bool isFeedback) {
    final isAnon = item['is_anonymous'] == true;
    final title = item['title'] as String? ?? '';
    final content = item['content'] as String? ?? '';
    final category = item['category'] as String? ?? '';
    final status = item['status'] as String? ?? 'pending';
    final date = ((item['created_at'] as String?) ?? '')
        .substring(0, 10)
        .replaceAll('-', '.');

    // Student info
    String studentName = 'Суралцагч';
    String? studentEmail;
    if (!isAnon && item['Students'] != null) {
      final st = item['Students'];
      final last = st['last_name'] ?? '';
      final first = st['first_name'] ?? '';
      studentName = '$last $first'.trim();
      studentEmail = st['email'];
    } else if (isAnon) {
      studentName = 'Нэргүй суралцагч';
    }

    // Status config
    Color statusColor;
    String statusLabel;
    IconData statusIcon;
    switch (status) {
      case 'reviewing':
        statusColor = _AppColors.accentBlue;
        statusLabel = 'Хянагдаж байна';
        statusIcon = Icons.remove_red_eye_outlined;
        break;
      case 'resolved':
        statusColor = _AppColors.accentGreen;
        statusLabel = 'Шийдвэрлэгдсэн';
        statusIcon = Icons.check_circle_outline_rounded;
        break;
      default:
        statusColor = _AppColors.accentOrange;
        statusLabel = 'Хүлээгдэж байна';
        statusIcon = Icons.schedule_rounded;
    }

    final typeColor = isFeedback ? _AppColors.accentBlue : _AppColors.accentRed;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RequestChatPage(request: item, senderRole: 'teacher'),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: typeColor.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: type badge + category + date
            Row(
              children: [
                // Type badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        typeColor.withOpacity(0.2),
                        typeColor.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: typeColor.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isFeedback
                            ? Icons.lightbulb_rounded
                            : Icons.flag_rounded,
                        size: 12,
                        color: typeColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isFeedback ? 'Санал' : 'Гомдол',
                        style: TextStyle(
                          color: typeColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (category.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      category,
                      style: const TextStyle(
                        color: _AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  date,
                  style: const TextStyle(
                    color: _AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  color: _AppColors.textMuted,
                  size: 16,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Student info
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isAnon
                        ? Colors.white.withOpacity(0.05)
                        : typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isAnon
                        ? Icons.visibility_off_rounded
                        : Icons.person_rounded,
                    size: 16,
                    color: isAnon ? _AppColors.textMuted : typeColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        studentName,
                        style: const TextStyle(
                          color: _AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (studentEmail != null)
                        Text(
                          studentEmail,
                          style: const TextStyle(
                            color: _AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            // Title & Content
            if (title.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  color: _AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ],
            if (content.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],

            const SizedBox(height: 14),
            // Divider
            Container(height: 1, color: Colors.white.withOpacity(0.04)),
            const SizedBox(height: 12),
            // Хавсаргасан файл
            if (item['file_url'] != null &&
                (item['file_url'] as String).isNotEmpty) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () async {
                  final url = item['file_url'] as String;
                  final uri = Uri.tryParse(url);
                  if (uri != null) {
                    try {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    } catch (_) {}
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _AppColors.accentBlue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _AppColors.accentBlue.withOpacity(0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getFileIcon(item['file_url'] as String),
                        color: _AppColors.accentBlue,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Хавсаргасан файл',
                          style: TextStyle(
                            color: _AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.open_in_new_rounded,
                        color: _AppColors.accentBlue,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            // Status row with dropdown
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
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
                // Dropdown
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: status,
                      isDense: true,
                      dropdownColor: const Color(0xFF1E2A4A),
                      borderRadius: BorderRadius.circular(12),
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: _AppColors.textMuted,
                      ),
                      style: const TextStyle(
                        color: _AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'pending',
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 14,
                                color: _AppColors.accentOrange,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Хүлээгдэж байна',
                                style: TextStyle(
                                  color: _AppColors.accentOrange,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'reviewing',
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.remove_red_eye_outlined,
                                size: 14,
                                color: _AppColors.accentBlue,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Хянагдаж байна',
                                style: TextStyle(
                                  color: _AppColors.accentBlue,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'resolved',
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_outline_rounded,
                                size: 14,
                                color: _AppColors.accentGreen,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Шийдвэрлэгдсэн',
                                style: TextStyle(
                                  color: _AppColors.accentGreen,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (newStatus) async {
                        if (newStatus == null || newStatus == status) return;
                        await _client
                            .from('requests')
                            .update({'status': newStatus})
                            .eq('id', item['id']);
                        _loadData();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════
// Shared Empty State
// ════════════════════════════════════════════
Widget _emptyState(String text, IconData icon) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 32, color: _AppColors.textMuted),
        ),
        const SizedBox(height: 16),
        Text(
          text,
          style: const TextStyle(
            color: _AppColors.textMuted,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

IconData _getFileIcon(String url) {
  final lower = url.toLowerCase();
  if (lower.contains('.pdf')) return Icons.picture_as_pdf_outlined;
  if (lower.contains('.doc') || lower.contains('.docx'))
    return Icons.description_outlined;
  if (lower.contains('.jpg') ||
      lower.contains('.jpeg') ||
      lower.contains('.png'))
    return Icons.image_outlined;
  if (lower.contains('.xls') || lower.contains('.xlsx'))
    return Icons.table_chart_outlined;
  return Icons.insert_drive_file_outlined;
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/auth_controller.dart';
import '../auth/login_page.dart';
import 'request_chat_page.dart';
import 'teacher_profile_page.dart';
import '../../widgets/notification_bell.dart';

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
      backgroundColor: const Color(0xFF0F1C3F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1C3F),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Сайн байна уу,',
              style: TextStyle(color: Colors.white60, fontSize: 13),
            ),
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          NotificationBell(
            userId: context.watch<AuthController>().currentUser?['id'],
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              context.read<AuthController>().logout();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
          ),
        ],
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F1C3F),
          border: Border(top: BorderSide(color: Colors.white12)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          type: BottomNavigationBarType.fixed,
          onTap: (i) {
            if (i == 2) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TeacherProfilePage()),
              );
              return;
            }
            setState(() => _selectedIndex = i);
          },
          backgroundColor: Colors.transparent,
          selectedItemColor: const Color(0xFF4C6EF5),
          unselectedItemColor: Colors.white38,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.star_outline),
              activeIcon: Icon(Icons.star),
              label: 'Үнэлгээ',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              activeIcon: Icon(Icons.chat_bubble),
              label: 'Санал/Гомдол',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Профайл',
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────
// TAB 1: Үнэлгээ
// ────────────────────────────────────────────
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
      if (list.isNotEmpty) {
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
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF4C6EF5)),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadEvaluations,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B5BDB), Color(0xFF4C6EF5)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.star_rounded, color: Colors.amber, size: 40),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _avgRating.toStringAsFixed(1),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Дундаж үнэлгээ · ${_evaluations.length} үнэлгээ',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_evaluations.isEmpty)
            _emptyState('Үнэлгээ байхгүй байна', Icons.star_outline)
          else
            ..._evaluations.map((ev) {
              final rating = ((ev['rating'] as num?)?.toInt()) ?? 0;
              final comment = ev['comment'] as String? ?? '';
              final isAnon = ev['is_anonymous'] == true;
              final date = ((ev['created_at'] as String?) ?? '')
                  .substring(0, 10)
                  .replaceAll('-', '.');
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.white12,
                          child: Icon(
                            isAnon ? Icons.visibility_off : Icons.person,
                            size: 14,
                            color: Colors.white54,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isAnon
                                  ? 'Нэргүй'
                                  : () {
                                      final st = ev['Students'];
                                      if (st == null) return 'Суралцагч';
                                      final last = st['last_name'] ?? '';
                                      final first = st['first_name'] ?? '';
                                      return '${last.isNotEmpty ? '$last.' : ''} $first'
                                          .trim();
                                    }(),
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (!isAnon && ev['Students']?['email'] != null)
                              Text(
                                ev['Students']['email'],
                                style: const TextStyle(
                                  color: Colors.white30,
                                  fontSize: 10,
                                ),
                              ),
                          ],
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
                    const SizedBox(height: 10),
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 18,
                        ),
                      ),
                    ),
                    if (comment.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        comment,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
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
    );
  }
}

// ────────────────────────────────────────────
// TAB 2: Санал / Гомдол
// ────────────────────────────────────────────
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
        Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
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
        isFeedback ? Icons.chat_bubble_outline : Icons.report_outlined,
      );
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final item = items[i];
          final isAnon = item['is_anonymous'] == true;
          final title = item['title'] as String? ?? '';
          final content = item['content'] as String? ?? '';
          final category = item['category'] as String? ?? '';
          final status = item['status'] as String? ?? 'pending';
          final date = ((item['created_at'] as String?) ?? '')
              .substring(0, 10)
              .replaceAll('-', '.');

          Color statusColor;
          String statusLabel;
          IconData statusIcon;
          switch (status) {
            case 'reviewing':
              statusColor = Colors.orange;
              statusLabel = 'Хүлээгдэж байна';
              statusIcon = Icons.hourglass_empty;
              break;
            case 'resolved':
              statusColor = Colors.green;
              statusLabel = 'Шийдвэрлэгдсэн';
              statusIcon = Icons.check_circle_outline;
              break;
            default:
              statusColor = Colors.white38;
              statusLabel = 'Бүгд';
              statusIcon = Icons.circle_outlined;
          }

          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    RequestChatPage(request: item, senderRole: 'teacher'),
              ),
            ),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: status == 'resolved'
                      ? Colors.green.withOpacity(0.3)
                      : isFeedback
                      ? Colors.blue.withOpacity(0.2)
                      : Colors.red.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isFeedback
                              ? Colors.blue.withOpacity(0.15)
                              : Colors.red.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isFeedback ? 'Санал' : 'Гомдол',
                          style: TextStyle(
                            color: isFeedback
                                ? Colors.blue[300]
                                : Colors.red[300],
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (category.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            category,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      const Icon(
                        Icons.chevron_right,
                        color: Colors.white24,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        date,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        isAnon ? Icons.visibility_off : Icons.person,
                        size: 13,
                        color: Colors.white38,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isAnon
                                  ? 'Нэргүй суралцагч'
                                  : () {
                                      final st = item['Students'];
                                      if (st == null) return 'Суралцагч';
                                      final last = st['last_name'] ?? '';
                                      final first = st['first_name'] ?? '';
                                      return '$last $first'.trim();
                                    }(),
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                            if (!isAnon && item['Students']?['email'] != null)
                              Text(
                                item['Students']['email'],
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
                  if (title.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (content.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      content,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 6),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: statusColor.withOpacity(0.3),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: status,
                            isDense: true,
                            dropdownColor: const Color(0xFF1E2340),
                            icon: Icon(
                              Icons.keyboard_arrow_down,
                              size: 14,
                              color: statusColor,
                            ),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'pending',
                                child: Text(
                                  'Хүлээгдэж байна',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'reviewing',
                                child: Text(
                                  'Хянагдсан',
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'resolved',
                                child: Text(
                                  'Шийдвэрлэгдсэн',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (newStatus) async {
                              if (newStatus == null || newStatus == status) {
                                return;
                              }
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
        },
      ),
    );
  }
}

// ────────────────────────────────────────────
// Shared empty state
// ────────────────────────────────────────────
Widget _emptyState(String text, IconData icon) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 48, color: Colors.white24),
        const SizedBox(height: 12),
        Text(text, style: const TextStyle(color: Colors.white38, fontSize: 14)),
      ],
    ),
  );
}

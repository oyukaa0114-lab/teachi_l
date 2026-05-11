import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/auth_controller.dart';
import '../auth/login_page.dart';
import '../../widgets/app_sidebar.dart';
import '../../widgets/notification_bell.dart';
import '../../core/services/notification_service.dart';
import '../notifications_page.dart';
import 'evaluation_page.dart';
import 'feedback_page.dart';
import 'my_requests_page.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  int _selectedIndex = 0;
  bool _sidebarOpen = false;
  List<Map<String, dynamic>> _recentNotifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final userId = context.read<AuthController>().currentUser?['id'];
    if (userId == null) return;
    final data = await NotificationService.getAll(userId);
    if (mounted) {
      setState(() {
        _recentNotifications = data.take(5).toList();
      });
    }
  }

  void _onMenuTap(int index) {
    setState(() {
      _selectedIndex = index;
      _sidebarOpen = false;
    });
    if (index == 0) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const EvaluationPage()),
      );
    } else if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const FeedbackPage()),
      );
    } else if (index == 4) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MyRequestsPage()),
      );
    }
  }

  void _onLogout() {
    context.read<AuthController>().logout();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'status_change':
        return Colors.green;
      case 'new_request':
        return const Color(0xFF4C6EF5);
      case 'new_message':
        return Colors.orange;
      default:
        return const Color(0xFF0CA678);
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'status_change':
        return Icons.update_rounded;
      case 'new_request':
        return Icons.mark_email_unread_outlined;
      case 'new_message':
        return Icons.chat_bubble_outline;
      default:
        return Icons.notifications_outlined;
    }
  }

  String _timeAgo(String createdAt) {
    final dt = DateTime.tryParse(createdAt)?.toLocal();
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Дөнгөж сая';
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин өмнө';
    if (diff.inHours < 24) return '${diff.inHours} цаг өмнө';
    return '${diff.inDays} өдөр өмнө';
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().currentUser;
    final userId = user?['id'] as int?;
    final lastName = user?['last_name'] as String? ?? '';
    final firstName = user?['first_name'] as String? ?? '';
    final username = (lastName.isNotEmpty || firstName.isNotEmpty)
        ? '${lastName.isNotEmpty ? "$lastName. " : ""}$firstName'.trim()
        : (user?['username'] as String? ?? 'Оюутан');

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: Stack(
        children: [
          // Main content
          CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0F1C3F), Color(0xFF5C7CFA)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top bar
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                onTap: () => setState(
                                  () => _sidebarOpen = !_sidebarOpen,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.menu,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                              ),
                              // ── NotificationBell ──
                              if (userId != null)
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: NotificationBell(userId: userId),
                                )
                              else
                                const SizedBox.shrink(),
                            ],
                          ),
                          const SizedBox(height: 26),
                          Text(
                            'Сайн байна уу,',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 24,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            username,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // Quick actions
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Үйлдлүүд',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _QuickActionCard(
                              icon: Icons.assignment_outlined,
                              label: 'Үнэлгээ',
                              color: const Color(0xFF3B5BDB),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const EvaluationPage(),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _QuickActionCard(
                              icon: Icons.chat_bubble_outline,
                              label: 'Санал',
                              color: const Color(0xFF0CA678),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const FeedbackPage(),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _QuickActionCard(
                              icon: Icons.list_alt_outlined,
                              label: 'Жагсаалт',
                              color: const Color(0xFFE8590C),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const MyRequestsPage(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // Сүүлийн мэдэгдлүүд — бодит дата
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Сүүлийн мэдэгдлүүд',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          if (userId != null) {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    NotificationsPage(userId: userId),
                              ),
                            );
                            _loadNotifications();
                          }
                        },
                        child: const Text(
                          'Бүгд',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF3B5BDB),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                sliver: _recentNotifications.isEmpty
                    ? SliverToBoxAdapter(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: Text(
                              'Мэдэгдэл байхгүй байна',
                              style: TextStyle(
                                color: Color(0xFF888888),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate((_, i) {
                          final n = _recentNotifications[i];
                          final isRead = n['is_read'] == true;
                          final type = n['type'] as String? ?? '';
                          final color = _colorForType(type);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: GestureDetector(
                              onTap: () async {
                                if (!isRead) {
                                  await NotificationService.markRead(n['id']);
                                  _loadNotifications();
                                }
                              },
                              child: _NotificationItem(
                                title: n['title'] ?? '',
                                body: n['body'] ?? '',
                                time: _timeAgo(n['created_at'] ?? ''),
                                icon: _iconForType(type),
                                color: color,
                                isUnread: !isRead,
                              ),
                            ),
                          );
                        }, childCount: _recentNotifications.length),
                      ),
              ),
            ],
          ),

          // Sidebar overlay
          if (_sidebarOpen)
            GestureDetector(
              onTap: () => setState(() => _sidebarOpen = false),
              child: Container(color: Colors.black.withOpacity(0.4)),
            ),

          // Sidebar
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            left: _sidebarOpen ? 0 : -300,
            top: 0,
            bottom: 0,
            child: AppSidebar(
              selectedIndex: _selectedIndex,
              onMenuTap: _onMenuTap,
              onLogout: _onLogout,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
class _NotificationItem extends StatelessWidget {
  const _NotificationItem({
    required this.title,
    required this.body,
    required this.time,
    required this.icon,
    required this.color,
    required this.isUnread,
  });
  final String title, body, time;
  final IconData icon;
  final Color color;
  final bool isUnread;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isUnread ? Colors.white : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
        border: isUnread
            ? Border.all(color: color.withOpacity(0.2))
            : Border.all(color: Colors.transparent),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isUnread
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: const Color(0xFF1A1A2E),
                        ),
                      ),
                    ),
                    if (isUnread)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF888888),
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/auth_controller.dart';
import '../teachers/request_chat_page.dart';
import '../../core/services/notification_service.dart';
import '../../features/notifications_page.dart';
import 'admin_profile.dart';
import 'admin_evaluation_page.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _client = Supabase.instance.client;
  int _selectedIndex = 0;
  Map<String, dynamic>? _adminData;
  int? _adminId;
  int? _adminUserId;
  int _unreadCount = 0;

  bool get _isTenhimiinErkhlegt =>
      (_adminData?['position'] as String? ?? '').contains('Тэнхимийн эрхлэгч');

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    final userId = context.read<AuthController>().currentUser?['id'];
    if (userId == null) return;
    try {
      final data = await _client
          .from('admins')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _adminData = data;
          _adminId = data?['id'] as int?;
          _adminUserId = userId is int
              ? userId
              : int.tryParse(userId.toString());
        });
        _loadUnreadCount();
        _subscribeRealtime();
      }
    } catch (_) {}
  }

  Future<void> _loadUnreadCount() async {
    if (_adminUserId == null) return;
    final count = await NotificationService.getUnreadCount(_adminUserId!);
    if (mounted) setState(() => _unreadCount = count);
  }

  void _subscribeRealtime() {
    if (_adminUserId == null) return;
    _client
        .channel('admin_bell_$_adminUserId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: _adminUserId,
            // .toString(), // Realtime Web: int биш String байх ёстой
          ),
          callback: (_) => _loadUnreadCount(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    // _client.removeAllChannels(); realtime-д бүх сувгийг устгадаг тул зөвхөн өөрийнхөө сувгийг устгаж байна
    _client.channel('admin_bell_$_adminUserId').unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().currentUser;
    final username = user?['username'] ?? 'Захиргаа';
    final firstName = _adminData?['first_name'] as String? ?? '';
    final lastName = _adminData?['last_name'] as String? ?? '';
    final position = _adminData?['position'] as String? ?? '';
    final displayName = (lastName.isNotEmpty || firstName.isNotEmpty)
        ? '${lastName.isNotEmpty ? "$lastName." : ""} $firstName'.trim()
        : username;

    // Хоёуланд нь: Хүсэлтүүд | Үнэлгээ | Профайл (3 tab)
    // Тэнхимийн эрхлэгч: Хүсэлтүүд = admin_id-аар ирсэн оюутны санал/гомдол/хүсэлт
    //                     Үнэлгээ    = өөрийн тэнхимийн багш нарын үнэлгээ + санал/гомдол
    final List<Widget> pages = [
      _RequestsTab(adminId: _adminId, adminData: _adminData),
      AdminEvaluationPage(adminData: _adminData),
      AdminProfilePage(adminData: _adminData),
    ];

    const navItems = [
      BottomNavigationBarItem(
        icon: Icon(Icons.inbox_outlined),
        activeIcon: Icon(Icons.inbox),
        label: 'Хүсэлтүүд',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.star_outline),
        activeIcon: Icon(Icons.star),
        label: 'Үнэлгээ',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.person_outline),
        activeIcon: Icon(Icons.person),
        label: 'Профайл',
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0F1C3F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1C3F),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              position.isNotEmpty ? position : 'Захиргаа',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          if (_adminUserId != null)
            _NotificationBellButton(
              userId: _adminUserId!,
              unreadCount: _unreadCount,
              onReturn: _loadUnreadCount,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _adminId == null
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4C6EF5)),
            )
          : pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F1C3F),
          border: Border(top: BorderSide(color: Colors.white12)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          type: BottomNavigationBarType.fixed,
          onTap: (i) => setState(() => _selectedIndex = i),
          backgroundColor: Colors.transparent,
          selectedItemColor: const Color(0xFF4C6EF5),
          unselectedItemColor: Colors.white38,
          elevation: 0,
          items: navItems,
        ),
      ),
    );
  }
}

// ── Notification bell ────────────────────────────────────────────────────────
class _NotificationBellButton extends StatefulWidget {
  final int userId;
  final int unreadCount;
  final VoidCallback onReturn;

  const _NotificationBellButton({
    required this.userId,
    required this.unreadCount,
    required this.onReturn,
  });

  @override
  State<_NotificationBellButton> createState() =>
      _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<_NotificationBellButton> {
  bool _isNavigating = false;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () async {
        if (_isNavigating) return;
        _isNavigating = true;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NotificationsPage(userId: widget.userId),
          ),
        );
        _isNavigating = false;
        widget.onReturn();
      },
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(
            Icons.notifications_outlined,
            color: Colors.white,
            size: 26,
          ),
          if (widget.unreadCount > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  widget.unreadCount > 99 ? '99+' : '${widget.unreadCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════
// Хүсэлтүүд Tab — Сургалтын алба болон бусад
// ════════════════════════════════════════════
class _RequestsTab extends StatefulWidget {
  final int? adminId;
  final Map<String, dynamic>? adminData;

  const _RequestsTab({this.adminId, this.adminData});

  @override
  State<_RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<_RequestsTab>
    with SingleTickerProviderStateMixin {
  final _client = Supabase.instance.client;
  late TabController _tabController;
  List<Map<String, dynamic>> _feedbacks = [];
  List<Map<String, dynamic>> _complaints = [];
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void didUpdateWidget(_RequestsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.adminId != widget.adminId) _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      var query = _client
          .from('requests')
          .select(
            '*, Students!fk_requests_student(first_name, last_name, email)',
          )
          .filter('teacher_id', 'is', null);

      if (widget.adminId != null) {
        query = query.eq('admin_id', widget.adminId!);
      }

      final all = await query.order('created_at', ascending: false);
      final list = List<Map<String, dynamic>>.from(all);

      if (!mounted) return;
      setState(() {
        _feedbacks = list.where((r) => r['type'] == 'feedback').toList();
        _complaints = list.where((r) => r['type'] == 'gomdol').toList();
        _requests = list.where((r) => r['type'] == 'request').toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Admin requests error: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(int id, String status) async {
    await _client.from('requests').update({'status': status}).eq('id', id);
    if (!mounted) return;
    _loadData();
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
              Tab(text: 'Хүсэлт (${_requests.length})'),
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
                    _requestList(_feedbacks, Colors.blue),
                    _requestList(_complaints, Colors.red),
                    _requestList(_requests, Colors.green),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _requestList(List<Map<String, dynamic>> items, Color accent) {
    if (items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.white24),
            SizedBox(height: 12),
            Text(
              'Хүсэлт байхгүй байна',
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final item = items[i];
          final status = item['status'] as String? ?? 'pending';
          final title = item['title'] as String? ?? '';
          final content = item['content'] as String? ?? '';
          final date = ((item['created_at'] as String?) ?? '')
              .substring(0, 10)
              .replaceAll('-', '.');
          final isAnon = item['is_anonymous'] == true;
          final st = item['Students'];
          final stName = isAnon
              ? 'Нэргүй'
              : (st != null
                    ? '${st['last_name'] ?? ''} ${st['first_name'] ?? ''}'
                          .trim()
                    : 'Суралцагч');
          final stEmail = isAnon ? null : st?['email'] as String?;

          Color statusColor;
          String statusLabel;
          switch (status) {
            case 'reviewing':
              statusColor = Colors.orange;
              statusLabel = 'Хянагдсан';
              break;
            case 'resolved':
              statusColor = Colors.green;
              statusLabel = 'Шийдвэрлэгдсэн';
              break;
            default:
              statusColor = Colors.white38;
              statusLabel = 'Хүлээгдэж байна';
          }

          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    RequestChatPage(request: item, senderRole: 'admin'),
              ),
            ),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: status == 'resolved'
                      ? Colors.green.withOpacity(0.3)
                      : accent.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            color: accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
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
                              stName,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (stEmail != null)
                              Text(
                                stEmail,
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4C6EF5).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF4C6EF5).withOpacity(0.4),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 12,
                              color: Color(0xFF4C6EF5),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Чатлах',
                              style: TextStyle(
                                color: Color(0xFF4C6EF5),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white60,
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
                      Icon(
                        status == 'resolved'
                            ? Icons.check_circle_outline
                            : status == 'reviewing'
                            ? Icons.hourglass_empty
                            : Icons.circle_outlined,
                        size: 14,
                        color: statusColor,
                      ),
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
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'reviewing',
                                child: Text(
                                  'Хянагдсан',
                                  style: TextStyle(
                                    color: Colors.orange,
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
                            onChanged: (val) {
                              if (val != null && val != status) {
                                _updateStatus(item['id'], val);
                              }
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

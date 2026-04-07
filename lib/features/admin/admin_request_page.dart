import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../teachers/request_chat_page.dart';

class AdminRequestsPage extends StatefulWidget {
  const AdminRequestsPage({super.key});

  @override
  State<AdminRequestsPage> createState() => _AdminRequestsPageState();
}

class _AdminRequestsPageState extends State<AdminRequestsPage>
    with SingleTickerProviderStateMixin {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;
  String _filterType = 'all';
  String _filterStatus = 'all';
  String _searchQuery = '';
  late TabController _tabController;

  final _statusTabs = [
    {'value': 'all', 'label': 'Бүгд'},
    {'value': 'pending', 'label': 'Хүлээгдэж буй'},
    {'value': 'in_progress', 'label': 'Шийдвэрлэж буй'},
    {'value': 'resolved', 'label': 'Шийдвэрлэсэн'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statusTabs.length, vsync: this);
    _tabController.addListener(() {
      setState(
        () => _filterStatus = _statusTabs[_tabController.index]['value']!,
      );
    });
    _loadRequests();
    _subscribeToRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _client.removeAllChannels();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    try {
      final data = await _client
          .from('requests')
          .select('*, users:sender_id(name, role)')
          .order('created_at', ascending: false);
      setState(() {
        _requests = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _subscribeToRequests() {
    _client
        .channel('admin_requests')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'requests',
          callback: (_) => _loadRequests(),
        )
        .subscribe();
  }

  List<Map<String, dynamic>> get _filteredRequests {
    return _requests.where((r) {
      if (_filterStatus != 'all' && r['status'] != _filterStatus) return false;
      if (_filterType != 'all' && r['type'] != _filterType) return false;
      if (_searchQuery.isNotEmpty) {
        final title = (r['title'] ?? '').toString().toLowerCase();
        final content = (r['content'] ?? '').toString().toLowerCase();
        final q = _searchQuery.toLowerCase();
        if (!title.contains(q) && !content.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'feedback':
        return 'Санал';
      case 'gomdol':
        return 'Гомдол';
      case 'request':
        return 'Хүсэлт';
      case 'medeelel':
        return 'Мэдээлэл';
      case 'busad':
        return 'Бусад';
      default:
        return type;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'feedback':
        return Colors.amber;
      case 'gomdol':
        return Colors.redAccent;
      case 'request':
        return Colors.green;
      case 'medeelel':
        return Colors.blue;
      case 'busad':
        return Colors.purple;
      default:
        return Colors.white38;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'feedback':
        return Icons.lightbulb_outline;
      case 'gomdol':
        return Icons.report_outlined;
      case 'request':
        return Icons.inbox_outlined;
      case 'medeelel':
        return Icons.info_outline;
      case 'busad':
        return Icons.more_horiz;
      default:
        return Icons.message_outlined;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Хүлээгдэж буй';
      case 'in_progress':
        return 'Шийдвэрлэж буй';
      case 'resolved':
        return 'Шийдвэрлэсэн';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      default:
        return Colors.white38;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.schedule;
      case 'in_progress':
        return Icons.autorenew;
      case 'resolved':
        return Icons.check_circle_outline;
      default:
        return Icons.help_outline;
    }
  }

  String _timeAgo(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Дөнгөж сая';
      if (diff.inMinutes < 60) return '${diff.inMinutes} мин';
      if (diff.inHours < 24) return '${diff.inHours} цаг';
      if (diff.inDays < 7) return '${diff.inDays} өдөр';
      return '${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  int _countByStatus(String status) {
    if (status == 'all') return _requests.length;
    return _requests.where((r) => r['status'] == status).length;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRequests;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1C3F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1C3F),
        elevation: 0,
        title: const Text(
          'Санал / Хүсэлт',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          // Төрлөөр шүүх
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list, color: Colors.white70),
            color: const Color(0xFF1E2340),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (v) => setState(() => _filterType = v),
            itemBuilder: (_) => [
              _filterItem('all', 'Бүх төрөл', Icons.all_inclusive),
              _filterItem('feedback', 'Санал', Icons.lightbulb_outline),
              _filterItem('request', 'Хүсэлт', Icons.inbox_outlined),
              _filterItem('gomdol', 'Гомдол', Icons.report_outlined),
              _filterItem('medeelel', 'Мэдээлэл', Icons.info_outline),
              _filterItem('busad', 'Бусад', Icons.more_horiz),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              // Хайлт
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Хайх...',
                    hintStyle: const TextStyle(
                      color: Colors.white24,
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Colors.white30,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.06),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Статус tab
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: const Color(0xFF4C6EF5),
                unselectedLabelColor: Colors.white38,
                indicatorColor: const Color(0xFF4C6EF5),
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(fontSize: 12),
                tabs: _statusTabs.map((t) {
                  final count = _countByStatus(t['value']!);
                  return Tab(text: '${t['label']} ($count)');
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4C6EF5)),
            )
          : filtered.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 56,
                    color: Colors.white.withOpacity(0.1),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Хүсэлт олдсонгүй',
                    style: TextStyle(color: Colors.white30, fontSize: 14),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadRequests,
              color: const Color(0xFF4C6EF5),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                itemCount: filtered.length,
                itemBuilder: (_, i) => _RequestCard(
                  request: filtered[i],
                  typeLabel: _typeLabel,
                  typeColor: _typeColor,
                  typeIcon: _typeIcon,
                  statusLabel: _statusLabel,
                  statusColor: _statusColor,
                  statusIcon: _statusIcon,
                  timeAgo: _timeAgo,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RequestChatPage(
                          request: filtered[i],
                          senderRole: 'admin',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
    );
  }

  PopupMenuItem<String> _filterItem(String value, String label, IconData icon) {
    final selected = _filterType == value;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            color: selected ? const Color(0xFF4C6EF5) : Colors.white54,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: selected ? const Color(0xFF4C6EF5) : Colors.white70,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Request Card ──
class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final String Function(String) typeLabel;
  final Color Function(String) typeColor;
  final IconData Function(String) typeIcon;
  final String Function(String) statusLabel;
  final Color Function(String) statusColor;
  final IconData Function(String) statusIcon;
  final String Function(String) timeAgo;
  final VoidCallback onTap;

  const _RequestCard({
    required this.request,
    required this.typeLabel,
    required this.typeColor,
    required this.typeIcon,
    required this.statusLabel,
    required this.statusColor,
    required this.statusIcon,
    required this.timeAgo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = request['title'] ?? '';
    final type = request['type'] ?? '';
    final content = request['content'] ?? '';
    final status = request['status'] ?? 'pending';
    final category = request['category'] ?? '';
    final createdAt = request['created_at'] ?? '';
    final hasFile =
        request['file_url'] != null &&
        (request['file_url'] as String).isNotEmpty;
    final senderData = request['users'] as Map<String, dynamic>?;
    final senderName = senderData?['name'] ?? 'Тодорхойгүй';

    final tColor = typeColor(type);
    final sColor = statusColor(status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: status == 'pending'
                ? Colors.orange.withOpacity(0.2)
                : Colors.white10,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Дээд хэсэг: төрөл, статус, цаг
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: tColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(typeIcon(type), color: tColor, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        typeLabel(type),
                        style: TextStyle(color: tColor, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (category.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      category,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: sColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon(status), color: sColor, size: 11),
                      const SizedBox(width: 3),
                      Text(
                        statusLabel(status),
                        style: TextStyle(color: sColor, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Гарчиг
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 4),

            // Агуулга
            Text(
              content,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 10),

            // Доод хэсэг: илгээгч, цаг, файл
            Row(
              children: [
                Icon(Icons.person_outline, color: Colors.white30, size: 14),
                const SizedBox(width: 4),
                Text(
                  senderName,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
                const Spacer(),
                if (hasFile) ...[
                  const Icon(
                    Icons.attach_file,
                    color: Colors.white24,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(Icons.access_time, color: Colors.white24, size: 12),
                const SizedBox(width: 3),
                Text(
                  timeAgo(createdAt),
                  style: const TextStyle(color: Colors.white30, fontSize: 10),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right,
                  color: Colors.white24,
                  size: 18,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

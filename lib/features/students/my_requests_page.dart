//sanali, gomidol, huseltiin jagsaalt page
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/auth_controller.dart';
import '../teachers/request_chat_page.dart';

class MyRequestsPage extends StatefulWidget {
  const MyRequestsPage({super.key});

  @override
  State<MyRequestsPage> createState() => _MyRequestsPageState();
}

class _MyRequestsPageState extends State<MyRequestsPage> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _allItems = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;
  String? _error;

  String _selectedType = 'all';
  String _selectedStatus = 'all';

  final _types = [
    {'value': 'all', 'label': 'Бүгд', 'icon': Icons.list_alt_rounded},
    {'value': 'feedback', 'label': 'Санал', 'icon': Icons.chat_bubble_outline},
    {'value': 'gomdol', 'label': 'Гомдол', 'icon': Icons.report_outlined},
    {'value': 'request', 'label': 'Хүсэлт', 'icon': Icons.add_box_outlined},
  ];

  final _statuses = [
    {'value': 'all', 'label': 'Бүгд'},
    {'value': 'pending', 'label': 'Хүлээгдэж байна'},
    {'value': 'reviewing', 'label': 'Хянагдсан'},
    {'value': 'resolved', 'label': 'Шийдвэрлэгдсэн'},
  ];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final userId = context.read<AuthController>().currentUser?['id'];
    int? studentId;
    try {
      final studentData = await _client
          .from('Students')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();
      studentId = studentData?['id'] as int?;
    } catch (_) {}

    if (studentId == null) {
      setState(() {
        _error = 'Суралцагчийн мэдээлэл олдсонгүй';
        _isLoading = false;
      });
      return;
    }
    try {
      final data = await _client
          .from('requests')
          .select(
            '*, Teachers!requests_teacher_id_fkey(first_name, last_name), admins!requests_admin_id_fkey(position, department, last_name, first_name, email), request_messages!request_messages_request_id_fkey(content, sender_role, created_at)',
          )
          .eq('student_id', studentId)
          .order('created_at', ascending: false);
      setState(() {
        _allItems = List<Map<String, dynamic>>.from(data);
        _applyFilter();
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      debugPrint('Request load error: $e');
      setState(() {
        _error = 'Мэдээлэл ачааллахад алдаа гарлаа';
        _isLoading = false;
      });
    }
  }

  void _applyFilter() {
    setState(() {
      _filtered = _allItems.where((item) {
        final typeMatch =
            _selectedType == 'all' || item['type'] == _selectedType;
        final statusMatch =
            _selectedStatus == 'all' || item['status'] == _selectedStatus;
        return typeMatch && statusMatch;
      }).toList();
    });
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'feedback':
        return const Color(0xFF4C6EF5);
      case 'gomdol':
        return const Color(0xFFE74C3C);
      case 'request':
        return const Color(0xFF2ECC71);
      default:
        return Colors.grey;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'feedback':
        return 'Санал';
      case 'gomdol':
        return 'Гомдол';
      case 'request':
        return 'Хүсэлт';
      default:
        return type;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFE8A020);
      case 'reviewing':
        return const Color(0xFF4C6EF5);
      case 'resolved':
        return const Color(0xFF2ECC71);
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Хүлээгдэж байна';
      case 'reviewing':
        return 'Хянагдсан';
      case 'resolved':
        return 'Шийдвэрлэгдсэн';
      default:
        return status;
    }
  }

  // created_at-г local цагт хөрвүүлэх
  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      return DateTime.parse(
        raw,
      ).toLocal().toString().substring(0, 10).replaceAll('-', '.');
    } catch (_) {
      return raw.length >= 10 ? raw.substring(0, 10).replaceAll('-', '.') : '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1C3F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1C3F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Миний хүсэлтүүд',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadItems();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Type filter
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _types.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final t = _types[i];
                final selected = _selectedType == t['value'];
                return GestureDetector(
                  onTap: () {
                    _selectedType = t['value'] as String;
                    _applyFilter();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : Colors.white24,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          t['icon'] as IconData,
                          size: 13,
                          color: selected
                              ? const Color(0xFF3B5BDB)
                              : Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          t['label'] as String,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: selected
                                ? const Color(0xFF3B5BDB)
                                : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // Status filter
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _statuses.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final s = _statuses[i];
                final selected = _selectedStatus == s['value'];
                return GestureDetector(
                  onTap: () {
                    _selectedStatus = s['value'] as String;
                    _applyFilter();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white.withOpacity(0.9)
                          : Colors.white12,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected ? Colors.transparent : Colors.white30,
                      ),
                    ),
                    child: Text(
                      s['label'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        color: selected
                            ? const Color(0xFF3B5BDB)
                            : Colors.white70,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF2F4F7),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.black38,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: const TextStyle(color: Colors.black45),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: _loadItems,
                            child: const Text('Дахин оролдох'),
                          ),
                        ],
                      ),
                    )
                  : _filtered.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            color: Colors.black26,
                            size: 56,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Мэдээлэл байхгүй байна',
                            style: TextStyle(color: Colors.black38),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadItems,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) {
                          final item = _filtered[index];
                          final type = item['type'] as String? ?? '';
                          final status = item['status'] as String? ?? 'pending';
                          final content = item['content'] as String? ?? '';
                          final title = item['title'] as String? ?? '';
                          // ── NULL-SAFE огноо ──
                          final date = _formatDate(
                            item['created_at'] as String?,
                          );
                          final isAnon = item['is_anonymous'] as bool? ?? false;

                          // Багшийн нэр
                          final teacherData = item['Teachers'];
                          final teacherName = teacherData != null
                              ? '${teacherData['last_name'] ?? ''} ${teacherData['first_name'] ?? ''}'
                                    .trim()
                              : null;
                          final hasTeacher = teacherData != null;

                          // Админ мэдээлэл
                          final adminData = item['admins'];
                          final adminPosition =
                              adminData?['position'] as String? ?? '';
                          final adminDept =
                              adminData?['department'] as String? ?? '';
                          final adminLastName =
                              adminData?['last_name'] as String? ?? '';
                          final adminFirstName =
                              adminData?['first_name'] as String? ?? '';
                          final adminPersonName =
                              (adminLastName.isNotEmpty ||
                                  adminFirstName.isNotEmpty)
                              ? '${adminLastName.isNotEmpty ? "$adminLastName." : ""} $adminFirstName'
                                    .trim()
                              : null;
                          final adminEmail =
                              adminData?['email'] as String? ?? '';
                          final hasAdmin =
                              adminData != null && adminPosition.isNotEmpty;

                          // ── NULL-SAFE сүүлийн хариу ──
                          final messages =
                              item['request_messages'] as List? ?? [];
                          final validMessages = messages
                              .whereType<Map>()
                              .where(
                                (m) =>
                                    m['created_at'] != null &&
                                    (m['created_at'] as String).isNotEmpty,
                              )
                              .toList();
                          validMessages.sort(
                            (a, b) => (a['created_at'] as String).compareTo(
                              b['created_at'] as String,
                            ),
                          );
                          final lastReply = validMessages.lastWhere(
                            (m) =>
                                m['sender_role'] == 'teacher' ||
                                m['sender_role'] == 'admin',
                            orElse: () => <String, dynamic>{},
                          );
                          final hasReply =
                              lastReply.isNotEmpty &&
                              lastReply['content'] != null;

                          return GestureDetector(
                            onTap: (hasTeacher || hasAdmin)
                                ? () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => RequestChatPage(
                                        request: item,
                                        senderRole: 'student',
                                      ),
                                    ),
                                  )
                                : null,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Дээд мөр
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _typeColor(
                                            type,
                                          ).withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          _typeLabel(type),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: _typeColor(type),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _statusColor(
                                            status,
                                          ).withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          _statusLabel(status),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: _statusColor(status),
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      if (isAnon)
                                        const Icon(
                                          Icons.visibility_off_outlined,
                                          size: 14,
                                          color: Colors.black26,
                                        ),
                                      const SizedBox(width: 4),
                                      Text(
                                        date,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.black38,
                                        ),
                                      ),
                                      if (hasTeacher || hasAdmin) ...[
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.chevron_right,
                                          size: 16,
                                          color: Colors.black26,
                                        ),
                                      ],
                                    ],
                                  ),

                                  // Гарчиг
                                  if (title.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF222222),
                                      ),
                                    ),
                                  ],

                                  // Агуулга
                                  const SizedBox(height: 6),
                                  Text(
                                    content,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black54,
                                      height: 1.4,
                                    ),
                                  ),

                                  // Сүүлийн хариу
                                  if (hasReply) ...[
                                    const SizedBox(height: 10),
                                    const Divider(
                                      height: 1,
                                      color: Color(0xFFEEEEEE),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.reply_rounded,
                                          size: 14,
                                          color: Color(0xFF4C6EF5),
                                        ),
                                        const SizedBox(width: 4),
                                        const Text(
                                          'Хариу:',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF4C6EF5),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            lastReply['content'] as String? ??
                                                '',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],

                                  // Админ мэдээлэл + чатлах
                                  if (hasAdmin) ...[
                                    const SizedBox(height: 10),
                                    const Divider(
                                      height: 1,
                                      color: Color(0xFFEEEEEE),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.business_outlined,
                                          size: 13,
                                          color: Colors.black38,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                adminPosition,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.black54,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              if (adminDept.isNotEmpty)
                                                Text(
                                                  adminDept,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.black38,
                                                  ),
                                                ),
                                              if (adminPersonName != null)
                                                Text(
                                                  adminPersonName,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.black38,
                                                  ),
                                                ),
                                              if (adminEmail.isNotEmpty)
                                                Text(
                                                  adminEmail,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.black38,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFF4C6EF5,
                                            ).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.chat_bubble_outline,
                                                size: 11,
                                                color: Color(0xFF4C6EF5),
                                              ),
                                              SizedBox(width: 3),
                                              Text(
                                                'Чатлах',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Color(0xFF4C6EF5),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],

                                  // Багшийн нэр + чатлах
                                  if (teacherName != null &&
                                      teacherName.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    const Divider(
                                      height: 1,
                                      color: Color(0xFFEEEEEE),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.person_outline,
                                          size: 13,
                                          color: Colors.black38,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            'Багш: $teacherName',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.black45,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFF4C6EF5,
                                            ).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.chat_bubble_outline,
                                                size: 11,
                                                color: Color(0xFF4C6EF5),
                                              ),
                                              SizedBox(width: 3),
                                              Text(
                                                'Чатлах',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Color(0xFF4C6EF5),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

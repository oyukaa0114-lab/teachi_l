import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/auth/auth_controller.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key, required int userId});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final userId = context.read<AuthController>().currentUser?['id'];
      if (userId == null) return;

      final data = await _client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      setState(() {
        _notifications = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAllRead() async {
    try {
      final userId = context.read<AuthController>().currentUser?['id'];
      if (userId == null) return;

      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);

      setState(() {
        for (var n in _notifications) {
          n['is_read'] = true;
        }
      });
    } catch (_) {}
  }

  Future<void> _deleteNotification(String id) async {
    try {
      await _client.from('notifications').delete().eq('id', id);
      setState(() => _notifications.removeWhere((n) => n['id'] == id));
    } catch (_) {}
  }

  IconData _notifIcon(String type) {
    switch (type) {
      case 'new_request':
        return Icons.inbox_outlined;
      case 'new_message':
        return Icons.chat_bubble_outline;
      case 'status_change':
        return Icons.sync;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _notifColor(String type) {
    switch (type) {
      case 'new_request':
        return Colors.amber;
      case 'new_message':
        return const Color(0xFF4C6EF5);
      case 'status_change':
        return Colors.green;
      default:
        return Colors.white54;
    }
  }

  String _timeAgo(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Дөнгөж сая';
      if (diff.inMinutes < 60) return '${diff.inMinutes} мин өмнө';
      if (diff.inHours < 24) return '${diff.inHours} цагийн өмнө';
      if (diff.inDays < 7) return '${diff.inDays} өдрийн өмнө';
      return '${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications
        .where((n) => n['is_read'] == false)
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1C3F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1C3F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Text(
              'Мэдэгдэл',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text(
                'Бүгдийг уншсан',
                style: TextStyle(color: Color(0xFF4C6EF5), fontSize: 12),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4C6EF5)),
            )
          : _notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 56,
                    color: Colors.white.withOpacity(0.1),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Мэдэгдэл байхгүй',
                    style: TextStyle(color: Colors.white30, fontSize: 14),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadNotifications,
              color: const Color(0xFF4C6EF5),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                itemCount: _notifications.length,
                itemBuilder: (_, i) {
                  final notif = _notifications[i];
                  final isRead = notif['is_read'] == true;
                  final type = notif['type'] ?? '';
                  final color = _notifColor(type);

                  return Dismissible(
                    key: Key(notif['id'].toString()),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) => _deleteNotification(notif['id']),
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                    ),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isRead
                            ? const Color(0xFF1A1A2E)
                            : const Color(0xFF4C6EF5).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isRead
                              ? Colors.white10
                              : const Color(0xFF4C6EF5).withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _notifIcon(type),
                              color: color,
                              size: 20,
                            ),
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
                                        notif['title'] ?? '',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: isRead
                                              ? FontWeight.normal
                                              : FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (!isRead)
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF4C6EF5),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  notif['body'] ?? '',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _timeAgo(notif['created_at'] ?? ''),
                                  style: const TextStyle(
                                    color: Colors.white24,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

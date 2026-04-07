import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../auth/auth_controller.dart';

class RequestChatPage extends StatefulWidget {
  final Map<String, dynamic> request;
  final String senderRole; // 'teacher', 'student', 'admin'

  const RequestChatPage({
    super.key,
    required this.request,
    required this.senderRole,
  });

  @override
  State<RequestChatPage> createState() => _RequestChatPageState();
}

class _RequestChatPageState extends State<RequestChatPage> {
  final _client = Supabase.instance.client;
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _subscribeToMessages();
    _markNotificationsRead();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _client.removeAllChannels();
    super.dispose();
  }

  // ── Мэдэгдлийг уншсан болгох ──
  Future<void> _markNotificationsRead() async {
    try {
      final userId = context.read<AuthController>().currentUser?['id'];
      if (userId == null) return;
      final requestId = widget.request['id'];
      if (requestId == null) return;
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('related_id', requestId)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('Mark notifications read error: $e');
    }
  }

  Future<void> _loadMessages() async {
    try {
      final data = await _client
          .from('request_messages')
          .select()
          .eq('request_id', widget.request['id'])
          .order('created_at', ascending: true);
      setState(() {
        _messages = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _subscribeToMessages() {
    _client
        .channel('request_${widget.request['id']}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'request_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'request_id',
            value: widget.request['id'],
          ),
          callback: (payload) {
            final newMsg = payload.newRecord;
            setState(() => _messages.add(newMsg));
            _scrollToBottom();
          },
        )
        .subscribe();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _isSending = true);
    _controller.clear();
    try {
      final userId = context.read<AuthController>().currentUser?['id'];
      await _client.from('request_messages').insert({
        'request_id': widget.request['id'],
        'sender_id': userId,
        'sender_role': widget.senderRole,
        'content': text,
      });

      // ── Мэдэгдэл илгээх (нөгөө талд) ──
      await _sendNotification(text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Алдаа: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    if (mounted) setState(() => _isSending = false);
  }

  Future<void> _sendNotification(String message) async {
    try {
      final requestData = widget.request;
      final senderId = context.read<AuthController>().currentUser?['id'];

      String? recipientId;
      String title;

      if (widget.senderRole == 'admin') {
        // Админ хариу бичвэл → request илгээсэн хүнд мэдэгдэл
        recipientId = requestData['sender_id'];
        title = 'Захиргаанаас хариу ирлээ';
      } else {
        // Багш/сурагч бичвэл → админ нарт мэдэгдэл
        final admins = await _client
            .from('users')
            .select('id')
            .eq('role', 'admin');
        for (final admin in admins) {
          await _client.from('notifications').insert({
            'user_id': admin['id'],
            'title': 'Шинэ хариу: ${requestData['title']}',
            'body': message.length > 100
                ? '${message.substring(0, 100)}...'
                : message,
            'type': 'new_message',
            'related_id': requestData['id'],
            'is_read': false,
          });
        }
        return;
      }

      if (recipientId != null && recipientId != senderId) {
        await _client.from('notifications').insert({
          'user_id': recipientId,
          'title': title,
          'body': message.length > 100
              ? '${message.substring(0, 100)}...'
              : message,
          'type': 'new_message',
          'reference_id': requestData['id'],
          'is_read': false,
        });
      }
    } catch (_) {}
  }

  Future<void> _openFile(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Файл нээхэд алдаа гарлаа'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── Статус солих (Админ) ──
  Future<void> _changeStatus(String newStatus) async {
    try {
      await _client
          .from('requests')
          .update({'status': newStatus})
          .eq('id', widget.request['id']);
      setState(() => widget.request['status'] = newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Статус: ${_statusLabel(newStatus)}'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Алдаа: $e'), backgroundColor: Colors.red),
        );
      }
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

  IconData _fileIcon(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.pdf')) return Icons.picture_as_pdf_outlined;
    if (lower.contains('.doc') || lower.contains('.docx'))
      return Icons.description_outlined;
    if (lower.contains('.jpg') ||
        lower.contains('.jpeg') ||
        lower.contains('.png'))
      return Icons.image_outlined;
    return Icons.insert_drive_file_outlined;
  }

  String _fileName(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      if (segments.isNotEmpty) {
        final parts = segments.last.split('.');
        if (parts.length >= 2) return 'Хавсаргасан файл.${parts.last}';
        return segments.last;
      }
    } catch (_) {}
    return 'Файл';
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inDays == 0) return 'Өнөөдөр';
      if (diff.inDays == 1) return 'Өчигдөр';
      return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.request['title'] ?? '';
    final type = widget.request['type'] ?? '';
    final content = widget.request['content'] ?? '';
    final category = widget.request['category'] ?? '';
    final status = widget.request['status'] ?? 'pending';
    final fileUrl = widget.request['file_url'] as String?;
    final typeColor = _typeColor(type);
    final isAdmin = widget.senderRole == 'admin';

    return Scaffold(
      backgroundColor: const Color(0xFF0F1C3F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1C3F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                _TypeBadge(label: _typeLabel(type), color: typeColor),
                if (category.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  _TypeBadge(label: category, color: Colors.white54),
                ],
                const SizedBox(width: 4),
                _StatusBadge(
                  label: _statusLabel(status),
                  color: _statusColor(status),
                  icon: _statusIcon(status),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (isAdmin)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              color: const Color(0xFF1E2340),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: _changeStatus,
              itemBuilder: (_) => [
                _statusMenuItem(
                  'pending',
                  'Хүлээгдэж буй',
                  Icons.schedule,
                  Colors.orange,
                ),
                _statusMenuItem(
                  'in_progress',
                  'Шийдвэрлэж буй',
                  Icons.autorenew,
                  Colors.blue,
                ),
                _statusMenuItem(
                  'resolved',
                  'Шийдвэрлэсэн',
                  Icons.check_circle_outline,
                  Colors.green,
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Анхны request агуулга ──
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_typeIcon(type), color: typeColor, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      '${_typeLabel(type)}ын агуулга',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    if (widget.request['created_at'] != null)
                      Text(
                        _formatDate(widget.request['created_at']),
                        style: const TextStyle(
                          color: Colors.white24,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  content,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                if (fileUrl != null && fileUrl.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white10, height: 1),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => _openFile(fileUrl),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4C6EF5).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF4C6EF5).withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _fileIcon(fileUrl),
                            color: const Color(0xFF4C6EF5),
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _fileName(fileUrl),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const Text(
                                  'Дарж нээх',
                                  style: TextStyle(
                                    color: Color(0xFF4C6EF5),
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.open_in_new,
                            color: Color(0xFF4C6EF5),
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 8),
          const Divider(color: Colors.white10, height: 1),

          // ── Чат мессежүүд ──
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF4C6EF5)),
                  )
                : _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_outlined,
                          size: 48,
                          color: Colors.white.withOpacity(0.1),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isAdmin ? 'Хариу бичих...' : 'Хариу хүлээж байна...',
                          style: const TextStyle(
                            color: Colors.white30,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final msg = _messages[i];
                      final isMe = msg['sender_role'] == widget.senderRole;
                      String time = '';
                      final rawTime = msg['created_at'] as String? ?? '';
                      if (rawTime.isNotEmpty) {
                        try {
                          final dt = DateTime.parse(rawTime).toLocal();
                          time =
                              '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                        } catch (_) {}
                      }

                      // Огноогоор бүлэглэх
                      bool showDate = false;
                      if (i == 0) {
                        showDate = true;
                      } else {
                        final prevTime =
                            _messages[i - 1]['created_at'] as String? ?? '';
                        if (prevTime.isNotEmpty && rawTime.isNotEmpty) {
                          final prevDt = DateTime.tryParse(prevTime)?.toLocal();
                          final curDt = DateTime.tryParse(rawTime)?.toLocal();
                          if (prevDt != null && curDt != null) {
                            showDate =
                                prevDt.day != curDt.day ||
                                prevDt.month != curDt.month ||
                                prevDt.year != curDt.year;
                          }
                        }
                      }

                      return Column(
                        children: [
                          if (showDate)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  _formatDate(rawTime),
                                  style: const TextStyle(
                                    color: Colors.white30,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
                          _MessageBubble(
                            content: msg['content'] ?? '',
                            isMe: isMe,
                            role: msg['sender_role'] ?? '',
                            time: time,
                          ),
                        ],
                      );
                    },
                  ),
          ),

          // ── Input хэсэг ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A2E),
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Хариу бичих...',
                        hintStyle: const TextStyle(
                          color: Colors.white24,
                          fontSize: 13,
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.06),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _isSending ? null : _send,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _isSending
                            ? Colors.white24
                            : const Color(0xFF4C6EF5),
                        shape: BoxShape.circle,
                      ),
                      child: _isSending
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _statusMenuItem(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ── Badges ──
class _TypeBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _TypeBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 9)),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _StatusBadge({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 10),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(color: color, fontSize: 9)),
        ],
      ),
    );
  }
}

// ── Message Bubble ──
class _MessageBubble extends StatelessWidget {
  final String content;
  final bool isMe;
  final String role;
  final String time;

  const _MessageBubble({
    required this.content,
    required this.isMe,
    required this.role,
    required this.time,
  });

  String _roleLabel(String role) {
    switch (role) {
      case 'teacher':
        return '👨‍🏫 Багш';
      case 'admin':
        return '🏫 Захиргаа';
      case 'student':
        return '🎓 Суралцагч';
      default:
        return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 3),
                child: Text(
                  _roleLabel(role),
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFF4C6EF5) : const Color(0xFF1E2340),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                border: isMe ? null : Border.all(color: Colors.white10),
              ),
              child: Text(
                content,
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.white70,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
              child: Text(
                time,
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

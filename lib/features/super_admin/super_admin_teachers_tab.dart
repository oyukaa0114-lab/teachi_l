// Super Admin - Багш нарын удирдлага (CRUD)
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SuperAdminTeachersTab extends StatefulWidget {
  const SuperAdminTeachersTab({super.key});

  @override
  State<SuperAdminTeachersTab> createState() => _SuperAdminTeachersTabState();
}

class _SuperAdminTeachersTabState extends State<SuperAdminTeachersTab> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _teachers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTeachers() async {
    setState(() => _isLoading = true);
    try {
      final data = await _client
          .from('Teachers')
          .select('*, Users(email, username)')
          .order('id');
      setState(() {
        _teachers = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Teachers load error: $e');
    }
  }

  List<Map<String, dynamic>> get _filteredTeachers {
    if (_searchQuery.isEmpty) return _teachers;
    final q = _searchQuery.toLowerCase();
    return _teachers.where((t) {
      final name = '${t['last_name'] ?? ''} ${t['first_name'] ?? ''}'
          .toLowerCase();
      final email = (t['Users']?['email'] as String? ?? '').toLowerCase();
      return name.contains(q) || email.contains(q);
    }).toList();
  }

  Future<void> _deleteTeacher(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2240),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Багш устгах', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Энэ багшийг устгахдаа итгэлтэй байна уу?',
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Үгүй',
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF87171),
            ),
            child: const Text('Устгах'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      // user_id авах
      final teacher = await _client
          .from('Teachers')
          .select('user_id')
          .eq('id', id)
          .single();
      final userId = teacher['user_id'];

      // Teachers-ээс устгах
      await _client.from('Teachers').delete().eq('id', id);

      // Users-ээс устгах
      if (userId != null) {
        await _client.from('Users').delete().eq('id', userId);
      }

      _loadTeachers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Алдаа: $e')));
      }
    }
  }

  void _showEditDialog(Map<String, dynamic>? teacher) {
    final isNew = teacher == null;
    final lastNameC = TextEditingController(text: teacher?['last_name'] ?? '');
    final firstNameC = TextEditingController(
      text: teacher?['first_name'] ?? '',
    );
    final rankC = TextEditingController(text: teacher?['rank'] ?? '');
    final schoolC = TextEditingController(text: teacher?['school'] ?? '');
    final facultyC = TextEditingController(text: teacher?['faculty'] ?? '');
    final departmentC = TextEditingController(
      text: teacher?['department'] ?? '',
    );
    // Шинэ багш нэмэхэд Users хүснэгтэд бас нэмнэ
    final usernameC = TextEditingController();
    final emailC = TextEditingController();
    final passwordC = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2240),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isNew ? 'Багш нэмэх' : 'Багш засах',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isNew) ...[
                  _buildField('Нэвтрэх нэр (username)', usernameC),
                  _buildField('Имэйл', emailC),
                  _buildField('Нууц үг', passwordC),
                  const Divider(color: Color(0xFF2A3555), height: 24),
                ],
                _buildField('Овог', lastNameC),
                _buildField('Нэр', firstNameC),
                _buildField('Зэрэг/Цол', rankC),
                _buildField('Салбар сургууль', schoolC),
                _buildField('Бүрэлдэхүүн', facultyC),
                _buildField('Тэнхим', departmentC),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Болих',
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final teacherData = {
                'last_name': lastNameC.text.trim(),
                'first_name': firstNameC.text.trim(),
                'rank': rankC.text.trim(),
                'school': schoolC.text.trim(),
                'faculty': facultyC.text.trim(),
                'department': departmentC.text.trim(),
              };
              try {
                if (isNew) {
                  // 1. Users хүснэгтэд нэмэх
                  final username = usernameC.text.trim();
                  final email = emailC.text.trim();
                  final password = passwordC.text.trim();

                  if (username.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Нэвтрэх нэр заавал бөглөнө'),
                      ),
                    );
                    return;
                  }

                  final userInsert = <String, dynamic>{
                    'username': username,
                    'role': 'teacher',
                  };
                  if (email.isNotEmpty) userInsert['email'] = email;
                  if (password.isNotEmpty) {
                    final hashed = sha256
                        .convert(utf8.encode(password))
                        .toString();
                    userInsert['password_hash'] = hashed;
                  }

                  final userResult = await _client
                      .from('Users')
                      .insert(userInsert)
                      .select()
                      .single();

                  // 2. Teachers хүснэгтэд user_id-тай нэмэх
                  teacherData['user_id'] = userResult['id'].toString();
                  await _client.from('Teachers').insert(teacherData);
                } else {
                  await _client
                      .from('Teachers')
                      .update(teacherData)
                      .eq('id', teacher!['id']);
                }
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) _loadTeachers();
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(
                    ctx,
                  ).showSnackBar(SnackBar(content: Text('Алдаа: $e')));
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5B8DEF),
            ),
            child: Text(isNew ? 'Нэмэх' : 'Хадгалах'),
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTeachers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Row(
            children: [
              const Text(
                'Багш нарын удирдлага',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              // Search
              SizedBox(
                width: 250,
                height: 40,
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Хайх...',
                    hintStyle: const TextStyle(color: Color(0xFF64748B)),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF64748B),
                      size: 18,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF12182B),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _showEditDialog(null),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Багш нэмэх'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5B8DEF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Table
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF5B8DEF)),
                )
              : filtered.isEmpty
              ? const Center(
                  child: Text(
                    'Багш олдсонгүй',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF12182B),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.04)),
                    ),
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        Colors.white.withOpacity(0.03),
                      ),
                      dataRowColor: WidgetStateProperty.all(Colors.transparent),
                      columnSpacing: 20,
                      columns: const [
                        DataColumn(label: _ColLabel('№')),
                        DataColumn(label: _ColLabel('Овог Нэр')),
                        DataColumn(label: _ColLabel('Зэрэг')),
                        DataColumn(label: _ColLabel('Имэйл')),
                        DataColumn(label: _ColLabel('Сургууль')),
                        DataColumn(label: _ColLabel('Тэнхим')),
                        DataColumn(label: _ColLabel('Үйлдэл')),
                      ],
                      rows: filtered.asMap().entries.map((entry) {
                        final index = entry.key;
                        final t = entry.value;
                        final lastName = t['last_name'] as String? ?? '';
                        final firstName = t['first_name'] as String? ?? '';
                        final name =
                            '${lastName.isNotEmpty ? '$lastName.' : ''} $firstName'
                                .trim();
                        final email = t['Users']?['email'] as String? ?? '-';

                        return DataRow(
                          cells: [
                            DataCell(
                              Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                t['rank'] ?? '-',
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                email,
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                t['school'] ?? '-',
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                t['department'] ?? '-',
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit_rounded,
                                      color: Color(0xFF5B8DEF),
                                      size: 18,
                                    ),
                                    onPressed: () => _showEditDialog(t),
                                    tooltip: 'Засах',
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_rounded,
                                      color: Color(0xFFF87171),
                                      size: 18,
                                    ),
                                    onPressed: () =>
                                        _deleteTeacher(t['id'] as int),
                                    tooltip: 'Устгах',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _ColLabel extends StatelessWidget {
  final String text;
  const _ColLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: Color(0xFF94A3B8),
      fontSize: 12,
      fontWeight: FontWeight.w600,
    ),
  );
}

// Super Admin - Админ хэрэглэгчдийн удирдлага
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SuperAdminAdminsTab extends StatefulWidget {
  const SuperAdminAdminsTab({super.key});

  @override
  State<SuperAdminAdminsTab> createState() => _SuperAdminAdminsTabState();
}

class _SuperAdminAdminsTabState extends State<SuperAdminAdminsTab> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _admins = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAdmins();
  }

  Future<void> _loadAdmins() async {
    setState(() => _isLoading = true);
    try {
      final data = await _client
          .from('admins')
          .select('*, Users(email)')
          .order('id');
      setState(() {
        _admins = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      // admins хүснэгт Users join байхгүй бол
      try {
        final data = await _client.from('admins').select().order('id');
        setState(() {
          _admins = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      } catch (e2) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteAdmin(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2240),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Админ устгах',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Энэ админыг устгахдаа итгэлтэй байна уу?\nUsers хүснэгтээс бас устгагдана.',
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
      final admin = await _client
          .from('admins')
          .select('user_id')
          .eq('id', id)
          .single();
      final userId = admin['user_id'];

      // admins-ээс устгах
      await _client.from('admins').delete().eq('id', id);

      // Users-ээс устгах
      if (userId != null) {
        await _client.from('Users').delete().eq('id', userId);
      }

      _loadAdmins();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Алдаа: $e')));
      }
    }
  }

  void _showEditDialog(Map<String, dynamic>? admin) {
    final isNew = admin == null;
    final lastNameC = TextEditingController(text: admin?['last_name'] ?? '');
    final firstNameC = TextEditingController(text: admin?['first_name'] ?? '');
    final positionC = TextEditingController(text: admin?['position'] ?? '');
    final schoolC = TextEditingController(text: admin?['school'] ?? '');
    final facultyC = TextEditingController(text: admin?['faculty'] ?? '');
    final departmentC = TextEditingController(text: admin?['department'] ?? '');
    // Шинэ админ нэмэхэд Users-д бас нэмнэ
    final usernameC = TextEditingController();
    final emailC = TextEditingController();
    final passwordC = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2240),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isNew ? 'Админ нэмэх' : 'Админ засах',
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
                _buildField('Албан тушаал', positionC),
                _buildField('Сургууль', schoolC),
                // _buildField('Бүрэлдэхүүн', facultyC),
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
              try {
                final adminData = {
                  'last_name': lastNameC.text.trim(),
                  'first_name': firstNameC.text.trim(),
                  'position': positionC.text.trim(),
                  'school': schoolC.text.trim(),
                  //'faculty': facultyC.text.trim(),
                  'department': departmentC.text.trim(),
                };
                if (isNew) {
                  final username = usernameC.text.trim();
                  final password = passwordC.text.trim();
                  final email = emailC.text.trim();

                  if (username.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Нэвтрэх нэр заавал бөглөнө'),
                      ),
                    );
                    return;
                  }

                  // 1. Users хүснэгтэд нэмэх
                  final userInsert = <String, dynamic>{
                    'username': username,
                    'role': 'admin',
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

                  // 2. admins хүснэгтэд user_id-тай нэмэх
                  adminData['user_id'] = userResult['id'].toString();
                  await _client.from('admins').insert(adminData);
                } else {
                  await _client
                      .from('admins')
                      .update(adminData)
                      .eq('id', admin!['id']);
                }
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) _loadAdmins();
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Row(
            children: [
              const Text(
                'Админ удирдлага',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showEditDialog(null),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Админ нэмэх'),
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
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF5B8DEF)),
                )
              : _admins.isEmpty
              ? const Center(
                  child: Text(
                    'Админ олдсонгүй',
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
                      columnSpacing: 24,
                      columns: const [
                        DataColumn(label: _ColLabel('№')),
                        DataColumn(label: _ColLabel('Овог Нэр')),
                        DataColumn(label: _ColLabel('Имэйл')),
                        DataColumn(label: _ColLabel('Албан тушаал')),
                        DataColumn(label: _ColLabel('Сургууль')),
                        DataColumn(label: _ColLabel('Тэнхим')),
                        //DataColumn(label: _ColLabel('Бүрэлдэхүүн')),
                        DataColumn(label: _ColLabel('Үйлдэл')),
                      ],
                      rows: _admins.asMap().entries.map((entry) {
                        final index = entry.key;
                        final a = entry.value;
                        final lastName = a['last_name'] as String? ?? '';
                        final firstName = a['first_name'] as String? ?? '';
                        final name =
                            '${lastName.isNotEmpty ? '$lastName.' : ''} $firstName'
                                .trim();
                        final email = a['Users']?['email'] as String? ?? '-';

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
                                name.isNotEmpty ? name : '-',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
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
                                a['position'] ?? '-',
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                a['school'] ?? '-',
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                a['department'] ?? '-',
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            // DataCell(
                            //   Text(
                            //     a['faculty'] ?? '-',
                            //     style: const TextStyle(
                            //       color: Color(0xFF94A3B8),
                            //       fontSize: 12,
                            //     ),
                            //   ),
                            // ),
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
                                    onPressed: () => _showEditDialog(a),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_rounded,
                                      color: Color(0xFFF87171),
                                      size: 18,
                                    ),
                                    onPressed: () =>
                                        _deleteAdmin(a['id'] as int),
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

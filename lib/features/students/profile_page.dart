//suragchiin profile page
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/auth/login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _client = Supabase.instance.client;
  Map<String, dynamic>? _studentData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  Future<void> _loadStudentData() async {
    final userId = context.read<AuthController>().currentUser?['id'];
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final data = await _client
          .from('Students')
          .select(
            'first_name, last_name, email, student_code, school, faculty, department, year_level',
          )
          .eq('user_id', userId)
          .single();
      setState(() {
        _studentData = data;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().currentUser;
    final username = user?['username'] ?? 'Хэрэглэгч';

    final firstName = _studentData?['first_name'] as String? ?? '';
    final lastName = _studentData?['last_name'] as String? ?? '';
    final email =
        _studentData?['email'] as String? ?? user?['email'] as String? ?? '';
    final studentCode = _studentData?['student_code'] as String? ?? '';
    final school = _studentData?['school'] as String? ?? '';
    final faculty = _studentData?['faculty'] as String? ?? '';
    final department = _studentData?['department'] as String? ?? '';
    final yearLevel = _studentData?['year_level'];
    final displayName = (lastName.isNotEmpty || firstName.isNotEmpty)
        ? '${lastName.isNotEmpty ? '$lastName.' : ''} $firstName'.trim()
        : username;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1C3F),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4C6EF5)),
            )
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _buildHeader(context, displayName, email, studentCode),
                ),
                SliverToBoxAdapter(
                  child: _buildInfoSection(
                    context,
                    firstName,
                    lastName,
                    email,
                    studentCode,
                    username,
                    school,
                    faculty,
                    department,
                    yearLevel,
                  ),
                ),
                SliverToBoxAdapter(child: _buildMenuSection(context)),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    String displayName,
    String email,
    String studentCode,
  ) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A3A6B), Color(0xFF0F1C3F)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios,
                      color: Colors.white70,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  const Text(
                    'Профайл',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(
                      Icons.settings_outlined,
                      color: Colors.white70,
                    ),
                    onPressed: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Avatar
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B5BDB), Color(0xFF4C6EF5)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3B5BDB).withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person,
                    size: 52,
                    color: Colors.white,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B5BDB),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF0F1C3F),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
            Text(
              displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            if (email.isNotEmpty)
              Text(
                email,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            if (studentCode.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  studentCode,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(
    BuildContext context,
    String firstName,
    String lastName,
    String email,
    String studentCode,
    String username,
    String school,
    String faculty,
    String department,
    dynamic yearLevel,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              'МИНИЙ МЭДЭЭЛЭЛ',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A2847),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            child: Column(
              children: [
                _buildInfoTile(
                  Icons.person_outline,
                  'Нэр',
                  (lastName.isNotEmpty || firstName.isNotEmpty)
                      ? '${lastName.isNotEmpty ? '$lastName.' : ''} $firstName'
                            .trim()
                      : username,
                ),
                if (studentCode.isNotEmpty) ...[
                  _divider(),
                  _buildInfoTile(
                    Icons.numbers_outlined,
                    'Оюутны код',
                    studentCode,
                  ),
                ],
                if (email.isNotEmpty) ...[
                  _divider(),
                  _buildInfoTile(Icons.email_outlined, 'Имэйл', email),
                ],
                if (school.isNotEmpty) ...[
                  _divider(),
                  _buildInfoTile(
                    Icons.school_outlined,
                    'Салбар Сургууль',
                    school,
                  ),
                ],
                if (faculty.isNotEmpty) ...[
                  _divider(),
                  _buildInfoTile(
                    Icons.account_tree_outlined,
                    'Тэнхим',
                    faculty,
                  ),
                ],
                if (department.isNotEmpty) ...[
                  _divider(),
                  _buildInfoTile(Icons.work_outline, 'Мэргэжил', department),
                ],
                if (yearLevel != null) ...[
                  _divider(),
                  _buildInfoTile(
                    Icons.calendar_today_outlined,
                    'Курс',
                    '$yearLevel-р курс',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF3B5BDB).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF4C6EF5), size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
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

  Widget _divider() =>
      Divider(height: 1, color: Colors.white.withOpacity(0.06), indent: 16);

  Widget _buildMenuSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              'ТОХИРГОО',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A2847),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            child: Column(
              children: [
                _buildMenuTile(
                  context,
                  Icons.notifications_outlined,
                  'Мэдэгдэл',
                  const Color(0xFF2ECC71),
                  () {},
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          GestureDetector(
            onTap: () {
              context.read<AuthController>().logout();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (_) => false,
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFE74C3C).withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFE74C3C).withOpacity(0.3),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout, color: Color(0xFFE74C3C), size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Гарах',
                    style: TextStyle(
                      color: Color(0xFFE74C3C),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          const Center(
            child: Text(
              'App Version 1.0.0',
              style: TextStyle(fontSize: 12, color: Colors.white24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: Colors.white24,
        size: 20,
      ),
    );
  }
}

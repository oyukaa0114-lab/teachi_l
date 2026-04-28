import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth/auth_controller.dart';
import '../auth/login_page.dart';

class AdminProfilePage extends StatelessWidget {
  final Map<String, dynamic>? adminData;
  const AdminProfilePage({super.key, this.adminData});

  @override
  Widget build(BuildContext context) {
    final firstName = adminData?['first_name'] as String? ?? '';
    final lastName = adminData?['last_name'] as String? ?? '';
    final position = adminData?['position'] as String? ?? '';
    final department = adminData?['department'] as String? ?? '';
    final adminCode = adminData?['admin_code'] as String? ?? '';
    final email = adminData?['email'] as String? ?? '';
    final school = adminData?['school'] as String? ?? '';
    final status = adminData?['status'] as String? ?? '';

    final fullName = (lastName.isNotEmpty || firstName.isNotEmpty)
        ? '$lastName $firstName'.trim()
        : 'Захиргааны ажилтан';
    final initials =
        ((lastName.isNotEmpty ? lastName[0] : '') +
                (firstName.isNotEmpty ? firstName[0] : ''))
            .toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFF0F1C3F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1C3F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Профайл',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 24),

            // ── Avatar ──────────────────────────────
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4C6EF5), Color(0xFF748FFC)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4C6EF5).withOpacity(0.45),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        initials.isNotEmpty ? initials : 'А',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  // Онлайн цэг
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF0F1C3F),
                          width: 2.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Нэр ──────────────────────────────────
            Text(
              fullName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),

            if (position.isNotEmpty)
              Text(
                position,
                style: const TextStyle(
                  color: Color(0xFF748FFC),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),

            const SizedBox(height: 10),

            // Статус badge
            if (status.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.withOpacity(0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      status,
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 32),

            // ── Мэдээлэл хэсэг ───────────────────────
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  _infoTile(
                    icon: Icons.badge_outlined,
                    label: 'Ажилтны код',
                    value: adminCode,
                    iconColor: const Color(0xFF4C6EF5),
                  ),
                  _divider(),
                  _infoTile(
                    icon: Icons.work_outline,
                    label: 'Албан тушаал',
                    value: position,
                    iconColor: const Color(0xFF748FFC),
                  ),
                  _divider(),
                  _infoTile(
                    icon: Icons.apartment_outlined,
                    label: 'Тэнхим / Алба',
                    value: department,
                    iconColor: Colors.teal,
                  ),
                  _divider(),
                  _infoTile(
                    icon: Icons.school_outlined,
                    label: 'Сургууль',
                    value: school,
                    iconColor: Colors.amber,
                  ),
                  _divider(),
                  _infoTile(
                    icon: Icons.email_outlined,
                    label: 'Имэйл',
                    value: email,
                    iconColor: Colors.orange,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Тусламж хэсэг ────────────────────────
            // Container(
            //   decoration: BoxDecoration(
            //     color: const Color(0xFF1A1A2E),
            //     borderRadius: BorderRadius.circular(16),
            //     border: Border.all(color: Colors.white12),
            //   ),
            //   child: Column(
            //     children: [
            //       _actionTile(
            //         icon: Icons.palette_outlined,
            //         label: 'Dark mode',
            //         onTap: () {},
            //       ),
            //       _divider(),
            //       _actionTile(
            //         icon: Icons.help_outline,
            //         label: 'Тусламж',
            //         onTap: () {},
            //       ),
            //     ],
            //   ),
            // ),

            // const SizedBox(height: 24),

            // ── Гарах товч ───────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: const Color(0xFF1A1A2E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: const Text(
                        'Гарах уу?',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      content: const Text(
                        'Системээс гарахдаа итгэлтэй байна уу?',
                        style: TextStyle(color: Colors.white54),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Болих',
                            style: TextStyle(color: Colors.white38),
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.withOpacity(0.15),
                            foregroundColor: Colors.red,
                            side: BorderSide(
                              color: Colors.red.withOpacity(0.3),
                            ),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            context.read<AuthController>().logout();
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginPage(),
                              ),
                              (_) => false,
                            );
                          },
                          child: const Text('Гарах'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.logout, size: 18),
                label: const Text(
                  'Системээс гарах',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.withOpacity(0.12),
                  foregroundColor: Colors.red,
                  side: BorderSide(color: Colors.red.withOpacity(0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
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
                const SizedBox(height: 3),
                Text(
                  value.isNotEmpty ? value : '—',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
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

  Widget _actionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: Colors.white54),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _divider() => const Divider(
    height: 1,
    color: Colors.white12,
    indent: 16,
    endIndent: 16,
  );
}

//sidebar
import 'package:flutter/material.dart';
import '../features/students/profile_page.dart';
import '../features/students/complaint_screen.dart';
import '../features/students/send_request_page.dart';

class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.onMenuTap,
    required this.onLogout,
    this.selectedIndex = 0,
  });

  final Function(int) onMenuTap;
  final VoidCallback onLogout;
  final int selectedIndex;

  static const _menuItems = [
    {'icon': Icons.assignment_outlined, 'label': 'Үнэлгээ'},
    {'icon': Icons.chat_bubble_outline, 'label': 'Санал'},
    {'icon': Icons.report_outlined, 'label': 'Гомдол'},
    {'icon': Icons.add_box_outlined, 'label': 'Хүсэлт'},
    {'icon': Icons.list_alt_outlined, 'label': 'Хүсэлтийн жагсаалт'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF0F1C3F),
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 32),

            // Profile section
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfilePage()),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: Colors.white24,
                    child: ClipOval(
                      // child: Image.network(
                      //   'https://i.pravatar.cc/150?img=47',
                      //   width: 88,
                      //   height: 88,
                      //   fit: BoxFit.cover,
                      //   errorBuilder: (_, __, ___) => const Icon(
                      //     Icons.person,
                      //     size: 40,
                      //     color: Colors.white,
                      //   ),
                      // ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Profile',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 36),

            // Menu items
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _menuItems.length,
                itemBuilder: (context, index) {
                  final item = _menuItems[index];
                  final isSelected = selectedIndex == index;
                  return GestureDetector(
                    onTap: () {
                      onMenuTap(index);
                      if (index == 2) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ComplaintPage(),
                          ),
                        );
                      }

                      if (index == 3) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SendRequestPage(),
                          ),
                        );
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withOpacity(0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item['icon'] as IconData,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              item['label'] as String,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Logout button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: GestureDetector(
                onTap: onLogout,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white30),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Logout',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

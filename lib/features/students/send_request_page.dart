// send_request_page.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/auth_controller.dart';

const _bg = Color(0xFF0A1628);
const _surface = Color(0xFF111D35);
const _card = Color(0xFF162040);
const _accent = Color(0xFF4C6EF5);
const _accentSoft = Color(0xFF3B5BDB);
const _border = Color(0xFF1E2D50);
const _textPrimary = Colors.white;
const _textSecondary = Color(0xFF8896B3);
const _textMuted = Color(0xFF4A5878);

class _Category {
  final String label;
  final String sublabel;
  final IconData icon;
  final Color color;
  const _Category({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.color,
  });
}

const _categories = [
  _Category(
    label: 'Академик',
    sublabel: 'Хичээл, багш, хуваарь',
    icon: Icons.school_rounded,
    color: Color(0xFF4C6EF5),
  ),
  _Category(
    label: 'Захиргааны',
    sublabel: 'Бичиг баримт, тодорхойлолт',
    icon: Icons.description_rounded,
    color: Color(0xFF20C997),
  ),
  _Category(
    label: 'Орчны',
    sublabel: 'Анги танхим, тоног төхөөрөмж',
    icon: Icons.meeting_room_rounded,
    color: Color(0xFFF59F00),
  ),
  _Category(
    label: 'Бусад',
    sublabel: 'Бусад хүсэлтүүд',
    icon: Icons.more_horiz_rounded,
    color: Color(0xFFAE3EC9),
  ),
];

class SendRequestPage extends StatefulWidget {
  const SendRequestPage({super.key});

  @override
  State<SendRequestPage> createState() => _SendRequestPageState();
}

class _SendRequestPageState extends State<SendRequestPage>
    with SingleTickerProviderStateMixin {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _client = Supabase.instance.client;

  bool _isLoading = false;
  _Category? _selectedCategory;
  Map<String, dynamic>? _selectedAdmin;
  PlatformFile? _pickedFile;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  // ── File helpers ──────────────────────────────────────────────────────────
  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
      withData: kIsWeb,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _pickedFile = result.files.first);
    }
  }

  void _removeFile() => setState(() => _pickedFile = null);

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _getContentType(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      default:
        return 'application/octet-stream';
    }
  }

  // ── Оюутны мэдээлэл авах ─────────────────────────────────────────────────
  // Students хүснэгт:
  //   school     → салбар сургууль  (admins.school-тай таарна)
  //   department → тэнхим           (admins.department-тай таарна)
  //   faculty    → мэргэжил         (ашиглахгүй)
  Future<Map<String, dynamic>> _getStudentInfo() async {
    final userId = context.read<AuthController>().currentUser?['id'];
    final data = await _client
        .from('Students')
        .select('id, school, department')
        .eq('user_id', userId)
        .maybeSingle();

    // .trim() — trailing space-ийн улмаас match болохгүй байх асуудлаас сэргийлнэ
    return {
      'student_id': data?['id'],
      'school': data?['school']?.toString().trim() ?? '',
      'department': data?['department']?.toString().trim() ?? '',
    };
  }

  // ── Admin шийдвэрлэх логик ────────────────────────────────────────────────
  //
  // АКАДЕМИК:
  //   1. Оюутны school + department-тай тохирох Тэнхимийн эрхлэгч
  //   2. Олдохгүй → ижил school-ийн аль нэг Тэнхимийн эрхлэгч
  //   3. Олдохгүй → ижил school-ийн Сургалтын алба
  //   4. Олдохгүй → аль ч Сургалтын алба (last resort)
  //
  // ЗАХИРГААНЫ / ОРЧНЫ / БУСАД:
  //   → Оюутны school-ийн Сургалтын алба
  //   → Олдохгүй → аль ч Сургалтын алба
  //   → БУСАД + нэмэлт admin сонгосон бол тэрийг ч нэмнэ
  //
  Future<List<int>> _resolveAdminIds(
    String studentSchool,
    String studentDepartment,
  ) async {
    final List<int> adminIds = [];

    if (_selectedCategory!.label == 'Академик') {
      // 1. Яг таарах Тэнхимийн эрхлэгч (school + department)
      if (studentSchool.isNotEmpty && studentDepartment.isNotEmpty) {
        final exact = await _client
            .from('admins')
            .select('id')
            .eq('position', 'Тэнхимийн эрхлэгч')
            .eq('school', studentSchool)
            .eq('department', studentDepartment)
            .eq('status', 'active')
            .not('user_id', 'is', null)
            .limit(1)
            .maybeSingle();
        if (exact != null) adminIds.add(exact['id'] as int);
      }

      // 2. Ижил school-ийн аль нэг Тэнхимийн эрхлэгч
      if (adminIds.isEmpty && studentSchool.isNotEmpty) {
        final bySchool = await _client
            .from('admins')
            .select('id')
            .eq('position', 'Тэнхимийн эрхлэгч')
            .eq('school', studentSchool)
            .eq('status', 'active')
            .not('user_id', 'is', null)
            .limit(1)
            .maybeSingle();
        if (bySchool != null) adminIds.add(bySchool['id'] as int);
      }

      // 3. Ижил school-ийн Сургалтын алба (fallback)
      if (adminIds.isEmpty && studentSchool.isNotEmpty) {
        final alba = await _client
            .from('admins')
            .select('id')
            .eq('position', 'Сургалтын алба')
            .eq('school', studentSchool)
            .eq('status', 'active')
            .not('user_id', 'is', null)
            .limit(1)
            .maybeSingle();
        if (alba != null) adminIds.add(alba['id'] as int);
      }

      // 4. Last resort — аль ч Сургалтын алба
      if (adminIds.isEmpty) {
        final any = await _client
            .from('admins')
            .select('id')
            .eq('position', 'Сургалтын алба')
            .eq('status', 'active')
            .not('user_id', 'is', null)
            .limit(1)
            .maybeSingle();
        if (any != null) adminIds.add(any['id'] as int);
      }
    } else {
      // ЗАХИРГААНЫ / ОРЧНЫ / БУСАД → Сургалтын алба
      if (studentSchool.isNotEmpty) {
        final alba = await _client
            .from('admins')
            .select('id')
            .eq('position', 'Сургалтын алба')
            .eq('school', studentSchool)
            .eq('status', 'active')
            .not('user_id', 'is', null)
            .limit(1)
            .maybeSingle();
        if (alba != null) adminIds.add(alba['id'] as int);
      }

      // School-аар олдохгүй бол — аль ч Сургалтын алба
      if (adminIds.isEmpty) {
        final any = await _client
            .from('admins')
            .select('id')
            .eq('position', 'Сургалтын алба')
            .eq('status', 'active')
            .not('user_id', 'is', null)
            .limit(1)
            .maybeSingle();
        if (any != null) adminIds.add(any['id'] as int);
      }

      // БУСАД: нэмэлт admin сонгосон бол нэмнэ
      if (_selectedCategory!.label == 'Бусад' && _selectedAdmin != null) {
        final selectedId = _selectedAdmin!['id'] as int;
        if (!adminIds.contains(selectedId)) adminIds.add(selectedId);
      }
    }

    return adminIds;
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (_selectedCategory == null) {
      _showSnack('Ангилал сонгоно уу', isError: true);
      return;
    }
    if (_titleController.text.trim().isEmpty) {
      _showSnack('Гарчиг бичнэ үү', isError: true);
      return;
    }
    if (_descController.text.trim().isEmpty) {
      _showSnack('Хүсэлтээ бичнэ үү', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? fileUrl;

      if (_pickedFile != null) {
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${_pickedFile!.name}';
        late Uint8List bytes;
        if (kIsWeb) {
          bytes = _pickedFile!.bytes!;
        } else {
          bytes = await File(_pickedFile!.path!).readAsBytes();
        }
        await _client.storage
            .from('request-files')
            .uploadBinary(
              fileName,
              bytes,
              fileOptions: FileOptions(
                contentType: _getContentType(_pickedFile!.extension ?? ''),
              ),
            );
        fileUrl = _client.storage.from('request-files').getPublicUrl(fileName);
      }

      // Оюутны мэдээлэл
      final studentInfo = await _getStudentInfo();
      final studentId = studentInfo['student_id'];
      final studentSchool = studentInfo['school'] as String;
      final studentDepartment = studentInfo['department'] as String;

      debugPrint('🎓 Student school: "$studentSchool"');
      debugPrint('🏛️ Student department: "$studentDepartment"');

      // Admin шийдвэрлэх
      final adminIds = await _resolveAdminIds(studentSchool, studentDepartment);

      debugPrint('👤 Resolved admin IDs: $adminIds');

      if (adminIds.isEmpty) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showSnack(
            'Хариуцсан admin олдсонгүй. Дараа дахин оролдоно уу.',
            isError: true,
          );
        }
        return;
      }

      // Тус тусд нь insert + мэдэгдэл
      for (final adminId in adminIds) {
        final inserted = await _client
            .from('requests')
            .insert({
              'student_id': studentId,
              'type': 'request',
              'category': _selectedCategory!.label,
              'title': _titleController.text.trim(),
              'content': _descController.text.trim(),
              'is_anonymous': false,
              'status': 'pending',
              'admin_id': adminId,
              if (fileUrl != null) 'file_url': fileUrl,
            })
            .select('id')
            .single();

        final adminData = await _client
            .from('admins')
            .select('user_id')
            .eq('id', adminId)
            .maybeSingle();

        if (adminData?['user_id'] != null) {
          await _client.from('notifications').insert({
            'user_id': adminData!['user_id'],
            'type': 'new_request',
            'title': 'Шинэ хүсэлт ирлээ',
            'body': _titleController.text.trim(),
            'related_id': inserted['id'],
            'is_read': false,
          });
        }
      }

      if (mounted) {
        setState(() {
          _titleController.clear();
          _descController.clear();
          _pickedFile = null;
          _selectedCategory = null;
          _selectedAdmin = null;
          _isLoading = false;
        });
        _showSnack('Хүсэлт амжилттай илгээгдлээ!');
      }
    } catch (e) {
      debugPrint('❌ Submit error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnack('Алдаа гарлаа: $e', isError: true);
      }
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(msg, style: const TextStyle(fontSize: 13))),
          ],
        ),
        backgroundColor: isError
            ? const Color(0xFFE03131)
            : const Color(0xFF2F9E44),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildSectionTitle('АНГИЛАЛ СОНГОХ'),
              const SizedBox(height: 12),
              _buildCategoryGrid(),
              const SizedBox(height: 24),

              if (_selectedCategory?.label == 'Бусад') ...[
                _buildSectionTitle('ХҮЛЭЭН АВАГЧ НЭМЭХ (ЗААВАЛ БИШ)'),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFAE3EC9).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFAE3EC9).withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: const Color(0xFFAE3EC9).withOpacity(0.8),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Хүсэлт таны салбар сургуулийн Сургалтын алба руу автоматаар явна. '
                          'Тэнхимийн эрхлэгч нэмэхийг хүсвэл доороос хайна уу.',
                          style: TextStyle(
                            color: _textSecondary,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                AdminSearchField(
                  onSelected: (a) => setState(() => _selectedAdmin = a),
                ),
                const SizedBox(height: 24),
              ],

              _buildSectionTitle('ГАРЧИГ'),
              const SizedBox(height: 10),
              _buildTextField(
                _titleController,
                'Хүсэлтийн гарчиг оруулна уу...',
              ),
              const SizedBox(height: 20),
              _buildSectionTitle('ХҮСЭЛТИЙН АГУУЛГА'),
              const SizedBox(height: 10),
              _buildTextField(
                _descController,
                'Хүсэлтээ дэлгэрэнгүй бичнэ үү...',
                maxLines: 6,
              ),
              const SizedBox(height: 20),
              _buildSectionTitle('ФАЙЛ ХАВСАРГАХ (ЗААВАЛ БИШ)'),
              const SizedBox(height: 10),
              _buildFileWidget(),
              const SizedBox(height: 28),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _bg,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: _textPrimary,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Хүсэлт илгээх',
        style: TextStyle(
          color: _textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _border),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_accent.withOpacity(0.15), _accentSoft.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accent.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.send_rounded, color: _accent, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Хүсэлт илгээх',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Таны хүсэлтийг бид хүлээн авч шийдвэрлэнэ',
                  style: TextStyle(color: _textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: _textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildCategoryGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.8,
      children: _categories.map((cat) {
        final selected = _selectedCategory == cat;
        return GestureDetector(
          onTap: () => setState(() {
            _selectedCategory = cat;
            _selectedAdmin = null;
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? cat.color.withOpacity(0.12) : _card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? cat.color : _border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: cat.color.withOpacity(selected ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    cat.icon,
                    color: selected ? cat.color : _textMuted,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        cat.label,
                        style: TextStyle(
                          color: selected ? _textPrimary : _textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        cat.sublabel,
                        style: const TextStyle(
                          color: _textMuted,
                          fontSize: 9.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: _textPrimary, fontSize: 14, height: 1.5),
      cursorColor: _accent,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _textMuted, fontSize: 13),
        filled: true,
        fillColor: _card,
        contentPadding: const EdgeInsets.all(14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _accent, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildFileWidget() {
    if (_pickedFile == null) {
      return GestureDetector(
        onTap: _pickFile,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.upload_file_rounded,
                  color: _textMuted,
                  size: 26,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Файл сонгох',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'PDF · DOC · DOCX · JPG · PNG',
                style: TextStyle(color: _textMuted, fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }

    final ext = (_pickedFile!.extension ?? '').toLowerCase();
    final isImage = ['jpg', 'jpeg', 'png'].contains(ext);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _accent.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isImage ? Icons.image_rounded : Icons.insert_drive_file_rounded,
              color: _accent,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _pickedFile!.name,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _formatFileSize(_pickedFile!.size),
                  style: const TextStyle(color: _textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _removeFile,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.close_rounded,
                color: _textSecondary,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: _accent,
          disabledBackgroundColor: _accent.withOpacity(0.5),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send_rounded, size: 18),
                  SizedBox(width: 10),
                  Text(
                    'Илгээх',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// AdminSearchField
// ═══════════════════════════════════════════════════════════════════════════════
class AdminSearchField extends StatefulWidget {
  final Function(Map<String, dynamic>? admin) onSelected;
  const AdminSearchField({super.key, required this.onSelected});

  @override
  State<AdminSearchField> createState() => _AdminSearchFieldState();
}

class _AdminSearchFieldState extends State<AdminSearchField> {
  final _controller = TextEditingController();
  final _client = Supabase.instance.client;
  final _focusNode = FocusNode();
  List<Map<String, dynamic>> _results = [];
  Map<String, dynamic>? _selected;
  bool _isSearching = false;
  bool _showResults = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().length < 2) {
      setState(() {
        _results = [];
        _showResults = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    try {
      final data = await _client
          .from('admins')
          .select(
            'id, first_name, last_name, email, position, department, school',
          )
          .eq('status', 'active')
          .not('user_id', 'is', null)
          .or(
            'first_name.ilike.%$query%,'
            'last_name.ilike.%$query%,'
            'email.ilike.%$query%',
          )
          .limit(8);

      setState(() {
        _results = List<Map<String, dynamic>>.from(data);
        _showResults = true;
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
    }
  }

  void _select(Map<String, dynamic> admin) {
    setState(() {
      _selected = admin;
      _showResults = false;
      final ln = admin['last_name'] ?? '';
      final fn = admin['first_name'] ?? '';
      _controller.text = '$ln $fn'.trim();
    });
    _focusNode.unfocus();
    widget.onSelected(admin);
  }

  void _clear() {
    setState(() {
      _selected = null;
      _results = [];
      _showResults = false;
    });
    _controller.clear();
    widget.onSelected(null);
  }

  String _fullName(Map<String, dynamic> a) {
    return '${a['last_name'] ?? ''} ${a['first_name'] ?? ''}'.trim();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          style: const TextStyle(color: _textPrimary, fontSize: 14),
          cursorColor: _accent,
          onChanged: (val) {
            if (_selected != null) {
              setState(() => _selected = null);
              widget.onSelected(null);
            }
            _search(val);
          },
          decoration: InputDecoration(
            hintText: 'Нэр эсвэл имэйлээр хайх...',
            hintStyle: const TextStyle(color: _textMuted, fontSize: 13),
            filled: true,
            fillColor: _card,
            prefixIcon: const Icon(
              Icons.manage_accounts_rounded,
              color: _textMuted,
              size: 20,
            ),
            suffixIcon: _isSearching
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: _textMuted,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : _controller.text.isNotEmpty
                ? GestureDetector(
                    onTap: _clear,
                    child: const Icon(
                      Icons.close_rounded,
                      color: _textMuted,
                      size: 18,
                    ),
                  )
                : null,
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFAE3EC9),
                width: 1.5,
              ),
            ),
          ),
        ),

        if (_selected != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFAE3EC9).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFAE3EC9).withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFAE3EC9).withOpacity(0.2),
                  child: const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: Color(0xFFAE3EC9),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _fullName(_selected!),
                        style: const TextStyle(
                          color: _textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_selected!['position'] != null)
                        Text(
                          _selected!['position'],
                          style: const TextStyle(
                            color: _textSecondary,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFFAE3EC9),
                  size: 20,
                ),
              ],
            ),
          ),
        ],

        if (_showResults) ...[
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _results.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          color: _textMuted,
                          size: 18,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Admin олдсонгүй',
                          style: TextStyle(color: _textMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Column(
                      children: _results.asMap().entries.map((entry) {
                        final i = entry.key;
                        final a = entry.value;
                        return GestureDetector(
                          onTap: () => _select(a),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: _surface,
                              border: i < _results.length - 1
                                  ? const Border(
                                      bottom: BorderSide(
                                        color: _border,
                                        width: 1,
                                      ),
                                    )
                                  : null,
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: const Color(
                                    0xFFAE3EC9,
                                  ).withOpacity(0.1),
                                  child: const Icon(
                                    Icons.admin_panel_settings_rounded,
                                    color: _textMuted,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _fullName(a),
                                        style: const TextStyle(
                                          color: _textPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      if (a['email'] != null)
                                        Text(
                                          a['email'],
                                          style: const TextStyle(
                                            color: _textMuted,
                                            fontSize: 11,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (a['position'] != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFFAE3EC9,
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      a['position'],
                                      style: const TextStyle(
                                        color: Color(0xFFAE3EC9),
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ],
    );
  }
}

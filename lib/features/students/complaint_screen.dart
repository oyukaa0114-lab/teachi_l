//oyutan gomdol ywuulah
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/auth_controller.dart';
import 'feedback_page.dart'; // AdminSelectField, TeacherSearchField

class ComplaintPage extends StatefulWidget {
  const ComplaintPage({super.key});

  @override
  State<ComplaintPage> createState() => _ComplaintPageState();
}

class _ComplaintPageState extends State<ComplaintPage> {
  final _complaintController = TextEditingController();
  final _titleController = TextEditingController();
  final _client = Supabase.instance.client;
  bool _isLoading = false;
  String? _selectedCategory;
  Map<String, dynamic>? _selectedTeacher;
  Map<String, dynamic>? _selectedAdmin;

  final List<String> _categories = ['Багш', 'Сургууль'];
  PlatformFile? _pickedFile;
  String? _studentSchool;
  String? _studentFaculty;
  String? _studentDepartment;
  int? _studentId;

  @override
  void initState() {
    super.initState();
    _loadStudentInfo();
  }

  Future<void> _loadStudentInfo() async {
    final userId = context.read<AuthController>().currentUser?['id'];
    if (userId == null) return;
    try {
      final data = await _client
          .from('Students')
          .select('id, school, faculty, department')
          .eq('user_id', userId)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _studentSchool = data?['school'] as String?;
          _studentFaculty = data?['faculty'] as String?;
          _studentDepartment = data?['department'] as String?;
          _studentId = data?['id'] as int?;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _complaintController.dispose();
    _titleController.dispose();
    super.dispose();
  }

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

  Future<void> _submit() async {
    if (_selectedCategory == null) {
      _showSnack('Ангилал сонгоно уу', isError: true);
      return;
    }
    if (_selectedCategory == 'Багш' && _selectedTeacher == null) {
      _showSnack('Багш сонгоно уу', isError: true);
      return;
    }
    if (_selectedCategory == 'Сургууль' && _selectedAdmin == null) {
      _showSnack('Алба/тэнхим сонгоно уу', isError: true);
      return;
    }
    if (_titleController.text.trim().isEmpty ||
        _complaintController.text.trim().isEmpty) {
      _showSnack('Бүх талбарыг бөглөнө үү', isError: true);
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
            .from('complaint-files')
            .uploadBinary(
              fileName,
              bytes,
              fileOptions: FileOptions(
                contentType: _getContentType(_pickedFile!.extension ?? ''),
              ),
            );
        fileUrl = _client.storage
            .from('complaint-files')
            .getPublicUrl(fileName);
      }

      // ── Гомдол insert ─────────────────────────────────────────────────
      final insertedComplaint = await _client
          .from('requests')
          .insert({
            'student_id': _studentId,
            'type': 'gomdol',
            'category': _selectedCategory,
            if (_selectedTeacher != null) 'teacher_id': _selectedTeacher!['id'],
            if (_selectedAdmin != null) 'admin_id': _selectedAdmin!['id'],
            'title': _titleController.text.trim(),
            'content': _complaintController.text.trim(),
            'is_anonymous': false,
            if (fileUrl != null) 'file_url': fileUrl,
          })
          .select('id')
          .single();

      // ── Багш-д мэдэгдэл явуулах ───────────────────────────────────────
      if (_selectedTeacher != null) {
        try {
          final teacherData = await _client
              .from('Teachers')
              .select('user_id')
              .eq('id', _selectedTeacher!['id'] as int)
              .maybeSingle();
          if (teacherData?['user_id'] != null) {
            await _client.from('notifications').insert({
              'user_id': teacherData!['user_id'],
              'type': 'new_request',
              'title': 'Шинэ гомдол ирлээ',
              'body': _titleController.text.trim(),
              'related_id': insertedComplaint['id'],
              'is_read': false,
            });
          }
        } catch (_) {}
      }

      // ── Admin-д мэдэгдэл явуулах ──────────────────────────────────────
      if (_selectedAdmin != null) {
        try {
          final adminData = await _client
              .from('admins')
              .select('user_id')
              .eq('id', _selectedAdmin!['id'] as int)
              .maybeSingle();
          if (adminData?['user_id'] != null) {
            await _client.from('notifications').insert({
              'user_id': adminData!['user_id'],
              'type': 'new_request',
              'title': 'Шинэ гомдол ирлээ',
              'body': _titleController.text.trim(),
              'related_id': insertedComplaint['id'],
              'is_read': false,
            });
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _titleController.clear();
          _complaintController.clear();
          _pickedFile = null;
          _selectedCategory = null;
          _selectedTeacher = null;
          _selectedAdmin = null;
          _isLoading = false;
        });
        _showSnack('Гомдол амжилттай илгээгдлээ!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnack('Алдаа гарлаа: $e', isError: true);
      }
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
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
          'Гомдол',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Гомдол илгээх',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Таны гомдлыг бид анхааралтай хянана',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 24),

              _label('Ангилал'),
              const SizedBox(height: 8),
              _dropdown(_categories, _selectedCategory, 'Ангилал сонгох', (
                val,
              ) {
                setState(() {
                  _selectedCategory = val;
                  _selectedTeacher = null;
                  _selectedAdmin = null;
                });
              }),
              const SizedBox(height: 16),

              if (_selectedCategory == 'Багш') ...[
                _label('Багш сонгох'),
                const SizedBox(height: 8),
                TeacherSearchField(
                  onSelected: (t) => setState(() => _selectedTeacher = t),
                ),
                const SizedBox(height: 16),
              ],

              if (_selectedCategory == 'Сургууль') ...[
                _label('Алба / Тэнхим сонгох'),
                const SizedBox(height: 8),
                AdminSelectField(
                  onSelected: (a) => setState(() => _selectedAdmin = a),
                  studentSchool: _studentSchool,
                  studentFaculty: _studentFaculty,
                  studentDepartment: _studentDepartment,
                ),
                const SizedBox(height: 16),
              ],

              _label('Гарчиг'),
              const SizedBox(height: 8),
              _textField(_titleController, 'Гомдлын гарчиг'),
              const SizedBox(height: 16),

              _label('Гомдол'),
              const SizedBox(height: 8),
              _textField(
                _complaintController,
                'Гомдлоо дэлгэрэнгүй бичнэ үү...',
                maxLines: 6,
              ),
              const SizedBox(height: 16),

              _label('Файл хавсаргах'),
              const SizedBox(height: 8),
              _fileWidget(),
              const SizedBox(height: 24),
              _submitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      color: Colors.white70,
      fontSize: 13,
      fontWeight: FontWeight.w500,
    ),
  );

  Widget _dropdown(
    List<String> items,
    String? value,
    String hint,
    ValueChanged<String?> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value != null ? const Color(0xFF4C6EF5) : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: const Color(0xFF1A1A2E),
          hint: Text(
            hint,
            style: const TextStyle(color: Colors.white30, fontSize: 13),
          ),
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white38),
          items: items
              .map(
                (c) => DropdownMenuItem(
                  value: c,
                  child: Text(c, style: const TextStyle(color: Colors.white)),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white30),
        filled: true,
        fillColor: Colors.white10,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.all(14),
      ),
    );
  }

  Widget _fileWidget() {
    if (_pickedFile == null) {
      return GestureDetector(
        onTap: _pickFile,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: const Column(
            children: [
              Icon(Icons.upload_file_outlined, color: Colors.white38, size: 32),
              SizedBox(height: 8),
              Text(
                'Файл сонгох',
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
              SizedBox(height: 4),
              Text(
                'PDF, DOC, JPG, PNG',
                style: TextStyle(color: Colors.white24, fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4C6EF5)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.insert_drive_file_outlined,
            color: Color(0xFF4C6EF5),
            size: 28,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _pickedFile!.name,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _formatFileSize(_pickedFile!.size),
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _removeFile,
            child: const Icon(Icons.close, color: Colors.white38, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _submitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _submit,
        icon: _isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.send, size: 18),
        label: Text(_isLoading ? 'Илгээж байна...' : 'Илгээх'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3B5BDB),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

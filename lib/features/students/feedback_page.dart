import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/auth_controller.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _feedbackController = TextEditingController();
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
    _feedbackController.dispose();
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
    if (_titleController.text.trim().isEmpty) {
      _showSnack('Гарчиг бичнэ үү', isError: true);
      return;
    }
    if (_feedbackController.text.trim().isEmpty) {
      _showSnack('Санал бичнэ үү', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      String? fileUrl;
      if (_pickedFile != null) {
        final ext = _pickedFile!.extension ?? 'file';
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
        late Uint8List bytes;
        if (kIsWeb) {
          bytes = _pickedFile!.bytes!;
        } else {
          bytes = await File(_pickedFile!.path!).readAsBytes();
        }
        await _client.storage
            .from('feedback-files')
            .uploadBinary(
              fileName,
              bytes,
              fileOptions: FileOptions(
                contentType: _getContentType(_pickedFile!.extension ?? ''),
              ),
            );
        fileUrl = _client.storage.from('feedback-files').getPublicUrl(fileName);
      }

      // ── Requests insert ───────────────────────────────────────────────
      final insertedFeedback = await _client
          .from('requests')
          .insert({
            'student_id': _studentId,
            'type': 'feedback',
            'category': _selectedCategory,
            if (_selectedTeacher != null) 'teacher_id': _selectedTeacher!['id'],
            if (_selectedAdmin != null) 'admin_id': _selectedAdmin!['id'],
            'title': _titleController.text.trim(),
            'content': _feedbackController.text.trim(),
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
              'title': 'Шинэ санал ирлээ',
              'body': _titleController.text.trim(),
              'related_id': insertedFeedback['id'],
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
              'title': 'Шинэ санал ирлээ',
              'body': _titleController.text.trim(),
              'related_id': insertedFeedback['id'],
              'is_read': false,
            });
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _feedbackController.clear();
          _titleController.clear();
          _pickedFile = null;
          _selectedCategory = null;
          _selectedTeacher = null;
          _selectedAdmin = null;
          _isLoading = false;
        });
        _showSnack('Санал амжилттай илгээгдлээ!');
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
          'Санал',
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
                'Санал илгээх',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Таны санал бодлыг бид үнэлдэг',
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
              _textField(_titleController, 'Саналын гарчиг'),
              const SizedBox(height: 16),

              _label('Санал'),
              const SizedBox(height: 8),
              _textField(
                _feedbackController,
                'Санал бодлоо энд бичнэ үү...',
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

// ═══════════════════════════════════════════════════════════════════════════════
// AdminSelectField — оюутаны school + faculty-аар шүүж харуулна
// ═══════════════════════════════════════════════════════════════════════════════
class AdminSelectField extends StatefulWidget {
  final Function(Map<String, dynamic>? admin) onSelected;
  final String? studentSchool;
  final String? studentFaculty;
  final String? studentDepartment;

  const AdminSelectField({
    super.key,
    required this.onSelected,
    this.studentSchool,
    this.studentFaculty,
    this.studentDepartment,
  });

  @override
  State<AdminSelectField> createState() => _AdminSelectFieldState();
}

class _AdminSelectFieldState extends State<AdminSelectField> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _admins = [];
  Map<String, dynamic>? _selected;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAdmins();
  }

  Future<void> _loadAdmins() async {
    try {
      var query = _client
          .from('admins')
          .select(
            'id, position, department, school, last_name, first_name, email',
          )
          .eq('status', 'active')
          .not('user_id', 'is', null);

      if (widget.studentSchool != null && widget.studentSchool!.isNotEmpty) {
        query = query.eq('school', widget.studentSchool!);
      }

      final data = await query.order('position');

      // department байхгүй → сургуулийн түвшний admin (Сургалтын алба г.м)
      // department байвал → оюутны department-тай таарах ёстой
      final filtered = (data as List).where((a) {
        final adminDept = a['department'] as String? ?? '';
        if (adminDept.isEmpty) return true;
        return adminDept == (widget.studentDepartment ?? '');
      }).toList();

      setState(() {
        _admins = List<Map<String, dynamic>>.from(filtered);
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  String _personName(Map<String, dynamic> a) {
    final last = a['last_name'] as String? ?? '';
    final first = a['first_name'] as String? ?? '';
    if (last.isEmpty && first.isEmpty) return '';
    return '${last.isNotEmpty ? "$last." : ""} $first'.trim();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF4C6EF5)),
      );
    }

    if (_selected != null) {
      final name = _personName(_selected!);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF4C6EF5).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF4C6EF5).withOpacity(0.4)),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF4C6EF5),
              child: Icon(Icons.business, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selected!['position'] ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if ((_selected!['department'] as String? ?? '').isNotEmpty)
                    Text(
                      _selected!['department'],
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  if (name.isNotEmpty)
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  if ((_selected!['email'] as String? ?? '').isNotEmpty)
                    Text(
                      _selected!['email'],
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () {
                setState(() => _selected = null);
                widget.onSelected(null);
              },
              child: const Icon(Icons.close, color: Colors.white38, size: 18),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF252540),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: _admins.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'Алба/тэнхим олдсонгүй',
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Column(
                children: _admins.asMap().entries.map((entry) {
                  final i = entry.key;
                  final a = entry.value;
                  final name = _personName(a);
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selected = a);
                      widget.onSelected(a);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: i < _admins.length - 1
                            ? const Border(
                                bottom: BorderSide(color: Colors.white12),
                              )
                            : null,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4C6EF5).withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.business,
                              color: Color(0xFF4C6EF5),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a['position'] ?? '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if ((a['department'] as String? ?? '')
                                    .isNotEmpty)
                                  Text(
                                    a['department'],
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 11,
                                    ),
                                  ),
                                if (name.isNotEmpty)
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: Colors.white24,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TeacherSearchField
// ═══════════════════════════════════════════════════════════════════════════════
class TeacherSearchField extends StatefulWidget {
  final Function(Map<String, dynamic>? teacher) onSelected;
  final String hint;

  const TeacherSearchField({
    super.key,
    required this.onSelected,
    this.hint = 'Нэр эсвэл имэйлээр хайх...',
  });

  @override
  State<TeacherSearchField> createState() => _TeacherSearchFieldState();
}

class _TeacherSearchFieldState extends State<TeacherSearchField> {
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

  String _formatName(String? last, String? first) {
    final l = last ?? '';
    final f = first ?? '';
    return '${l.isNotEmpty ? "$l." : ""} $f'.trim();
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
          .from('Teachers')
          .select('id, first_name, last_name, email, teacher_code')
          .or(
            'first_name.ilike.%$query%,last_name.ilike.%$query%,email.ilike.%$query%',
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

  void _selectTeacher(Map<String, dynamic> teacher) {
    final last = teacher['last_name'] as String? ?? '';
    final first = teacher['first_name'] as String? ?? '';
    setState(() {
      _selected = teacher;
      _showResults = false;
      _controller.text = _formatName(last, first);
    });
    _focusNode.unfocus();
    widget.onSelected(teacher);
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          onChanged: (val) {
            if (_selected != null) {
              setState(() => _selected = null);
              widget.onSelected(null);
            }
            _search(val);
          },
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
            filled: true,
            fillColor: Colors.white10,
            prefixIcon: const Icon(
              Icons.search,
              color: Colors.white38,
              size: 20,
            ),
            suffixIcon: _isSearching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white38,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : _controller.text.isNotEmpty
                ? GestureDetector(
                    onTap: _clear,
                    child: const Icon(
                      Icons.close,
                      color: Colors.white38,
                      size: 18,
                    ),
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF4C6EF5),
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),

        if (_selected != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF4C6EF5).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF4C6EF5).withOpacity(0.4),
              ),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(0xFF4C6EF5),
                  child: Icon(Icons.person, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatName(
                          _selected!['last_name'] as String?,
                          _selected!['first_name'] as String?,
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_selected!['email'] != null)
                        Text(
                          _selected!['email'],
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF4C6EF5),
                  size: 18,
                ),
              ],
            ),
          ),
        ],

        if (_showResults) ...[
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF252540),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: _results.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Icon(Icons.search_off, color: Colors.white38, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Багш олдсонгүй',
                          style: TextStyle(color: Colors.white38, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      children: _results.asMap().entries.map((entry) {
                        final i = entry.key;
                        final t = entry.value;
                        final name = _formatName(
                          t['last_name'] as String?,
                          t['first_name'] as String?,
                        );
                        return GestureDetector(
                          onTap: () => _selectTeacher(t),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              border: i < _results.length - 1
                                  ? const Border(
                                      bottom: BorderSide(color: Colors.white12),
                                    )
                                  : null,
                            ),
                            child: Row(
                              children: [
                                const CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Colors.white12,
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.white54,
                                    size: 14,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      if (t['email'] != null)
                                        Text(
                                          t['email'],
                                          style: const TextStyle(
                                            color: Colors.white38,
                                            fontSize: 11,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (t['teacher_code'] != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white10,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      t['teacher_code'],
                                      style: const TextStyle(
                                        color: Colors.white38,
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

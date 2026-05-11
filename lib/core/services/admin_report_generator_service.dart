// admin_report_generator_service.dart
// Admin-ын сургуулиар шүүсэн Excel тайлан үүсгэх сервис
// Байрлал: lib/core/services/admin_report_generator_service.dart
import 'dart:convert';
import 'dart:io' if (dart.library.html) 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// ignore: avoid_web_libraries_in_flutters
import 'package:universal_html/html.dart' as html;

import 'package:path_provider/path_provider.dart'
    if (dart.library.html) 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart'
    if (dart.library.html) 'package:open_file/open_file.dart';

class AdminReportGeneratorService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getEvaluationPeriods() async {
    try {
      final data = await _client
          .from('evaluation_periods')
          .select()
          .order('start_date', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Periods load error: $e');
      return [];
    }
  }

  Future<String?> generateReport({
    required int periodId,
    required String periodName,
    required String? school,
    required String? department,
    required bool isDepartmentHead,
    Function(String status)? onStatus,
  }) async {
    try {
      onStatus?.call('Мэдээлэл ачаалж байна...');

      // Admin-ын сургуулиар шүүгдсэн багш нар
      var teacherQuery = _client
          .from('Teachers')
          .select(
            'id, first_name, last_name, rank, department, school, teacher_code',
          );
      if (school != null && school.isNotEmpty) {
        teacherQuery = teacherQuery.eq('school', school);
      }
      if (isDepartmentHead && department != null && department.isNotEmpty) {
        teacherQuery = teacherQuery.eq('department', department);
      }

      final teachers = await teacherQuery.order('id');
      final teacherIds = (teachers as List).map((t) => t['id']).toList();

      List<dynamic> evaluations = [];
      if (teacherIds.isNotEmpty) {
        evaluations = await _client
            .from('evaluations')
            .select(
              '*, Students(first_name, last_name, student_code, department, faculty, year_level), Teachers(first_name, last_name)',
            )
            .eq('period_id', periodId)
            .inFilter('teacher_id', teacherIds)
            .order('created_at', ascending: false);
      }

      onStatus?.call('Excel файл үүсгэж байна...');

      final excel = Excel.createExcel();

      _buildSummarySheet(
        excel,
        evaluations,
        teachers,
        periodName,
        school,
        department,
        isDepartmentHead,
      );
      _buildTeacherSheet(excel, evaluations, teachers);
      _buildEvaluationsSheet(excel, evaluations);

      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      onStatus?.call('Файл хадгалж байна...');

      final bytes = excel.encode();
      if (bytes == null) return null;

      final sanitizedName = periodName
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(' ', '_');
      final fileName =
          'Admin_Taillan_${sanitizedName}_${DateTime.now().millisecondsSinceEpoch}.xlsx';

      if (kIsWeb) {
        _downloadForWeb(Uint8List.fromList(bytes), fileName);
        onStatus?.call('Амжилттай!');
        return fileName;
      } else {
        final path = await _saveForMobile(bytes, fileName);
        onStatus?.call('Амжилттай!');
        return path;
      }
    } catch (e) {
      debugPrint('Admin report generation error: $e');
      onStatus?.call('Алдаа гарлаа');
      return null;
    }
  }

  void _downloadForWeb(Uint8List bytes, String fileName) {
    final base64 = base64Encode(bytes);
    final anchor = html.AnchorElement()
      ..href =
          'data:application/vnd.openxmlformats-officedocument.spreadsheetml.sheet;base64,$base64'
      ..download = fileName
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
  }

  Future<String> _saveForMobile(List<int> bytes, String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(bytes);
    try {
      await OpenFile.open(filePath);
    } catch (e) {
      debugPrint('File open error: $e');
    }
    return filePath;
  }

  // ============================================================
  // Sheet 1: Ерөнхий мэдээлэл
  // ============================================================
  void _buildSummarySheet(
    Excel excel,
    List<dynamic> evaluations,
    List<dynamic> teachers,
    String periodName,
    String? school,
    String? department,
    bool isDepartmentHead,
  ) {
    final sheet = excel['Ерөнхий мэдээлэл'];

    final titleStyle = CellStyle(
      bold: true,
      fontSize: 16,
      fontFamily: getFontFamily(FontFamily.Arial),
    );
    final headerStyle = CellStyle(
      bold: true,
      fontSize: 11,
      backgroundColorHex: ExcelColor.fromHexString('#1A2847'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      fontFamily: getFontFamily(FontFamily.Arial),
    );
    final dataStyle = CellStyle(
      fontSize: 11,
      fontFamily: getFontFamily(FontFamily.Arial),
    );

    _setCell(sheet, 'A1', 'Үнэлгээний тайлан (Admin)', titleStyle);
    _setCell(sheet, 'A2', 'Үе: $periodName', dataStyle);
    if (school != null && school.isNotEmpty) {
      _setCell(sheet, 'A3', 'Сургууль: $school', dataStyle);
    }
    if (isDepartmentHead && department != null && department.isNotEmpty) {
      _setCell(sheet, 'A4', 'Тэнхим: $department', dataStyle);
    }
    _setCell(
      sheet,
      'A5',
      'Огноо: ${DateTime.now().toString().substring(0, 10)}',
      dataStyle,
    );

    _setCell(sheet, 'A7', 'Үзүүлэлт', headerStyle);
    _setCell(sheet, 'B7', 'Тоо', headerStyle);

    double avgRating = 0;
    if (evaluations.isNotEmpty) {
      final sum = evaluations.fold<double>(
        0,
        (s, e) => s + ((e['rating'] as num?)?.toDouble() ?? 0),
      );
      avgRating = sum / evaluations.length;
    }

    final dist = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    for (final e in evaluations) {
      final r = (e['rating'] as num?)?.toInt() ?? 0;
      if (r >= 1 && r <= 5) dist[r] = (dist[r] ?? 0) + 1;
    }

    final evaluated = teachers.where((t) {
      final tid = t['id'];
      return evaluations.any((e) => e['teacher_id'] == tid);
    }).length;

    final rows = [
      ['Нийт багш', '${teachers.length}'],
      ['Үнэлэгдсэн багш', '$evaluated'],
      ['Нийт үнэлгээ', '${evaluations.length}'],
      ['Дундаж үнэлгээ', avgRating == 0 ? '—' : avgRating.toStringAsFixed(2)],
      ['', ''],
      ['5 од', '${dist[5]}'],
      ['4 од', '${dist[4]}'],
      ['3 од', '${dist[3]}'],
      ['2 од', '${dist[2]}'],
      ['1 од', '${dist[1]}'],
    ];

    for (int i = 0; i < rows.length; i++) {
      _setCellRC(sheet, 7 + i, 0, rows[i][0], dataStyle);
      _setCellRC(sheet, 7 + i, 1, rows[i][1], dataStyle);
    }

    sheet.setColumnWidth(0, 25);
    sheet.setColumnWidth(1, 15);
  }

  // ============================================================
  // Sheet 2: Багш нарын үнэлгээ
  // ============================================================
  void _buildTeacherSheet(
    Excel excel,
    List<dynamic> evaluations,
    List<dynamic> teachers,
  ) {
    final sheet = excel['Багш нарын үнэлгээ'];

    final headerStyle = CellStyle(
      bold: true,
      fontSize: 11,
      backgroundColorHex: ExcelColor.fromHexString('#1A2847'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      fontFamily: getFontFamily(FontFamily.Arial),
    );
    final dataStyle = CellStyle(
      fontSize: 11,
      fontFamily: getFontFamily(FontFamily.Arial),
    );

    final headers = [
      '№',
      'Багшийн нэр',
      'Зэрэг',
      'Тэнхим',
      'Нийт',
      'Дундаж',
      '5★',
      '4★',
      '3★',
      '2★',
      '1★',
    ];
    for (int i = 0; i < headers.length; i++) {
      _setCellRC(sheet, 0, i, headers[i], headerStyle);
    }

    final stats = <int, Map<String, dynamic>>{};
    for (final t in teachers) {
      final tid = t['id'] as int;
      stats[tid] = {
        'name': '${t['last_name'] ?? ''}. ${t['first_name'] ?? ''}'.trim(),
        'rank': t['rank']?.toString() ?? '',
        'dept': t['department']?.toString() ?? '',
        'count': 0,
        'sum': 0.0,
        'dist': {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
      };
    }

    for (final e in evaluations) {
      final tid = e['teacher_id'] as int?;
      if (tid == null || !stats.containsKey(tid)) continue;
      final r = (e['rating'] as num?)?.toInt() ?? 0;
      stats[tid]!['count'] = (stats[tid]!['count'] as int) + 1;
      stats[tid]!['sum'] = (stats[tid]!['sum'] as double) + r;
      if (r >= 1 && r <= 5) {
        (stats[tid]!['dist'] as Map<int, int>)[r] =
            ((stats[tid]!['dist'] as Map<int, int>)[r] ?? 0) + 1;
      }
    }

    final sorted = stats.entries.toList()
      ..sort((a, b) {
        final avgA = a.value['count'] > 0
            ? (a.value['sum'] as double) / (a.value['count'] as int)
            : 0.0;
        final avgB = b.value['count'] > 0
            ? (b.value['sum'] as double) / (b.value['count'] as int)
            : 0.0;
        return avgB.compareTo(avgA);
      });

    for (int i = 0; i < sorted.length; i++) {
      final s = sorted[i].value;
      final count = s['count'] as int;
      final avg = count > 0 ? ((s['sum'] as double) / count) : 0.0;
      final d = s['dist'] as Map<int, int>;

      final row = [
        '${i + 1}',
        s['name'].toString(),
        s['rank'].toString(),
        s['dept'].toString(),
        '$count',
        count > 0 ? avg.toStringAsFixed(2) : '—',
        '${d[5]}',
        '${d[4]}',
        '${d[3]}',
        '${d[2]}',
        '${d[1]}',
      ];
      for (int j = 0; j < row.length; j++) {
        _setCellRC(sheet, i + 1, j, row[j], dataStyle);
      }
    }

    sheet.setColumnWidth(0, 5);
    sheet.setColumnWidth(1, 25);
    sheet.setColumnWidth(2, 20);
    sheet.setColumnWidth(3, 20);
    for (int i = 4; i < 11; i++) {
      sheet.setColumnWidth(i, 10);
    }
  }

  // ============================================================
  // Sheet 3: Үнэлгээний жагсаалт
  // ============================================================
  void _buildEvaluationsSheet(Excel excel, List<dynamic> evaluations) {
    final sheet = excel['Үнэлгээний жагсаалт'];

    final headerStyle = CellStyle(
      bold: true,
      fontSize: 11,
      backgroundColorHex: ExcelColor.fromHexString('#1A2847'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      fontFamily: getFontFamily(FontFamily.Arial),
    );
    final dataStyle = CellStyle(
      fontSize: 11,
      fontFamily: getFontFamily(FontFamily.Arial),
    );

    final headers = [
      '№',
      'Багш',
      'Оюутан',
      'Оноо',
      'Сэтгэгдэл',
      'Нэргүй',
      'Огноо',
    ];
    for (int i = 0; i < headers.length; i++) {
      _setCellRC(sheet, 0, i, headers[i], headerStyle);
    }

    for (int i = 0; i < evaluations.length; i++) {
      final e = evaluations[i];

      final t = e['Teachers'];
      final teacherName = t != null
          ? '${t['last_name'] ?? ''}. ${t['first_name'] ?? ''}'.trim()
          : 'Багш #${e['teacher_id']}';

      final s = e['Students'];
      final isAnon = e['is_anonymous'] == true;
      final studentName = isAnon
          ? 'Нэргүй'
          : (s != null
                ? '${s['last_name'] ?? ''}. ${s['first_name'] ?? ''}'.trim()
                : 'Оюутан #${e['student_id']}');

      final rating = (e['rating'] as num?)?.toString() ?? '';
      final comment = e['comment'] as String? ?? '';
      final rawDate = e['created_at'] as String? ?? '';
      final date = rawDate.length >= 10 ? rawDate.substring(0, 10) : '';

      final row = [
        '${i + 1}',
        teacherName,
        studentName,
        rating,
        comment,
        isAnon ? 'Тийм' : 'Үгүй',
        date,
      ];
      for (int j = 0; j < row.length; j++) {
        _setCellRC(sheet, i + 1, j, row[j], dataStyle);
      }
    }

    sheet.setColumnWidth(0, 5);
    sheet.setColumnWidth(1, 25);
    sheet.setColumnWidth(2, 25);
    sheet.setColumnWidth(3, 8);
    sheet.setColumnWidth(4, 50);
    sheet.setColumnWidth(5, 10);
    sheet.setColumnWidth(6, 14);
  }

  void _setCell(Sheet sheet, String cellRef, String value, CellStyle style) {
    sheet.cell(CellIndex.indexByString(cellRef)).value = TextCellValue(value);
    sheet.cell(CellIndex.indexByString(cellRef)).cellStyle = style;
  }

  void _setCellRC(
    Sheet sheet,
    int row,
    int col,
    String value,
    CellStyle style,
  ) {
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
        .value = TextCellValue(
      value,
    );
    sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
            .cellStyle =
        style;
  }
}

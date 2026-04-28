// import 'dart:io';
// import 'package:excel/excel.dart';
// import 'package:open_file/open_file.dart';
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';

// class EvaluationExcelExporter {
//   /// Үнэлгээнүүдийг Excel файл болгож хадгалаад нээнэ
//   static Future<void> exportToExcel({
//     required BuildContext context,
//     required List<Map<String, dynamic>> evaluations,
//     required String teacherName,
//     required double avgRating,
//   }) async {
//     try {
//       final excel = Excel.createExcel();

//       // ── Sheet 1: Дүгнэлт (Summary) ──
//       final summarySheet = excel['Дүгнэлт'];
//       excel.setDefaultSheet('Дүгнэлт');

//       // Header styling
//       final headerStyle = CellStyle(
//         bold: true,
//         fontSize: 14,
//         fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
//         backgroundColorHex: ExcelColor.fromHexString('#1A3060'),
//         horizontalAlign: HorizontalAlign.Center,
//       );

//       final labelStyle = CellStyle(
//         bold: true,
//         fontSize: 11,
//         fontColorHex: ExcelColor.fromHexString('#1E293B'),
//         backgroundColorHex: ExcelColor.fromHexString('#F1F5F9'),
//       );

//       final valueStyle = CellStyle(
//         fontSize: 11,
//         fontColorHex: ExcelColor.fromHexString('#334155'),
//       );

//       // Title
//       summarySheet.merge(
//         CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
//         CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 0),
//       );
//       final titleCell = summarySheet.cell(
//         CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
//       );
//       titleCell.value = TextCellValue('Багшийн үнэлгээний тайлан');
//       titleCell.cellStyle = CellStyle(
//         bold: true,
//         fontSize: 16,
//         fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
//         backgroundColorHex: ExcelColor.fromHexString('#0F1E3D'),
//         horizontalAlign: HorizontalAlign.Center,
//       );

//       // Blank row
//       // Row 2: Багшийн нэр
//       _addLabelValueRow(
//         summarySheet,
//         2,
//         'Багшийн нэр:',
//         teacherName,
//         labelStyle,
//         valueStyle,
//       );

//       // Row 3: Огноо
//       _addLabelValueRow(
//         summarySheet,
//         3,
//         'Тайлан гаргасан огноо:',
//         DateFormat('yyyy.MM.dd HH:mm').format(DateTime.now()),
//         labelStyle,
//         valueStyle,
//       );

//       // Row 4: Нийт үнэлгээ
//       _addLabelValueRow(
//         summarySheet,
//         4,
//         'Нийт үнэлгээний тоо:',
//         '${evaluations.length}',
//         labelStyle,
//         valueStyle,
//       );

//       // Row 5: Дундаж
//       _addLabelValueRow(
//         summarySheet,
//         5,
//         'Дундаж үнэлгээ:',
//         avgRating.toStringAsFixed(1),
//         labelStyle,
//         valueStyle,
//       );

//       // Row 6: Хамгийн өндөр
//       if (evaluations.isNotEmpty) {
//         final maxRating = evaluations
//             .map((e) => (e['rating'] as num?)?.toInt() ?? 0)
//             .reduce((a, b) => a > b ? a : b);
//         final minRating = evaluations
//             .map((e) => (e['rating'] as num?)?.toInt() ?? 0)
//             .reduce((a, b) => a < b ? a : b);
//         _addLabelValueRow(
//           summarySheet,
//           6,
//           'Хамгийн өндөр үнэлгээ:',
//           '$maxRating',
//           labelStyle,
//           valueStyle,
//         );
//         _addLabelValueRow(
//           summarySheet,
//           7,
//           'Хамгийн бага үнэлгээ:',
//           '$minRating',
//           labelStyle,
//           valueStyle,
//         );
//       }

//       // Row 9: Тархалт header
//       final distHeaderStyle = CellStyle(
//         bold: true,
//         fontSize: 11,
//         fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
//         backgroundColorHex: ExcelColor.fromHexString('#EAB308'),
//         horizontalAlign: HorizontalAlign.Center,
//       );

//       summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 9))
//         ..value = TextCellValue('Од')
//         ..cellStyle = distHeaderStyle;
//       summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 9))
//         ..value = TextCellValue('Тоо')
//         ..cellStyle = distHeaderStyle;
//       summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 9))
//         ..value = TextCellValue('Хувь')
//         ..cellStyle = distHeaderStyle;

//       for (int star = 5; star >= 1; star--) {
//         final count = evaluations
//             .where((e) => ((e['rating'] as num?)?.toInt() ?? 0) == star)
//             .length;
//         final pct = evaluations.isEmpty
//             ? 0.0
//             : (count / evaluations.length * 100);
//         final row = 10 + (5 - star);

//         summarySheet.cell(
//             CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
//           )
//           ..value = TextCellValue('$star ★')
//           ..cellStyle = valueStyle;
//         summarySheet.cell(
//             CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row),
//           )
//           ..value = IntCellValue(count)
//           ..cellStyle = valueStyle;
//         summarySheet.cell(
//             CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row),
//           )
//           ..value = TextCellValue('${pct.toStringAsFixed(1)}%')
//           ..cellStyle = valueStyle;
//       }

//       // Column widths
//       summarySheet.setColumnWidth(0, 25);
//       summarySheet.setColumnWidth(1, 20);
//       summarySheet.setColumnWidth(2, 15);
//       summarySheet.setColumnWidth(3, 20);

//       // ── Sheet 2: Дэлгэрэнгүй (Detail) ──
//       final detailSheet = excel['Дэлгэрэнгүй'];

//       // Headers
//       final colHeaders = [
//         '№',
//         'Огноо',
//         'Үнэлгээ (од)',
//         'Сэтгэгдэл',
//         'Нэргүй эсэх',
//       ];
//       final detailHeaderStyle = CellStyle(
//         bold: true,
//         fontSize: 11,
//         fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
//         backgroundColorHex: ExcelColor.fromHexString('#1A3060'),
//         horizontalAlign: HorizontalAlign.Center,
//       );

//       for (var c = 0; c < colHeaders.length; c++) {
//         detailSheet.cell(
//             CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0),
//           )
//           ..value = TextCellValue(colHeaders[c])
//           ..cellStyle = detailHeaderStyle;
//       }

//       // Data rows
//       for (var i = 0; i < evaluations.length; i++) {
//         final ev = evaluations[i];
//         final rating = ((ev['rating'] as num?)?.toInt()) ?? 0;
//         final comment = ev['comment'] as String? ?? '';
//         final isAnon = ev['is_anonymous'] == true;
//         final dateRaw = ev['created_at'] as String? ?? '';
//         final date = dateRaw.length >= 10
//             ? dateRaw.substring(0, 10).replaceAll('-', '.')
//             : '';

//         final row = i + 1;

//         final evenRowStyle = CellStyle(
//           fontSize: 11,
//           fontColorHex: ExcelColor.fromHexString('#334155'),
//           backgroundColorHex: i % 2 == 0
//               ? ExcelColor.fromHexString('#FFFFFF')
//               : ExcelColor.fromHexString('#F8FAFC'),
//         );

//         // №
//         detailSheet.cell(
//             CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
//           )
//           ..value = IntCellValue(i + 1)
//           ..cellStyle = evenRowStyle;

//         // Огноо
//         detailSheet.cell(
//             CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row),
//           )
//           ..value = TextCellValue(date)
//           ..cellStyle = evenRowStyle;

//         // Үнэлгээ
//         detailSheet.cell(
//             CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row),
//           )
//           ..value = IntCellValue(rating)
//           ..cellStyle = CellStyle(
//             fontSize: 11,
//             fontColorHex: rating >= 4
//                 ? ExcelColor.fromHexString('#16A34A')
//                 : rating == 3
//                 ? ExcelColor.fromHexString('#EA580C')
//                 : ExcelColor.fromHexString('#DC2626'),
//             backgroundColorHex: i % 2 == 0
//                 ? ExcelColor.fromHexString('#FFFFFF')
//                 : ExcelColor.fromHexString('#F8FAFC'),
//             horizontalAlign: HorizontalAlign.Center,
//             bold: true,
//           );

//         // Сэтгэгдэл
//         detailSheet.cell(
//             CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row),
//           )
//           ..value = TextCellValue(comment.isEmpty ? '-' : comment)
//           ..cellStyle = evenRowStyle;

//         // Нэргүй
//         detailSheet.cell(
//             CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row),
//           )
//           ..value = TextCellValue(isAnon ? 'Тийм' : 'Үгүй')
//           ..cellStyle = evenRowStyle;
//       }

//       // Column widths
//       detailSheet.setColumnWidth(0, 8);
//       detailSheet.setColumnWidth(1, 15);
//       detailSheet.setColumnWidth(2, 15);
//       detailSheet.setColumnWidth(3, 45);
//       detailSheet.setColumnWidth(4, 14);

//       // Remove default Sheet1
//       if (excel.sheets.containsKey('Sheet1')) {
//         excel.delete('Sheet1');
//       }

//       // ── Save & Open ──
//       final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
//       final sanitizedName = teacherName
//           .replaceAll(RegExp(r'[^\w\s]'), '')
//           .trim();
//       final fileName = 'vnelgee_${sanitizedName}_$timestamp.xlsx';

//       // Platform-аас хамааран хадгалах зам
//       String dirPath;
//       if (Platform.isWindows) {
//         dirPath = '${Platform.environment['USERPROFILE']}\\Downloads';
//       } else if (Platform.isMacOS || Platform.isLinux) {
//         dirPath = '${Platform.environment['HOME']}/Downloads';
//       } else {
//         // Android/iOS
//         dirPath = '/storage/emulated/0/Download';
//       }

//       final dir = Directory(dirPath);
//       if (!dir.existsSync()) {
//         dir.createSync(recursive: true);
//       }

//       final filePath = '${dir.path}${Platform.pathSeparator}$fileName';
//       final fileBytes = excel.encode();
//       if (fileBytes != null) {
//         final file = File(filePath)
//           ..createSync(recursive: true)
//           ..writeAsBytesSync(fileBytes);

//         try {
//           await OpenFile.open(filePath);
//         } catch (_) {
//           // Файл нээгдэхгүй байсан ч хадгалагдсан
//         }

//         if (context.mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text('Excel файл Downloads-д хадгалагдлаа: $fileName'),
//               backgroundColor: const Color(0xFF22C55E),
//               behavior: SnackBarBehavior.floating,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(12),
//               ),
//             ),
//           );
//         }
//       }
//     } catch (e) {
//       if (context.mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Excel гаргахад алдаа: $e'),
//             backgroundColor: const Color(0xFFEF4444),
//             behavior: SnackBarBehavior.floating,
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(12),
//             ),
//           ),
//         );
//       }
//     }
//   }

//   static void _addLabelValueRow(
//     Sheet sheet,
//     int row,
//     String label,
//     String value,
//     CellStyle labelStyle,
//     CellStyle valueStyle,
//   ) {
//     sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
//       ..value = TextCellValue(label)
//       ..cellStyle = labelStyle;
//     sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
//       ..value = TextCellValue(value)
//       ..cellStyle = valueStyle;
//   }
// }

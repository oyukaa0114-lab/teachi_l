// evaluation_moderation_service.dart
// Үнэлгээний модерац - Groq API (Llama 3.3 70B)
// Байрлал: lib/core/services/evaluation_moderation_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class EvaluationModerationService {
  final SupabaseClient _client = Supabase.instance.client;

  // ══════════════════════════════════════
  // Groq API тохиргоо
  // ══════════════════════════════════════
  static String get _apiKey => dotenv.env['GROQ_API_KEY'] ?? '';

  static const String _groqUrl =
      'https://api.groq.com/openai/v1/chat/completions';

  // Groq model — llama-3.3-70b (хурдан, чадварлаг, free)
  static const String _model = 'llama-3.3-70b-versatile';

  static const int _maxRetries = 3;
  static const int _retryDelaySeconds = 30;
  static const int _batchDelaySeconds = 2; // Groq хурдан учраас бага хүлээнэ
  static const int _batchSize = 10; // Groq-д 10 хүртэл batch амархан

  // ============================================================
  // Үнэлгээнүүдийг ачаалах
  // ============================================================
  Future<List<Map<String, dynamic>>> loadEvaluations() async {
    try {
      final data = await _client
          .from('evaluations')
          .select(
            '*, Students(id, first_name, last_name, department, user_id), Teachers(first_name, last_name, department)',
          )
          .not('comment', 'is', null)
          .neq('comment', '')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      try {
        final data = await _client
            .from('evaluations')
            .select()
            .not('comment', 'is', null)
            .neq('comment', '')
            .order('created_at', ascending: false);
        return List<Map<String, dynamic>>.from(data);
      } catch (e2) {
        debugPrint('Evaluations ачаалахад алдаа: $e2');
        return [];
      }
    }
  }

  String _sanitizeComment(String comment) {
    return comment
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ')
        .replaceAll('\t', ' ')
        .trim();
  }

  // ============================================================
  // 📝 SYSTEM PROMPT — Модератор заавар
  // ============================================================
  static const String _systemPrompt =
      '''Чи Монгол хэлний сургуулийн үнэлгээний контент модератор.
Оюутнуудын багш нарт бичсэн үнэлгээний сэтгэгдлүүдийг шалгана.

══ ДААЛГАВАР 1: ДОРОМЖЛОЛ ШАЛГАЛТ ══

Дараах БҮГДИЙГ илрүүл:

🔴 ШУУД ДОРОМЖЛОЛ — Хараалын үг шууд бичсэн:
   Монгол: тэнэг, мангар, мунхаг, ганган, өөдгүй, хог, муухай, шаахай,
           мал, нохой, гахай, солиотой, галзуу, могой, худалч, донтой,
           тэнэгдүү, ганц бүдүүн, амьтан чи, гөлөг
   Англи: fuck, shit, bitch, asshole, damn, bastard, dick, pussy, cunt,
          wtf, stfu, whore, slut, retard, idiot, stupid, dumb, moron, loser
   Нууцалсан: f*ck, sh*t, b*tch, f**k, a** гэх мэт
   Латин Монгол: teneg, muuhai, hog, gangan, munhag

🟠 ШУУД БУС ДОРОМЖЛОЛ — Утгаараа доромжилсон:
   Жишээ: "энэ хүн юу ч мэдэхгүй", "хог шиг хичээл", "хамгийн муу багш"

🟡 ЗАНАЛХИЙЛЭЛ — "чамайг алж хаяна", "зодно шүү"

⚠️ КОНТЕКСТ:
   ✅ "шалгалт намайг алж байна" = ЗӨВ (хэлц үг)
   ✅ "хичээл хүнд байна" = ЗӨВ (шүүмжлэл)
   ❌ "чамайг алах юм" = ДОРОМЖЛОЛ
   ❌ "тэнэг багш" = ДОРОМЖЛОЛ

Шүүмжлэл ≠ доромжлол.

══ ДААЛГАВАР 2: МЭДРЭМЖ (Sentiment) ══

"positive" — Талархал, магтаал, сэтгэл ханамж
"negative" — Гомдол, шүүмжлэл, дургүйцэл
"neutral" — Төвийг сахисан, мэдээллийн шинжтэй

══ ХАРИУ ФОРМАТ ══
Зөвхөн JSON array буцаа. Өөр текст бүү бич. БҮХ сэтгэгдлийг буцаа.

[{"number":1,"is_inappropriate":true,"reason":"тайлбар","flagged_words":["үг"],"severity":"high","sentiment":"negative","sentiment_score":0.05,"sentiment_reason":"тайлбар"}]

severity: "high"=шууд хараал, "medium"=шууд бус доромжлол, "low"=хөнгөн, "none"=цэвэр
sentiment_score: 0.0=сөрөг → 0.5=төвийг сахисан → 1.0=эерэг''';

  // ============================================================
  // 🚀 GROQ API дуудлага
  // ============================================================
  Future<http.Response> _callGroq(String userMessage) async {
    return await http.post(
      Uri.parse(_groqUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': _model,
        'messages': [
          {'role': 'system', 'content': _systemPrompt},
          {'role': 'user', 'content': userMessage},
        ],
        'temperature': 0.05,
        'max_completion_tokens': 4000,
      }),
    );
  }

  // Groq хариунаас текст авах
  String _extractResponseText(http.Response response) {
    final data = jsonDecode(response.body);
    return data['choices']?[0]?['message']?['content'] ?? '';
  }

  // ============================================================
  // 🚀 BATCH ШАЛГАЛТ
  // ============================================================
  Future<List<Map<String, dynamic>>> batchScanWithGemini({
    required List<Map<String, dynamic>> evaluations,
    Function(String message)? onStatus,
  }) async {
    if (_apiKey.isEmpty) {
      debugPrint('GROQ_API_KEY .env файлд тохируулаагүй!');
      onStatus?.call('API key тохируулаагүй!');
      return [];
    }

    final commentsWithIndex = <Map<String, dynamic>>[];
    for (int i = 0; i < evaluations.length; i++) {
      final comment = evaluations[i]['comment'] as String? ?? '';
      if (comment.trim().isNotEmpty) {
        commentsWithIndex.add({'index': i, 'comment': comment});
      }
    }
    if (commentsWithIndex.isEmpty) return [];

    // Batch-д хуваах
    final batches = <List<Map<String, dynamic>>>[];
    for (int i = 0; i < commentsWithIndex.length; i += _batchSize) {
      final end = (i + _batchSize < commentsWithIndex.length)
          ? i + _batchSize
          : commentsWithIndex.length;
      batches.add(commentsWithIndex.sublist(i, end));
    }

    final allResults = <Map<String, dynamic>>[];
    for (int bi = 0; bi < batches.length; bi++) {
      onStatus?.call('AI шалгаж байна... (${bi + 1}/${batches.length} багц)');

      final result = await _sendBatch(
        batches[bi],
        evaluations,
        onStatus: onStatus,
      );
      allResults.addAll(result);

      // Groq хурдан, 2 секунд хүлээхэд хангалттай
      if (bi < batches.length - 1) {
        await Future.delayed(Duration(seconds: _batchDelaySeconds));
      }
    }

    return allResults;
  }

  Future<List<Map<String, dynamic>>> _sendBatch(
    List<Map<String, dynamic>> batch,
    List<Map<String, dynamic>> evaluations, {
    int retryCount = 0,
    Function(String message)? onStatus,
  }) async {
    if (retryCount >= _maxRetries) {
      debugPrint('Groq max retries хүрлээ');
      return batch.map((item) {
        final idx = item['index'] as int;
        return <String, dynamic>{
          ...evaluations[idx],
          '_ai_reason': '',
          '_flagged_words': <String>[],
          '_severity': 'none',
          '_is_inappropriate': false,
          '_sentiment': 'neutral',
          '_sentiment_score': 0.5,
          '_sentiment_reason': 'AI шалгалт амжилтгүй',
          '_method': 'failed',
        };
      }).toList();
    }

    // Сэтгэгдлүүдийг дугаарлах
    final numberedComments = batch
        .asMap()
        .entries
        .map(
          (e) =>
              '${e.key + 1}. ${_sanitizeComment(e.value['comment'] as String)}',
        )
        .join('\n');

    final userMessage = 'Дараах сэтгэгдлүүдийг шалга:\n\n$numberedComments';

    try {
      final response = await _callGroq(userMessage);

      debugPrint('Groq status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final text = _extractResponseText(response);

        // JSON array олох
        final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(text);
        if (jsonMatch == null) {
          debugPrint('Groq JSON parse алдаа, дахин оролдож байна...');
          await Future.delayed(const Duration(seconds: 2));
          return _sendBatch(
            batch,
            evaluations,
            retryCount: retryCount + 1,
            onStatus: onStatus,
          );
        }

        final List<dynamic> results = jsonDecode(jsonMatch.group(0)!);
        final resultList = <Map<String, dynamic>>[];

        for (final item in results) {
          final number = (item['number'] as num?)?.toInt();
          if (number == null || number < 1 || number > batch.length) continue;

          final origIdx = batch[number - 1]['index'] as int;
          final eval = evaluations[origIdx];
          final isInappropriate = item['is_inappropriate'] == true;

          final flaggedWords = (item['flagged_words'] is List)
              ? (item['flagged_words'] as List)
                    .map((e) => e.toString())
                    .toList()
              : <String>[];

          resultList.add({
            ...eval,
            '_ai_reason': item['reason'] ?? '',
            '_flagged_words': flaggedWords,
            '_severity': isInappropriate
                ? (item['severity'] ?? 'medium')
                : 'none',
            '_is_inappropriate': isInappropriate,
            '_sentiment': item['sentiment'] ?? 'neutral',
            '_sentiment_score':
                (item['sentiment_score'] as num?)?.toDouble() ?? 0.5,
            '_sentiment_reason': item['sentiment_reason'] ?? '',
            '_method': 'groq',
          });
        }
        return resultList;
      } else if (response.statusCode == 429) {
        final wait = _retryDelaySeconds * (retryCount + 1);
        debugPrint('429 Rate limited → ${wait}с хүлээж байна');
        onStatus?.call('API хязгаарлалт - ${wait}с хүлээж байна...');
        await Future.delayed(Duration(seconds: wait));
        return _sendBatch(
          batch,
          evaluations,
          retryCount: retryCount + 1,
          onStatus: onStatus,
        );
      } else {
        debugPrint('Groq error ${response.statusCode}: ${response.body}');
        await Future.delayed(const Duration(seconds: 3));
        return _sendBatch(
          batch,
          evaluations,
          retryCount: retryCount + 1,
          onStatus: onStatus,
        );
      }
    } catch (e) {
      debugPrint('Groq exception: $e');
      await Future.delayed(const Duration(seconds: 3));
      return _sendBatch(
        batch,
        evaluations,
        retryCount: retryCount + 1,
        onStatus: onStatus,
      );
    }
  }

  // ============================================================
  // Ганц сэтгэгдэл шалгах
  // ============================================================
  Future<Map<String, dynamic>> checkSingleWithGemini(
    String comment, {
    int retryCount = 0,
    Function(String message)? onRetryWait,
  }) async {
    if (_apiKey.isEmpty) {
      return _defaultResult('API key тохируулаагүй');
    }

    if (retryCount >= _maxRetries) {
      return _defaultResult('AI шалгалт амжилтгүй');
    }

    final safe = _sanitizeComment(comment);
    final userMessage =
        'Дараах 1 сэтгэгдлийг шалга. JSON object буцаа (array биш):\n\n$safe';

    try {
      final response = await _callGroq(userMessage);

      if (response.statusCode == 200) {
        final text = _extractResponseText(response);
        final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(text);
        if (jsonMatch != null) {
          final result =
              jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;

          result['flagged_words'] = (result['flagged_words'] is List)
              ? (result['flagged_words'] as List)
                    .map((e) => e.toString())
                    .toList()
              : <String>[];
          result['sentiment'] ??= 'neutral';
          result['sentiment_score'] =
              (result['sentiment_score'] as num?)?.toDouble() ?? 0.5;
          result['sentiment_reason'] ??= '';
          result['severity'] ??= 'none';
          return result;
        }
      } else if (response.statusCode == 429) {
        final wait = _retryDelaySeconds * (retryCount + 1);
        onRetryWait?.call('API хязгаарлалт - ${wait}с хүлээж байна...');
        await Future.delayed(Duration(seconds: wait));
        return checkSingleWithGemini(
          comment,
          retryCount: retryCount + 1,
          onRetryWait: onRetryWait,
        );
      }

      return _defaultResult('');
    } catch (e) {
      debugPrint('Groq error: $e');
      return _defaultResult('AI алдаа: $e');
    }
  }

  Map<String, dynamic> _defaultResult(String reason) {
    return {
      'is_inappropriate': false,
      'reason': reason,
      'flagged_words': <String>[],
      'severity': 'none',
      'sentiment': 'neutral',
      'sentiment_score': 0.5,
      'sentiment_reason': '',
    };
  }

  // ============================================================
  // Мэдэгдэл + устгах
  // ============================================================
  Future<bool> sendWarningToStudent(Map<String, dynamic> eval) async {
    try {
      final studentData = eval['Students'];
      if (studentData == null) return false;
      final studentUserId = studentData['user_id'];
      if (studentUserId == null) return false;

      final teacherData = eval['Teachers'];
      final teacherName = teacherData != null
          ? '${(teacherData['last_name'] as String? ?? '')}. ${teacherData['first_name'] ?? ''}'
                .trim()
          : 'Багш';

      final flaggedWords = eval['_flagged_words'] as List<String>?;
      final severity = eval['_severity'] as String? ?? 'medium';

      String severityText;
      switch (severity) {
        case 'high':
          severityText = 'хүнд зөрчил';
          break;
        case 'medium':
          severityText = 'дунд зөрчил';
          break;
        default:
          severityText = 'зөрчил';
      }

      // final wordsText = (flaggedWords != null && flaggedWords.isNotEmpty)
      //     ? ' Илэрсэн: ${flaggedWords.join(", ")}.'
      //     : '';

      await _client.from('notifications').insert({
        'user_id': studentUserId,
        'title': '⚠️ Үнэлгээ устгагдлаа',
        'body':
            'Таны "$teacherName" багшид бичсэн үнэлгээ доромжлол/хараалын үг агуулсан тул '
            'устгагдлаа '
            'Та зөв, боловсон үгээр дахин үнэлгээ бичнэ үү.',
        'type': 'warning',
        'is_read': false,
      });
      return true;
    } catch (e) {
      debugPrint('Мэдэгдэл алдаа: $e');
      return false;
    }
  }

  Future<bool> deleteEvaluation(dynamic id) async {
    try {
      await _client.from('evaluations').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Устгах алдаа: $e');
      return false;
    }
  }

  Future<bool> deleteAndNotify(Map<String, dynamic> eval) async {
    await sendWarningToStudent(eval);
    return await deleteEvaluation(eval['id']);
  }

  Future<({int deleted, int failed})> deleteAllFlagged(
    List<Map<String, dynamic>> flaggedList,
  ) async {
    int deleted = 0;
    int failed = 0;
    for (final f in flaggedList) {
      try {
        await sendWarningToStudent(f);
        final ok = await deleteEvaluation(f['id']);
        ok ? deleted++ : failed++;
      } catch (_) {
        failed++;
      }
    }
    return (deleted: deleted, failed: failed);
  }

  // ============================================================
  // Helpers
  // ============================================================
  static String getTeacherName(Map<String, dynamic> eval) {
    final t = eval['Teachers'];
    if (t == null) return 'Багш #${eval['teacher_id']}';
    final last = t['last_name'] as String? ?? '';
    final first = t['first_name'] as String? ?? '';
    return '${last.isNotEmpty ? '$last.' : ''} $first'.trim();
  }

  static String getStudentName(Map<String, dynamic> eval) {
    final s = eval['Students'];
    if (s == null) return 'Суралцагч #${eval['student_id']}';
    final last = s['last_name'] as String? ?? '';
    final first = s['first_name'] as String? ?? '';
    return '${last.isNotEmpty ? '$last.' : ''} $first'.trim();
  }
}

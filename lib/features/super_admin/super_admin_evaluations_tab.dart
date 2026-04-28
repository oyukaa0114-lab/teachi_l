// super_admin_evaluations_tab.dart
// Super Admin - Үнэлгээний модерац UI (AI шалгалт + Sentiment)
import 'package:flutter/material.dart';
import 'evaluation_moderation_service.dart';

class SuperAdminEvaluationsTab extends StatefulWidget {
  const SuperAdminEvaluationsTab({super.key});

  @override
  State<SuperAdminEvaluationsTab> createState() =>
      _SuperAdminEvaluationsTabState();
}

class _SuperAdminEvaluationsTabState extends State<SuperAdminEvaluationsTab> {
  final _service = EvaluationModerationService();

  List<Map<String, dynamic>> _evaluations = [];
  List<Map<String, dynamic>> _scannedResults = [];
  List<Map<String, dynamic>> _flagged = [];
  bool _isLoading = true;
  bool _isScanning = false;
  String _scanStatus = '';
  bool _hasScanned = false;
  String _activeFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadEvaluations();
  }

  Future<void> _loadEvaluations() async {
    setState(() => _isLoading = true);
    final data = await _service.loadEvaluations();
    setState(() {
      _evaluations = data;
      _isLoading = false;
    });
  }

  Future<void> _scanWithAI() async {
    if (_isScanning) return;
    setState(() {
      _isScanning = true;
      _scanStatus = 'AI шалгаж эхэлж байна...';
      _flagged = [];
      _scannedResults = [];
      _hasScanned = false;
    });

    final results = await _service.batchScanWithGemini(
      evaluations: _evaluations,
      onStatus: (msg) {
        if (mounted) setState(() => _scanStatus = msg);
      },
    );

    if (!mounted) return;

    final flaggedList = results
        .where((r) => r['_is_inappropriate'] == true)
        .toList();

    setState(() {
      _scannedResults = results;
      _flagged = flaggedList;
      _isScanning = false;
      _scanStatus = '';
      _hasScanned = true;
      _activeFilter = flaggedList.isNotEmpty ? 'flagged' : 'all';
    });

    final pos = results.where((r) => r['_sentiment'] == 'positive').length;
    final neu = results.where((r) => r['_sentiment'] == 'neutral').length;
    final neg = results.where((r) => r['_sentiment'] == 'negative').length;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          flaggedList.isEmpty
              ? '✅ Зөрчил олдсонгүй | 😊$pos · 😐$neu · 😟$neg'
              : '⚠️ ${flaggedList.length} зөрчил | 😊$pos · 😐$neu · 😟$neg',
        ),
        backgroundColor: flaggedList.isEmpty
            ? const Color(0xFF34D399)
            : const Color(0xFFF87171),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredList {
    if (!_hasScanned) return _evaluations;
    switch (_activeFilter) {
      case 'flagged':
        return _flagged;
      case 'positive':
        return _scannedResults
            .where((r) => r['_sentiment'] == 'positive')
            .toList();
      case 'negative':
        return _scannedResults
            .where((r) => r['_sentiment'] == 'negative')
            .toList();
      case 'neutral':
        return _scannedResults
            .where((r) => r['_sentiment'] == 'neutral')
            .toList();
      default:
        return _scannedResults.isNotEmpty ? _scannedResults : _evaluations;
    }
  }

  // ── Устгах + мэдэгдэл ──
  Future<void> _deleteAndNotify(Map<String, dynamic> eval) async {
    final comment = eval['comment'] as String? ?? '';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2240),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Үнэлгээ устгах',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Энэ үнэлгээг устгаж, оюутан руу анхааруулга илгээх үү?',
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '"$comment"',
                style: const TextStyle(
                  color: Color(0xFFF87171),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Болих',
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_rounded, size: 16),
            label: const Text('Устгах + Мэдэгдэл'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF87171),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final success = await _service.deleteAndNotify(eval);
    if (success && mounted) {
      setState(() {
        _evaluations.removeWhere((e) => e['id'] == eval['id']);
        _flagged.removeWhere((e) => e['id'] == eval['id']);
        _scannedResults.removeWhere((e) => e['id'] == eval['id']);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Устгагдаж, мэдэгдэл илгээгдлээ ✅'),
          backgroundColor: Color(0xFF34D399),
        ),
      );
    }
  }

  Future<void> _deleteAllFlagged() async {
    if (_flagged.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2240),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Бүгдийг устгах',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '${_flagged.length} зөрчилтэй үнэлгээг устгаж, оюутнууд руу мэдэгдэл илгээх үү?',
          style: const TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Болих',
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_sweep_rounded, size: 16),
            label: const Text('Бүгдийг устгах'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF87171),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final result = await _service.deleteAllFlagged(_flagged);
    final ids = _flagged.map((f) => f['id']).toSet();
    setState(() {
      _evaluations.removeWhere((e) => ids.contains(e['id']));
      _scannedResults.removeWhere((e) => ids.contains(e['id']));
      _flagged = [];
      if (_activeFilter == 'flagged') _activeFilter = 'all';
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${result.deleted} устгагдлаа${result.failed > 0 ? ' (${result.failed} алдаатай)' : ''} ✅',
          ),
          backgroundColor: const Color(0xFF34D399),
        ),
      );
    }
  }

  // ── Helpers ──
  Color _severityColor(String s) {
    switch (s) {
      case 'high':
        return const Color(0xFFF87171);
      case 'medium':
        return const Color(0xFFFF8E53);
      case 'low':
        return const Color(0xFFFFBF47);
      default:
        return const Color(0xFF64748B);
    }
  }

  String _severityLabel(String s) {
    switch (s) {
      case 'high':
        return 'Өндөр';
      case 'medium':
        return 'Дунд';
      case 'low':
        return 'Бага';
      default:
        return 'Цэвэр';
    }
  }

  Color _sentimentColor(String s) {
    switch (s) {
      case 'positive':
        return const Color(0xFF34D399);
      case 'negative':
        return const Color(0xFFF87171);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  IconData _sentimentIcon(String s) {
    switch (s) {
      case 'positive':
        return Icons.sentiment_satisfied_alt_rounded;
      case 'negative':
        return Icons.sentiment_dissatisfied_rounded;
      default:
        return Icons.sentiment_neutral_rounded;
    }
  }

  String _sentimentLabel(String s) {
    switch (s) {
      case 'positive':
        return 'Эерэг';
      case 'negative':
        return 'Сөрөг';
      default:
        return 'Төвийг сахисан';
    }
  }

  // ============================================================
  // UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Үнэлгээний модерац',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _StatChip(
                    icon: Icons.comment_rounded,
                    label: '${_evaluations.length}',
                    color: const Color(0xFF5B8DEF),
                  ),
                  if (_flagged.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    _StatChip(
                      icon: Icons.warning_rounded,
                      label: '${_flagged.length} зөрчил',
                      color: const Color(0xFFF87171),
                    ),
                  ],
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: (_isScanning || _isLoading) ? null : _scanWithAI,
                    icon: _isScanning
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.auto_awesome, size: 18),
                    label: Text(_isScanning ? _scanStatus : 'AI шалгалт'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
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
                  if (_flagged.isNotEmpty && !_isScanning) ...[
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _deleteAllFlagged,
                      icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                      label: const Text('Бүгдийг устгах'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF87171),
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
                ],
              ),
              if (_isScanning) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: const LinearProgressIndicator(
                    minHeight: 4,
                    backgroundColor: Color(0xFF1E293B),
                    valueColor: AlwaysStoppedAnimation(Color(0xFF8B5CF6)),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Sentiment Summary
        if (_hasScanned && !_isScanning) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildSentimentSummary(),
          ),
        ],

        // Filter Tabs
        if (_hasScanned && !_isScanning) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildFilterTabs(),
          ),
        ],

        const SizedBox(height: 12),

        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF5B8DEF)),
                )
              : _buildContentList(),
        ),
      ],
    );
  }

  Widget _buildSentimentSummary() {
    final pos = _scannedResults
        .where((r) => r['_sentiment'] == 'positive')
        .length;
    final neg = _scannedResults
        .where((r) => r['_sentiment'] == 'negative')
        .length;
    final neu = _scannedResults
        .where((r) => r['_sentiment'] == 'neutral')
        .length;
    final total = _scannedResults.length;

    return Row(
      children: [
        _SentimentCard(
          icon: Icons.sentiment_satisfied_alt_rounded,
          label: 'Эерэг',
          count: pos,
          total: total,
          color: const Color(0xFF34D399),
        ),
        const SizedBox(width: 10),
        _SentimentCard(
          icon: Icons.sentiment_neutral_rounded,
          label: 'Төвийг сахисан',
          count: neu,
          total: total,
          color: const Color(0xFF94A3B8),
        ),
        const SizedBox(width: 10),
        _SentimentCard(
          icon: Icons.sentiment_dissatisfied_rounded,
          label: 'Сөрөг',
          count: neg,
          total: total,
          color: const Color(0xFFF87171),
        ),
        const SizedBox(width: 10),
        _SentimentCard(
          icon: Icons.warning_rounded,
          label: 'Зөрчилтэй',
          count: _flagged.length,
          total: total,
          color: const Color(0xFFFF8E53),
        ),
      ],
    );
  }

  Widget _buildFilterTabs() {
    final pos = _scannedResults
        .where((r) => r['_sentiment'] == 'positive')
        .length;
    final neg = _scannedResults
        .where((r) => r['_sentiment'] == 'negative')
        .length;
    final neu = _scannedResults
        .where((r) => r['_sentiment'] == 'neutral')
        .length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterTab(
            label: 'Бүгд (${_scannedResults.length})',
            isActive: _activeFilter == 'all',
            color: const Color(0xFF5B8DEF),
            onTap: () => setState(() => _activeFilter = 'all'),
          ),
          const SizedBox(width: 8),
          if (_flagged.isNotEmpty)
            _FilterTab(
              label: '⚠️ Зөрчил (${_flagged.length})',
              isActive: _activeFilter == 'flagged',
              color: const Color(0xFFF87171),
              onTap: () => setState(() => _activeFilter = 'flagged'),
            ),
          if (_flagged.isNotEmpty) const SizedBox(width: 8),
          _FilterTab(
            label: '😊 Эерэг ($pos)',
            isActive: _activeFilter == 'positive',
            color: const Color(0xFF34D399),
            onTap: () => setState(() => _activeFilter = 'positive'),
          ),
          const SizedBox(width: 8),
          _FilterTab(
            label: '😐 Төвийг сахисан ($neu)',
            isActive: _activeFilter == 'neutral',
            color: const Color(0xFF94A3B8),
            onTap: () => setState(() => _activeFilter = 'neutral'),
          ),
          const SizedBox(width: 8),
          _FilterTab(
            label: '😟 Сөрөг ($neg)',
            isActive: _activeFilter == 'negative',
            color: const Color(0xFFF87171),
            onTap: () => setState(() => _activeFilter = 'negative'),
          ),
        ],
      ),
    );
  }

  Widget _buildContentList() {
    final list = _filteredList;
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _hasScanned ? Icons.check_circle_outline : Icons.comment_outlined,
              color: const Color(0xFF34D399),
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              _hasScanned
                  ? (_activeFilter == 'flagged'
                        ? 'Зөрчилтэй сэтгэгдэл олдсонгүй ✅'
                        : 'Энэ ангилалд сэтгэгдэл байхгүй')
                  : 'Сэтгэгдэл байхгүй',
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: list.length,
      itemBuilder: (_, i) => _buildEvalCard(
        list[i],
        isFlagged: list[i]['_is_inappropriate'] == true,
      ),
    );
  }

  Widget _buildEvalCard(Map<String, dynamic> eval, {bool isFlagged = false}) {
    final comment = eval['comment'] as String? ?? '';
    final rating = ((eval['rating'] as num?)?.toInt()) ?? 0;
    final isAnon = eval['is_anonymous'] == true;
    final createdAt = eval['created_at'] as String? ?? '';
    final date = createdAt.length >= 10
        ? createdAt.substring(0, 10).replaceAll('-', '.')
        : '';
    final aiReason = eval['_ai_reason'] as String?;
    final flaggedWords = eval['_flagged_words'] as List<String>?;
    final severity = eval['_severity'] as String? ?? 'none';
    final sentiment = eval['_sentiment'] as String? ?? '';
    final sentimentScore =
        (eval['_sentiment_score'] as num?)?.toDouble() ?? 0.5;
    final sentimentReason = eval['_sentiment_reason'] as String? ?? '';
    final hasSentiment = sentiment.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF12182B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isFlagged
              ? _severityColor(severity).withOpacity(0.3)
              : hasSentiment
              ? _sentimentColor(sentiment).withOpacity(0.15)
              : Colors.white.withOpacity(0.04),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row
          Row(
            children: [
              _InfoChip(
                icon: Icons.school_rounded,
                label: EvaluationModerationService.getTeacherName(eval),
                color: const Color(0xFF5B8DEF),
              ),
              const SizedBox(width: 8),
              _InfoChip(
                icon: isAnon
                    ? Icons.visibility_off_rounded
                    : Icons.person_rounded,
                label: isAnon
                    ? 'Нэргүй'
                    : EvaluationModerationService.getStudentName(eval),
                color: const Color(0xFF64748B),
              ),
              const Spacer(),
              if (hasSentiment) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _sentimentColor(sentiment).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _sentimentColor(sentiment).withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _sentimentIcon(sentiment),
                        color: _sentimentColor(sentiment),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _sentimentLabel(sentiment),
                        style: TextStyle(
                          color: _sentimentColor(sentiment),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: const Color(0xFFFFBF47),
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                date,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Comment
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isFlagged
                  ? _severityColor(severity).withOpacity(0.05)
                  : hasSentiment
                  ? _sentimentColor(sentiment).withOpacity(0.03)
                  : Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(10),
              border: isFlagged
                  ? Border.all(
                      color: _severityColor(severity).withOpacity(0.15),
                    )
                  : null,
            ),
            child: Text(
              comment,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),

          // Sentiment (зөрчилгүй бол)
          if (hasSentiment && !isFlagged && sentimentReason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _sentimentColor(sentiment).withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _sentimentColor(sentiment).withOpacity(0.1),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _sentimentIcon(sentiment),
                    color: _sentimentColor(sentiment),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${_sentimentLabel(sentiment)} мэдрэмж',
                              style: TextStyle(
                                color: _sentimentColor(sentiment),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _SentimentBar(
                                score: sentimentScore,
                                color: _sentimentColor(sentiment),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${(sentimentScore * 100).toInt()}%',
                              style: TextStyle(
                                color: _sentimentColor(sentiment),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          sentimentReason,
                          style: TextStyle(
                            color: _sentimentColor(sentiment).withOpacity(0.8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // AI зөрчил (зөрчилтэй бол)
          if (isFlagged && aiReason != null && aiReason.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _severityColor(severity).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _severityColor(severity).withOpacity(0.15),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.auto_awesome,
                    color: _severityColor(severity),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Gemini AI: ',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _severityColor(
                                  severity,
                                ).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _severityLabel(severity),
                                style: TextStyle(
                                  color: _severityColor(severity),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (hasSentiment) ...[
                              const SizedBox(width: 6),
                              Icon(
                                _sentimentIcon(sentiment),
                                color: _sentimentColor(sentiment),
                                size: 14,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                _sentimentLabel(sentiment),
                                style: TextStyle(
                                  color: _sentimentColor(sentiment),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          aiReason,
                          style: TextStyle(
                            color: _severityColor(severity),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (flaggedWords != null && flaggedWords.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: flaggedWords
                    .map(
                      (w) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _severityColor(severity).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _severityColor(severity).withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          '"$w"',
                          style: TextStyle(
                            color: _severityColor(severity),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],

          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isFlagged)
                TextButton.icon(
                  onPressed: () => setState(() {
                    _flagged.removeWhere((e) => e['id'] == eval['id']);
                    final idx = _scannedResults.indexWhere(
                      (e) => e['id'] == eval['id'],
                    );
                    if (idx >= 0) {
                      _scannedResults[idx]['_is_inappropriate'] = false;
                      _scannedResults[idx]['_severity'] = 'none';
                    }
                  }),
                  icon: const Icon(
                    Icons.check_rounded,
                    color: Color(0xFF34D399),
                    size: 16,
                  ),
                  label: const Text(
                    'Зөвшөөрөх',
                    style: TextStyle(color: Color(0xFF34D399), fontSize: 12),
                  ),
                ),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: () => _deleteAndNotify(eval),
                icon: const Icon(
                  Icons.delete_rounded,
                  color: Color(0xFFF87171),
                  size: 16,
                ),
                label: Text(
                  isFlagged ? 'Устгах + Мэдэгдэл' : 'Устгах',
                  style: const TextStyle(
                    color: Color(0xFFF87171),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Widgets ──
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SentimentCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final int total;
  final Color color;
  const _SentimentCard({
    required this.icon,
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (count / total * 100).toInt() : 0;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              '$count',
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color.withOpacity(0.8),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: total > 0 ? count / total : 0,
                minHeight: 4,
                backgroundColor: color.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation(color.withOpacity(0.6)),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$pct%',
              style: TextStyle(color: color.withOpacity(0.6), fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color color;
  final VoidCallback onTap;
  const _FilterTab({
    required this.label,
    required this.isActive,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? color.withOpacity(0.15)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? color.withOpacity(0.4)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? color : const Color(0xFF64748B),
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _SentimentBar extends StatelessWidget {
  final double score;
  final Color color;
  const _SentimentBar({required this.score, required this.color});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: LinearProgressIndicator(
        value: score,
        minHeight: 6,
        backgroundColor: color.withOpacity(0.1),
        valueColor: AlwaysStoppedAnimation(color.withOpacity(0.6)),
      ),
    );
  }
}

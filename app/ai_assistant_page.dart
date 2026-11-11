import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Case-scoped assistant using the existing authenticated Edge Function.
class SamanvayAiAssistantPage extends StatefulWidget {
  const SamanvayAiAssistantPage({super.key});
  @override
  State<SamanvayAiAssistantPage> createState() => _SamanvayAiAssistantPageState();
}

class _SamanvayAiAssistantPageState extends State<SamanvayAiAssistantPage> {
  Color get _aiNavy => Theme.of(context).appBarTheme.backgroundColor ?? Theme.of(context).colorScheme.primary;
  Color get _aiPanel => Theme.of(context).colorScheme.surface;
  Color get _aiBlue => Theme.of(context).colorScheme.primary;
  Color get _aiCyan => Theme.of(context).colorScheme.secondary;
  Color get _aiMuted => Theme.of(context).colorScheme.onSurfaceVariant;
  Color get _aiInk => Theme.of(context).colorScheme.onSurface;
  Color get _aiBorder => Theme.of(context).colorScheme.outlineVariant;
  bool get _isLight => Theme.of(context).brightness == Brightness.light;

  final SupabaseClient _db = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _requestsFuture;
  String? _selectedRequestId;
  String _purpose = 'coordination';
  bool _running = false;
  String? _error;
  Map<String, dynamic>? _assessment;
  String? _assessmentId;
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _requestsFuture = _loadRequests();
  }

  Future<List<Map<String, dynamic>>> _loadRequests() async {
    final rows = await _db.from('excavation_requests')
        .select('id,request_number,title,status,case_category')
        .order('created_at', ascending: false).limit(100);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> _loadHistory(String requestId) async {
    try {
      final rows = await _db.from('case_ai_assessments')
          .select('id,purpose,assessment,review_status,created_at')
          .eq('request_id', requestId)
          .order('created_at', ascending: false).limit(12);
      if (!mounted || _selectedRequestId != requestId) return;
      setState(() => _history = List<Map<String, dynamic>>.from(rows));
    } catch (_) {
      if (mounted) setState(() => _history = []);
    }
  }

  void _selectRequest(String? value) {
    if (value == null) return;
    setState(() {
      _selectedRequestId = value;
      _assessment = null;
      _assessmentId = null;
      _error = null;
      _history = [];
    });
    _loadHistory(value);
  }

  String _errorMessage(Object error) {
    final value = error.toString();
    if (value.contains('AI_NOT_CONFIGURED')) {
      return 'The built-in case assistant is temporarily unavailable. Check your connection and try again.';
    }
    if (value.contains('DAILY_AI_LIMIT_REACHED') || value.contains('429')) {
      return 'The per-user daily rule-based assessment limit has been reached. Try again after the 24-hour usage window.';
    }
    if (value.contains('STAFF_ACCESS_REQUIRED') ||
        value.contains('CASE_NOT_ASSIGNED_TO_YOUR_DEPARTMENT')) {
      return 'This account is not authorised to assess the selected case.';
    }
    if (value.contains('FUNCTION_NOT_FOUND') || value.contains('404')) {
      return 'The samanvay-case-assistant Edge Function is not deployed in this Supabase project.';
    }
    return 'The assessment could not be completed. Check the function deployment and case permissions.';
  }

  Future<void> _runAssessment() async {
    final requestId = _selectedRequestId;
    if (requestId == null || _running) return;
    setState(() {
      _running = true;
      _error = null;
      _assessment = null;
      _assessmentId = null;
    });
    try {
      final response = await _db.functions.invoke(
        'samanvay-case-assistant',
        body: {'request_id': requestId, 'purpose': _purpose},
      );
      final data = response.data;
      if (response.status < 200 || response.status >= 300) {
        throw StateError(data is Map
            ? (data['error'] ?? 'AI_PROVIDER_ERROR').toString()
            : 'AI_PROVIDER_ERROR');
      }
      if (data is! Map || data['assessment'] is! Map) {
        throw StateError(data is Map
            ? (data['error'] ?? 'INVALID_ASSESSMENT').toString()
            : 'INVALID_ASSESSMENT');
      }
      if (!mounted) return;
      setState(() {
        _assessment = Map<String, dynamic>.from(data['assessment'] as Map);
        _assessmentId = data['assessment_id']?.toString();
      });
      await _loadHistory(requestId);
    } catch (error) {
      if (mounted) setState(() => _error = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  String _readable(String value) =>
      value.replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  Widget _notice(String text, {bool warning = false}) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: warning ? (_isLight ? const Color(0xFFFFE8E8) : const Color(0xFF462B32)) : _aiPanel,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: warning ? const Color(0xFFB85D67) : _aiBorder),
    ),
    child: Text(text, style: TextStyle(color: _aiInk, fontSize: 12, height: 1.4)),
  );

  Widget _tag(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: _aiPanel,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _aiBorder),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: _aiMuted, fontSize: 8, letterSpacing: .7, fontWeight: FontWeight.w800)),
      const SizedBox(height: 3),
      Text(value, style: TextStyle(color: _aiInk, fontSize: 10, fontWeight: FontWeight.w800)),
    ]),
  );

  Widget _section(String title, dynamic raw, IconData icon) {
    final items = raw is List ? raw.map((item) => item.toString()).where((item) => item.trim().isNotEmpty).toList() : <String>[];
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: _aiPanel, borderRadius: BorderRadius.circular(14), border: Border.all(color: _aiBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: _aiCyan, size: 17), const SizedBox(width: 8),
          Expanded(child: Text(title.toUpperCase(), style: TextStyle(color: _aiCyan, fontSize: 10, letterSpacing: .7, fontWeight: FontWeight.w800))),
        ]),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('• ', style: TextStyle(color: _aiCyan, fontSize: 13)),
            Expanded(child: Text(item, style: TextStyle(color: _aiInk, fontSize: 12, height: 1.35))),
          ]),
        )),
      ]),
    );
  }

  Widget _assessmentCard() {
    final data = _assessment;
    if (data == null) return const SizedBox.shrink();
    final confidence = data['confidence'];
    final confidenceText = confidence is num ? (confidence * 100).round().toString() + '%' : 'Not reported';
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _aiPanel, borderRadius: BorderRadius.circular(18), border: Border.all(color: _aiCyan.withValues(alpha: .45))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.auto_awesome, color: _aiCyan, size: 20), const SizedBox(width: 8),
          Expanded(child: Text('Rule-based case assessment', style: TextStyle(color: _aiInk, fontSize: 16, fontWeight: FontWeight.w800))),
          if (_assessmentId != null && _assessmentId!.isNotEmpty)
            const Icon(Icons.verified_outlined, color: Color(0xFF77D5B0), size: 18),
        ]),
        const SizedBox(height: 12),
        Text((data['summary'] ?? 'No summary returned.').toString(), style: TextStyle(color: _aiInk, fontSize: 13, height: 1.5)),
        const SizedBox(height: 13),
        Wrap(spacing: 7, runSpacing: 7, children: [
          _tag('CATEGORY', _readable((data['category'] ?? 'other').toString())),
          _tag('PRIORITY', _readable((data['priority_band'] ?? 'not reported').toString()).toUpperCase()),
          _tag('RULE MATCH', confidenceText),
        ]),
        _section('Suggested departments', data['suggested_departments'], Icons.account_tree_outlined),
        _section('Coordination flags', data['coordination_flags'], Icons.flag_outlined),
        _section('Missing information', data['missing_information'], Icons.help_outline),
        _section('Recommended checks', data['recommended_checks'], Icons.fact_check_outlined),
        const SizedBox(height: 12),
        Text('Advisory only. An authorised officer must independently verify information and make all official decisions. This is not a permit, excavation clearance or utility-safety determination.', style: TextStyle(color: _aiMuted, fontSize: 10, height: 1.45)),
      ]),
    );
  }

  Widget _historyCard() {
    if (_history.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _aiPanel, borderRadius: BorderRadius.circular(16), border: Border.all(color: _aiBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('RECENT CASE ASSESSMENTS', style: TextStyle(color: _aiCyan, fontSize: 10, letterSpacing: .9, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        ..._history.take(6).map((item) {
          final assessment = item['assessment'] is Map ? Map<String, dynamic>.from(item['assessment'] as Map) : <String, dynamic>{};
          final created = DateTime.tryParse((item['created_at'] ?? '').toString());
          final date = created == null ? 'Date not reported' :
              created.day.toString().padLeft(2, '0') + '/' +
              created.month.toString().padLeft(2, '0') + '/' + created.year.toString();
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.history, color: _aiCyan, size: 19),
            title: Text(_readable((item['purpose'] ?? 'assessment').toString()).toUpperCase(), style: TextStyle(color: _aiInk, fontSize: 10, fontWeight: FontWeight.w800)),
            subtitle: Text((assessment['summary'] ?? 'Assessment record').toString() + '\n' + date + ' · ' + _readable((item['review_status'] ?? 'suggested').toString()), maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: _aiMuted, fontSize: 10)),
            isThreeLine: true,
          );
        }),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    appBar: AppBar(backgroundColor: _aiNavy, foregroundColor: Colors.white, title: const Text('Case Intelligence')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _requestsFuture,
      builder: (context, snapshot) {
        final requests = snapshot.data ?? [];
        final selected = requests.any((r) => r['id'].toString() == _selectedRequestId) ? _selectedRequestId : null;
        return ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 28), children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: _isLight ? const [Color(0xFFE3F2EF), Color(0xFFDDECF0), Color(0xFFEAF1F7)] : [_aiPanel, const Color(0xFF124B6C), const Color(0xFF123B72)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20), border: Border.all(color: _aiCyan.withValues(alpha: .35)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 43, height: 43, decoration: BoxDecoration(color: _aiCyan.withValues(alpha: .14), borderRadius: BorderRadius.circular(13)), child: Icon(Icons.smart_toy_outlined, color: _aiCyan, size: 25)),
                const SizedBox(width: 12),
                Expanded(child: Text('Case intelligence', style: GoogleFonts.spaceGrotesk(color: _isLight ? _aiInk : Colors.white, fontWeight: FontWeight.w700, fontSize: 21))),
                const Chip(label: Text('ADVISORY', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w800)), backgroundColor: Color(0xFF266A82), side: BorderSide.none, visualDensity: VisualDensity.compact),
              ]),
              const SizedBox(height: 11),
              Text('Run a structured summary, triage or coordination assessment against a case your authenticated role is allowed to access.', style: TextStyle(color: _isLight ? _aiMuted : const Color(0xFFD7E7F2), fontSize: 12, height: 1.45)),
            ]),
          ),
          const SizedBox(height: 16),
          if (snapshot.connectionState == ConnectionState.waiting)
            Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: _aiCyan)))
          else if (snapshot.hasError)
            _notice('Cases could not be loaded. Your account may not have access to case records.')
          else if (requests.isEmpty)
            _notice('No cases are currently visible to this account. Case visibility is controlled by Supabase row-level security.')
          else ...[
            Text('SELECT CASE', style: TextStyle(color: _aiMuted, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w800)),
            const SizedBox(height: 7),
            DropdownButtonFormField<String>(
              value: selected,
              isExpanded: true,
              dropdownColor: _aiPanel,
              style: TextStyle(color: _aiInk, fontSize: 12),
              decoration: InputDecoration(
                filled: true, fillColor: _aiPanel, hintText: 'Choose an accessible infrastructure case',
                hintStyle: TextStyle(color: _aiMuted, fontSize: 11),
                prefixIcon: Icon(Icons.folder_open, color: _aiCyan),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide(color: _aiBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: Color(0xFF31536F))),
              ),
              items: requests.map((r) {
                final number = (r['request_number'] ?? r['id']).toString();
                final title = (r['title'] ?? 'Infrastructure request').toString();
                return DropdownMenuItem<String>(value: r['id'].toString(), child: Text(number + ' · ' + title, maxLines: 1, overflow: TextOverflow.ellipsis));
              }).toList(),
              onChanged: _running ? null : _selectRequest,
            ),
            const SizedBox(height: 15),
            Text('ASSESSMENT TYPE', style: TextStyle(color: _aiMuted, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w800)),
            const SizedBox(height: 7),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'summary', label: Text('Summary')),
                ButtonSegment(value: 'triage', label: Text('Triage')),
                ButtonSegment(value: 'coordination', label: Text('Coordination')),
              ],
              selected: <String>{_purpose},
              onSelectionChanged: _running ? null : (value) => setState(() => _purpose = value.first),
              style: SegmentedButton.styleFrom(
                foregroundColor: Colors.white, selectedForegroundColor: _aiNavy,
                selectedBackgroundColor: _aiCyan, side: BorderSide(color: _aiBorder),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _selectedRequestId == null || _running ? null : _runAssessment,
                style: FilledButton.styleFrom(backgroundColor: _aiBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
                icon: _running ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.auto_awesome),
                label: Text(_running ? 'CHECKING CASE…' : 'RUN RULE-BASED REVIEW'),
              ),
            ),
          ],
          if (_error != null) ...[const SizedBox(height: 12), _notice(_error!, warning: true)],
          _assessmentCard(),
          _historyCard(),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(color: _aiPanel, borderRadius: BorderRadius.circular(14), border: Border.all(color: _aiBorder)),
            child: Text('Zero-cost mode: the existing Supabase function validates the session and department assignment, applies a per-user usage limit, and analyses selected case text using built-in rules. No paid AI API or external model is called. Never use this rule-based assessment as a no-dig clearance or statutory approval.', style: TextStyle(color: _aiMuted, fontSize: 10, height: 1.45)),
          ),
        ]);
      },
    ),
  );
}

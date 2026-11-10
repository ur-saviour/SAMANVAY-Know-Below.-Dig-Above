import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PublicExcavationTrackerPage extends StatefulWidget {
  const PublicExcavationTrackerPage({super.key});
  @override
  State<PublicExcavationTrackerPage> createState() => _PublicExcavationTrackerPageState();
}

class _PublicExcavationTrackerPageState extends State<PublicExcavationTrackerPage> {
  Color get _trackerNavy => Theme.of(context).appBarTheme.backgroundColor ?? Theme.of(context).colorScheme.primary;
  Color get _trackerBlue => Theme.of(context).colorScheme.primary;
  Color get _trackerCyan => Theme.of(context).colorScheme.secondary;
  Color get _trackerMuted => Theme.of(context).colorScheme.onSurfaceVariant;
  Color get _trackerInk => Theme.of(context).colorScheme.onSurface;
  bool get _isLight => Theme.of(context).brightness == Brightness.light;

  final SupabaseClient _db = Supabase.instance.client;
  final TextEditingController _search = TextEditingController();
  late Future<List<Map<String, dynamic>>> _future;
  String _filter = 'all';

  @override
  void initState() { super.initState(); _future = _load(); }
  @override
  void dispose() { _search.dispose(); super.dispose(); }

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await _db.from('public_excavation_notices')
      .select('id,notice_code,title,notice_type,summary,city,district,ward_code,area_label,responsible_department_name,starts_on,ends_on,progress_percent,notice_status,source_reference,published_at')
      .neq('notice_status', 'draft')
      .order('published_at', ascending: false).limit(250);
    return List<Map<String, dynamic>>.from(rows);
  }

  String _date(dynamic value) {
    final d = DateTime.tryParse((value ?? '').toString());
    if (d == null) return 'Not reported';
    return d.day.toString().padLeft(2, '0') + '/' +
      d.month.toString().padLeft(2, '0') + '/' + d.year.toString();
  }

  void _toast(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value), behavior: SnackBarBehavior.floating));
  }

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> rows) {
    final q = _search.text.trim().toLowerCase();
    return rows.where((row) {
      final type = (row['notice_type'] ?? '').toString();
      final status = (row['notice_status'] ?? '').toString();
      if (_filter == 'no_dig' && type != 'no_dig') return false;
      if (_filter == 'active' && !['active', 'published'].contains(status)) return false;
      if (q.isEmpty) return true;
      return [row['city'],row['district'],row['ward_code'],row['area_label'],row['title'],row['notice_code']]
        .any((v) => v != null && v.toString().toLowerCase().contains(q));
    }).toList();
  }

  Future<void> _timeline(Map<String, dynamic> notice) async {
    try {
      final rows = await _db.from('public_excavation_notice_events')
        .select('event_type,title,details,progress_percent,created_at')
        .eq('notice_id', notice['id'].toString())
        .order('created_at', ascending: false).limit(100);
      if (!mounted) return;
      final events = List<Map<String, dynamic>>.from(rows);
      await showModalBottomSheet<void>(
        context: context, isScrollControlled: true, backgroundColor: Colors.white,
        builder: (sheet) => SafeArea(child: SizedBox(
          height: MediaQuery.of(sheet).size.height * .65,
          child: events.isEmpty
            ? const Center(child: Text('No published progress events are available.'))
            : ListView(padding: const EdgeInsets.all(16), children: [
                Text((notice['title'] ?? 'Public work notice').toString(),
                  style: TextStyle(fontWeight: FontWeight.w800, color: _trackerNavy)),
                const SizedBox(height: 12),
                ...events.map((event) => ListTile(
                  leading: Icon(Icons.timeline_rounded, color: _trackerBlue),
                  title: Text((event['title'] ?? event['event_type'] ?? 'Update').toString()),
                  subtitle: Text(
                    (event['details'] ?? 'No details.').toString() + '\n' +
                    (event['progress_percent'] == null ? '' :
                      'Reported progress: ' + event['progress_percent'].toString() + '%\n') +
                    _date(event['created_at']),
                  ), isThreeLine: true,
                )),
              ]),
        )),
      );
    } catch (_) {
      _toast('Timeline unavailable. The public tracker migration may not be applied.');
    }
  }

  Future<void> _report() async {
    final user = _db.auth.currentUser;
    if (user == null) { _toast('Sign in before submitting an obstruction report.'); return; }
    final key = GlobalKey<FormState>();
    final city = TextEditingController();
    final district = TextEditingController();
    final ward = TextEditingController();
    final area = TextEditingController();
    final details = TextEditingController();
    var type = 'road_obstruction';
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Report a public obstruction'),
        content: SizedBox(width: 440, child: SingleChildScrollView(
          child: Form(key: key, child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              initialValue: type, isExpanded: true,
              decoration: const InputDecoration(labelText: 'Report category'),
              items: const [
                DropdownMenuItem(value: 'road_obstruction', child: Text('Road obstruction')),
                DropdownMenuItem(value: 'blocked_access', child: Text('Blocked access')),
                DropdownMenuItem(value: 'unmarked_work', child: Text('Unmarked worksite')),
                DropdownMenuItem(value: 'unsafe_excavation', child: Text('Worksite safety concern')),
                DropdownMenuItem(value: 'possible_damage', child: Text('Possible utility damage')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (v) { if (v != null) type = v; },
            ),
            const SizedBox(height: 8),
            TextFormField(controller: city, decoration: const InputDecoration(labelText: 'City / town'),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
            const SizedBox(height: 8),
            TextFormField(controller: district, decoration: const InputDecoration(labelText: 'District (optional)')),
            const SizedBox(height: 8),
            TextFormField(controller: ward, decoration: const InputDecoration(labelText: 'Ward code (optional)')),
            const SizedBox(height: 8),
            TextFormField(controller: area, decoration: const InputDecoration(labelText: 'Area / road / landmark'),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
            const SizedBox(height: 8),
            TextFormField(controller: details, minLines: 3, maxLines: 5, maxLength: 1500,
              decoration: const InputDecoration(labelText: 'Details', alignLabelWithHint: true),
              validator: (v) => v == null || v.trim().length < 10 ? 'Enter at least 10 characters' : null),
            const SizedBox(height: 8),
            Text('Reports remain private to the reporter and authorised reviewers unless an authority publishes an update. Avoid sensitive personal information.',
              style: TextStyle(color: _trackerMuted, fontSize: 11)),
          ])),
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
          FilledButton(onPressed: () async {
            if (!key.currentState!.validate()) return;
            try {
              await _db.from('public_obstruction_reports').insert({
                'reporter_id': user.id, 'city': city.text.trim(),
                'district': district.text.trim().isEmpty ? null : district.text.trim(),
                'ward_code': ward.text.trim().isEmpty ? null : ward.text.trim(),
                'area_label': area.text.trim(), 'report_type': type,
                'details': details.text.trim(),
              });
              if (dialog.mounted) Navigator.pop(dialog, true);
            } catch (_) {
              _toast('Report not submitted. Check tracker migration and account access.');
            }
          }, child: const Text('Submit report')),
        ],
      ),
    );
    city.dispose(); district.dispose(); ward.dispose(); area.dispose(); details.dispose();
    if (submitted == true) _toast('Report submitted to the private review queue.');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    appBar: AppBar(title: const Text('Public works tracker'), actions: [
      IconButton(tooltip: 'Refresh', onPressed: () => setState(() => _future = _load()),
        icon: const Icon(Icons.refresh_rounded)),
    ]),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _report, backgroundColor: _trackerBlue, foregroundColor: Colors.white,
      icon: const Icon(Icons.flag_outlined), label: const Text('Report obstruction')),
    body: FutureBuilder<List<Map<String, dynamic>>>(future: _future, builder: (context, snapshot) {
      final rows = snapshot.data ?? <Map<String, dynamic>>[];
      final visible = _filtered(rows);
      return RefreshIndicator(onRefresh: () async => setState(() => _future = _load()),
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: _isLight
                  ? const [Color(0xFFE3F2EF), Color(0xFFDDECF0), Color(0xFFEAF1F7)]
                  : [_trackerNavy, const Color(0xFF123B65), const Color(0xFF075E72)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _trackerCyan.withValues(alpha: .28))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('PUBLIC INFRASTRUCTURE NOTICES',
                style: TextStyle(color: _isLight ? _trackerBlue : const Color(0xFFB8E6F4), fontSize: 10, letterSpacing: 1.3, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Text('Know what is happening in your ward.',
                style: GoogleFonts.spaceGrotesk(color: _isLight ? _trackerInk : Colors.white, fontSize: 23, fontWeight: FontWeight.w700)),
              const SizedBox(height: 7),
              Text('Authority-published excavation notices, work dates, progress updates and no-dig notices.',
                style: TextStyle(color: _isLight ? _trackerMuted : const Color(0xFFD8E7F3), fontSize: 12, height: 1.45)),
            ]),
          ),
          const SizedBox(height: 14),
          TextField(controller: _search, onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search city, ward, area or notice code',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _search.text.isEmpty ? null : IconButton(
                onPressed: () { _search.clear(); setState(() {}); },
                icon: const Icon(Icons.close_rounded)))),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            _chip('All notices', 'all'), _chip('Active works', 'active'), _chip('No-dig notices', 'no_dig'),
          ]),
          const SizedBox(height: 10),
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
          else if (snapshot.hasError)
            Card(child: Padding(padding: EdgeInsets.all(16),
              child: Text('Published notices are not available yet. Only notices published by an authorised department appear here. Apply the additive tracker migration and publish a sourced notice; no sample records are prefilled.',
                style: TextStyle(color: _trackerMuted, fontSize: 12, height: 1.45))))
          else if (visible.isEmpty)
            Card(child: Padding(padding: EdgeInsets.all(18),
              child: Text('No matching published notices. This does not mean no work is taking place; no matching notice has been published to SAMANVAY.',
                textAlign: TextAlign.center, style: TextStyle(color: _trackerMuted, fontSize: 12))))
          else
            ...visible.map(_noticeCard),
          const SizedBox(height: 8),
          Text('An empty search result or a no-dig notice does not establish excavation clearance or absence of underground utilities.',
            style: TextStyle(color: _trackerMuted, fontSize: 10, height: 1.4)),
        ]),
      );
    }),
  );

  Widget _chip(String label, String value) => ChoiceChip(
    label: Text(label), selected: _filter == value,
    onSelected: (_) => setState(() => _filter = value),
    selectedColor: _trackerCyan.withValues(alpha: .2),
    labelStyle: TextStyle(color: _filter == value ? _trackerNavy : _trackerMuted,
      fontWeight: FontWeight.w700, fontSize: 11));

  Widget _noticeCard(Map<String, dynamic> notice) {
    final noDig = notice['notice_type'] == 'no_dig';
    final progress = notice['progress_percent'];
    final fraction = progress is num ? progress.toDouble().clamp(0, 100) / 100 : null;
    final parts = [notice['area_label'],
      notice['ward_code'] == null ? null : 'Ward ' + notice['ward_code'].toString(),
      notice['city'], notice['district']];
    final location = parts.where((v) => v != null && v.toString().trim().isNotEmpty)
      .map((v) => v.toString()).join(' · ');
    return Card(margin: const EdgeInsets.only(bottom: 12),
      child: Padding(padding: const EdgeInsets.all(15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text((notice['notice_code'] ?? 'Published notice').toString(),
              style: TextStyle(color: _trackerBlue, fontSize: 11, fontWeight: FontWeight.w800))),
            Chip(label: Text(noDig ? 'NO-DIG' : 'EXCAVATION'),
              backgroundColor: noDig ? const Color(0xFFFFF1D8) : const Color(0xFFE8F5FF),
              labelStyle: TextStyle(color: noDig ? const Color(0xFF8C5A06) : const Color(0xFF195B9A),
                fontWeight: FontWeight.w900, fontSize: 9),
              visualDensity: VisualDensity.compact),
          ]),
          Text((notice['title'] ?? 'Infrastructure work notice').toString(),
            style: GoogleFonts.spaceGrotesk(color: _trackerNavy, fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(location.isEmpty ? 'Location not specified' : location,
            style: TextStyle(color: _trackerMuted, fontSize: 12)),
          const SizedBox(height: 9),
          _detail(Icons.account_balance_outlined,
            (notice['responsible_department_name'] ?? 'Responsible department not listed').toString()),
          _detail(Icons.calendar_month_outlined,
            _date(notice['starts_on']) + ' – ' + _date(notice['ends_on'])),
          _detail(Icons.info_outline, 'Status: ' + (notice['notice_status'] ?? 'published').toString()),
          if (fraction != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: Text('Reported progress', style: TextStyle(color: _trackerMuted, fontSize: 11))),
              Text(progress.toString() + '%', style: TextStyle(color: _trackerInk, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 5),
            ClipRRect(borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: fraction.toDouble(), minHeight: 7,
                backgroundColor: const Color(0xFFE8EEF5),
                valueColor: AlwaysStoppedAnimation<Color>(_trackerBlue))),
          ] else
            Padding(padding: EdgeInsets.only(top: 8),
              child: Text('Progress not reported by the publishing authority.',
                style: TextStyle(color: _trackerMuted, fontSize: 11))),
          if ((notice['summary'] ?? '').toString().trim().isNotEmpty) ...[
            const SizedBox(height: 9),
            Text(notice['summary'].toString(),
              style: TextStyle(color: _trackerInk, fontSize: 12, height: 1.4)),
          ],
          if ((notice['source_reference'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Source: ' + notice['source_reference'].toString(),
              style: TextStyle(color: _trackerMuted, fontSize: 10)),
          ],
          Align(alignment: Alignment.centerRight,
            child: TextButton.icon(onPressed: () => _timeline(notice),
              icon: const Icon(Icons.timeline_rounded, size: 17), label: const Text('View timeline'))),
        ]),
      ),
    );
  }

  Widget _detail(IconData icon, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Icon(icon, size: 15, color: _trackerBlue), const SizedBox(width: 8),
      Expanded(child: Text(value, style: TextStyle(color: _trackerInk, fontSize: 11))),
    ]),
  );
}

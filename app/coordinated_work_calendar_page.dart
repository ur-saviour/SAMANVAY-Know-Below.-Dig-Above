import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Read-only, RLS-scoped planner for coordinating planned infrastructure works.
/// Proximity flags are planning advisories only; they are not utility clearance.
class CoordinatedWorkCalendarPage extends StatefulWidget {
  const CoordinatedWorkCalendarPage({super.key});

  @override
  State<CoordinatedWorkCalendarPage> createState() =>
      _CoordinatedWorkCalendarPageState();
}

class _CoordinatedWorkCalendarPageState
    extends State<CoordinatedWorkCalendarPage> {
  final SupabaseClient _db = Supabase.instance.client;
  final TextEditingController _search = TextEditingController();

  List<Map<String, dynamic>> _records = [];
  bool _loading = true;
  String? _error;
  String _statusFilter = 'all';
  String _domainFilter = 'all';
  String _windowFilter = '90';
  String _searchText = '';
  Set<String> _overlapIds = <String>{};
  DateTime _today = DateUtils.dateOnly(DateTime.now());

  static const Color _background = Color(0xFF061426);
  static const Color _panel = Color(0xFF10243A);
  static const Color _border = Color(0xFF25415E);
  static const Color _accent = Color(0xFF35C6B5);
  static const Color _muted = Color(0xFFB6C7D6);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  DateTime? _date(dynamic value) {
    if (value == null) return null;
    final parsed = DateTime.tryParse(value.toString());
    return parsed == null ? null : DateUtils.dateOnly(parsed);
  }

  String _text(Map<String, dynamic> row, String key,
      [String fallback = 'Not provided']) {
    final value = row[key]?.toString().trim() ?? '';
    return value.isEmpty ? fallback : value;
  }

  String _label(String value) =>
      value.replaceAll('_', ' ').split(' ').map((word) {
        if (word.isEmpty) return word;
        return word[0].toUpperCase() + word.substring(1);
      }).join(' ');

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      const pageSize = 250;
      const maxRows = 2000;
      final rows = <Map<String, dynamic>>[];
      for (var offset = 0; offset < maxRows; offset += pageSize) {
        final page = await _db
            .from('excavation_requests')
            .select(
              'id,request_number,title,status,case_category,work_activity,'
              'road_name,city,latitude,longitude,planned_start_date,'
              'planned_end_date,created_at',
            )
            .order('planned_start_date', ascending: true)
            .order('created_at', ascending: false)
            .range(offset, offset + pageSize - 1);
        final batch = List<Map<String, dynamic>>.from(page);
        rows.addAll(batch);
        if (batch.length < pageSize) break;
      }
      if (!mounted) return;
      setState(() {
        _records = rows;
        _overlapIds = _findPotentialOverlaps(rows);
        _loading = false;
      });
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'The schedule could not be loaded: ${e.message}';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'The schedule is unavailable. Check connectivity and account permissions.';
      });
    }
  }

  double _distanceMetres(Map<String, dynamic> a, Map<String, dynamic> b) {
    final lat1 = (a['latitude'] as num).toDouble() * math.pi / 180;
    final lat2 = (b['latitude'] as num).toDouble() * math.pi / 180;
    final dLat = lat2 - lat1;
    final dLon = ((b['longitude'] as num).toDouble() -
            (a['longitude'] as num).toDouble()) *
        math.pi /
        180;
    final h = math.pow(math.sin(dLat / 2), 2) +
        math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLon / 2), 2);
    return 6371000 * 2 * math.asin(math.sqrt(h));
  }

  Set<String> _findPotentialOverlaps(List<Map<String, dynamic>> rows) {
    final flagged = <String>{};
    final eligible = rows.where((row) {
      final status = _text(row, 'status', '').toLowerCase();
      return row['latitude'] is num &&
          row['longitude'] is num &&
          (row['latitude'] as num).abs() <= 90 &&
          (row['longitude'] as num).abs() <= 180 &&
          _date(row['planned_start_date']) != null &&
          !{'completed', 'resolved', 'rejected', 'cancelled'}.contains(status);
    }).take(700).toList();

    for (var i = 0; i < eligible.length; i++) {
      final a = eligible[i];
      final aStart = _date(a['planned_start_date'])!;
      final aEnd = _date(a['planned_end_date']) ?? aStart;
      for (var j = i + 1; j < eligible.length; j++) {
        final b = eligible[j];
        final bStart = _date(b['planned_start_date'])!;
        final bEnd = _date(b['planned_end_date']) ?? bStart;
        final datesOverlap =
            !aEnd.isBefore(bStart) && !bEnd.isBefore(aStart);
        if (!datesOverlap) continue;
        if (_distanceMetres(a, b) <= 100) {
          flagged.add(a['id'].toString());
          flagged.add(b['id'].toString());
        }
      }
    }
    return flagged;
  }

  List<Map<String, dynamic>> get _filtered {
    final now = _today;
    final horizon = _windowFilter == 'all'
        ? null
        : now.add(Duration(days: int.parse(_windowFilter)));
    final query = _searchText.trim().toLowerCase();

    return _records.where((row) {
      final start = _date(row['planned_start_date']);
      final end = _date(row['planned_end_date']) ?? start;
      if (start == null) return false;
      if (horizon != null && (end!.isBefore(now) || start.isAfter(horizon))) {
        return false;
      }
      if (_statusFilter != 'all' &&
          _text(row, 'status', '').toLowerCase() != _statusFilter) {
        return false;
      }
      if (_domainFilter != 'all' &&
          _text(row, 'case_category', 'legacy_excavation') != _domainFilter) {
        return false;
      }
      if (query.isNotEmpty) {
        final haystack = [
          _text(row, 'title', ''),
          _text(row, 'request_number', ''),
          _text(row, 'road_name', ''),
          _text(row, 'city', ''),
          _text(row, 'case_category', ''),
        ].join(' ').toLowerCase();
        if (!haystack.contains(query)) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => (_date(a['planned_start_date']) ?? _today)
          .compareTo(_date(b['planned_start_date']) ?? _today));
  }

  List<String> get _domains {
    final values = _records
        .map((row) => _text(row, 'case_category', 'legacy_excavation'))
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return values;
  }

  String _dateLabel(DateTime? date) {
    if (date == null) return 'Not scheduled';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Color _statusColor(String status) => switch (status.toLowerCase()) {
        'approved' || 'completed' || 'resolved' => const Color(0xFF41C98E),
        'rejected' || 'cancelled' => const Color(0xFFF16F79),
        'in_progress' => const Color(0xFFF5A64A),
        'under_review' => const Color(0xFFF0C56A),
        _ => const Color(0xFF62B8E8),
      };

  Widget _metric(String label, String value, IconData icon) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
          decoration: BoxDecoration(
            color: _panel,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: _border),
          ),
          child: Column(children: [
            Icon(icon, color: _accent, size: 19),
            const SizedBox(height: 7),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800)),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted, fontSize: 9)),
          ]),
        ),
      );

  Widget _filterDropdown({
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) =>
      DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: _panel,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(11)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: _border),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        ),
        dropdownColor: _panel,
        style: const TextStyle(color: Colors.white, fontSize: 12),
        items: items,
        onChanged: onChanged,
      );

  Widget _workCard(Map<String, dynamic> row) {
    final id = row['id'].toString();
    final status = _text(row, 'status', 'submitted');
    final start = _date(row['planned_start_date']);
    final end = _date(row['planned_end_date']);
    final overlap = _overlapIds.contains(id);
    final road = _text(row, 'road_name', '');
    final city = _text(row, 'city', '');
    final location = [road, city].where((x) => x.isNotEmpty).join(' · ');
    final category = _label(_text(row, 'case_category', 'legacy_excavation'));
    final activity = _label(_text(row, 'work_activity', 'Not specified'));

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: overlap ? const Color(0xFFB77A34) : _border,
          width: overlap ? 1.2 : 1,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(
              'CASE ${_text(row, 'request_number', id)}',
              style: const TextStyle(
                  color: _accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .5),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: _statusColor(status).withValues(alpha: .13),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(_label(status),
                style: TextStyle(
                    color: _statusColor(status),
                    fontSize: 9,
                    fontWeight: FontWeight.w800)),
          ),
        ]),
        const SizedBox(height: 9),
        Text(_text(row, 'title', 'Infrastructure work'),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        _detail(Icons.layers_outlined, '$category · $activity'),
        if (location.isNotEmpty) _detail(Icons.place_outlined, location),
        _detail(Icons.date_range_outlined,
            '${_dateLabel(start)} – ${_dateLabel(end)}'),
        if (overlap) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: const Color(0x22D99135),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFFFC36B), size: 17),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Potential nearby schedule overlap: another active work case is within 100 m and has overlapping planned dates. Coordinate with the responsible departments before scheduling.',
                    style: TextStyle(
                        color: Color(0xFFFFDDA8), fontSize: 10, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ]),
    );
  }

  Widget _detail(IconData icon, String value) => Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Row(children: [
          Icon(icon, color: _muted, size: 15),
          const SizedBox(width: 7),
          Expanded(
              child: Text(value,
                  style: const TextStyle(color: _muted, fontSize: 11))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final rows = _filtered;
    final flaggedVisible =
        rows.where((row) => _overlapIds.contains(row['id'].toString())).length;
    final active = rows
        .where((row) => !{'completed', 'resolved', 'rejected', 'cancelled'}
            .contains(_text(row, 'status', '').toLowerCase()))
        .length;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text('Coordinated Works Calendar'),
        actions: [
          IconButton(
            tooltip: 'Refresh schedule',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_outlined,
                            color: Color(0xFFF16F79), size: 38),
                        const SizedBox(height: 10),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white)),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF123B65), Color(0xFF075E72)],
                          ),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ONE PLAN · MULTIPLE DEPARTMENTS',
                                style: TextStyle(
                                    color: Color(0xFF9DECE1),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1)),
                            SizedBox(height: 7),
                            Text(
                              'See planned infrastructure works together to identify opportunities for joint scheduling and reduce repeated road openings.',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  height: 1.45),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        _metric('Scheduled', rows.length.toString(),
                            Icons.calendar_month_outlined),
                        const SizedBox(width: 8),
                        _metric('Active', active.toString(),
                            Icons.pending_actions_outlined),
                        const SizedBox(width: 8),
                        _metric('Potential overlaps', flaggedVisible.toString(),
                            Icons.warning_amber_outlined),
                      ]),
                      const SizedBox(height: 15),
                      TextField(
                        controller: _search,
                        onChanged: (value) =>
                            setState(() => _searchText = value),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search case, road, city or work type',
                          hintStyle:
                              const TextStyle(color: _muted, fontSize: 12),
                          prefixIcon:
                              const Icon(Icons.search, color: _accent),
                          filled: true,
                          fillColor: _panel,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(11)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                          child: _filterDropdown(
                            label: 'Planning window',
                            value: _windowFilter,
                            items: const [
                              DropdownMenuItem(
                                  value: '30', child: Text('Next 30 days')),
                              DropdownMenuItem(
                                  value: '90', child: Text('Next 90 days')),
                              DropdownMenuItem(
                                  value: 'all', child: Text('All dates')),
                            ],
                            onChanged: (v) =>
                                setState(() => _windowFilter = v ?? '90'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _filterDropdown(
                            label: 'Status',
                            value: _statusFilter,
                            items: const [
                              DropdownMenuItem(
                                  value: 'all', child: Text('All statuses')),
                              DropdownMenuItem(
                                  value: 'submitted', child: Text('Submitted')),
                              DropdownMenuItem(
                                  value: 'under_review',
                                  child: Text('Under review')),
                              DropdownMenuItem(
                                  value: 'approved', child: Text('Approved')),
                              DropdownMenuItem(
                                  value: 'in_progress',
                                  child: Text('In progress')),
                              DropdownMenuItem(
                                  value: 'completed', child: Text('Completed')),
                            ],
                            onChanged: (v) =>
                                setState(() => _statusFilter = v ?? 'all'),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      _filterDropdown(
                        label: 'Infrastructure domain',
                        value: _domainFilter,
                        items: [
                          const DropdownMenuItem(
                              value: 'all', child: Text('All domains')),
                          ..._domains.map((value) => DropdownMenuItem(
                                value: value,
                                child: Text(_label(value)),
                              )),
                        ],
                        onChanged: (v) =>
                            setState(() => _domainFilter = v ?? 'all'),
                      ),
                      const SizedBox(height: 15),
                      Row(children: [
                        const Expanded(
                          child: Text('PLANNED WORKS',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .7)),
                        ),
                        Text('${rows.length} records',
                            style: const TextStyle(
                                color: _muted, fontSize: 10)),
                      ]),
                      const SizedBox(height: 9),
                      if (rows.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: _panel,
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(color: _border),
                          ),
                          child: const Column(children: [
                            Icon(Icons.event_busy_outlined,
                                color: _accent, size: 32),
                            SizedBox(height: 9),
                            Text('No scheduled works match these filters.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white)),
                            SizedBox(height: 5),
                            Text(
                              'Only authenticated records visible to your account are shown. Cases without planned dates are excluded from this calendar.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: _muted, fontSize: 10, height: 1.4),
                            ),
                          ]),
                        )
                      else
                        ...rows.map(_workCard),
                      const SizedBox(height: 8),
                      const Text(
                        'Planning advisory only. Nearby cases are flagged using their submitted coordinates and planned dates; this is not a verified utility conflict, permit approval, site-safety clearance or proof that two works can be combined. Confirm with each asset owner and competent authority.',
                        style: TextStyle(
                            color: _muted, fontSize: 9, height: 1.45),
                      ),
                    ],
                  ),
                ),
    );
  }
}

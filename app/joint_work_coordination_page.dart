import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Coordinates a proposed shared work window across cases and departments.
/// This is a planning workflow only; it does not grant a permit or site clearance.
class JointWorkCoordinationPage extends StatefulWidget {
  const JointWorkCoordinationPage({super.key});

  @override
  State<JointWorkCoordinationPage> createState() =>
      _JointWorkCoordinationPageState();
}

class _JointWorkCoordinationPageState extends State<JointWorkCoordinationPage> {
  final SupabaseClient _db = Supabase.instance.client;

  bool _loading = true;
  bool _working = false;
  String? _error;
  String _role = '';
  String? _departmentId;
  List<Map<String, dynamic>> _cases = [];
  List<Map<String, dynamic>> _proposals = [];
  List<Map<String, dynamic>> _responses = [];
  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _departments = [];

  bool get _canCoordinate => _role == 'admin' || _role == 'coordinator';

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _value(Map<String, dynamic> row, String key,
      [String fallback = 'Not provided']) {
    final raw = row[key];
    if (raw == null || raw.toString().trim().isEmpty) return fallback;
    return raw.toString();
  }

  String _label(String value) => value.replaceAll('_', ' ').split(' ').map(
        (word) => word.isEmpty
            ? word
            : word[0].toUpperCase() + word.substring(1),
      ).join(' ');

  String _dateLabel(dynamic raw) {
    if (raw == null) return 'Not set';
    final date = DateTime.tryParse(raw.toString());
    if (date == null) return raw.toString();
    return date.day.toString().padLeft(2, '0') + '/' +
        date.month.toString().padLeft(2, '0') + '/' +
        date.year.toString();
  }

  String _caseLabel(String id) {
    final match = _cases.where((item) => item['id'].toString() == id);
    if (match.isEmpty) return 'Related case (' + id.substring(0, 8) + ')';
    final item = match.first;
    return 'Case #' + _value(item, 'request_number', id.substring(0, 8)) +
        ' · ' + _value(item, 'title', 'Infrastructure work');
  }

  String _departmentLabel(String id) {
    final match = _departments.where((item) => item['id'].toString() == id);
    return match.isEmpty ? 'Department' : _value(match.first, 'name');
  }

  List<Map<String, dynamic>> _responsesFor(String proposalId) =>
      _responses.where((item) => item['proposal_id'].toString() == proposalId).toList();

  List<Map<String, dynamic>> _eventsFor(String proposalId) =>
      _events.where((item) => item['proposal_id'].toString() == proposalId).toList();

  Map<String, dynamic>? _myResponse(String proposalId) {
    if (_departmentId == null) return null;
    final matches = _responses.where((item) =>
        item['proposal_id'].toString() == proposalId &&
        item['department_id'].toString() == _departmentId);
    return matches.isEmpty ? null : matches.first;
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = _db.auth.currentUser;
      if (user == null) throw StateError('Your session has expired. Sign in again.');

      final profile = await _db.from('profiles')
          .select('role,department_id')
          .eq('id', user.id)
          .maybeSingle();
      _role = (profile?['role'] ?? '').toString();
      _departmentId = profile?['department_id']?.toString();

      if (!_canCoordinate && _role != 'department') {
        throw StateError('This workspace is available to department officers, coordinators and administrators.');
      }

      final rawCases = await _db.from('excavation_requests')
          .select('id,request_number,title,status,case_category,city,road_name,planned_start_date,planned_end_date')
          .order('created_at', ascending: false)
          .limit(300);
      final rawProposals = await _db.from('case_joint_work_proposals')
          .select('id,primary_request_id,related_request_id,created_by,proposal_status,reason,proposed_start_on,proposed_end_on,scheduled_start_on,scheduled_end_on,coordinator_remarks,created_at,finalised_at')
          .order('created_at', ascending: false)
          .limit(100);
      final proposals = List<Map<String, dynamic>>.from(rawProposals);
      final proposalIds = proposals.map((item) => item['id'].toString()).toList();

      List<Map<String, dynamic>> responses = [];
      List<Map<String, dynamic>> events = [];
      if (proposalIds.isNotEmpty) {
        final rawResponses = await _db.from('case_joint_work_responses')
            .select('id,proposal_id,department_id,response_status,response_remarks,responded_at')
            .inFilter('proposal_id', proposalIds)
            .order('created_at');
        responses = List<Map<String, dynamic>>.from(rawResponses);

        final rawEvents = await _db.from('case_joint_work_events')
            .select('id,proposal_id,actor_id,event_type,details,created_at')
            .inFilter('proposal_id', proposalIds)
            .order('created_at', ascending: false);
        events = List<Map<String, dynamic>>.from(rawEvents);
      }

      final rawDepartments = await _db.from('departments')
          .select('id,name')
          .order('name');
      if (!mounted) return;
      setState(() {
        _cases = List<Map<String, dynamic>>.from(rawCases);
        _proposals = proposals;
        _responses = responses;
        _events = events;
        _departments = List<Map<String, dynamic>>.from(rawDepartments);
        _loading = false;
      });
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Joint-work data could not be loaded: ' + e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<DateTime?> _pickDate(
    DateTime? current, {
    DateTime? minimum,
  }) {
    final today = DateUtils.dateOnly(DateTime.now());
    final firstDate = DateUtils.dateOnly(minimum ?? today);
    final requested = DateUtils.dateOnly(current ?? firstDate);
    final initial = requested.isBefore(firstDate) ? firstDate : requested;
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: DateTime(today.year + 5),
    );
  }

  Future<void> _createProposal() async {
    if (!_canCoordinate) return;
    if (_cases.length < 2) {
      _toast('At least two visible infrastructure cases are required.');
      return;
    }
    String firstId = _cases.first['id'].toString();
    String secondId = _cases.firstWhere(
      (item) => item['id'].toString() != firstId,
    )['id'].toString();
    DateTime? proposedStart;
    DateTime? proposedEnd;
    final reason = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Propose coordinated work'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: firstId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'First case'),
                  items: _cases.map((item) => DropdownMenuItem<String>(
                    value: item['id'].toString(),
                    child: Text(_caseLabel(item['id'].toString()),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  )).toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() {
                      firstId = value;
                      if (firstId == secondId) {
                        secondId = _cases.firstWhere(
                          (item) => item['id'].toString() != firstId,
                        )['id'].toString();
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: secondId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Second case'),
                  items: _cases.where((item) => item['id'].toString() != firstId)
                      .map((item) => DropdownMenuItem<String>(
                        value: item['id'].toString(),
                        child: Text(_caseLabel(item['id'].toString()),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                      )).toList(),
                  onChanged: (value) {
                    if (value != null) setDialogState(() => secondId = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reason,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    labelText: 'Why should these cases be coordinated?',
                    hintText: 'Explain the shared work opportunity, location or timing.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: Text('Proposed window: ' +
                      _dateLabel(proposedStart) + ' – ' + _dateLabel(proposedEnd),
                      style: const TextStyle(fontSize: 11))),
                  IconButton(
                    tooltip: 'Choose proposed start date',
                    onPressed: () async {
                      final picked = await _pickDate(proposedStart);
                      if (picked != null) {
                        setDialogState(() {
                          proposedStart = picked;
                          if (proposedEnd != null && proposedEnd!.isBefore(picked)) {
                            proposedEnd = null;
                          }
                        });
                      }
                    },
                    icon: const Icon(Icons.calendar_month_outlined),
                  ),
                  IconButton(
                    tooltip: 'Choose proposed end date',
                    onPressed: () async {
                      final picked = await _pickDate(
                        proposedEnd ?? proposedStart,
                        minimum: proposedStart,
                      );
                      if (picked != null) setDialogState(() => proposedEnd = picked);
                    },
                    icon: const Icon(Icons.event_outlined),
                  ),
                ]),
                const Text(
                  'The proposed window is indicative. Each department must respond before a coordinator can record a shared schedule.',
                  style: TextStyle(fontSize: 10, color: Colors.black54),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (reason.text.trim().length < 10 ||
                    firstId == secondId ||
                    (proposedStart != null && proposedEnd != null &&
                        proposedEnd!.isBefore(proposedStart!))) {
                  return;
                }
                Navigator.pop(dialogContext, {
                  'first': firstId,
                  'second': secondId,
                  'reason': reason.text.trim(),
                  'start': proposedStart,
                  'end': proposedEnd,
                });
              },
              child: const Text('Send for department response'),
            ),
          ],
        ),
      ),
    );
    final reasonText = reason.text;
    reason.dispose();
    if (result == null) return;

    setState(() => _working = true);
    try {
      await _db.rpc('create_case_joint_work_proposal', params: {
        'p_primary_request_id': result['first'],
        'p_related_request_id': result['second'],
        'p_reason': reasonText,
        'p_proposed_start_on': (result['start'] as DateTime?)?.toIso8601String().split('T').first,
        'p_proposed_end_on': (result['end'] as DateTime?)?.toIso8601String().split('T').first,
      });
      _toast('Joint-work proposal sent to the assigned departments.');
      await _load();
    } on PostgrestException catch (e) {
      _toast('Proposal was not created: ' + e.message);
    } catch (_) {
      _toast('Unable to create the proposal. Check the database migration and your coordinator access.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _respond(Map<String, dynamic> proposal, String decision) async {
    final remarks = TextEditingController();
    final accepted = decision == 'accepted';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(accepted ? 'Accept joint-work proposal' : 'Decline joint-work proposal'),
        content: TextField(
          controller: remarks,
          minLines: 2,
          maxLines: 4,
          maxLength: 1500,
          decoration: const InputDecoration(
            labelText: 'Department remarks (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(accepted ? 'Confirm acceptance' : 'Confirm decline'),
          ),
        ],
      ),
    );
    final note = remarks.text.trim();
    remarks.dispose();
    if (confirm != true) return;

    setState(() => _working = true);
    try {
      await _db.rpc('respond_case_joint_work_proposal', params: {
        'p_proposal_id': proposal['id'].toString(),
        'p_response_status': decision,
        'p_remarks': note.isEmpty ? null : note,
      });
      _toast(accepted ? 'Department response recorded.' : 'Proposal declined by your department.');
      await _load();
    } on PostgrestException catch (e) {
      _toast('Response was not saved: ' + e.message);
    } catch (_) {
      _toast('Unable to submit the department response.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _finalise(Map<String, dynamic> proposal, String decision) async {
    DateTime? start;
    DateTime? end;
    final remarks = TextEditingController();
    final schedule = decision == 'schedule';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(schedule ? 'Record coordinated schedule' : 'Reject joint-work proposal'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (schedule) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Scheduled start'),
                    subtitle: Text(_dateLabel(start)),
                    trailing: IconButton(
                      icon: const Icon(Icons.calendar_month_outlined),
                      onPressed: () async {
                        final picked = await _pickDate(start);
                        if (picked != null) {
                          setDialogState(() {
                            start = picked;
                            if (end != null && end!.isBefore(picked)) end = null;
                          });
                        }
                      },
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Scheduled end'),
                    subtitle: Text(_dateLabel(end)),
                    trailing: IconButton(
                      icon: const Icon(Icons.event_outlined),
                      onPressed: () async {
                        final picked = await _pickDate(
                          end ?? start,
                          minimum: start,
                        );
                        if (picked != null) setDialogState(() => end = picked);
                      },
                    ),
                  ),
                ],
                TextField(
                  controller: remarks,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    labelText: 'Coordinator remarks',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (schedule)
                  const Text(
                    'This records a shared planning schedule only. It does not replace statutory permits, owner clearances or field verification.',
                    style: TextStyle(fontSize: 10, color: Colors.black54),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: schedule && (start == null || end == null || end!.isBefore(start!))
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: Text(schedule ? 'Confirm schedule' : 'Confirm rejection'),
            ),
          ],
        ),
      ),
    );
    final note = remarks.text.trim();
    remarks.dispose();
    if (confirm != true) return;

    setState(() => _working = true);
    try {
      await _db.rpc('finalise_case_joint_work_proposal', params: {
        'p_proposal_id': proposal['id'].toString(),
        'p_decision': decision,
        'p_scheduled_start_on': schedule ? start!.toIso8601String().split('T').first : null,
        'p_scheduled_end_on': schedule ? end!.toIso8601String().split('T').first : null,
        'p_remarks': note.isEmpty ? null : note,
      });
      _toast(schedule ? 'Shared work schedule recorded.' : 'Joint-work proposal rejected.');
      await _load();
    } on PostgrestException catch (e) {
      _toast('Decision was not saved: ' + e.message);
    } catch (_) {
      _toast('Unable to finalise the proposal.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'scheduled':
      case 'ready_for_coordinator':
        return Colors.green;
      case 'declined':
      case 'rejected_by_coordinator':
        return Colors.redAccent;
      default:
        return Colors.orange;
    }
  }

  Widget _proposalCard(Map<String, dynamic> proposal) {
    final id = proposal['id'].toString();
    final status = _value(proposal, 'proposal_status', 'pending_department_responses');
    final responses = _responsesFor(id);
    final mine = _myResponse(id);
    final primaryId = proposal['primary_request_id'].toString();
    final relatedId = proposal['related_request_id'].toString();
    final events = _eventsFor(id);
    final isOpen = !{'scheduled','rejected_by_coordinator','withdrawn','declined'}.contains(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text('JOINT-WORK PROPOSAL',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900,
                      letterSpacing: .8, color: Theme.of(context).colorScheme.secondary))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: _statusColor(status).withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(_label(status).toUpperCase(),
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
                        color: _statusColor(status))),
              ),
            ]),
            const SizedBox(height: 10),
            Text(_caseLabel(primaryId),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Icon(Icons.link, size: 17),
            ),
            Text(_caseLabel(relatedId),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text(_value(proposal, 'reason'),
                style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            Text('Proposed window: ' + _dateLabel(proposal['proposed_start_on']) +
                ' – ' + _dateLabel(proposal['proposed_end_on']),
                style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
            if (status == 'scheduled') ...[
              const SizedBox(height: 7),
              Text('Recorded schedule: ' + _dateLabel(proposal['scheduled_start_on']) +
                  ' – ' + _dateLabel(proposal['scheduled_end_on']),
                  style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.green)),
            ],
            if (_value(proposal, 'coordinator_remarks', '').isNotEmpty) ...[
              const SizedBox(height: 7),
              Text('Coordinator remarks: ' + _value(proposal, 'coordinator_remarks'),
                  style: const TextStyle(fontSize: 11)),
            ],
            const Divider(height: 22),
            const Text('DEPARTMENT RESPONSES',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .6)),
            const SizedBox(height: 6),
            ...responses.map((response) {
              final responseStatus = response['response_status'].toString();
              final departmentId = response['department_id'].toString();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  const Icon(Icons.account_balance_outlined, size: 15),
                  const SizedBox(width: 7),
                  Expanded(child: Text(_departmentLabel(departmentId),
                      style: const TextStyle(fontSize: 11))),
                  Text(_label(responseStatus),
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                          color: responseStatus == 'accepted' ? Colors.green :
                              responseStatus == 'declined' ? Colors.redAccent : Colors.orange)),
                ]),
              );
            }),
            if (mine != null && mine['response_status'] == 'pending' &&
                status == 'pending_department_responses') ...[
              const SizedBox(height: 12),
              const Text('Your department response is required.',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                FilledButton.icon(
                  onPressed: _working ? null : () => _respond(proposal, 'accepted'),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Accept'),
                ),
                OutlinedButton.icon(
                  onPressed: _working ? null : () => _respond(proposal, 'declined'),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Decline'),
                ),
              ]),
            ],
            if (_canCoordinate && status == 'ready_for_coordinator') ...[
              const SizedBox(height: 12),
              const Text('All participating departments have accepted. Final coordinator decision is pending.',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.green)),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _working ? null : () => _finalise(proposal, 'schedule'),
                icon: const Icon(Icons.event_available_outlined, size: 16),
                label: const Text('Record shared schedule'),
              ),
            ],
            if (_canCoordinate && isOpen) ...[
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: _working ? null : () => _finalise(proposal, 'reject'),
                icon: const Icon(Icons.block, size: 15),
                label: const Text('Reject proposal'),
              ),
            ],
            if (events.isNotEmpty) ...[
              const Divider(height: 20),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: const Text('Decision history',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                children: events.map((event) {
                  final date = DateTime.tryParse(event['created_at'].toString());
                  final dateText = date == null ? '' :
                      date.day.toString().padLeft(2, '0') + '/' +
                      date.month.toString().padLeft(2, '0') + '/' +
                      date.year.toString();
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.history, size: 16),
                    title: Text(_label(event['event_type'].toString()),
                        style: const TextStyle(fontSize: 11)),
                    subtitle: Text(dateText, style: const TextStyle(fontSize: 10)),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Joint-work coordination'),
        actions: [
          IconButton(
            tooltip: 'Refresh proposals',
            onPressed: _loading || _working ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: _canCoordinate
          ? FloatingActionButton.extended(
              onPressed: _working ? null : _createProposal,
              icon: const Icon(Icons.add_link),
              label: const Text('New proposal'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_outlined, size: 38),
                        const SizedBox(height: 10),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 95),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: const Color(0xFF102B40),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: const Color(0xFF294763)),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ONE LOCATION · COORDINATED DELIVERY',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900,
                                    letterSpacing: .8, color: Color(0xFF35D7C2))),
                            SizedBox(height: 8),
                            Text(
                              'Propose a shared work window across related cases. Participating departments record their responses, then an authorised coordinator records the final planning decision.',
                              style: TextStyle(fontSize: 12, height: 1.45),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: _metric('Proposals', _proposals.length.toString())),
                        const SizedBox(width: 8),
                        Expanded(child: _metric('Awaiting response',
                            _proposals.where((item) => item['proposal_status'] == 'pending_department_responses').length.toString())),
                        const SizedBox(width: 8),
                        Expanded(child: _metric('Scheduled',
                            _proposals.where((item) => item['proposal_status'] == 'scheduled').length.toString())),
                      ]),
                      const SizedBox(height: 16),
                      if (_proposals.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10243A),
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(color: const Color(0xFF25415E)),
                          ),
                          child: const Column(children: [
                            Icon(Icons.hub_outlined, size: 34, color: Color(0xFF35C6B5)),
                            SizedBox(height: 8),
                            Text('No joint-work proposals yet.',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                            SizedBox(height: 5),
                            Text('New proposals will appear here when a coordinator links two assigned cases.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 11, color: Color(0xFFB6C7D6))),
                          ]),
                        )
                      else
                        ..._proposals.map(_proposalCard),
                      const SizedBox(height: 12),
                      const Text(
                        'This workflow is a coordination aid. A scheduled proposal is not an excavation permit, utility-owner clearance, legal approval or safety certification. Existing statutory approvals, no-dig rules, owner clearances and field verification remain separate requirements.',
                        style: TextStyle(fontSize: 10, height: 1.45, color: Color(0xFFB6C7D6)),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _metric(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFF10243A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF25415E)),
      ),
      child: Column(children: [
        Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(label, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 9, color: Color(0xFFB6C7D6))),
      ]),
    );
  }
}

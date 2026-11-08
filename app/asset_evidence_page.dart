import 'package:crypto/crypto.dart' show sha256;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Color _evidenceNavy = Color(0xFF0B1728);
const Color _evidenceMuted = Color(0xFF718096);

class UtilityAssetEvidenceSubmissionPage extends StatefulWidget {
  const UtilityAssetEvidenceSubmissionPage({super.key});

  @override
  State<UtilityAssetEvidenceSubmissionPage> createState() =>
      _UtilityAssetEvidenceSubmissionPageState();
}

class _UtilityAssetEvidenceSubmissionPageState
    extends State<UtilityAssetEvidenceSubmissionPage> {
  final _db = Supabase.instance.client;
  bool _loading = true;
  bool _busy = false;
  String _errorMessage = '';
  List<Map<String, dynamic>> _assets = [];

  static const Map<String, String> _methods = {
    'ground_penetrating_radar': 'Ground-penetrating radar',
    'electromagnetic_locator': 'Electromagnetic locator',
    'gnss_survey': 'GNSS survey',
    'as_built_review': 'As-built record review',
    'manual_inspection': 'Manual inspection',
    'other': 'Other authorised survey method',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _errorMessage = ''; });
    try {
      final response = await _db.functions.invoke(
        'samanvay-asset-evidence',
        body: {'action': 'list'},
      );
      if (response.status < 200 || response.status >= 300) {
        throw StateError('Evidence queue request failed.');
      }
      final payload = response.data;
      final rawItems = payload is Map ? payload['items'] : null;
      if (rawItems is! List) throw const FormatException('Invalid evidence queue response.');
      final rows = rawItems.whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item)).toList();
      if (!mounted) return;
      setState(() { _assets = rows; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Could not load submissions belonging to your assigned department.';
      });
    }
  }

  String _date(dynamic value) {
    if (value == null) return 'Not recorded';
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return 'Not recorded';
    return parsed.toLocal().toString().split(' ').first;
  }

  Color _statusColor(String status) {
    if (status == 'owner_confirmed') return const Color(0xFFE4F4E9);
    if (status == 'field_surveyed') return const Color(0xFFE6F0FB);
    if (status == 'disputed') return const Color(0xFFFFE8E8);
    return const Color(0xFFFFF0D7);
  }

  Future<Map<String, String>?> _collectMetadata() async {
    final surveyDate = TextEditingController(
      text: DateTime.now().toIso8601String().substring(0, 10),
    );
    final organisation = TextEditingController();
    final reference = TextEditingController();
    final notes = TextEditingController();
    var method = 'ground_penetrating_radar';
    try {
      return await showDialog<Map<String, String>>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialog) => AlertDialog(
            title: const Text('Record survey evidence reference'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter the survey details and official evidence reference. Keep the source document in your department’s authorised records system.',
                    style: TextStyle(fontSize: 12, color: _evidenceMuted, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: method,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Survey method', border: OutlineInputBorder()),
                    items: _methods.entries.map((entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value, maxLines: 2, overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (value) {
                      if (value != null) setDialog(() => method = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: surveyDate,
                    decoration: const InputDecoration(labelText: 'Survey date (YYYY-MM-DD)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: organisation,
                    maxLength: 200,
                    decoration: const InputDecoration(labelText: 'Surveyor organisation', border: OutlineInputBorder()),
                  ),
                  TextField(
                    controller: reference,
                    maxLength: 120,
                    decoration: const InputDecoration(labelText: 'Official evidence reference code', hintText: 'e.g. SURVEY-REF-2026-001', border: OutlineInputBorder()),
                  ),
                  TextField(
                    controller: notes,
                    minLines: 2,
                    maxLines: 3,
                    maxLength: 1000,
                    decoration: const InputDecoration(labelText: 'Non-sensitive notes (optional)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Do not enter coordinates, utility layouts, routes, depths, or excavation-clearance details.',
                    style: TextStyle(fontSize: 10, color: Color(0xFF9A6700), height: 1.35),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  final dateValue = surveyDate.text.trim();
                  final organisationValue = organisation.text.trim();
                  final referenceValue = reference.text.trim();
                  final notesValue = notes.text.trim();
                  final dateOk = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateValue);
                  final referenceOk = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._/-]{2,119}$').hasMatch(referenceValue);
                  if (!dateOk || organisationValue.length < 3 || !referenceOk || notesValue.length > 1000) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(content: Text('Enter a valid date, organisation and evidence reference code.')),
                    );
                    return;
                  }
                  Navigator.pop(dialogContext, {
                    'survey_method': method,
                    'survey_date': dateValue,
                    'surveyor_organisation': organisationValue,
                    'evidence_reference_code': referenceValue,
                    'notes': notesValue,
                  });
                },
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      );
    } finally {
      surveyDate.dispose();
      organisation.dispose();
      reference.dispose();
      notes.dispose();
    }
  }

  Future<void> _recordEvidence(Map<String, dynamic> asset) async {
    if (_busy) return;
    final metadata = await _collectMetadata();
    if (metadata == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      );
      if (file == null) return;
      final fileSize = file.lengthSync() ?? await file.length();
      if (fileSize == null || fileSize <= 0 || fileSize > 20 * 1024 * 1024) {
        throw StateError('Select a non-empty reference document no larger than 20 MB.');
      }
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty || bytes.length != fileSize) {
        throw StateError('The selected file could not be read completely.');
      }

      // Hash locally. The original document bytes are never uploaded or sent.
      final checksum = sha256.convert(bytes).toString();
      final response = await _db.functions.invoke(
        'samanvay-asset-evidence',
        body: {
          'action': 'submit',
          'asset_id': asset['asset_id'].toString(),
          ...metadata,
          'evidence_sha256': checksum,
        },
      );
      if (response.status < 200 || response.status >= 300) {
        throw StateError('Evidence metadata was not accepted.');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(
          'Evidence reference and checksum recorded. The original file remains in the owner department’s records system.',
        )),
      );
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(
          'Evidence reference could not be recorded. Check the department assignment, survey date and reference code.',
        )),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _assetCard(Map<String, dynamic> row) {
    final status = (row['verification_status'] ?? 'unverified').toString();
    final rawEvidence = row['evidence'] is List ? row['evidence'] as List : const [];
    final evidence = rawEvidence.whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item)).toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(
                (row['asset_type'] ?? 'unknown').toString().toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w900, color: _evidenceNavy),
              )),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(color: _statusColor(status), borderRadius: BorderRadius.circular(8)),
                child: Text(status.replaceAll('_', ' ').toUpperCase(),
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _evidenceNavy)),
              ),
            ]),
            const SizedBox(height: 6),
            Text(
              'Submission created: ${_date(row['created_at'])} · Evidence references: ${row['evidence_count'] ?? 0}',
              style: const TextStyle(fontSize: 11, color: _evidenceMuted),
            ),
            if (evidence.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(left: 8, right: 8, bottom: 6),
                title: const Text('Recorded survey references', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                subtitle: Text('${evidence.length} reference record(s)'),
                children: evidence.map((item) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text((item['evidence_reference_code'] ?? 'Reference').toString()),
                  subtitle: Text(
                    '${_methods[item['survey_method']] ?? item['survey_method']} · ${_date(item['survey_date'])}\nSHA-256: ${(item['evidence_sha256'] ?? '').toString()}',
                    style: const TextStyle(fontSize: 9, color: _evidenceMuted),
                  ),
                )).toList(),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => _recordEvidence(row),
                icon: const Icon(Icons.fingerprint_outlined),
                label: const Text('Record survey evidence reference'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Department survey evidence'),
        actions: [
          IconButton(onPressed: _loading || _busy ? null : _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('OWNER-DEPARTMENT EVIDENCE REGISTER',
                            style: TextStyle(fontWeight: FontWeight.w900, color: _evidenceNavy)),
                          SizedBox(height: 7),
                          Text(
                            'Select an eligible submission, enter survey details and choose the source document so its SHA-256 checksum can be calculated locally. The document itself is not uploaded. SAMANVAY stores only the reference code, checksum and non-sensitive metadata.',
                            style: TextStyle(fontSize: 11, color: _evidenceMuted, height: 1.45),
                          ),
                          SizedBox(height: 7),
                          Text(
                            'Keep the original file in your department’s authorised records system. Do not submit utility maps, coordinates, routes, depths or excavation-clearance information.',
                            style: TextStyle(fontSize: 10, color: Color(0xFF9A6700), height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_errorMessage.isNotEmpty)
                    Card(child: Padding(padding: const EdgeInsets.all(14), child: Text(_errorMessage)))
                  else if (_assets.isEmpty)
                    const Card(child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text(
                        'No eligible asset submissions are currently assigned to this department. An authorised owner account must register assets first.',
                        style: TextStyle(height: 1.4),
                      ),
                    ))
                  else ...[
                    Text('${_assets.length} eligible submission(s)',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: _evidenceNavy)),
                    const SizedBox(height: 9),
                    ..._assets.map(_assetCard),
                  ],
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.all(10),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
    );
  }
}

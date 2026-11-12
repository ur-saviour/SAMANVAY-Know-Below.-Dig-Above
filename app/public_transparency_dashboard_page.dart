import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class PublicTransparencyDashboardPage extends StatefulWidget {
  const PublicTransparencyDashboardPage({
    super.key, required this.client, required this.onOpenMap, required this.onOpenNotices,
  });
  final SupabaseClient client;
  final VoidCallback onOpenMap;
  final VoidCallback onOpenNotices;
  @override
  State<PublicTransparencyDashboardPage> createState() => _PublicTransparencyDashboardPageState();
}

class _PublicTransparencyDashboardPageState extends State<PublicTransparencyDashboardPage> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> notices = [];
  Color get ink => Theme.of(context).brightness == Brightness.light ? Colors.black : const Color(0xFFEAF2FA);
  Color get muted => Theme.of(context).brightness == Brightness.light ? const Color(0xFF242424) : const Color(0xFFA9BACB);
  Color get panel => Theme.of(context).colorScheme.surface;
  Color get line => Theme.of(context).brightness == Brightness.light ? const Color(0xFFD8E1E9) : const Color(0xFF29435E);

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    if (mounted) setState(() { loading = true; error = null; });
    try {
      final result = await widget.client.from('public_excavation_notices')
        .select('notice_code,title,notice_type,summary,city,starts_on,ends_on,progress_percent,notice_status,responsible_department_name,source_reference,source_url,published_at')
        .inFilter('notice_status', ['published', 'active', 'completed'])
        .order('starts_on', ascending: false).limit(250);
      if (!mounted) return;
      setState(() {
        notices = List<Map<String, dynamic>>.from(result);
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { loading = false; error = 'Published data is unavailable. Pull down to retry.'; });
    }
  }

  int get active => notices.where((e) =>
    ['published', 'active'].contains((e['notice_status'] ?? '').toString().toLowerCase())).length;

  Map<String, int> get activity {
    final result = <String, int>{};
    for (final row in notices) {
      final name = (row['responsible_department_name'] ?? 'Department not stated').toString();
      result[name] = (result[name] ?? 0) + 1;
    }
    return result;
  }

  int get publicDepartmentCount => activity.keys
    .where((name) => name.trim().isNotEmpty && name != 'Department not stated')
    .length;

  Widget heading(String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: GoogleFonts.spaceGrotesk(color: ink, fontSize: 18, fontWeight: FontWeight.w900)),
      const SizedBox(height: 3),
      Text(subtitle, style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w600)),
    ]),
  );

  Widget metric(String value, String title, String note, IconData icon, Color accent) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(15), border: Border.all(color: line)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: accent, size: 21), const SizedBox(height: 9),
      Text(value, style: GoogleFonts.spaceGrotesk(color: ink, fontSize: 24, fontWeight: FontWeight.w900)),
      const SizedBox(height: 3),
      Text(title, style: TextStyle(color: ink, fontSize: 10, fontWeight: FontWeight.w900)),
      const SizedBox(height: 5),
      Text(note, style: TextStyle(color: muted, fontSize: 9, height: 1.35, fontWeight: FontWeight.w600)),
    ]),
  );

  Widget panelCard(Widget child) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(16), border: Border.all(color: line)),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final items = activity.entries.toList()..sort((a,b) => b.value.compareTo(a.value));
    final maxValue = items.isEmpty ? 1 : items.first.value;
    final light = Theme.of(context).brightness == Brightness.light;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Public works register'),
        actions: [IconButton(tooltip: 'Refresh', onPressed: loading ? null : load, icon: const Icon(Icons.refresh_rounded))]),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 15, 16, 28), children: [
          Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF071A32), Color(0xFF104563), Color(0xFF075B62)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0x5544D7CE))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                ClipRRect(borderRadius: BorderRadius.circular(11),
                  child: Image.asset('assets/brand/samanvay_logo.jpg', width: 48, height: 48, fit: BoxFit.cover)),
                const SizedBox(width: 10),
                const Expanded(child: Text('SAMANVAY PUBLIC WORKS REGISTER',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .5))),
                const Icon(Icons.public_rounded, color: Color(0xFF54D9F2)),
              ]),
              const SizedBox(height: 13),
              const Text('TOWARDS OUR DEVELOPMENT 📈',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
              const SizedBox(height: 7),
              const Text('Authority-published notices and source-linked progress updates currently shared through SAMANVAY. This is not a complete government works inventory.',
                style: TextStyle(color: Color(0xFFD6E7F2), fontSize: 11, height: 1.45)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton.icon(onPressed: widget.onOpenMap, icon: const Icon(Icons.layers_outlined, size: 16),
                  label: const Text('OPEN PUBLIC 3D GIS MAP'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Color(0x887FE7E0)))),
                OutlinedButton.icon(onPressed: widget.onOpenNotices, icon: const Icon(Icons.campaign_outlined, size: 16),
                  label: const Text('PUBLIC NOTICES'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Color(0x887FE7E0)))),
              ]),
            ]),
          ),
          const SizedBox(height: 20),
          heading('Public impact indicators', 'Counts use only notices currently published to SAMANVAY; they are not national totals.'),
          if (loading) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
          else ...[
            LayoutBuilder(builder: (context, c) {
              final cols = c.maxWidth > 720 ? 4 : 2;
              const gap = 9.0;
              final w = (c.maxWidth - gap * (cols - 1)) / cols;
              return Wrap(spacing: gap, runSpacing: gap, children: [
                SizedBox(width:w, child: metric(active.toString(), 'ACTIVE NOTICES', 'Published and active notices', Icons.construction_rounded, const Color(0xFF20BFA8))),
                SizedBox(width:w, child: metric('—', 'AVOIDED EXCAVATIONS', 'Awaiting verified joint-work closure outcomes', Icons.layers_clear_rounded, const Color(0xFF60A5FA))),
                SizedBox(width:w, child: metric('—', 'PUBLIC FUNDS SAVED', 'Awaiting approved cost baselines and evidence', Icons.account_balance_wallet_outlined, const Color(0xFF34D399))),
                SizedBox(width:w, child: metric('—', 'COORDINATION RATE', 'No completed public assessments yet', Icons.hub_outlined, const Color(0xFFF59E0B))),
              ]);
            }),
            const SizedBox(height: 20),
            heading('Department coordination & activity', 'Published public notices grouped by department as named in each notice.'),
            panelCard(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('Departments named in published notices', style: TextStyle(color: ink, fontWeight: FontWeight.w900))),
                Text(publicDepartmentCount.toString(), style: GoogleFonts.robotoMono(color: ink, fontSize: 19, fontWeight: FontWeight.w900)),
              ]),
              const SizedBox(height: 10),
              if (items.isEmpty)
                Text('No departmental activity has been published yet. Draft notices and internal workloads are excluded from this public view.',
                  style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w600, height: 1.45))
              else ...items.take(10).map((e) => Padding(
                padding: const EdgeInsets.only(top: 9),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(e.key, style: TextStyle(color: ink, fontSize: 11, fontWeight: FontWeight.w800))),
                    Text(e.value.toString(), style: GoogleFonts.robotoMono(color: ink, fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 5),
                  ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(
                    value: e.value / maxValue, minHeight: 7,
                    backgroundColor: light ? const Color(0xFFE6EBF0) : const Color(0xFF26394C),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF20BFA8)))),
                ]),
              )),
              const SizedBox(height: 9),
              Text('Department count is derived only from published notices shown here. Internal department records and draft notices are excluded.',
                style: TextStyle(color: muted, fontSize: 9, fontWeight: FontWeight.w600)),
            ])),
            const SizedBox(height: 20),
            heading('Published public works notices', 'Only records with a public status and publication timestamp are shown.'),
            if (notices.isEmpty)
              panelCard(Text('No authority-published project notices are available in SAMANVAY at present. The current draft remains private and is excluded from the public register.',
                style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w600, height: 1.45)))
            else ...notices.map((row) {
              final progress = (row['progress_percent'] as num?)?.toDouble();
              final source = (row['source_url'] ?? '').toString();
              return Padding(padding: const EdgeInsets.only(bottom: 9), child: panelCard(Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text((row['title'] ?? 'Public works notice').toString(),
                    style: TextStyle(color: ink, fontSize: 13, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 5),
                  Text((row['city'] ?? 'Location not stated').toString() + ' • ' +
                    (row['responsible_department_name'] ?? 'Department not stated').toString(),
                    style: TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w700)),
                  if (progress != null) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: (progress / 100).clamp(0.0, 1.0).toDouble(), minHeight: 7),
                  ],
                  const SizedBox(height: 8),
                  Text('Status: ' + (row['notice_status'] ?? '').toString() +
                    ' • Starts: ' + (row['starts_on'] ?? 'Not stated').toString() +
                    ' • Source: ' + (row['source_reference'] ?? 'Not stated').toString(),
                    style: TextStyle(color: muted, fontSize: 9, height: 1.4)),
                  if (source.startsWith('https://'))
                    TextButton.icon(onPressed: () => launchUrl(Uri.parse(source), mode: LaunchMode.externalApplication),
                      icon: const Icon(Icons.open_in_new_rounded, size: 15), label: const Text('Open official source')),
                ],
              )));
            }),
            const SizedBox(height: 14),
            panelCard(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.verified_user_outlined, color: Color(0xFF22A06B), size: 19),
                const SizedBox(width: 8),
                Expanded(child: Text('Data integrity and public accountability',
                  style: TextStyle(color: ink, fontWeight: FontWeight.w900, fontSize: 12))),
              ]),
              const SizedBox(height: 7),
              Text('Funds saved, avoided excavations and coordination percentages are not estimated from assumptions. They appear only after the relevant authority publishes an auditable baseline, decision and outcome. Unpublished and draft records are never counted.',
                style: TextStyle(color: muted, fontSize: 10, height: 1.5, fontWeight: FontWeight.w600)),
            ])),
          ],
          if (error != null) ...[const SizedBox(height: 12), Text(error!, style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.w700))],
        ]),
      ),
    );
  }
}

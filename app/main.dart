import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

const String supabaseUrl =
    String.fromEnvironment('SUPABASE_URL');

const String supabasePublishableKey =
    String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) {
    throw StateError(
      'Supabase configuration is missing. '
      'Check your GitHub Actions secrets.',
    );
  }

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );

  runApp(const SamanvayApp());
}

final supabase = Supabase.instance.client;

const Color navy = Color(0xFF0B1728);
const Color teal = Color(0xFF20D6C2);
const Color background = Color(0xFFF2F6FA);
const Color ink = Color(0xFF14243A);
const Color mutedInk = Color(0xFF718096);

class SamanvayApp extends StatelessWidget {
  const SamanvayApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: teal,
        brightness: Brightness.light,
        primary: const Color(0xFF087F83),
        surface: Colors.white,
      ),
      fontFamily: 'Inter',
      appBarTheme: AppBarTheme(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: GoogleFonts.spaceGrotesk(
          color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        color: Colors.white, elevation: 0, margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFE4EAF1))),
      ),
    );
    return MaterialApp(
      title: 'SAMANVAY — Know Below. Dig Above.',
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: const AuthGate(),
    );
  }
}

// ==========================================
// AUTHENTICATION GATE
// ==========================================

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.hasData
            ? snapshot.data!.session
            : supabase.auth.currentSession;

        if (session == null) {
          return const AuthPage();
        }

        return const RoleGate();
      },
    );
  }
}

// ==========================================
// LOGIN, REGISTRATION AND EMAIL CONFIRMATION
// ==========================================

class RoleGate extends StatelessWidget {
  const RoleGate({super.key});

  Future<Map<String, dynamic>> _loadProfile() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw StateError('Session expired. Please log in again.');
    }

    final row = await supabase
        .from('profiles')
        .select('role, department_id, display_name')
        .eq('id', user.id)
        .maybeSingle();

    if (row == null) {
      throw StateError('Profile not found. Contact an administrator.');
    }

    return Map<String, dynamic>.from(row);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadProfile(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return _PortalError(
            message: snapshot.error.toString(),
          );
        }

        final profile = snapshot.data!;
        final role = (profile['role'] ?? '').toString().toLowerCase();
        final departmentId = profile['department_id']?.toString();

        switch (role) {
          case 'requester':
            return const MainScreen();

          case 'department':
            if (departmentId == null || departmentId.isEmpty) {
              return const _PortalError(
                message: 'No department assigned. Contact an administrator.',
              );
            }
            return DepartmentPortal(departmentId: departmentId);

          case 'coordinator':
            return const CoordinatorPortal();

          case 'admin':
            return const AdminPortal();

          default:
            return _PortalError(
              message: 'Unrecognized account role: $role',
            );
        }
      },
    );
  }
}

class _PortalError extends StatelessWidget {
  final String message;

  const _PortalError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SAMANVAY access')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.admin_panel_settings_outlined, size: 56),
              const SizedBox(height: 16),
              const Text(
                'Unable to open your portal',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () async {
                  await supabase.auth.signOut();
                },
                child: const Text('LOG OUT'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



class DepartmentPortal extends StatelessWidget {
  final String departmentId;

  const DepartmentPortal({
    super.key,
    required this.departmentId,
  });

  @override
  Widget build(BuildContext context) {
    return _OperationalPortal(
      title: 'Department Officer',
      subtitle: 'Review and respond to infrastructure cases assigned to your department.',
      icon: Icons.account_tree_outlined,
      departmentId: departmentId,
      isDepartment: true,
    );
  }
}

class CoordinatorPortal extends StatelessWidget {
  const CoordinatorPortal({super.key});

  @override
  Widget build(BuildContext context) {
    return const _OperationalPortal(
      title: 'Coordination Centre',
      subtitle: 'Coordinate infrastructure cases across departments.',
      icon: Icons.hub_outlined,
    );
  }
}

class AdminPortal extends StatelessWidget {
  const AdminPortal({super.key});

  @override
  Widget build(BuildContext context) {
    return const _OperationalPortal(
      title: 'Platform Administration',
      subtitle: 'Monitor cases and manage department coordination.',
      icon: Icons.admin_panel_settings_outlined,
      isAdmin: true,
    );
  }
}

class _OperationalPortal extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String? departmentId;
  final bool isDepartment;
  final bool isAdmin;

  const _OperationalPortal({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.departmentId,
    this.isDepartment = false,
    this.isAdmin = false,
  });

  @override
  State<_OperationalPortal> createState() =>
      _OperationalPortalState();
}

class _OperationalPortalState extends State<_OperationalPortal> {
  StreamSubscription<List<Map<String, dynamic>>>? _requestEvents;
  StreamSubscription<List<Map<String, dynamic>>>? _reviewEvents;
  List<Map<String, dynamic>> requests = [];
  List<Map<String, dynamic>> departments = [];
  Map<String, List<Map<String, dynamic>>> reviewsByRequest = {};

  bool loading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    loadRequests();
    _startRealtimeUpdates();
  }

  void _startRealtimeUpdates() {
    _requestEvents = supabase
        .from('excavation_requests')
        .stream(primaryKey: ['id'])
        .listen((_) {
      if (mounted) loadRequests();
    }, onError: (_) {
      if (mounted) notify('Live case updates are temporarily unavailable.');
    });

    _reviewEvents = supabase
        .from('request_department_reviews')
        .stream(primaryKey: ['id'])
        .listen((_) {
      if (mounted) loadRequests();
    }, onError: (_) {
      if (mounted) notify('Live department-review updates are temporarily unavailable.');
    });
  }

  @override
  void dispose() {
    _requestEvents?.cancel();
    _reviewEvents?.cancel();
    super.dispose();
  }

  void notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> loadRequests() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      errorMessage = '';
    });

    try {
      final Map<String, List<Map<String, dynamic>>> groupedReviews = {};
      List<Map<String, dynamic>> loadedRequests = [];
      List<Map<String, dynamic>> loadedDepartments = [];

      if (widget.isDepartment) {
        final rawReviews = await supabase
            .from('request_department_reviews')
            .select(
              'id,request_id,department_id,review_status,remarks,assigned_at,reviewed_at',
            )
            .eq('department_id', widget.departmentId!)
            .order('assigned_at', ascending: false)
            .limit(200);

        final reviewRows =
            List<Map<String, dynamic>>.from(rawReviews);

        for (final review in reviewRows) {
          final requestId = review['request_id'].toString();
          groupedReviews.putIfAbsent(requestId, () => []);
          groupedReviews[requestId]!.add(review);
        }

        final requestIds = reviewRows
            .map((review) => review['request_id'].toString())
            .toSet()
            .toList();

        if (requestIds.isNotEmpty) {
          final rawRequests = await supabase
              .from('excavation_requests')
              .select()
              .inFilter('id', requestIds)
              .order('created_at', ascending: false)
              .limit(200);

          loadedRequests =
              List<Map<String, dynamic>>.from(rawRequests);
        }
      } else {
        final rawRequests = await supabase
            .from('excavation_requests')
            .select()
            .order('created_at', ascending: false)
            .limit(200);

        loadedRequests =
            List<Map<String, dynamic>>.from(rawRequests);

        final rawReviews = await supabase
            .from('request_department_reviews')
            .select(
              'id,request_id,department_id,review_status,remarks,assigned_at,reviewed_at',
            )
            .order('assigned_at', ascending: false)
            .limit(500);

        final reviewRows =
            List<Map<String, dynamic>>.from(rawReviews);

        for (final review in reviewRows) {
          final requestId = review['request_id'].toString();
          groupedReviews.putIfAbsent(requestId, () => []);
          groupedReviews[requestId]!.add(review);
        }

        final rawDepartments = await supabase
            .from('departments')
            .select('id,name')
            .order('name');

        loadedDepartments =
            List<Map<String, dynamic>>.from(rawDepartments);
      }

      if (!mounted) return;

      setState(() {
        requests = loadedRequests;
        departments = loadedDepartments;
        reviewsByRequest = groupedReviews;
        loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        loading = false;
        errorMessage =
            'Unable to load records. Check your connection and account permissions.';
      });
    }
  }

  String valueOf(
    Map<String, dynamic> item,
    String key, {
    String fallback = 'Not provided',
  }) {
    final value = item[key];
    if (value == null || value.toString().trim().isEmpty) {
      return fallback;
    }
    return value.toString();
  }

  String departmentName(String id) {
    for (final department in departments) {
      if (department['id'].toString() == id) {
        return department['name'].toString();
      }
    }
    return 'Department';
  }

  int countStatus(String status) {
    return requests.where((item) {
      return valueOf(item, 'status', fallback: '')
              .toLowerCase() ==
          status.toLowerCase();
    }).length;
  }

  Widget domainBreakdown() {
    final counts = <String, int>{};
    for (final request in requests) {
      final category = valueOf(
        request,
        'case_category',
        fallback: 'legacy_excavation',
      );
      counts[category] = (counts[category] ?? 0) + 1;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(15),
          child: Text('Domain analytics will appear as cases are registered.'),
        ),
      );
    }
    final maxCount = entries.first.value;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cases by infrastructure domain',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: navy)),
            const SizedBox(height: 12),
            ...entries.take(6).map((entry) {
              final value = maxCount == 0 ? 0.0 : entry.value / maxCount;
              final label = entry.key.replaceAll('_', ' ').toUpperCase();
              return Padding(
                padding: const EdgeInsets.only(bottom: 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(label,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700))),
                        Text(entry.value.toString(),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        value: value,
                        minHeight: 7,
                        backgroundColor: const Color(0xFFE7EDF2),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF20AFA5)),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _executiveMetricCard({
    required String title,
    required String value,
    required String note,
    required IconData icon,
    required Color accent,
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFFE1EAF1)),
          boxShadow: const [
            BoxShadow(color: Color(0x0D0B1728), blurRadius: 12, offset: Offset(0, 5)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: accent, size: 20),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title.toUpperCase(), style: const TextStyle(
                    color: mutedInk, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.65)),
                  const SizedBox(height: 7),
                  Text(value, style: GoogleFonts.robotoMono(
                    color: navy, fontSize: value.length > 11 ? 14 : 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  Text(note, style: const TextStyle(color: mutedInk, fontSize: 10, height: 1.35)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget executiveSnapshot() {
    final activeCases = requests.where((item) {
      final status = valueOf(item, 'status', fallback: '').toLowerCase();
      return ['approved', 'in_progress', 'active'].contains(status);
    }).length;

    final allReviews = reviewsByRequest.values.expand((rows) => rows);
    final pendingResponses = allReviews.where((review) {
      final status = valueOf(review, 'review_status', fallback: 'pending').toLowerCase();
      return ['pending', 'submitted', 'under_review', 'clarification_required'].contains(status);
    }).length;

    final multiDepartmentCases = requests.where((request) {
      final id = request['id'].toString();
      final assigned = (reviewsByRequest[id] ?? [])
          .map((review) => review['department_id'].toString())
          .toSet();
      return assigned.length >= 2;
    }).length;

    final conflictRequestIds = <String>{};
    for (final request in requests) {
      if (valueOf(request, 'status', fallback: '').toLowerCase() == 'conflict_detected') {
        conflictRequestIds.add(request['id'].toString());
      }
    }
    for (final rows in reviewsByRequest.values) {
      for (final review in rows) {
        if (valueOf(review, 'review_status', fallback: '').toLowerCase() == 'conflict_detected') {
          conflictRequestIds.add(review['request_id'].toString());
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Executive operations snapshot',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: navy)),
        const SizedBox(height: 4),
        const Text('Calculated from cases and department reviews visible to this account.',
          style: TextStyle(color: mutedInk, fontSize: 11)),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 10.0;
            final columns = constraints.maxWidth >= 1050
                ? 4
                : constraints.maxWidth >= 560
                    ? 2
                    : 1;
            final cardWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                _executiveMetricCard(
                  title: 'Active works / cases', value: activeCases.toString(),
                  note: 'Approved or currently in progress',
                  icon: Icons.engineering_outlined, accent: const Color(0xFF087F83), width: cardWidth),
                _executiveMetricCard(
                  title: 'Pending department responses', value: pendingResponses.toString(),
                  note: 'Pending, under review or clarification',
                  icon: Icons.hourglass_top_rounded, accent: const Color(0xFFD28A28), width: cardWidth),
                _executiveMetricCard(
                  title: 'Multi-department cases', value: multiDepartmentCases.toString(),
                  note: 'Two or more departments assigned',
                  icon: Icons.account_tree_outlined, accent: const Color(0xFF3978B8), width: cardWidth),
                _executiveMetricCard(
                  title: 'Officer-flagged conflicts', value: conflictRequestIds.length.toString(),
                  note: 'Recorded case or review status flags',
                  icon: Icons.warning_amber_rounded, accent: const Color(0xFFC34C4C), width: cardWidth),
                _executiveMetricCard(
                  title: 'Avoided excavation / public savings', value: 'Not measured',
                  note: 'Requires verified joint-work outcomes and approved cost baselines; no estimate is inferred.',
                  icon: Icons.savings_outlined, accent: const Color(0xFF64748B), width: cardWidth),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'completed':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'conflict_detected':
      case 'clarification_required':
      case 'under_review':
      case 'in_progress':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  Widget metric(String label, int value, IconData icon) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: navy, size: 22),
              const SizedBox(height: 8),
              Text(
                value.toString(),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: navy,
                ),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget statusLabel(String status) {
    final color = statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  List<String> allowedTransitions(String current) {
    switch (current.toLowerCase()) {
      case 'draft':
        return ['submitted'];
      case 'submitted':
        return [
          'under_review',
          'rejected',
          'conflict_detected',
        ];
      case 'under_review':
        return [
          'approved',
          'rejected',
          'conflict_detected',
        ];
      case 'conflict_detected':
        return [
          'under_review',
          'approved',
          'rejected',
        ];
      case 'approved':
        return [
          'completed',
          'conflict_detected',
        ];
      default:
        return [];
    }
  }

  Future<void> showDepartmentReview(
    Map<String, dynamic> review,
  ) async {
    final current = valueOf(
      review,
      'review_status',
      fallback: 'pending',
    );

    if (current == 'approved' || current == 'rejected') {
      notify('This review is already finalised.');
      return;
    }

    final remarksController = TextEditingController(
      text: review['remarks']?.toString() ?? '',
    );

    String selectedStatus = 'under_review';

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Department review'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select your department response.',
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedStatus,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Review decision',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'under_review',
                          child: Text('Under review'),
                        ),
                        DropdownMenuItem(
                          value: 'approved',
                          child: Text('Approved'),
                        ),
                        DropdownMenuItem(
                          value: 'rejected',
                          child: Text('Rejected'),
                        ),
                        DropdownMenuItem(
                          value: 'conflict_detected',
                          child: Text('Conflict detected'),
                        ),
                        DropdownMenuItem(
                          value: 'clarification_required',
                          child: Text('Clarification required'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedStatus = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: remarksController,
                      maxLines: 4,
                      maxLength: 1000,
                      decoration: const InputDecoration(
                        labelText: 'Technical remarks',
                        hintText:
                            'Enter findings, observations or required clarification.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                      {
                        'status': selectedStatus,
                        'remarks': remarksController.text.trim(),
                      },
                    );
                  },
                  child: const Text('Submit review'),
                ),
              ],
            );
          },
        );
      },
    );

    remarksController.dispose();

    if (result == null) return;

    try {
      await supabase.rpc(
        'submit_department_review',
        params: {
          'p_review_id': review['id'].toString(),
          'p_review_status': result['status'],
          'p_remarks': result['remarks'],
        },
      );

      await loadRequests();
      notify('Department review submitted.');
    } catch (error) {
      notify('Review was not submitted: $error');
    }
  }

  
  Future<void> showDepartmentAssignment(
    Map<String, dynamic> request,
  ) async {
    final requestId = request['id'].toString();

    // Exclude departments already assigned to this request.
    final existingReviews = reviewsByRequest[requestId] ?? [];

    final assignedDepartmentIds = existingReviews
        .map((review) => review['department_id'].toString())
        .toSet();

    final availableDepartments = departments.where((department) {
      return !assignedDepartmentIds.contains(
        department['id'].toString(),
      );
    }).toList();

    if (availableDepartments.isEmpty) {
      notify('All available departments are already assigned.');
      return;
    }

    final category = (request['case_category'] ?? 'legacy_excavation').toString();
    List<Map<String, dynamic>> suggestedRoutes = [];
    try {
      final rawSuggestions = await supabase.rpc(
        'get_case_department_suggestions',
        params: {'p_case_category': category},
      );
      suggestedRoutes = List<Map<String, dynamic>>.from(rawSuggestions as List)
          .where((item) => !assignedDepartmentIds.contains(item['department_id'].toString()))
          .toList();
    } catch (_) {
      // Manual department assignment remains available if the routing directory is unavailable.
    }

    String? selectedDepartment = suggestedRoutes.isNotEmpty
        ? suggestedRoutes.first['department_id'].toString()
        : availableDepartments.first['id'].toString();

    if (!mounted) return;
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Assign department'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedDepartment,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Select unassigned department',
                        border: OutlineInputBorder(),
                      ),
                      items: availableDepartments.map((department) {
                        return DropdownMenuItem<String>(
                          value: department['id'].toString(),
                          child: Text(department['name'].toString()),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedDepartment = value;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'SUGGESTED ROUTING',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Suggestions are based on the case domain and must be confirmed by the coordinator.',
                      style: TextStyle(fontSize: 10, color: mutedInk),
                    ),
                    const SizedBox(height: 8),
                    if (suggestedRoutes.isEmpty)
                      const Text('No routing suggestions are configured. Use manual assignment.',
                        style: TextStyle(fontSize: 11, color: mutedInk))
                    else
                      ...suggestedRoutes.map((route) {
                        final departmentId = route['department_id'].toString();
                        final department = availableDepartments.firstWhere(
                          (item) => item['id'].toString() == departmentId,
                          orElse: () => {'name': route['department_name'] ?? 'Department'},
                        );
                        final isPrimary = route['route_priority'] == 'primary';
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            isPrimary ? Icons.star_outline : Icons.hub_outlined,
                            color: isPrimary ? const Color(0xFF087F83) : mutedInk,
                          ),
                          title: Text(department['name'].toString(),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          subtitle: Text(isPrimary ? 'Primary suggested department' : 'Supporting department',
                            style: const TextStyle(fontSize: 10)),
                          trailing: selectedDepartment == departmentId
                              ? const Icon(Icons.check_circle, color: Color(0xFF087F83))
                              : TextButton(
                                  onPressed: () => setDialogState(() => selectedDepartment = departmentId),
                                  child: const Text('Select'),
                                ),
                        );
                      }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: selectedDepartment == null
                      ? null
                      : () => Navigator.pop(
                            dialogContext,
                            selectedDepartment,
                          ),
                  child: const Text('Assign'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selected == null) return;

    try {
      await supabase.rpc(
        'assign_request_department',
        params: {
          'p_request_id': requestId,
          'p_department_id': selected,
        },
      );

      await loadRequests();
      notify('Department assigned successfully.');
    } catch (error) {
      // Refresh in case the assignment already exists
      // or another coordinator assigned it simultaneously.
      await loadRequests();

      final message = error.toString();

      if (message.contains('request_department_reviews_unique_assignment') ||
          message.contains('23505')) {
        notify('This department is already assigned to this request.');
      } else {
        notify('Assignment failed: $error');
      }
    }
  }


  Future<void> showOverallStatusDialog(
    Map<String, dynamic> request,
  ) async {
    final current = valueOf(
      request,
      'status',
      fallback: 'submitted',
    );

    final allowed = allowedTransitions(current);

    if (allowed.isEmpty) {
      notify('No further status transition is available.');
      return;
    }

    String selectedStatus = allowed.first;
    final remarksController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Update overall status'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Current status: $current'),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedStatus,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'New status',
                        border: OutlineInputBorder(),
                      ),
                      items: allowed.map((status) {
                        return DropdownMenuItem<String>(
                          value: status,
                          child: Text(
                            status.replaceAll('_', ' ').toUpperCase(),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedStatus = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: remarksController,
                      maxLines: 3,
                      maxLength: 1000,
                      decoration: const InputDecoration(
                        labelText: 'Coordinator remarks',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Approval is subject to the database rule requiring every assigned department review to be approved.',
                      style: TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                      {
                        'status': selectedStatus,
                        'remarks': remarksController.text.trim(),
                      },
                    );
                  },
                  child: const Text('Update status'),
                ),
              ],
            );
          },
        );
      },
    );

    remarksController.dispose();

    if (result == null) return;

    try {
      await supabase.rpc(
        'change_request_status',
        params: {
          'p_request_id': request['id'].toString(),
          'p_new_status': result['status'],
          'p_remarks': result['remarks'],
        },
      );

      await loadRequests();
      notify('Overall request status updated.');
    } catch (error) {
      notify('Status update failed: $error');
    }
  }

  Widget detailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.blueGrey,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.blueGrey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget requestCard(Map<String, dynamic> item) {
    final requestId = item['id'].toString();

    final status = valueOf(
      item,
      'status',
      fallback: 'submitted',
    );

    final number = valueOf(
      item,
      'request_number',
      fallback: requestId,
    );

    final assignedReviews =
        reviewsByRequest[requestId] ?? [];

    final ownReview = widget.isDepartment &&
            assignedReviews.isNotEmpty
        ? assignedReviews.first
        : null;
    final category = valueOf(item, 'case_category', fallback: 'legacy_excavation')
        .replaceAll('_', ' ').toUpperCase();
    final activity = valueOf(item, 'work_activity', fallback: 'not specified')
        .replaceAll('_', ' ');

    final reviewSummary = assignedReviews.isEmpty
        ? 'No department assignments yet.'
        : assignedReviews.map((review) {
            final name = departmentName(
              review['department_id'].toString(),
            );
            final reviewStatus = valueOf(
              review,
              'review_status',
              fallback: 'pending',
            );
            return '$name — ${reviewStatus.replaceAll('_', ' ')}';
          }).join('\n');

    return Card(
      margin: const EdgeInsets.only(bottom: 13),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Request #$number',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: navy,
                    ),
                  ),
                ),
                statusLabel(status),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              valueOf(
                item,
                'title',
                fallback: 'Untitled request',
              ),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 7),
            detailRow(Icons.layers_outlined, 'Domain: $category'),
            detailRow(Icons.build_outlined, 'Activity: $activity'),
            Text(
              valueOf(item, 'description'),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const Divider(height: 22),
            detailRow(
              Icons.location_on_outlined,
              valueOf(item, 'road_name'),
            ),
            detailRow(
              Icons.location_city_outlined,
              valueOf(item, 'city'),
            ),
            detailRow(
              Icons.calendar_today_outlined,
              valueOf(item, 'created_at'),
            ),
            if (item['latitude'] != null &&
                item['longitude'] != null)
              detailRow(
                Icons.map_outlined,
                '${item['latitude']}, ${item['longitude']}',
              ),
            const SizedBox(height: 8),
            const Text(
              'Department coordination',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              reviewSummary,
              style: const TextStyle(fontSize: 12),
            ),
            if (widget.isDepartment && ownReview != null) ...[
              const SizedBox(height: 10),
              statusLabel(
                valueOf(
                  ownReview,
                  'review_status',
                  fallback: 'pending',
                ),
              ),
              if (valueOf(
                    ownReview,
                    'remarks',
                    fallback: '',
                  ).isNotEmpty) ...[
                const SizedBox(height: 7),
                Text(
                  'Latest remarks: ${ownReview['remarks']}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
              const SizedBox(height: 12),
              if (![
                'approved',
                'rejected',
              ].contains(
                valueOf(ownReview, 'review_status'),
              ))
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () =>
                        showDepartmentReview(ownReview),
                    icon: const Icon(Icons.rate_review_outlined),
                    label: const Text('Submit department review'),
                  ),
                ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CaseWorkspacePage(
                      requestId: requestId,
                      requestTitle: valueOf(item, 'title', fallback: 'Infrastructure request'),
                    ),
                  ),
                ),
                icon: const Icon(Icons.forum_outlined),
                label: const Text('Open case workspace'),
              ),
            ),
            if (!widget.isDepartment) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () =>
                        showDepartmentAssignment(item),
                    icon: const Icon(
                      Icons.account_tree_outlined,
                    ),
                    label: const Text('Assign department'),
                  ),
                  FilledButton.icon(
                    onPressed: () =>
                        showOverallStatusDialog(item),
                    icon: const Icon(
                      Icons.sync_alt,
                    ),
                    label: const Text('Update status'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;

    final displayName =
        user?.userMetadata?['display_name']?.toString() ??
        user?.email ??
        'Authorised user';

    return Scaffold(
      appBar: AppBar(
        title: const Text('SAMANVAY'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: loading ? null : loadRequests,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Log out',
            onPressed: () async {
              await supabase.auth.signOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadRequests,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(18),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: navy,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    widget.icon,
                    color: Colors.white,
                    size: 36,
                  ),
                  const SizedBox(height: 13),
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Welcome, $displayName',
                    style: const TextStyle(
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    widget.subtitle,
                    style: const TextStyle(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Infrastructure overview',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: navy,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                metric(
                  'Total cases',
                  requests.length,
                  Icons.folder_open,
                ),
                metric(
                  'Submitted',
                  countStatus('submitted'),
                  Icons.inbox_outlined,
                ),
                metric(
                  'Under review',
                  countStatus('under_review'),
                  Icons.rate_review_outlined,
                ),
              ],
            ),
            Row(
              children: [
                metric(
                  'Approved',
                  countStatus('approved'),
                  Icons.verified_outlined,
                ),
                metric(
                  'Completed',
                  countStatus('completed'),
                  Icons.task_alt,
                ),
                metric(
                  'Conflicts',
                  countStatus('conflict_detected'),
                  Icons.warning_amber_outlined,
                ),
              ],
            ),
            const SizedBox(height: 10),
            domainBreakdown(),
            if (!widget.isDepartment) ...[
              const SizedBox(height: 18),
              executiveSnapshot(),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MapPage()),
                ),
                icon: const Icon(Icons.map_outlined),
                label: const Text('OPEN GIS OPERATIONS WORKSPACE'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0B5B67),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
            if (widget.isAdmin) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminManagementPage()),
                  ),
                  icon: const Icon(Icons.admin_panel_settings_outlined),
                  label: const Text('OPEN ADMINISTRATION CONSOLE'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0B5B67),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Infrastructure requests',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: navy,
                    ),
                  ),
                ),
                Text(
                  '${requests.length} records',
                  style: const TextStyle(
                    color: Colors.blueGrey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (loading)
              const Padding(
                padding: EdgeInsets.all(35),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (errorMessage.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.cloud_off_outlined,
                        size: 36,
                        color: Colors.orange,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        errorMessage,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: loadRequests,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              )
            else if (requests.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(22),
                  child: Column(
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 40,
                        color: Colors.blueGrey,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'No requests are currently visible to this account.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              ...requests.map(requestCard),
            const SizedBox(height: 18),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      color: Colors.teal,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Department reviews and coordinator status changes are processed by protected database functions. Role permissions and row-level security remain enforced by Supabase.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  static const String redirectUrl =
      'in.samanvay://login-callback/';

  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool isLogin = true;
  bool loading = false;
  bool hidePassword = true;
  String selectedRole = 'requester';

  final List<Map<String, String>> availableRoles = [
    {'value': 'requester', 'label': 'Requester'},
    {'value': 'department', 'label': 'Department Officer'},
    {'value': 'coordinator', 'label': 'Coordinator'},
    {'value': 'admin', 'label': 'Administrator'},
  ];
  String message = '';
  bool messageIsSuccess = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void showMessage(String text, {bool success = false}) {
    if (!mounted) return;

    setState(() {
      message = text;
      messageIsSuccess = success;
    });
  }

  Future<void> submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      loading = true;
      message = '';
      messageIsSuccess = false;
    });

    try {
      final email = _emailController.text.trim();

      if (isLogin) {
        await supabase.auth.signInWithPassword(
          email: email,
          password: _passwordController.text,
        );

        showMessage(
          'Login successful.',
          success: true,
        );
      } else {
        final response = await supabase.auth.signUp(
          email: email,
          password: _passwordController.text,
          emailRedirectTo: redirectUrl,
          data: {
            'display_name': _nameController.text.trim(),
          },
        );

        if (response.session == null) {
          showMessage(
            'Registration request submitted. '
            'Check your inbox and spam folder for '
            'the confirmation email. '
            'After confirming, return here and log in.',
            success: true,
          );
        } else {
          showMessage(
            'Your account has been created successfully.',
            success: true,
          );
        }
      }
    } on AuthException catch (error) {
      showMessage(error.message);
    } catch (error) {
      showMessage(
        'Unable to complete the request. '
        'Check your internet connection and try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // Resend the confirmation email to an existing
  // unconfirmed Supabase signup.

  Future<void> resendConfirmationEmail() async {
    final email = _emailController.text.trim();

    if (!email.contains('@') || !email.contains('.')) {
      showMessage(
        'Enter your registered email address first.',
      );
      return;
    }

    setState(() {
      loading = true;
      message = '';
      messageIsSuccess = false;
    });

    try {
      await supabase.auth.resend(
        type: OtpType.signup,
        email: email,
        emailRedirectTo: redirectUrl,
      );

      showMessage(
        'Supabase accepted the confirmation email request. '
        'Check your inbox, spam and promotions folders. '
        'Open the newest confirmation email.',
        success: true,
      );
    } on AuthException catch (error) {
      showMessage(
        'Confirmation email could not be requested: '
        '${error.message}',
      );
    } catch (error) {
      showMessage(
        'Unable to request the confirmation email. '
        'Check your internet connection and try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.location_city_rounded,
                    size: 68,
                    color: teal,
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    'SAMANVAY',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: navy,
                      letterSpacing: 2,
                    ),
                  ),

                  const SizedBox(height: 6),

                  const Text(
                    'Municipal Infrastructure Coordination',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.blueGrey,
                    ),
                  ),

                  const SizedBox(height: 36),

                  Text(
                    isLogin
                        ? 'Welcome back'
                        : 'Create your account',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: navy,
                    ),
                  ),

                  const SizedBox(height: 22),

                  if (!isLogin) ...[
                    TextFormField(
                      controller: _nameController,
                      textCapitalization:
                          TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        prefixIcon:
                            Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null ||
                            value.trim().isEmpty) {
                          return 'Enter your name';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 16),
                  ],
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Select account type',
                      prefixIcon: Icon(
                        Icons.admin_panel_settings_outlined,
                      ),
                      border: OutlineInputBorder(),
                    ),
                    items: availableRoles.map((role) {
                      return DropdownMenuItem<String>(
                        value: role['value'],
                        child: Text(role['label']!),
                      );
                    }).toList(),
                    onChanged: loading
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() {
                                selectedRole = value;
                              });
                            }
                          },
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'Privileged roles require administrator authorization.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blueGrey,
                    ),
                  ),

                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    keyboardType:
                        TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      prefixIcon:
                          Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null ||
                          !value.contains('@') ||
                          !value.contains('.')) {
                        return 'Enter a valid email address';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _passwordController,
                    obscureText: hidePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon:
                          const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            hidePassword = !hidePassword;
                          });
                        },
                        icon: Icon(
                          hidePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null ||
                          value.length < 8) {
                        return 'Password must contain '
                            'at least 8 characters';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 20),

                  if (message.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: messageIsSuccess
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        borderRadius:
                            BorderRadius.circular(10),
                        border: Border.all(
                          color: messageIsSuccess
                              ? Colors.green.shade200
                              : Colors.red.shade200,
                        ),
                      ),
                      child: Text(
                        message,
                        style: TextStyle(
                          fontSize: 13,
                          color: messageIsSuccess
                              ? Colors.green.shade900
                              : Colors.red.shade900,
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  FilledButton(
                    onPressed: loading ? null : submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: navy,
                      padding:
                          const EdgeInsets.symmetric(
                        vertical: 16,
                      ),
                    ),
                    child: loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child:
                                CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            isLogin
                                ? 'LOGIN'
                                : 'CREATE ACCOUNT',
                          ),
                  ),

                  if (isLogin) ...[
                    const SizedBox(height: 8),

                    OutlinedButton.icon(
                      onPressed: loading
                          ? null
                          : resendConfirmationEmail,
                      icon: const Icon(
                        Icons.mark_email_unread_outlined,
                      ),
                      label: const Text(
                        'RESEND CONFIRMATION EMAIL',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: navy,
                        padding:
                            const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  TextButton(
                    onPressed: loading
                        ? null
                        : () {
                            setState(() {
                              isLogin = !isLogin;
                              message = '';
                              messageIsSuccess = false;
                            });
                          },
                    child: Text(
                      isLogin
                          ? "Don't have an account? Register"
                          : 'Already registered? Login',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// MAIN APPLICATION
// ==========================================

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int selectedIndex = 0;

  final pages = const [
    DashboardPage(),
    RequestsPage(),
    MapPage(),
    NotificationsPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Requests',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ==========================================
// DASHBOARD
// ==========================================

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> requests = [];
  List<Map<String, dynamic>> departments = [];

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    if (mounted) setState(() { loading = true; error = null; });
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw StateError('Session expired');
      final result = await Future.wait([
        supabase.from('excavation_requests').select('id,status,created_at,case_category')
          .eq('requester_id', user.id)
          .order('created_at', ascending: false).limit(100),
        supabase.from('departments').select('id,name').order('name').limit(12),
      ]);
      if (!mounted) return;
      setState(() {
        requests = List<Map<String, dynamic>>.from(result[0]);
        departments = List<Map<String, dynamic>>.from(result[1]);
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { loading = false; error = 'Live data unavailable. Pull down to retry.'; });
    }
  }

  int count(String status) => requests.where((r) =>
    (r['status'] ?? '').toString().toLowerCase() == status).length;

  Widget _categoryOverview() {
    final grouped = <String, int>{};
    for (final request in requests) {
      final category = (request['case_category'] ?? 'legacy_excavation').toString();
      grouped[category] = (grouped[category] ?? 0) + 1;
    }
    final entries = grouped.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) {
      return const Text(
        'Your infrastructure-domain breakdown will appear after your first case is submitted.',
        style: TextStyle(fontSize: 11, color: mutedInk),
      );
    }
    final maxCount = entries.first.value;
    return Column(
      children: entries.take(6).map((entry) {
        final label = entry.key.replaceAll('_', ' ').toUpperCase();
        final ratio = maxCount == 0 ? 0.0 : entry.value / maxCount;
        return Padding(
          padding: const EdgeInsets.only(bottom: 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(label,
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: ink)),
                  ),
                  Text(entry.value.toString(),
                    style: GoogleFonts.robotoMono(fontSize: 11, fontWeight: FontWeight.w700, color: ink)),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 7,
                  backgroundColor: const Color(0xFFE7EDF2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF20AFA5)),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget metric(String title, String value, IconData icon, Color color) =>
    Expanded(child: Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3EAF1))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 10),
        Text(value, style: GoogleFonts.robotoMono(
          color: ink, fontSize: 21, fontWeight: FontWeight.w700)),
        Text(title, style: GoogleFonts.inter(
          color: mutedInk, fontSize: 10, fontWeight: FontWeight.w600)),
      ]),
    ));

  @override
  Widget build(BuildContext context) {
    final rawName = supabase.auth.currentUser?.userMetadata?['display_name'];
    final name = rawName == null || rawName.toString().trim().isEmpty
      ? 'there' : rawName.toString().trim();
    final active = requests.length - count('completed') - count('rejected');

    return Scaffold(
      appBar: AppBar(title: const Text('SAMANVAY'),
        actions: [IconButton(onPressed: loading ? null : refresh,
          tooltip: 'Refresh', icon: const Icon(Icons.refresh_rounded))]),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Container(
            padding: const EdgeInsets.all(21),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0B1728), Color(0xFF173B55), Color(0xFF075E67)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0x5534E5D1)),
              boxShadow: const [BoxShadow(color: Color(0x180B1728),
                blurRadius: 20, offset: Offset(0, 9))]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('KNOW BELOW. DIG ABOVE.',
                style: GoogleFonts.inter(color: const Color(0xFFB7D8E0),
                  fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
              const SizedBox(height: 15),
              Text('Good day, $name',
                style: GoogleFonts.spaceGrotesk(color: Colors.white,
                  fontSize: 25, fontWeight: FontWeight.w700)),
              const SizedBox(height: 7),
              Text('Connected infrastructure. Coordinated development.',
                style: GoogleFonts.inter(color: const Color(0xFFD1E0EA), fontSize: 12)),
              const SizedBox(height: 18),
              SizedBox(width: double.infinity, child: FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MapPage())),
                icon: const Icon(Icons.layers_rounded),
                label: const Text('OPEN GIS WORKSPACE'),
                style: FilledButton.styleFrom(backgroundColor: teal,
                  foregroundColor: navy, padding: const EdgeInsets.symmetric(vertical: 14)),
              )),
            ]),
          ),
          const SizedBox(height: 23),
          Text('Operational overview', style: GoogleFonts.spaceGrotesk(
            color: ink, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Your submitted infrastructure cases',
            style: GoogleFonts.inter(color: mutedInk, fontSize: 12)),
          const SizedBox(height: 13),
          if (error != null) Padding(padding: const EdgeInsets.only(bottom: 10),
            child: Text(error!, style: const TextStyle(color: Colors.deepOrange))),
          Row(children: [
            metric('TOTAL CASES', loading ? '—' : '${requests.length}',
              Icons.assignment_outlined, const Color(0xFF087F83)),
            const SizedBox(width: 9),
            metric('ACTIVE', loading ? '—' : '$active',
              Icons.pending_actions, const Color(0xFFD28A28)),
            const SizedBox(width: 9),
            metric('COMPLETED', loading ? '—' : '${count('completed')}',
              Icons.task_alt, const Color(0xFF25845C)),
          ]),
          const SizedBox(height: 22),
          Text('Cases by infrastructure domain', style: GoogleFonts.spaceGrotesk(
            color: ink, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Distribution of your submitted cases', style: GoogleFonts.inter(
            color: mutedInk, fontSize: 12)),
          const SizedBox(height: 13),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE3EAF1)),
            ),
            child: loading && requests.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _categoryOverview(),
          ),
          const SizedBox(height: 24),
          Text('Department network', style: GoogleFonts.spaceGrotesk(
            color: ink, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Live directory from the SAMANVAY database',
            style: GoogleFonts.inter(color: mutedInk, fontSize: 12)),
          const SizedBox(height: 12),
          if (loading && departments.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(18),
              child: CircularProgressIndicator()))
          else if (departments.isEmpty)
            const Text('No department directory records available.',
              style: TextStyle(color: mutedInk))
          else
            ...departments.map((d) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE3EAF1))),
              child: ListTile(dense: true,
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE7F8F6),
                  child: Icon(Icons.account_tree_outlined, color: Color(0xFF087F83))),
                title: Text((d['name'] ?? 'Department').toString(),
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.chevron_right, color: mutedInk),
              ),
            )),
          const SizedBox(height: 14),
          Container(padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFEAF2F8),
              borderRadius: BorderRadius.circular(14)),
            child: Text(
              'Underground visibility depends on verified survey records and access permissions. An empty layer does not prove that no utility exists.',
              style: GoogleFonts.inter(color: const Color(0xFF42627E),
                fontSize: 11, height: 1.45))),
        ]),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: teal, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: navy,
            ),
          ),
          Text(
            title,
            style: const TextStyle(color: Colors.blueGrey),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// DEPARTMENT TILE
// ==========================================

class DepartmentTile extends StatelessWidget {
  final String title;
  final IconData icon;

  const DepartmentTile({
    super.key,
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: teal.withValues(alpha: 0.12),
          child: Icon(icon, color: teal),
        ),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}


// ==========================================
// REQUESTS — LIVE SUPABASE MODULE
// ==========================================

class RequestsPage extends StatefulWidget {
  const RequestsPage({super.key});

  @override
  State<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends State<RequestsPage> {
  StreamSubscription<List<Map<String, dynamic>>>? _requestEvents;
  List<Map<String, dynamic>> requests = [];
  bool loading = true;
  String? errorMessage;
  String selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    loadRequests();
    final user = supabase.auth.currentUser;
    if (user != null) {
      _requestEvents = supabase
          .from('excavation_requests')
          .stream(primaryKey: ['id'])
          .eq('requester_id', user.id)
          .order('created_at', ascending: false)
          .listen((rows) {
        if (!mounted) return;
        setState(() {
          requests = List<Map<String, dynamic>>.from(rows);
          loading = false;
          errorMessage = null;
        });
      }, onError: (_) {
        if (!mounted) return;
        setState(() {
          errorMessage = 'Live updates are unavailable. Use refresh to retry.';
        });
      });
    }
  }

  @override
  void dispose() {
    _requestEvents?.cancel();
    super.dispose();
  }

  Future<void> loadRequests() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      setState(() {
        loading = false;
        errorMessage = 'Please log in again.';
      });
      return;
    }

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final result = await supabase
          .from('excavation_requests')
          .select()
          .eq('requester_id', user.id)
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        requests = List<Map<String, dynamic>>.from(result);
        loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        loading = false;
        errorMessage = error.toString();
      });
    }
  }

  List<Map<String, dynamic>> get filteredRequests {
    if (selectedFilter == 'all') return requests;

    return requests.where((request) {
      return request['status'] == selectedFilter;
    }).toList();
  }

  Future<void> openNewRequestForm() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const NewRequestPage(),
      ),
    );

    if (created == true) {
      await loadRequests();
    }
  }

  String statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
        return 'Submitted';
      case 'under_review':
        return 'Under Review';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      default:
        return status.replaceAll('_', ' ').toUpperCase();
    }
  }

  Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'completed':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'in_progress':
        return Colors.blue;
      case 'under_review':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  String displayDate(dynamic value) {
    if (value == null) return 'Not specified';

    final date = DateTime.tryParse(value.toString());
    if (date == null) return value.toString();

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final visibleRequests = filteredRequests;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Excavation Requests'),
        actions: [
          IconButton(
            onPressed: loading ? null : loadRequests,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh requests',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: openNewRequestForm,
        backgroundColor: navy,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Request'),
      ),
      body: RefreshIndicator(
        onRefresh: loadRequests,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 90),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: navy,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.assignment_turned_in_outlined,
                    color: Colors.white,
                    size: 36,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'My Excavation Requests',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${requests.length} request(s) recorded',
                          style: const TextStyle(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Filter by status',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: navy,
              ),
            ),

            const SizedBox(height: 10),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip('All', 'all'),
                  _filterChip('Submitted', 'submitted'),
                  _filterChip('Under Review', 'under_review'),
                  _filterChip('Approved', 'approved'),
                  _filterChip('Rejected', 'rejected'),
                  _filterChip('In Progress', 'in_progress'),
                  _filterChip('Completed', 'completed'),
                ],
              ),
            ),

            const SizedBox(height: 18),

            if (loading)
              const Padding(
                padding: EdgeInsets.all(45),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (errorMessage != null)
              _errorView()
            else if (visibleRequests.isEmpty)
              _emptyView()
            else
              ...visibleRequests.map(
                (request) => _requestCard(request),
              ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final selected = selectedFilter == value;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() {
            selectedFilter = value;
          });
        },
        selectedColor: teal.withValues(alpha: 0.18),
        checkmarkColor: teal,
      ),
    );
  }

  Widget _requestCard(Map<String, dynamic> request) {
    final status = request['status']?.toString() ?? 'submitted';
    final number = request['request_number']?.toString() ?? '-';
    final title = request['title']?.toString() ?? 'Untitled';
    final road = request['road_name']?.toString() ?? '';
    final city = request['city']?.toString() ?? '';
    final category = (request['case_category'] ?? 'legacy_excavation')
        .toString().replaceAll('_', ' ').toUpperCase();
    final activity = (request['work_activity'] ?? 'not specified')
        .toString().replaceAll('_', ' ');
    final color = statusColor(status);

    return Card(
      color: Colors.white,
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 13),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Request #$number',
                    style: const TextStyle(
                      color: teal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel(status),
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: navy,
              ),
            ),

            const SizedBox(height: 9),

            _detailRow(Icons.location_on_outlined, '$road, $city'),
            _detailRow(Icons.layers_outlined, 'Domain: $category'),
            _detailRow(Icons.build_outlined, 'Activity: $activity'),

            const SizedBox(height: 7),

            _detailRow(
              Icons.calendar_today_outlined,
              'Start: ${displayDate(request['planned_start_date'])}',
            ),

            const SizedBox(height: 7),

            _detailRow(
              Icons.event_outlined,
              'End: ${displayDate(request['planned_end_date'])}',
            ),

            if (request['description'] != null &&
                request['description'].toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                request['description'].toString(),
                style: const TextStyle(
                  color: Colors.blueGrey,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CaseWorkspacePage(
                      requestId: request['id'].toString(),
                      requestTitle: title,
                    ),
                  ),
                ),
                icon: const Icon(Icons.forum_outlined),
                label: const Text('OPEN CASE WORKSPACE'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 17, color: Colors.blueGrey),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.blueGrey,
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyView() {
    return Padding(
      padding: const EdgeInsets.only(top: 55),
      child: Column(
        children: [
          const Icon(
            Icons.assignment_outlined,
            size: 65,
            color: teal,
          ),
          const SizedBox(height: 15),
          const Text(
            'No requests found',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: navy,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create your first excavation request '
            'using the button below.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.blueGrey),
          ),
        ],
      ),
    );
  }

  Widget _errorView() {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 55,
            color: Colors.redAccent,
          ),
          const SizedBox(height: 12),
          const Text(
            'Unable to load requests',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            errorMessage ?? 'Unknown error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.blueGrey),
          ),
          const SizedBox(height: 15),
          FilledButton.icon(
            onPressed: loadRequests,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// NEW EXCAVATION REQUEST FORM
// ==========================================

class NewRequestPage extends StatefulWidget {
  const NewRequestPage({super.key});

  @override
  State<NewRequestPage> createState() => _NewRequestPageState();
}

class _NewRequestPageState extends State<NewRequestPage> {
  LatLng? selectedWorkPoint;
  String selectedCategory = 'road_reconstruction';
  String selectedActivity = 'new_installation';
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _roadController = TextEditingController();
  final _cityController = TextEditingController();
  final _workRadiusController = TextEditingController();

  DateTime? startDate;
  DateTime? endDate;

  bool submitting = false;
  String? formError;
  Future<void> pickWorkLocation() async {
  final LatLng? picked = await Navigator.push<LatLng>(
    context,
    MaterialPageRoute(
      builder: (_) => MapLocationPickerPage(
        initialPoint: selectedWorkPoint,
      ),
    ),
  );

  if (picked == null || !mounted) return;

  setState(() {
    selectedWorkPoint = picked;
  });
  }
  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _roadController.dispose();
    _cityController.dispose();
    _workRadiusController.dispose();
    super.dispose();
  }

  Future<void> chooseDate(bool isStart) async {
    final now = DateTime.now();

    final selected = await showDatePicker(
      context: context,
      initialDate: isStart
          ? startDate ?? now
          : endDate ?? startDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );

    if (selected == null || !mounted) return;

    setState(() {
      if (isStart) {
        startDate = selected;

        if (endDate != null && endDate!.isBefore(selected)) {
          endDate = null;
        }
      } else {
        endDate = selected;
      }
    });
  }

  String formatDate(DateTime? date) {
    if (date == null) return 'Select date';

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<void> submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    if (selectedWorkPoint == null) {
      setState(() {
        formError = 'Select the work or issue location on the map to support GIS coordination.';
      });
      return;
    }

    final radiusText = _workRadiusController.text.trim();
    final workRadius = radiusText.isEmpty ? null : double.tryParse(radiusText);
    if (radiusText.isNotEmpty &&
        (workRadius == null || workRadius < 1 || workRadius > 500)) {
      setState(() {
        formError = 'Work-site radius must be a number between 1 and 500 metres.';
      });
      return;
    }

    if (startDate != null &&
        endDate != null &&
        endDate!.isBefore(startDate!)) {
      setState(() {
        formError = 'End date cannot be before start date.';
      });
      return;
    }

    final user = supabase.auth.currentUser;

    if (user == null) {
      setState(() {
        formError = 'Your session has expired. Please log in again.';
      });
      return;
    }

    setState(() {
      submitting = true;
      formError = null;
    });

    try {
      final data = <String, dynamic>{
        'requester_id': user.id,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'road_name': _roadController.text.trim(),
        'city': _cityController.text.trim(),
        'case_category': selectedCategory,
        'work_activity': selectedActivity,
        'work_radius_m': workRadius,
        'latitude': selectedWorkPoint!.latitude,
        'longitude': selectedWorkPoint!.longitude,
      };

      if (startDate != null) {
        data['planned_start_date'] =
            startDate!.toIso8601String().split('T').first;
      }

      if (endDate != null) {
        data['planned_end_date'] =
            endDate!.toIso8601String().split('T').first;
      }

      await supabase
          .from('excavation_requests')
          .insert(data)
          .select()
          .single();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Infrastructure case submitted successfully.'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        formError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Infrastructure Case'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Request details',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: navy,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Register a work proposal or infrastructure issue for coordinated review by the responsible departments.',
              style: TextStyle(color: Colors.blueGrey),
            ),

            const SizedBox(height: 22),

            _field(
              controller: _titleController,
              label: 'Project title',
              icon: Icons.title,
              required: true,
            ),

            const SizedBox(height: 16),

            _field(
              controller: _descriptionController,
              label: 'Work / issue description',
              icon: Icons.description_outlined,
              maxLines: 4,
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: selectedCategory,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Infrastructure domain',
                prefixIcon: Icon(Icons.account_tree_outlined),
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'road_reconstruction', child: Text('Road reconstruction')),
                DropdownMenuItem(value: 'water_supply', child: Text('Water supply')),
                DropdownMenuItem(value: 'sewerage', child: Text('Sewerage')),
                DropdownMenuItem(value: 'stormwater_drainage', child: Text('Stormwater and drainage')),
                DropdownMenuItem(value: 'electricity', child: Text('Electricity')),
                DropdownMenuItem(value: 'telecom', child: Text('Telecommunications')),
                DropdownMenuItem(value: 'gas', child: Text('Gas network')),
                DropdownMenuItem(value: 'borewell_groundwater', child: Text('Borewell and groundwater')),
                DropdownMenuItem(value: 'building_planning', child: Text('Building planning / regulation')),
                DropdownMenuItem(value: 'public_health_engineering', child: Text('Public health engineering')),
                DropdownMenuItem(value: 'other', child: Text('Other infrastructure issue')),
              ],
              onChanged: submitting ? null : (value) {
                if (value != null) setState(() => selectedCategory = value);
              },
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: selectedActivity,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Work / issue type',
                prefixIcon: Icon(Icons.build_outlined),
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'new_installation', child: Text('New installation / development')),
                DropdownMenuItem(value: 'repair', child: Text('Repair')),
                DropdownMenuItem(value: 'maintenance', child: Text('Maintenance')),
                DropdownMenuItem(value: 'relocation', child: Text('Relocation')),
                DropdownMenuItem(value: 'survey', child: Text('Survey')),
                DropdownMenuItem(value: 'inspection', child: Text('Inspection')),
                DropdownMenuItem(value: 'violation_report', child: Text('Possible violation / complaint')),
                DropdownMenuItem(value: 'emergency_response', child: Text('Emergency response')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: submitting ? null : (value) {
                if (value != null) setState(() => selectedActivity = value);
              },
            ),

            const SizedBox(height: 16),

            _field(
              controller: _roadController,
              label: 'Road name / location',
              icon: Icons.location_on_outlined,
              required: true,
            ),

            const SizedBox(height: 16),

            _field(
              controller: _cityController,
              label: 'City',
              icon: Icons.location_city,
              required: true,
            ),
            const SizedBox(height: 14),

            OutlinedButton.icon(
              onPressed: pickWorkLocation,
              icon: const Icon(Icons.location_on),
              label: Text(
                selectedWorkPoint == null
                    ? 'Select work location on map'
                    : 'Change selected location',
              ),
             ),

             if (selectedWorkPoint != null) ...[
               const SizedBox(height: 8),
               Text(
                  'Latitude: ${selectedWorkPoint!.latitude.toStringAsFixed(6)}\n'
                  'Longitude: ${selectedWorkPoint!.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(fontSize: 13),
               ),
              ],

            const SizedBox(height: 16),

            TextFormField(
              controller: _workRadiusController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Approximate work-site radius (metres)',
                helperText: 'Optional. Enter 1–500 m to enable the recorded-utility proximity check. This is not a verified work boundary or safety clearance.',
                prefixIcon: Icon(Icons.radar_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final text = (value ?? '').trim();
                if (text.isEmpty) return null;
                final number = double.tryParse(text);
                if (number == null || number < 1 || number > 500) {
                  return 'Enter a radius between 1 and 500 metres.';
                }
                return null;
              },
            ),

            const SizedBox(height: 22),

            const Text(
              'Planned schedule',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: navy,
              ),
            ),

            const SizedBox(height: 12),

            _dateTile(
              'Planned start date',
              startDate,
              true,
            ),

            const SizedBox(height: 12),

            _dateTile(
              'Planned end date',
              endDate,
              false,
            ),

            const SizedBox(height: 18),

            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: teal.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'A case number will be generated automatically. Department assignment and official decisions are completed by authorised officers.',
                style: TextStyle(
                  color: navy,
                  fontSize: 13,
                ),
              ),
            ),

            if (formError != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  formError!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],

            const SizedBox(height: 22),

            FilledButton.icon(
              onPressed: submitting ? null : submitRequest,
              style: FilledButton.styleFrom(
                backgroundColor: navy,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send),
              label: Text(
                submitting ? 'SUBMITTING...' : 'SUBMIT REQUEST',
              ),
            ),

            const SizedBox(height: 25),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool required = false,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
        alignLabelWithHint: maxLines > 1,
      ),
      validator: (value) {
        if (required &&
            (value == null || value.trim().isEmpty)) {
          return 'Please enter $label';
        }
        return null;
      },
    );
  }

  Widget _dateTile(
    String label,
    DateTime? date,
    bool isStart,
  ) {
    return OutlinedButton(
      onPressed: submitting ? null : () => chooseDate(isStart),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.all(16),
        alignment: Alignment.centerLeft,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_month, color: teal),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.blueGrey),
                ),
                const SizedBox(height: 4),
                Text(
                  formatDate(date),
                  style: const TextStyle(
                    color: navy,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.edit_calendar_outlined),
        ],
      ),
    );
  }
}


// ==========================================
// MAP
// ==========================================


class MapLocationPickerPage extends StatefulWidget {
  final LatLng? initialPoint;

  const MapLocationPickerPage({
    super.key,
    this.initialPoint,
  });

  @override
  State<MapLocationPickerPage> createState() =>
      _MapLocationPickerPageState();
}

class _MapLocationPickerPageState
    extends State<MapLocationPickerPage> {
  MapLibreMapController? _controller;
  bool _ready = false;
  bool _locating = false;
  bool _hasLocationPermission = false;

  static const String _style =
      'https://tiles.openfreemap.org/styles/liberty';

  LatLng get _initialPoint =>
      widget.initialPoint ?? const LatLng(0, 0);

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
  }

  Future<void> _onStyleLoaded() async {
    if (!mounted) return;

    setState(() => _ready = true);

    if (widget.initialPoint == null) {
      await _goToCurrentLocation();
    }
  }

  Future<bool> _ensureLocationPermission() async {
    var permission = await Permission.locationWhenInUse.status;
    if (!permission.isGranted) {
      permission = await Permission.locationWhenInUse.request();
    }
    if (permission.isGranted) {
      if (mounted) setState(() => _hasLocationPermission = true);
      return true;
    }

    if (permission.isPermanentlyDenied || permission.isRestricted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Location permission is blocked. Enable it in Android app settings to use GPS.'),
            action: SnackBarAction(
              label: 'SETTINGS',
              onPressed: () async { await openAppSettings(); },
            ),
          ),
        );
      }
    } else {
      _message('Location permission is needed only to centre the map on your device. You can still select a location manually.');
    }
    return false;
  }

  Future<void> _goToCurrentLocation() async {
    final controller = _controller;
    if (controller == null || _locating) return;
    final granted = await _ensureLocationPermission();
    if (!mounted || !granted) return;

    setState(() => _locating = true);

    try {
      final location =
          await controller.requestMyLocationLatLng();

      if (location == null) {
        _message(
          'Current location unavailable. Check GPS permissions.',
        );
        return;
      }

      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: location,
            zoom: 18,
            tilt: 45,
          ),
        ),
        duration: const Duration(milliseconds: 1000),
      );
    } catch (_) {
      _message(
        'Unable to access GPS. You can still move the map manually.',
      );
    } finally {
      if (mounted) {
        setState(() => _locating = false);
      }
    }
  }

  Future<void> _confirmLocation() async {
    final controller = _controller;

    if (controller == null || !_ready) return;

    try {
      final camera = await controller.queryCameraPosition();
      final selected = camera?.target;

      if (selected == null) {
        _message('Unable to read the selected map coordinates.');
        return;
      }

      if (!mounted) return;

      Navigator.pop(context, selected);
    } catch (_) {
      _message('Unable to select this location.');
    }
  }

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101B29),
      appBar: AppBar(
        title: const Text('Select Work Location'),
        backgroundColor: const Color(0xFF10243A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Use current GPS location',
            onPressed: _goToCurrentLocation,
            icon: const Icon(Icons.my_location),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: MapLibreMap(
              styleString: _style,
              initialCameraPosition: CameraPosition(
                target: _initialPoint,
                zoom: widget.initialPoint == null ? 2 : 17,
                tilt: 40,
              ),
              onMapCreated: _onMapCreated,
              onStyleLoadedCallback: _onStyleLoaded,
              myLocationEnabled: _hasLocationPermission,
              compassEnabled: true,
              logoEnabled: true,
              rotateGesturesEnabled: true,
              tiltGesturesEnabled: true,
              zoomGesturesEnabled: true,
              scrollGesturesEnabled: true,
              minMaxZoomPreference:
                  const MinMaxZoomPreference(2, 20),
            ),
          ),

          // Fixed centre marker: selected coordinate is
          // the map centre when the user confirms.
          const Center(
            child: IgnorePointer(
              child: Icon(
                Icons.location_on,
                size: 46,
                color: Color(0xFFE53935),
              ),
            ),
          ),

          if (!_ready)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66101B29),
                child: Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF23C5B5),
                  ),
                ),
              ),
            ),

          Positioned(
            left: 14,
            right: 14,
            bottom: 20,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xF2182638),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Move the map until the required work location '
                    'is under the centre marker.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed:
                        _ready ? _confirmLocation : null,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('CONFIRM THIS LOCATION'),
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          const Color(0xFF13A89E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_locating)
            const Positioned(
              top: 15,
              left: 15,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(width: 9),
                      Text('Finding GPS location...'),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  static const String _mapTilerKey =
      String.fromEnvironment('MAPTILER_API_KEY');
  static const String _vectorStyle =
      'https://tiles.openfreemap.org/styles/liberty';

  MapLibreMapController? _controller;
  CameraPosition? _pendingBasemapCamera;
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _openingMapCases = <String>{};
  Timer? _viewportRefreshTimer;
  List<Map<String, dynamic>> _placeResults = [];
  bool _searching = false;
  bool _utilityQueryInFlight = false;
  String _scaleLabel = '';
  double _scaleWidth = 80;
  bool _is3D = true;
  bool _styleReady = false;
  bool _satellite = _mapTilerKey.isNotEmpty;
  bool _showRequests = true;
  bool _showUtilityZones = false;
  bool _canViewUtilityOverview = false;
  bool _loadingLayers = false;
  bool _locating = false;
  bool _hasLocationPermission = false;
  int _requestMarkerCount = 0;
  int _utilityCellCount = 0;
  int _verifiedAssetCount = 0;
  int _unverifiedAssetCount = 0;
  bool _canViewDepartmentAssets = false;
  bool _showVerifiedAssets = true;
  bool _showCoimbatoreWardBoundaries = true;
  int _coimbatoreWardCount = 0;
  bool _showGroundwaterTelemetry = true;
  int _groundwaterStationCount = 0;
  String _deviceCoordinateLabel = '';
  String _layerStatus =
      'Underground visibility requires authorised, verified GIS records.';

  String get _mapStyle {
    if (_satellite && _mapTilerKey.isNotEmpty) {
      return 'https://api.maptiler.com/maps/hybrid/style.json?key=$_mapTilerKey';
    }
    return _vectorStyle;
  }

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
    controller.onFeatureTapped.add(_onMapFeatureTapped);
  }

  void _onMapFeatureTapped(
    math.Point<double> point,
    LatLng coordinates,
    String id,
    String layerId,
    Annotation? annotation,
  ) {
    if (layerId == 'samanvay-work-request-points') {
      unawaited(_openCaseFromMap(id));
    }
  }

  Future<void> _openCaseFromMap(String requestId) async {
    final id = requestId.trim();
    if (id.isEmpty || !_openingMapCases.add(id)) return;

    try {
      // Re-fetch through the authenticated client. RLS remains the authority
      // for whether this account may open the selected case.
      final row = await supabase
          .from('excavation_requests')
          .select('id,title,request_number')
          .eq('id', id)
          .maybeSingle();

      if (!mounted) return;
      if (row == null) {
        _showMessage('This case is no longer available to your account.');
        return;
      }

      final title = (row['title'] ?? row['request_number'] ?? 'Infrastructure case').toString();
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CaseWorkspacePage(
            requestId: id,
            requestTitle: title,
          ),
        ),
      );
    } catch (_) {
      _showMessage('Unable to open this case. Your account may not have access.');
    } finally {
      _openingMapCases.remove(id);
    }
  }

  @override
  void dispose() {
    _viewportRefreshTimer?.cancel();
    try {
      _controller?.onFeatureTapped.remove(_onMapFeatureTapped);
    } catch (_) {}
    _searchController.dispose();
    super.dispose();
  }

  // Extrude basemap building polygons only where the active provider style
  // supplies OpenMapTiles building attributes. This is city context, not
  // underground utility geometry.
  void _handleCameraIdle() {
    if (!_styleReady) return;
    _viewportRefreshTimer?.cancel();
    _viewportRefreshTimer = Timer(const Duration(milliseconds: 420), () async {
      if (!mounted) return;
      await _refreshMapScale();
      if (!mounted) return;
      if (_showUtilityZones && _canViewUtilityOverview) {
        await _loadUtilityOverview();
      }
      if (_showVerifiedAssets && _canViewDepartmentAssets) {
        await _loadDepartmentAssets();
      }
    });
  }

  Future<void> _refreshMapScale() async {
    final controller = _controller;
    if (controller == null || !_styleReady) return;

    try {
      final camera = await controller.queryCameraPosition();
      if (camera == null) return;
      final latitude = camera.target.latitude.clamp(-85.0, 85.0);
      final metersPerPixel = (
        156543.03392 *
        math.cos(latitude * math.pi / 180) /
        math.pow(2, camera.zoom)
      ).toDouble();

      if (!metersPerPixel.isFinite || metersPerPixel <= 0) return;
      final targetMeters = metersPerPixel * 82;
      final magnitude = math.pow(
        10,
        (math.log(targetMeters) / math.ln10).floor(),
      ).toDouble();
      final fraction = targetMeters / magnitude;
      final niceMeters = (fraction >= 5 ? 5 : (fraction >= 2 ? 2 : 1)) * magnitude;
      final width = (niceMeters / metersPerPixel).clamp(42.0, 112.0).toDouble();
      final label = niceMeters >= 1000
          ? '${(niceMeters / 1000).toStringAsFixed(niceMeters >= 10000 ? 0 : 1)} km'
          : '${niceMeters.toStringAsFixed(niceMeters < 10 ? 1 : 0)} m';

      if (!mounted) return;
      setState(() {
        _scaleLabel = label;
        _scaleWidth = width;
      });
    } catch (_) {
      // A missing camera reading does not block map navigation.
    }
  }

  Future<void> _ensure3DBuildings() async {
    final controller = _controller;
    if (controller == null) return;

    try {
      final sources = await controller.getSourceIds();
      if (!sources.contains('openmaptiles')) return;

      final layers = await controller.getLayerIds();
      if (!layers.contains('samanvay-3d-buildings')) {
        await controller.addFillExtrusionLayer(
          'openmaptiles',
          'samanvay-3d-buildings',
          FillExtrusionLayerProperties(
            fillExtrusionColor: '#66849A',
            fillExtrusionHeight: [
              'interpolate',
              ['linear'],
              ['zoom'],
              14,
              0,
              16,
              ['coalesce', ['get', 'render_height'], ['get', 'height'], 0],
            ],
            fillExtrusionBase: [
              'coalesce',
              ['get', 'render_min_height'],
              ['get', 'min_height'],
              0,
            ],
            fillExtrusionOpacity: 0.84,
          ),
          sourceLayer: 'building',
          minzoom: 14,
          enableInteraction: false,
        );
      }

      await controller.setLayerVisibility('samanvay-3d-buildings', _is3D);
    } catch (_) {
      // If a provider style lacks the expected source/attributes, the
      // basemap remains usable. No illustrative buildings are substituted.
    }
  }

  Future<void> _searchPlaces(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty) {
      _showMessage('Enter a place, area, ward or road name to search.');
      return;
    }
    if (query.length > 120) {
      _showMessage('Search text is too long. Use a shorter place name.');
      return;
    }
    // MapTiler is preferred when configured. Photon provides a no-key
    // OpenStreetMap-based fallback so place search still works in free builds.

    setState(() {
      _searching = true;
      _placeResults = [];
    });

    try {
      final uri = _mapTilerKey.isNotEmpty
          ? Uri.https(
              'api.maptiler.com',
              '/geocoding/$query.json',
              {
                'key': _mapTilerKey,
                'limit': '6',
                'country': 'IN',
                'language': 'en',
                'autocomplete': 'false',
              },
            )
          : Uri.https(
              'photon.komoot.io',
              '/api/',
              {
                'q': query,
                'limit': '6',
                'lang': 'en',
              },
            );
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw StateError('Place search provider returned HTTP ${response.statusCode}.');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['features'] is! List) {
        throw const FormatException('Unexpected place search response.');
      }

      final results = <Map<String, dynamic>>[];
      for (final rawFeature in decoded['features'] as List) {
        if (rawFeature is! Map) continue;
        final feature = Map<String, dynamic>.from(rawFeature);

        if (_mapTilerKey.isNotEmpty) {
          final center = feature['center'];
          if (center is List &&
              center.length >= 2 &&
              center[0] is num &&
              center[1] is num) {
            results.add(feature);
          }
          continue;
        }

        // Normalize Photon GeoJSON to the same shape consumed by _selectPlace.
        final geometry = feature['geometry'];
        final properties = feature['properties'];
        if (geometry is! Map || properties is! Map) continue;
        final coordinates = geometry['coordinates'];
        if (coordinates is! List ||
            coordinates.length < 2 ||
            coordinates[0] is! num ||
            coordinates[1] is! num) {
          continue;
        }
        final props = Map<String, dynamic>.from(properties);
        final name = (props['name'] ??
                props['street'] ??
                props['district'] ??
                props['city'] ??
                'Place')
            .toString();
        final locationParts = [
          name,
          props['district'],
          props['city'],
          props['state'],
          props['country'],
        ].where((part) => part != null && part.toString().trim().isNotEmpty)
         .map((part) => part.toString().trim())
         .toList();
        results.add({
          'center': [coordinates[0], coordinates[1]],
          'text': name,
          'place_name': locationParts.toSet().join(', '),
        });
      }

      if (!mounted) return;
      setState(() => _placeResults = results);
      if (results.isEmpty) {
        _showMessage('No matching place was found. Try a nearby landmark or shorter query.');
      }
    } catch (_) {
      _showMessage('Place search failed. Check the MapTiler key, connection and usage quota.');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _selectPlace(Map<String, dynamic> feature) async {
    final center = feature['center'];
    if (center is! List ||
        center.length < 2 ||
        center[0] is! num ||
        center[1] is! num) {
      _showMessage('The selected place has no usable map coordinates.');
      return;
    }

    final controller = _controller;
    if (controller == null || !_styleReady) return;

    final longitude = (center[0] as num).toDouble();
    final latitude = (center[1] as num).toDouble();
    final name = (feature['place_name'] ?? feature['text'] ?? 'Selected place').toString();

    try {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(latitude, longitude),
            zoom: 16,
            tilt: _is3D ? 58 : 0,
            bearing: _is3D ? -22 : 0,
          ),
        ),
        duration: const Duration(milliseconds: 1100),
      );
      if (!mounted) return;
      setState(() {
        _searchController.text = name;
        _placeResults = [];
      });
      FocusScope.of(context).unfocus();
    } catch (_) {
      _showMessage('Unable to move the map to that search result.');
    }
  }

  Future<void> _onStyleLoaded() async {
    if (!mounted) return;

    setState(() => _styleReady = true);

    final controller = _controller;
    if (controller == null) return;

    try {
      await controller.setMapLanguage('en');

      // Preserve the exact camera when switching between vector and
      // satellite styles. Only use device GPS on the first map load.
      final restoreCamera = _pendingBasemapCamera;
      if (restoreCamera != null) {
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(restoreCamera),
          duration: const Duration(milliseconds: 900),
        );
        _pendingBasemapCamera = null;
      } else {
        await _goToMyLocation();
      }

      await _ensure3DBuildings();
      await _loadMapLayers();
      await _refreshMapScale();
    } catch (_) {
      _showMessage('The map loaded, but one or more data layers could not be prepared.');
    }
  }

  Future<void> _loadCoimbatoreWardBoundaries() async {
    final controller = _controller;
    if (controller == null || !_styleReady) return;

    try {
      final text = await rootBundle.loadString(
        'assets/reference/coimbatore/coimbatore_wards_2024_public_domain.geojson',
      );
      final decoded = jsonDecode(text);
      if (decoded is! Map || decoded['type'] != 'FeatureCollection') {
        throw const FormatException('Invalid ward reference GeoJSON.');
      }
      final rawFeatures = decoded['features'];
      if (rawFeatures is! List || rawFeatures.isEmpty) {
        throw const FormatException('Ward reference GeoJSON has no features.');
      }

      final collection = Map<String, dynamic>.from(decoded);
      final sources = await controller.getSourceIds();
      if (sources.contains('samanvay-coimbatore-ward-reference')) {
        await controller.setGeoJsonSource(
          'samanvay-coimbatore-ward-reference',
          collection,
        );
      } else {
        await controller.addGeoJsonSource(
          'samanvay-coimbatore-ward-reference',
          collection,
        );
      }

      var layers = await controller.getLayerIds();
      if (!layers.contains('samanvay-coimbatore-ward-fill')) {
        await controller.addFillLayer(
          'samanvay-coimbatore-ward-reference',
          'samanvay-coimbatore-ward-fill',
          const FillLayerProperties(
            fillColor: '#20D6C2',
            fillOpacity: 0.045,
            fillOutlineColor: '#45D9CE',
          ),
          enableInteraction: false,
        );
      }

      layers = await controller.getLayerIds();
      if (!layers.contains('samanvay-coimbatore-ward-lines')) {
        await controller.addLineLayer(
          'samanvay-coimbatore-ward-reference',
          'samanvay-coimbatore-ward-lines',
          const LineLayerProperties(
            lineColor: '#45D9CE',
            lineWidth: 1.4,
            lineOpacity: 0.88,
          ),
          enableInteraction: false,
        );
      }

      layers = await controller.getLayerIds();
      if (layers.contains('samanvay-coimbatore-ward-fill')) {
        await controller.setLayerVisibility(
          'samanvay-coimbatore-ward-fill',
          _showCoimbatoreWardBoundaries,
        );
      }
      if (layers.contains('samanvay-coimbatore-ward-lines')) {
        await controller.setLayerVisibility(
          'samanvay-coimbatore-ward-lines',
          _showCoimbatoreWardBoundaries,
        );
      }

      if (mounted) {
        setState(() => _coimbatoreWardCount = rawFeatures.length);
      }
    } catch (_) {
      if (mounted) setState(() => _coimbatoreWardCount = 0);
    }
  }

  Future<void> _loadGroundwaterTelemetryStations() async {
    final controller = _controller;
    if (controller == null || !_styleReady) return;

    try {
      final text = await rootBundle.loadString(
        'assets/reference/coimbatore/groundwater_telemetry_2026_2030.geojson',
      );
      final decoded = jsonDecode(text);
      if (decoded is! Map || decoded['type'] != 'FeatureCollection') {
        throw const FormatException('Invalid groundwater telemetry GeoJSON.');
      }
      final rawFeatures = decoded['features'];
      if (rawFeatures is! List || rawFeatures.isEmpty) {
        throw const FormatException('Groundwater telemetry has no station features.');
      }

      final collection = Map<String, dynamic>.from(decoded);
      final sources = await controller.getSourceIds();
      if (sources.contains('samanvay-groundwater-telemetry')) {
        await controller.setGeoJsonSource(
          'samanvay-groundwater-telemetry',
          collection,
        );
      } else {
        await controller.addGeoJsonSource(
          'samanvay-groundwater-telemetry',
          collection,
        );
      }

      var layers = await controller.getLayerIds();
      if (!layers.contains('samanvay-groundwater-telemetry-points')) {
        await controller.addCircleLayer(
          'samanvay-groundwater-telemetry',
          'samanvay-groundwater-telemetry-points',
          const CircleLayerProperties(
            circleRadius: 6.2,
            circleColor: '#A78BFA',
            circleOpacity: 0.96,
            circleStrokeColor: '#101B29',
            circleStrokeWidth: 1.8,
          ),
          enableInteraction: false,
        );
      }

      layers = await controller.getLayerIds();
      if (layers.contains('samanvay-groundwater-telemetry-points')) {
        await controller.setLayerVisibility(
          'samanvay-groundwater-telemetry-points',
          _showGroundwaterTelemetry,
        );
      }

      if (mounted) {
        setState(() => _groundwaterStationCount = rawFeatures.length);
      }
    } catch (_) {
      if (mounted) setState(() => _groundwaterStationCount = 0);
    }
  }

  Future<void> _loadMapLayers() async {
    final controller = _controller;
    if (controller == null || !_styleReady) return;

    if (mounted) setState(() => _loadingLayers = true);

    try {
      // Public administrative reference data is independent of account role.
      // This 2024 ward reference layer is not a current statutory jurisdiction source.
      await _loadCoimbatoreWardBoundaries();
      await _loadGroundwaterTelemetryStations();

      final user = supabase.auth.currentUser;
      if (user == null) {
        throw StateError('Sign in to view operational map layers.');
      }

      final profile = await supabase
          .from('profiles')
          .select('role,department_id')
          .eq('id', user.id)
          .maybeSingle();

      final role = (profile?['role'] ?? '').toString();
      final authorised = ['admin', 'coordinator', 'department'].contains(role);
      final departmentAssigned = role == 'department' &&
          profile?['department_id'] != null;

      final requestRows = await supabase
          .from('excavation_requests')
          .select('id,request_number,title,status,latitude,longitude')
          .order('created_at', ascending: false)
          .limit(500);

      final features = <Map<String, dynamic>>[];
      for (final row in List<Map<String, dynamic>>.from(requestRows)) {
        final lat = (row['latitude'] as num?)?.toDouble();
        final lon = (row['longitude'] as num?)?.toDouble();
        if (lat == null || lon == null || lat.abs() > 90 || lon.abs() > 180) {
          continue;
        }

        features.add({
          'type': 'Feature',
          'id': row['id'].toString(),
          'geometry': {
            'type': 'Point',
            'coordinates': [lon, lat],
          },
          'properties': {
            'request_id': row['id'].toString(),
            'request_number': row['request_number']?.toString() ?? '',
            'title': row['title']?.toString() ?? 'Infrastructure request',
            'status': row['status']?.toString() ?? 'submitted',
          },
        });
      }

      final sourceIds = await controller.getSourceIds();
      if (sourceIds.contains('samanvay-work-requests')) {
        await controller.setGeoJsonSource(
          'samanvay-work-requests',
          {'type': 'FeatureCollection', 'features': features},
        );
      } else {
        await controller.addGeoJsonSource(
          'samanvay-work-requests',
          {'type': 'FeatureCollection', 'features': features},
        );
      }

      final layerIds = await controller.getLayerIds();
      if (!layerIds.contains('samanvay-work-request-points')) {
        await controller.addCircleLayer(
          'samanvay-work-requests',
          'samanvay-work-request-points',
          CircleLayerProperties(
            circleRadius: 6,
            circleColor: [
              'match',
              ['get', 'status'],
              'submitted', '#38BDF8',
              'under_review', '#F59E0B',
              'approved', '#22C55E',
              'in_progress', '#F97316',
              'completed', '#64748B',
              'resolved', '#64748B',
              'rejected', '#EF4444',
              '#20D6C2',
            ],
            circleOpacity: 0.96,
            circleStrokeColor: '#082033',
            circleStrokeWidth: 1.6,
          ),
          enableInteraction: true,
        );
      } else {
        await controller.setLayerVisibility(
          'samanvay-work-request-points',
          _showRequests,
        );
      }

      if (mounted) {
        setState(() {
          _requestMarkerCount = features.length;
          _canViewUtilityOverview = authorised;
          _canViewDepartmentAssets = departmentAssigned;
          _layerStatus = departmentAssigned
              ? 'Department GIS view: verified assets owned by your department can be displayed.'
              : authorised
                  ? 'Staff GIS view: generalised utility coverage only; exact asset geometry is restricted.'
                  : 'Requester GIS view: only requests visible to your account are shown.';
        });
      }

      if (_showUtilityZones && authorised) {
        await _loadUtilityOverview();
      }
      if (_showVerifiedAssets && departmentAssigned) {
        await _loadDepartmentAssets();
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _layerStatus = 'Operational layers could not be loaded. Check your connection and account access.';
        });
      }
    } finally {
      if (mounted) setState(() => _loadingLayers = false);
    }
  }

  Future<void> _loadUtilityOverview() async {
    final controller = _controller;
    if (controller == null || !_styleReady || !_canViewUtilityOverview || _utilityQueryInFlight) return;
    _utilityQueryInFlight = true;

    try {
      final bounds = await controller.getVisibleRegion();
      final minLon = bounds.southwest.longitude;
      final minLat = bounds.southwest.latitude;
      final maxLon = bounds.northeast.longitude;
      final maxLat = bounds.northeast.latitude;

      if (minLon >= maxLon || minLat >= maxLat) {
        _showMessage('The current map extent cannot be queried. Adjust the view and retry.');
        return;
      }

      // This endpoint returns generalised 250 m aggregate cells, never exact utility routes.
      final raw = await supabase.rpc(
        'get_underground_asset_overview',
        params: {
          'p_min_lon': minLon,
          'p_min_lat': minLat,
          'p_max_lon': maxLon,
          'p_max_lat': maxLat,
        },
      );

      final geojson = Map<String, dynamic>.from(raw as Map);
      final featureList = geojson['features'];
      final count = featureList is List ? featureList.length : 0;

      final sourceIds = await controller.getSourceIds();
      if (sourceIds.contains('samanvay-utility-overview')) {
        await controller.setGeoJsonSource(
          'samanvay-utility-overview',
          geojson,
        );
      } else {
        await controller.addGeoJsonSource(
          'samanvay-utility-overview',
          geojson,
        );
      }

      final layerIds = await controller.getLayerIds();
      if (!layerIds.contains('samanvay-utility-overview-cells')) {
        await controller.addFillLayer(
          'samanvay-utility-overview',
          'samanvay-utility-overview-cells',
          const FillLayerProperties(
            fillColor: '#F59E0B',
            fillOpacity: 0.30,
            fillOutlineColor: '#FDE68A',
          ),
        );
      } else {
        await controller.setLayerVisibility(
          'samanvay-utility-overview-cells',
          _showUtilityZones,
        );
      }

      if (mounted) {
        setState(() {
          _utilityCellCount = count;
          _layerStatus = count == 0
              ? 'No verified aggregate records in this view. This does NOT mean underground infrastructure is absent.'
              : '$count generalised utility coverage cell(s) returned. Exact utility geometry is not displayed in this overview.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _utilityCellCount = 0;
          _layerStatus = 'The authorised utility overview is unavailable. No data is not proof of no utility.';
        });
      }
      _showMessage('Unable to load the authorised utility overview.');
    } finally {
      _utilityQueryInFlight = false;
    }
  }

  Future<void> _loadDepartmentAssets() async {
    final controller = _controller;
    if (controller == null || !_styleReady || !_canViewDepartmentAssets) return;

    try {
      final bounds = await controller.getVisibleRegion();
      final minLon = bounds.southwest.longitude;
      final minLat = bounds.southwest.latitude;
      final maxLon = bounds.northeast.longitude;
      final maxLat = bounds.northeast.latitude;
      if (minLon >= maxLon || minLat >= maxLat) return;

      // This RPC is scoped by auth.uid() to the signed-in department's own assets.
      // Only verified features are drawn; unverified records are counted, not mapped.
      final raw = await supabase.rpc(
        'get_my_department_verified_assets_geojson',
        params: {
          'p_min_lon': minLon,
          'p_min_lat': minLat,
          'p_max_lon': maxLon,
          'p_max_lat': maxLat,
        },
      );
      final collection = Map<String, dynamic>.from(raw as Map);
      final rawFeatures = collection['features'];
      final verified = <Map<String, dynamic>>[];
      final metadata = collection['metadata'] is Map
          ? Map<String, dynamic>.from(collection['metadata'] as Map)
          : <String, dynamic>{};
      final unverified = (metadata['withheld_unverified_count'] as num?)?.toInt() ?? 0;

      if (rawFeatures is List) {
        for (final item in rawFeatures) {
          if (item is! Map) continue;
          final feature = Map<String, dynamic>.from(item);
          final properties = feature['properties'];
          if (properties is! Map) continue;
          final props = Map<String, dynamic>.from(properties);
          feature['id'] = (props['id'] ?? feature['id'] ?? '').toString();
          verified.add(feature);
        }
      }

      final verifiedCollection = <String, dynamic>{
        'type': 'FeatureCollection',
        'features': verified,
      };
      final sources = await controller.getSourceIds();
      if (sources.contains('samanvay-verified-department-assets')) {
        await controller.setGeoJsonSource(
          'samanvay-verified-department-assets',
          verifiedCollection,
        );
      } else {
        await controller.addGeoJsonSource(
          'samanvay-verified-department-assets',
          verifiedCollection,
        );
      }

      final layers = await controller.getLayerIds();
      if (!layers.contains('samanvay-verified-asset-lines')) {
        await controller.addLineLayer(
          'samanvay-verified-department-assets',
          'samanvay-verified-asset-lines',
          LineLayerProperties(
            lineColor: [
              'match',
              ['get', 'asset_type'],
              'water', '#38BDF8',
              'sewer', '#A78BFA',
              'stormwater', '#22D3EE',
              'electricity', '#FBBF24',
              'telecom', '#F472B6',
              'gas', '#FB923C',
              '#20D6C2',
            ],
            lineWidth: 3.5,
            lineOpacity: 0.96,
          ),
          enableInteraction: false,
        );
      } else {
        await controller.setLayerVisibility(
          'samanvay-verified-asset-lines',
          _showVerifiedAssets,
        );
      }

      if (!layers.contains('samanvay-verified-asset-points')) {
        await controller.addCircleLayer(
          'samanvay-verified-department-assets',
          'samanvay-verified-asset-points',
          CircleLayerProperties(
            circleRadius: 5.5,
            circleColor: [
              'match',
              ['get', 'asset_type'],
              'water', '#38BDF8',
              'sewer', '#A78BFA',
              'stormwater', '#22D3EE',
              'electricity', '#FBBF24',
              'telecom', '#F472B6',
              'gas', '#FB923C',
              '#20D6C2',
            ],
            circleStrokeColor: '#071827',
            circleStrokeWidth: 1.8,
            circleOpacity: 0.98,
          ),
          enableInteraction: false,
        );
      } else {
        await controller.setLayerVisibility(
          'samanvay-verified-asset-points',
          _showVerifiedAssets,
        );
      }

      if (mounted) {
        setState(() {
          _verifiedAssetCount = verified.length;
          _unverifiedAssetCount = unverified;
          _layerStatus = verified.isEmpty
              ? 'No verified assets are registered in this department and map extent. $unverified unverified record(s) are withheld from the map.'
              : '$verified verified department asset(s) mapped. $unverified unverified record(s) withheld.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _verifiedAssetCount = 0;
          _layerStatus = 'Department asset layer unavailable. No unverified or estimated geometry is substituted.';
        });
      }
    }
  }

  Future<void> _toggleVerifiedAssets(bool enabled) async {
    if (!_canViewDepartmentAssets) {
      _showMessage('Verified asset geometry is restricted to the owning department.');
      return;
    }
    setState(() => _showVerifiedAssets = enabled);
    final controller = _controller;
    if (controller == null || !_styleReady) return;
    if (!enabled) {
      final layers = await controller.getLayerIds();
      if (layers.contains('samanvay-verified-asset-lines')) {
        await controller.setLayerVisibility('samanvay-verified-asset-lines', false);
      }
      if (layers.contains('samanvay-verified-asset-points')) {
        await controller.setLayerVisibility('samanvay-verified-asset-points', false);
      }
      return;
    }
    await _loadDepartmentAssets();
  }

  Future<void> _toggleRequests(bool enabled) async {
    setState(() => _showRequests = enabled);
    final controller = _controller;
    if (controller == null || !_styleReady) return;

    try {
      final layers = await controller.getLayerIds();
      if (!layers.contains('samanvay-work-request-points')) {
        await _loadMapLayers();
      } else {
        await controller.setLayerVisibility(
          'samanvay-work-request-points',
          enabled,
        );
      }
    } catch (_) {
      _showMessage('Unable to change the request layer.');
    }
  }

  Future<void> _toggleCoimbatoreWardBoundaries(bool enabled) async {
    setState(() => _showCoimbatoreWardBoundaries = enabled);
    final controller = _controller;
    if (controller == null || !_styleReady) return;

    if (enabled) {
      await _loadCoimbatoreWardBoundaries();
      return;
    }

    try {
      final layers = await controller.getLayerIds();
      if (layers.contains('samanvay-coimbatore-ward-fill')) {
        await controller.setLayerVisibility(
          'samanvay-coimbatore-ward-fill',
          false,
        );
      }
      if (layers.contains('samanvay-coimbatore-ward-lines')) {
        await controller.setLayerVisibility(
          'samanvay-coimbatore-ward-lines',
          false,
        );
      }
    } catch (_) {
      _showMessage('Unable to change the Coimbatore ward reference layer.');
    }
  }

  Future<void> _toggleGroundwaterTelemetry(bool enabled) async {
    setState(() => _showGroundwaterTelemetry = enabled);
    final controller = _controller;
    if (controller == null || !_styleReady) return;

    if (enabled) {
      await _loadGroundwaterTelemetryStations();
      return;
    }

    try {
      final layers = await controller.getLayerIds();
      if (layers.contains('samanvay-groundwater-telemetry-points')) {
        await controller.setLayerVisibility(
          'samanvay-groundwater-telemetry-points',
          false,
        );
      }
    } catch (_) {
      _showMessage('Unable to change the groundwater telemetry layer.');
    }
  }

  Future<void> _toggleUtilityZones(bool enabled) async {
    if (!_canViewUtilityOverview) {
      _showMessage('The utility overview is restricted to authorised infrastructure staff.');
      return;
    }

    setState(() => _showUtilityZones = enabled);
    final controller = _controller;
    if (controller == null || !_styleReady) return;

    if (!enabled) {
      try {
        final layers = await controller.getLayerIds();
        if (layers.contains('samanvay-utility-overview-cells')) {
          await controller.setLayerVisibility(
            'samanvay-utility-overview-cells',
            false,
          );
        }
      } catch (_) {}
      return;
    }

    await _loadUtilityOverview();
  }

  Future<void> _changeBasemap(bool useSatellite) async {
    if (useSatellite && _mapTilerKey.isEmpty) {
      _showMessage(
        'Satellite imagery is ready to connect, but MAPTILER_API_KEY is not configured in the release build.',
      );
      return;
    }

    if (_satellite == useSatellite) return;

    try {
      _pendingBasemapCamera = await _controller?.queryCameraPosition();
    } catch (_) {
      _pendingBasemapCamera = null;
    }
    if (!mounted) return;

    setState(() {
      _satellite = useSatellite;
      _styleReady = false;
      _controller = null;
      _requestMarkerCount = 0;
      _utilityCellCount = 0;
    });
  }

  Future<void> _changePerspective(bool use3D) async {
    final controller = _controller;
    if (controller == null || !_styleReady) return;

    try {
      final current = await controller.queryCameraPosition();
      final target = current?.target ?? const LatLng(0, 0);
      final zoom = current?.zoom ?? 13.0;

      setState(() => _is3D = use3D);

      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: target,
            zoom: zoom < 14 ? 14 : zoom,
            tilt: use3D ? 58 : 0,
            bearing: use3D ? -22 : 0,
          ),
        ),
        duration: const Duration(milliseconds: 1100),
      );
      final layers = await controller.getLayerIds();
      if (layers.contains('samanvay-3d-buildings')) {
        await controller.setLayerVisibility('samanvay-3d-buildings', use3D);
      }
    } catch (_) {
      _showMessage('Unable to change map perspective.');
    }
  }

  Future<void> _zoom(bool zoomIn) async {
    final controller = _controller;
    if (controller == null || !_styleReady) return;

    await controller.animateCamera(
      zoomIn ? CameraUpdate.zoomIn() : CameraUpdate.zoomOut(),
      duration: const Duration(milliseconds: 420),
    );
  }

  Future<bool> _ensureLocationPermission() async {
    var permission = await Permission.locationWhenInUse.status;
    if (!permission.isGranted) {
      permission = await Permission.locationWhenInUse.request();
    }
    if (permission.isGranted) {
      if (mounted) setState(() => _hasLocationPermission = true);
      return true;
    }

    if (permission.isPermanentlyDenied || permission.isRestricted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Location permission is blocked. Enable it in Android app settings to use GPS.'),
            action: SnackBarAction(
              label: 'SETTINGS',
              onPressed: () async { await openAppSettings(); },
            ),
          ),
        );
      }
    } else {
      _showMessage('Location permission is required to centre the map on your device. You can continue browsing without GPS.');
    }
    return false;
  }

  Future<void> _goToMyLocation() async {
    final controller = _controller;
    if (controller == null || !_styleReady || _locating) return;
    final granted = await _ensureLocationPermission();
    if (!granted) return;

    setState(() => _locating = true);
    try {
      final location = await controller.requestMyLocationLatLng();

      if (location == null) {
        _showMessage('Your device did not provide a location. Check GPS and app location permission.');
        return;
      }

      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: location,
            zoom: 17.0,
            tilt: _is3D ? 58 : 0,
            bearing: _is3D ? -22 : 0,
          ),
        ),
        duration: const Duration(milliseconds: 1200),
      );
      if (mounted) {
        setState(() {
          _deviceCoordinateLabel =
              '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}';
        });
      }
    } catch (_) {
      _showMessage('Unable to access device location. You can still navigate the map manually.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openAttribution() async {
    final uri = Uri.parse(
      _satellite
          ? 'https://www.maptiler.com/copyright/'
          : 'https://openfreemap.org/',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      _showMessage('Unable to open the map provider attribution page.');
    }
  }

  void _openLayerPanel() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF13263A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 26),
            child: StatefulBuilder(
              builder: (context, setSheetState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'GIS LAYERS',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Layers are drawn only from records your account is authorised to access.',
                      style: TextStyle(color: Color(0xFFB8C7D5), fontSize: 11),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      value: _showRequests,
                      activeThumbColor: const Color(0xFF20D6C2),
                      title: const Text('Work request locations',
                          style: TextStyle(color: Colors.white)),
                      subtitle: Text(
                        '$_requestMarkerCount request marker(s) visible to your account',
                        style: const TextStyle(color: Color(0xFFB8C7D5), fontSize: 11),
                      ),
                      onChanged: (value) {
                        setSheetState(() {});
                        _toggleRequests(value);
                      },
                    ),
                    SwitchListTile(
                      value: _showCoimbatoreWardBoundaries,
                      activeThumbColor: const Color(0xFF20D6C2),
                      title: const Text(
                        'Coimbatore ward boundaries (2024 reference)',
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        '$_coimbatoreWardCount polygons · OpenCity Public Domain dataset · reference only; confirm legal boundaries with CCMC',
                        style: const TextStyle(
                          color: Color(0xFFB8C7D5),
                          fontSize: 11,
                        ),
                      ),
                      onChanged: (value) {
                        setSheetState(() {});
                        _toggleCoimbatoreWardBoundaries(value);
                      },
                    ),
                    SwitchListTile(
                      value: _showGroundwaterTelemetry,
                      activeThumbColor: const Color(0xFFA78BFA),
                      title: const Text(
                        'Groundwater telemetry stations (2026–2030)',
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        '$_groundwaterStationCount Coimbatore district stations · latest published reading shown by timestamp · not a borewell register',
                        style: const TextStyle(
                          color: Color(0xFFB8C7D5),
                          fontSize: 11,
                        ),
                      ),
                      onChanged: (value) {
                        setSheetState(() {});
                        _toggleGroundwaterTelemetry(value);
                      },
                    ),
                    if (_canViewDepartmentAssets)
                      SwitchListTile(
                        value: _showVerifiedAssets,
                        activeThumbColor: const Color(0xFF20D6C2),
                        title: const Text('Verified department assets',
                            style: TextStyle(color: Colors.white)),
                        subtitle: Text(
                          '$_verifiedAssetCount verified asset(s) mapped · $_unverifiedAssetCount unverified withheld',
                          style: const TextStyle(color: Color(0xFFB8C7D5), fontSize: 11),
                        ),
                        onChanged: (value) {
                          setSheetState(() {});
                          _toggleVerifiedAssets(value);
                        },
                      ),
                    if (_canViewUtilityOverview)
                      SwitchListTile(
                        value: _showUtilityZones,
                        activeThumbColor: const Color(0xFFF59E0B),
                        title: const Text('Generalised utility coverage',
                            style: TextStyle(color: Colors.white)),
                        subtitle: Text(
                          '$_utilityCellCount aggregate cell(s); not individual utility routes',
                          style: const TextStyle(color: Color(0xFFB8C7D5), fontSize: 11),
                        ),
                        onChanged: (value) {
                          setSheetState(() {});
                          _toggleUtilityZones(value);
                        },
                      )
                    else
                      const ListTile(
                        leading: Icon(Icons.lock_outline, color: Color(0xFFF6C66B)),
                        title: Text('Utility coverage restricted',
                            style: TextStyle(color: Colors.white)),
                        subtitle: Text(
                          'Detailed infrastructure records are not available to requester accounts.',
                          style: TextStyle(color: Color(0xFFB8C7D5), fontSize: 11),
                        ),
                      ),
                    const Divider(color: Color(0x334B647C)),
                    const Text(
                      'Data integrity',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _layerStatus,
                      style: const TextStyle(color: Color(0xFFB8C7D5), fontSize: 11, height: 1.4),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _mapButton({
    required IconData icon,
    required VoidCallback onPressed,
    String? tooltip,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: const Color(0xF2182638),
        elevation: 5,
        borderRadius: BorderRadius.circular(12),
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon, color: Colors.white, size: 21),
        ),
      ),
    );
  }

  Widget _pill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF13A89E) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101B29),
      appBar: AppBar(
        backgroundColor: const Color(0xFF10243A),
        foregroundColor: Colors.white,
        titleSpacing: 16,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SAMANVAY GIS',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'GEOSPATIAL INFRASTRUCTURE WORKSPACE',
              style: TextStyle(
                fontSize: 9,
                letterSpacing: 1.35,
                color: Color(0xFF9FB4C8),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Import underground survey GeoJSON',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AssetGeoJsonImportPage(),
                ),
              );
            },
            icon: const Icon(Icons.file_upload_outlined),
          ),
          IconButton(
            tooltip: 'Layer controls',
            onPressed: _openLayerPanel,
            icon: const Icon(Icons.layers_outlined),
          ),
          IconButton(
            tooltip: 'My device location',
            onPressed: _goToMyLocation,
            icon: const Icon(Icons.my_location),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: MapLibreMap(
              key: ValueKey(_satellite ? 'samanvay-satellite' : 'samanvay-vector'),
              styleString: _mapStyle,
              // Regional fallback only; a granted device GPS fix immediately
              // replaces this camera. Never present 0,0 as the user's location.
              initialCameraPosition: const CameraPosition(
                target: LatLng(10.8, 78.6),
                zoom: 5.7,
                tilt: 0,
                bearing: 0,
              ),
              onMapCreated: _onMapCreated,
              onStyleLoadedCallback: _onStyleLoaded,
              onCameraIdle: _handleCameraIdle,
              myLocationEnabled: _hasLocationPermission,
              myLocationTrackingMode: MyLocationTrackingMode.none,
              compassEnabled: true,
              logoEnabled: true,
              rotateGesturesEnabled: true,
              tiltGesturesEnabled: true,
              zoomGesturesEnabled: true,
              scrollGesturesEnabled: true,
              trackCameraPosition: true,
              minMaxZoomPreference: const MinMaxZoomPreference(2, 20),
            ),
          ),

          if (!_styleReady)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66101B29),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Color(0xFF23C5B5)),
                      SizedBox(height: 14),
                      Text(
                        'INITIALISING GIS ENGINE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          letterSpacing: 1.7,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          Positioned(
            left: 12,
            top: 12,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 218),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xE6102031),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: const Color(0x5539BDB0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _satellite ? 'SATELLITE HYBRID' : 'VECTOR BASEMAP',
                    style: const TextStyle(
                      color: Color(0xFF9FB4C8),
                      fontSize: 9,
                      letterSpacing: 1.3,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _satellite ? 'AERIAL IMAGERY' : '2D / 3D CAMERA',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (_deviceCoordinateLabel.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      'DEVICE GPS  $_deviceCoordinateLabel',
                      style: const TextStyle(
                        color: Color(0xFF55D9CE),
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _satellite
                        ? 'Imagery date and resolution vary by location.'
                        : '3D perspective depends on available building data.',
                    style: const TextStyle(
                      color: Color(0xFFB6C7D6),
                      fontSize: 9,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            left: 12,
            right: 62,
            top: 116,
            child: Container(
              padding: const EdgeInsets.only(left: 12, right: 4),
              decoration: BoxDecoration(
                color: const Color(0xF2182638),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: const Color(0x6639BDB0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 14,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: Color(0xFF55D9CE), size: 20),
                  const SizedBox(width: 9),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: _searchPlaces,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: const InputDecoration(
                        hintText: 'Search area / ward / road',
                        hintStyle: TextStyle(color: Color(0xFF9FB4C8), fontSize: 11),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Search place',
                    onPressed: _searching ? null : () => _searchPlaces(_searchController.text),
                    icon: _searching
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF55D9CE),
                            ),
                          )
                        : const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 19),
                  ),
                ],
              ),
            ),
          ),

          if (_placeResults.isNotEmpty)
            Positioned(
              left: 12,
              right: 62,
              top: 172,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 240),
                decoration: BoxDecoration(
                  color: const Color(0xF2182638),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: const Color(0x6639BDB0)),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  itemCount: _placeResults.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0x334B647C)),
                  itemBuilder: (context, index) {
                    final feature = _placeResults[index];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.location_on_outlined, color: Color(0xFF55D9CE), size: 20),
                      title: Text(
                        (feature['text'] ?? 'Place').toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        (feature['place_name'] ?? '').toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFFB8C7D5), fontSize: 9),
                      ),
                      onTap: () => _selectPlace(feature),
                    );
                  },
                ),
              ),
            ),

          Positioned(
            right: 11,
            top: 12,
            child: Column(
              children: [
                _mapButton(
                  icon: Icons.add,
                  tooltip: 'Zoom in',
                  onPressed: () => _zoom(true),
                ),
                _mapButton(
                  icon: Icons.remove,
                  tooltip: 'Zoom out',
                  onPressed: () => _zoom(false),
                ),
                _mapButton(
                  icon: Icons.layers_outlined,
                  tooltip: 'Map layers',
                  onPressed: _openLayerPanel,
                ),
              ],
            ),
          ),

          if (_scaleLabel.isNotEmpty)
            Positioned(
              left: 14,
              bottom: 183,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xE6102031),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: const Color(0x5539BDB0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _scaleLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: _scaleWidth,
                      height: 3,
                      decoration: BoxDecoration(
                        color: const Color(0xFF55D9CE),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          Positioned(
            left: 12,
            right: 12,
            bottom: 118,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xF2182638),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: const Color(0x5539BDB0)),
              ),
              child: Row(
                children: [
                  _pill(
                    label: 'VECTOR',
                    selected: !_satellite,
                    onTap: () => _changeBasemap(false),
                  ),
                  _pill(
                    label: 'SATELLITE',
                    selected: _satellite,
                    onTap: () => _changeBasemap(true),
                  ),
                  const SizedBox(width: 4),
                  Container(width: 1, height: 24, color: const Color(0x554B647C)),
                  const SizedBox(width: 4),
                  _pill(
                    label: '2D',
                    selected: !_is3D,
                    onTap: () => _changePerspective(false),
                  ),
                  _pill(
                    label: '3D',
                    selected: _is3D,
                    onTap: () => _changePerspective(true),
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            left: 12,
            right: 12,
            bottom: 54,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xF2182638),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: const Color(0x5539BDB0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.hub_outlined, color: Color(0xFF35C6B5), size: 19),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      _loadingLayers
                          ? 'SYNCING AUTHORISED GIS LAYERS...'
                          : _layerStatus,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFD4E1EA),
                        fontSize: 9,
                        height: 1.3,
                      ),
                    ),
                  ),
                  if (_loadingLayers)
                    const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF35C6B5),
                      ),
                    )
                  else
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Refresh layers',
                      onPressed: _loadMapLayers,
                      icon: const Icon(Icons.refresh, color: Colors.white, size: 19),
                    ),
                ],
              ),
            ),
          ),

          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _openAttribution,
                    child: Text(
                      _satellite
                          ? '© MapTiler · © OpenStreetMap contributors'
                          : '© OpenFreeMap · © OpenStreetMap contributors',
                      style: const TextStyle(
                        color: Color(0xFFE1EAF1),
                        fontSize: 8,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                if (_locating)
                  const Text(
                    'LOCATING',
                    style: TextStyle(color: Color(0xFF35C6B5), fontSize: 8),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// AUTHORISED GIS DATA INGESTION
// ==========================================

class AssetGeoJsonImportPage extends StatefulWidget {
  const AssetGeoJsonImportPage({super.key});

  @override
  State<AssetGeoJsonImportPage> createState() => _AssetGeoJsonImportPageState();
}

class _AssetGeoJsonImportPageState extends State<AssetGeoJsonImportPage> {
  static const Set<String> _assetTypes = {
    'water', 'sewer', 'stormwater', 'electricity', 'telecom',
    'gas', 'borewell', 'drain', 'other', 'unknown',
  };
  static const Set<String> _sourceTypes = {
    'utility_owner', 'field_survey', 'as_built_drawing',
    'public_dataset', 'estimated', 'other',
  };
  static const Set<String> _geometryTypes = {
    'Point', 'MultiPoint', 'LineString', 'MultiLineString',
  };

  bool _checkingAccess = true;
  bool _authorised = false;
  bool _loadingFile = false;
  bool _importing = false;
  String _departmentName = '';
  String _fileName = '';
  String _status = 'Select a GeoJSON FeatureCollection from an authorised survey source.';
  List<Map<String, dynamic>> _records = [];
  List<String> _errors = [];
  int _imported = 0;
  int _failed = 0;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw StateError('Sign in to continue.');
      final profile = await supabase.from('profiles')
          .select('role,department_id').eq('id', user.id).maybeSingle();
      final role = (profile?['role'] ?? '').toString();
      final departmentId = profile?['department_id']?.toString();
      if (role != 'department' || departmentId == null || departmentId.isEmpty) {
        throw StateError('Only an assigned department account can register underground utility records. The database independently enforces this restriction.');
      }
      final department = await supabase.from('departments')
          .select('name').eq('id', departmentId).maybeSingle();
      if (!mounted) return;
      setState(() {
        _authorised = true;
        _departmentName = (department?['name'] ?? 'Assigned department').toString();
        _status = 'Access confirmed. Imported records will be stored as UNVERIFIED.';
      });
    } catch (error) {
      if (mounted) {
        setState(() => _status = error.toString().replaceFirst('Bad state: ', ''));
      }
    } finally {
      if (mounted) setState(() => _checkingAccess = false);
    }
  }

  bool _validCoordinates(dynamic value) {
    if (value is! List || value.length < 2) return false;
    if (value[0] is num && value[1] is num) {
      final lon = (value[0] as num).toDouble();
      final lat = (value[1] as num).toDouble();
      return lon >= -180 && lon <= 180 && lat >= -90 && lat <= 90;
    }
    return value.isNotEmpty && value.every(_validCoordinates);
  }

  String? _validate(Map<String, dynamic> feature) {
    if (feature['geometry'] is! Map || feature['properties'] is! Map) {
      return 'Geometry and properties objects are required.';
    }
    final geometry = Map<String, dynamic>.from(feature['geometry'] as Map);
    final type = (geometry['type'] ?? '').toString();
    if (!_geometryTypes.contains(type)) return 'Unsupported geometry type: $type';
    if (!_validCoordinates(geometry['coordinates'])) return 'Invalid WGS84 coordinates. GeoJSON order must be [longitude, latitude].';

    final p = Map<String, dynamic>.from(feature['properties'] as Map);
    final code = (p['asset_code'] ?? '').toString().trim();
    final name = (p['asset_name'] ?? '').toString().trim();
    final assetType = (p['asset_type'] ?? '').toString().trim().toLowerCase();
    final sourceType = (p['source_type'] ?? '').toString().trim().toLowerCase();
    if (code.length < 2 || code.length > 100) return 'asset_code is required (2–100 characters).';
    if (name.length < 2 || name.length > 200) return 'asset_name is required (2–200 characters).';
    if (!_assetTypes.contains(assetType)) return 'Unsupported asset_type.';
    if (!_sourceTypes.contains(sourceType)) return 'Unsupported source_type.';

    for (final key in ['depth_m', 'horizontal_accuracy_m', 'vertical_accuracy_m', 'diameter_mm']) {
      final raw = p[key];
      if (raw == null || raw.toString().trim().isEmpty) continue;
      final value = double.tryParse(raw.toString());
      if (value == null || !value.isFinite || value < 0) return '$key must be a non-negative number.';
    }
    final depth = double.tryParse((p['depth_m'] ?? '').toString());
    if (depth != null && depth > 100) return 'depth_m cannot exceed 100 metres.';
    final diameter = double.tryParse((p['diameter_mm'] ?? '').toString());
    if (diameter != null && (diameter <= 0 || diameter > 10000)) return 'diameter_mm must be 1–10000.';
    return null;
  }

  Future<void> _pickFile() async {
    if (!_authorised || _importing || _loadingFile) return;
    setState(() {
      _loadingFile = true;
      _records = [];
      _errors = [];
      _fileName = '';
      _imported = 0;
      _failed = 0;
      _progress = 0;
    });
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['geojson', 'json'],
      );
      if (file == null) return;
      final fileSize = await file.length();
      if (fileSize == null || fileSize > 10 * 1024 * 1024) {
        throw StateError('File size could not be confirmed or exceeds 10 MB.');
      }
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) throw StateError('The selected file is empty. Export it as UTF-8 GeoJSON.');
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map || decoded['type'] != 'FeatureCollection' || decoded['features'] is! List) {
        throw const FormatException('Expected a GeoJSON FeatureCollection.');
      }
      final features = decoded['features'] as List;
      if (features.isEmpty) throw StateError('No features found in the file.');
      if (features.length > 500) throw StateError('Maximum 500 features per import batch.');
      final records = <Map<String, dynamic>>[];
      final errors = <String>[];
      final seen = <String>{};
      for (var i = 0; i < features.length; i++) {
        final raw = features[i];
        final feature = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
        var error = raw is Map ? _validate(feature) : 'Feature is not a JSON object.';
        final props = feature['properties'] is Map
            ? Map<String, dynamic>.from(feature['properties'] as Map) : <String, dynamic>{};
        final code = (props['asset_code'] ?? '').toString().trim();
        if (error == null && !seen.add(code)) error = 'Duplicate asset_code in this file.';
        records.add({'feature': feature, 'error': error});
        if (error != null) errors.add('Feature ${i + 1}: $error');
      }
      if (!mounted) return;
      setState(() {
        _fileName = file.name;
        _records = records;
        _errors = errors;
        _status = 'Preview ready. ${records.length - errors.length} valid feature(s); ${errors.length} invalid feature(s). Nothing has been written yet.';
      });
    } catch (error) {
      if (mounted) setState(() => _status = 'Preview failed: ${error.toString().replaceFirst('Bad state: ', '')}');
    } finally {
      if (mounted) setState(() => _loadingFile = false);
    }
  }

  Future<void> _register() async {
    if (!_authorised || _importing) return;
    final valid = _records.where((r) => r['error'] == null).toList();
    if (valid.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Register as unverified?'),
        content: Text(
          '${valid.length} records from "$_fileName" will be registered under $_departmentName. '
          'They remain UNVERIFIED until an authorised verification process is completed.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Register')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() {
      _importing = true;
      _progress = 0;
      _imported = 0;
      _failed = 0;
      _errors = [];
      _status = 'Sending validated batch to the secured server-side registry…';
    });

    try {
      final features = valid
          .map((record) => Map<String, dynamic>.from(record['feature'] as Map))
          .toList(growable: false);
      final response = await supabase.functions.invoke(
        'samanvay-asset-registry',
        body: {'action': 'import', 'features': features},
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      final imported = (data['imported'] as num?)?.toInt() ?? 0;
      final failed = (data['failed'] as num?)?.toInt() ?? (valid.length - imported);
      final resultRows = data['results'] is List ? data['results'] as List : const [];
      final errors = <String>[];
      for (final row in resultRows) {
        if (row is! Map) continue;
        final item = Map<String, dynamic>.from(row);
        if (item['error'] != null) {
          errors.add('${item['asset_code'] ?? 'Unknown feature'}: ${item['error']}');
        }
      }

      if (!mounted) return;
      setState(() {
        _imported = imported;
        _failed = failed;
        _progress = valid.length;
        _errors = errors;
        _status = 'Server registration complete: $_imported stored as UNVERIFIED; $_failed failed. '
            'Only authorised department-owned records are accepted.';
        _records = [];
        _fileName = '';
        _importing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registry import: $_imported registered; $_failed failed.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _failed = valid.length;
        _progress = 0;
        _errors = [error.toString()];
        _status = 'Server-side import failed. No success has been assumed; check the session and retry after resolving the error.';
        _importing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GIS import failed. No records were confirmed as registered.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final validCount = _records.where((r) => r['error'] == null).length;
    final invalidCount = _records.length - validCount;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F6FA),
      appBar: AppBar(title: const Text('GIS Data Ingestion'), backgroundColor: navy),
      body: _checkingAccess
          ? const Center(child: CircularProgressIndicator())
          : !_authorised
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.lock_outline, size: 52, color: Colors.blueGrey),
                    const SizedBox(height: 14),
                    const Text('Department authorisation required',
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: navy)),
                    const SizedBox(height: 8),
                    Text(_status, textAlign: TextAlign.center),
                  ]),
                ))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(18)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('AUTHORISED DATA SOURCE',
                            style: TextStyle(color: Color(0xFF8EDFD6), fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 7),
                        Text(_departmentName,
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        const Text('Owner-supplied and field-surveyed geometry only. Imported records remain UNVERIFIED.',
                            style: TextStyle(color: Color(0xFFD3E0EA), height: 1.4, fontSize: 12)),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    Card(child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('SUPPORTED FILE',
                            style: TextStyle(fontWeight: FontWeight.w800, color: navy, letterSpacing: 0.7)),
                        const SizedBox(height: 8),
                        const Text('GeoJSON FeatureCollection (.geojson / .json), WGS84 EPSG:4326. Point, MultiPoint, LineString and MultiLineString. Maximum 10 MB / 500 features.',
                            style: TextStyle(color: mutedInk, height: 1.45, fontSize: 12)),
                        const SizedBox(height: 8),
                        const Text('Required properties: asset_code, asset_name, asset_type, source_type.',
                            style: TextStyle(color: navy, fontSize: 12, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        const Text('Optional: source_reference, depth_m, horizontal_accuracy_m, vertical_accuracy_m, material, diameter_mm, surveyed_at, surveyed_by_org, verification_notes.',
                            style: TextStyle(color: mutedInk, fontSize: 11, height: 1.4)),
                        const SizedBox(height: 14),
                        SizedBox(width: double.infinity, child: FilledButton.icon(
                          onPressed: _loadingFile || _importing ? null : _pickFile,
                          icon: _loadingFile
                              ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.folder_open_outlined),
                          label: Text(_loadingFile ? 'READING FILE…' : 'SELECT GEOJSON SURVEY FILE'),
                          style: FilledButton.styleFrom(backgroundColor: navy, padding: const EdgeInsets.symmetric(vertical: 14)),
                        )),
                      ]),
                    )),
                    if (_fileName.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Card(child: Padding(
                        padding: const EdgeInsets.all(15),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('PRE-IMPORT VALIDATION',
                              style: TextStyle(fontWeight: FontWeight.w800, color: navy)),
                          const SizedBox(height: 6),
                          Text(_fileName, style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(child: _countTile('VALID', validCount, const Color(0xFF087F83))),
                            const SizedBox(width: 7),
                            Expanded(child: _countTile('INVALID', invalidCount, Colors.red)),
                            const SizedBox(width: 7),
                            Expanded(child: _countTile('TOTAL', _records.length, navy)),
                          ]),
                          const SizedBox(height: 8),
                          ..._records.asMap().entries.take(20).map((entry) {
                            final item = entry.value;
                            final f = item['feature'] as Map<String, dynamic>;
                            final p = f['properties'] is Map
                                ? Map<String, dynamic>.from(f['properties'] as Map) : <String, dynamic>{};
                            final error = item['error']?.toString();
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(error == null ? Icons.check_circle_outline : Icons.error_outline,
                                  color: error == null ? const Color(0xFF087F83) : Colors.red),
                              title: Text((p['asset_code'] ?? 'Feature ${entry.key + 1}').toString(), 
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                              subtitle: Text(error ?? '${p['asset_name'] ?? ''} · ${p['asset_type'] ?? ''} · ${(f['geometry'] as Map?)?['type'] ?? ''}',
                                  style: const TextStyle(fontSize: 10)),
                            );
                          }),
                          if (_records.length > 20)
                            Text('Showing first 20 of ${_records.length} features.',
                                style: const TextStyle(color: mutedInk, fontSize: 11)),
                          if (_importing) ...[
                            const SizedBox(height: 8),
                            LinearProgressIndicator(value: _records.isEmpty ? null : _progress / validCount),
                            Text('Processed $_progress of $validCount'),
                          ],
                          const SizedBox(height: 12),
                          SizedBox(width: double.infinity, child: FilledButton.icon(
                            onPressed: !_importing && validCount > 0 ? _register : null,
                            icon: const Icon(Icons.cloud_upload_outlined),
                            label: Text('REGISTER $validCount VALID RECORD(S) AS UNVERIFIED'),
                            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF087F83), padding: const EdgeInsets.symmetric(vertical: 14)),
                          )),
                        ]),
                      )),
                    ],
                    if (_errors.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Card(child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('VALIDATION / IMPORT ERRORS',
                              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          ..._errors.take(30).map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text('• $e', style: const TextStyle(fontSize: 11, color: Colors.red)), 
                          )),
                        ]),
                      )),
                    ],
                    const SizedBox(height: 12),
                    Card(color: const Color(0xFFFFF7E6), child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.verified_user_outlined, color: Color(0xFF9A6700)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_status,
                            style: const TextStyle(color: Color(0xFF664B16), fontSize: 12, height: 1.45))),
                      ]),
                    )),
                    const SizedBox(height: 10),
                    const Text('Only import records your department is authorised to submit. This tool does not independently verify geometry and does not issue excavation clearance or safety certification.',
                        style: TextStyle(color: mutedInk, fontSize: 10, height: 1.4)),
                  ],
                ),
    );
  }

  Widget _countTile(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Text(value.toString(), style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

// ==========================================
// PROFILE
// ==========================================

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<void> logout(BuildContext context) async {
    try {
      await supabase.auth.signOut();
    } on AuthException catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final name = user?.userMetadata?['display_name'] ?? 'User';

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          const CircleAvatar(
            radius: 42,
            backgroundColor: teal,
            child: Icon(
              Icons.person,
              size: 45,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            name.toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.bold,
              color: navy,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            user?.email ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.blueGrey),
          ),
          const SizedBox(height: 30),
          const ListTile(
            leading: Icon(Icons.verified_user, color: teal),
            title: Text('Authentication'),
            subtitle: Text('Supabase'),
          ),
          const SizedBox(height: 25),
          FilledButton.icon(
            onPressed: () => logout(context),
            icon: const Icon(Icons.logout),
            label: const Text('LOG OUT'),
            style: FilledButton.styleFrom(
              backgroundColor: navy,
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// CASE WORKSPACE
// ==========================================
class CaseWorkspacePage extends StatefulWidget {
  final String requestId;
  final String requestTitle;
  const CaseWorkspacePage({super.key, required this.requestId, required this.requestTitle});
  @override
  State<CaseWorkspacePage> createState() => _CaseWorkspacePageState();
}

class _CaseWorkspacePageState extends State<CaseWorkspacePage> {
  final _message = TextEditingController();
  late final Stream<List<Map<String, dynamic>>> _messages;
  bool _sending = false, _uploading = false, _aiBusy = false, _staff = false;
  String _role = '';
  static const _bucket = 'samanvay-case-evidence';

  @override
  void initState() {
    super.initState();
    _messages = supabase.from('case_messages').stream(primaryKey: ['id'])
      .eq('request_id', widget.requestId).order('created_at', ascending: true);
    _loadRole();
  }

  Future<void> _loadRole() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final row = await supabase.from('profiles').select('role')
        .eq('id', user.id).maybeSingle();
      final role = (row?['role'] ?? '').toString();
      if (mounted) {
        setState(() {
          _role = role;
          _staff = ['admin','coordinator','department'].contains(role);
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  void _toast(String value) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(value), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _send() async {
    final user = supabase.auth.currentUser;
    final body = _message.text.trim();
    if (user == null || body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await supabase.from('case_messages').insert({
        'request_id': widget.requestId, 'sender_id': user.id, 'body': body,
      });
      _message.clear();
    } on PostgrestException catch (e) {
      _toast('Message not sent: ${e.message}');
    } catch (_) {
      _toast('Unable to send message. Check your case access and connection.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _upload() async {
    final user = supabase.auth.currentUser;
    if (user == null || _uploading) return;
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['jpg','jpeg','png','webp','pdf'],
      );
      if (file == null) return;
      final fileSize = file.lengthSync() ?? await file.length();
      if (fileSize == null || fileSize <= 0) {
        _toast('Unable to read that file. Select it again.');
        return;
      }
      if (fileSize > 20 * 1024 * 1024) {
        _toast('Evidence files must be 20 MB or smaller.');
        return;
      }
      final bytes = await file.readAsBytes();
      final ext = (file.extension ?? '').toLowerCase();
      final mime = switch (ext) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        'pdf' => 'application/pdf',
        _ => '',
      };
      if (mime.isEmpty) {
        _toast('Only JPG, PNG, WEBP and PDF are supported.');
        return;
      }
      final safeName = file.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_').replaceAll('..', '_');
      final path = '${widget.requestId}/${user.id}/${DateTime.now().microsecondsSinceEpoch}_$safeName';
      setState(() => _uploading = true);
      await supabase.storage.from(_bucket).uploadBinary(
        path, bytes, fileOptions: FileOptions(contentType: mime, upsert: false));
      try {
        await supabase.from('case_attachments').insert({
          'request_id': widget.requestId, 'storage_path': path,
          'file_name': file.name, 'content_type': mime,
          'file_size_bytes': fileSize, 
          'attachment_type': mime == 'application/pdf' ? 'survey_evidence' : 'site_photo',
          'uploaded_by': user.id,
        });
      } catch (_) {
        try { await supabase.storage.from(_bucket).remove([path]); } catch (_) {}
        rethrow;
      }
      _toast('Evidence uploaded to the private case record.');
    } on PostgrestException catch (e) {
      _toast('Evidence was not recorded: ${e.message}');
    } catch (_) {
      _toast('Upload failed. Check case access and supported file type.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _viewEvidence() async {
    try {
      final rows = await supabase.from('case_attachments')
        .select('storage_path,file_name,content_type,file_size_bytes')
        .eq('request_id', widget.requestId).order('created_at', ascending: false);
      if (!mounted) return;
      final files = List<Map<String,dynamic>>.from(rows);
      await showModalBottomSheet<void>(
        context: context, isScrollControlled: true, backgroundColor: Colors.white,
        builder: (sheet) => SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheet).size.height * .55,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('PRIVATE CASE EVIDENCE', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: files.isEmpty
                    ? const Center(child: Text('No evidence has been uploaded.'))
                    : ListView.builder(
                        itemCount: files.length,
                        itemBuilder: (context, index) {
                          final item = files[index];
                          final kb = ((item['file_size_bytes'] as num?) ?? 0) / 1024;
                          return ListTile(
                            leading: Icon(item['content_type'] == 'application/pdf'
                              ? Icons.picture_as_pdf_outlined : Icons.image_outlined, color: teal),
                            title: Text(item['file_name'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text('$kb KB · Private file'),
                            trailing: IconButton(
                              icon: const Icon(Icons.open_in_new),
                              onPressed: () async {
                                try {
                                  final url = await supabase.storage.from(_bucket)
                                    .createSignedUrl(item['storage_path'].toString(), 600);
                                  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                } catch (_) { _toast('Unable to open secure evidence link.'); }
                              },
                            ),
                          );
                        },
                      ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (_) {
      _toast('Unable to list case evidence. Check your case permissions.');
    }
  }

  Future<void> _addInspection() async {
    final user = supabase.auth.currentUser;
    if (user == null || !_staff) return;
    var type = 'progress';
    var outcome = 'pass';
    final notes = TextEditingController();
    final submit = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Record site inspection'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                initialValue: type, isExpanded: true,
                decoration: const InputDecoration(labelText: 'Inspection type'),
                items: const [
                  DropdownMenuItem(value: 'pre_work', child: Text('Pre-work')),
                  DropdownMenuItem(value: 'progress', child: Text('Work progress')),
                  DropdownMenuItem(value: 'post_work', child: Text('Post-work')),
                  DropdownMenuItem(value: 'utility_verification', child: Text('Utility verification')),
                  DropdownMenuItem(value: 'safety_check', child: Text('Safety check')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (v) { if (v != null) { setDialog(() => type = v); } },
              ),
              DropdownButtonFormField<String>(
                initialValue: outcome, isExpanded: true,
                decoration: const InputDecoration(labelText: 'Outcome'),
                items: const [
                  DropdownMenuItem(value: 'pass', child: Text('Pass')),
                  DropdownMenuItem(value: 'issue_found', child: Text('Issue found')),
                  DropdownMenuItem(value: 'follow_up_required', child: Text('Follow-up required')),
                  DropdownMenuItem(value: 'not_applicable', child: Text('Not applicable')),
                ],
                onChanged: (v) { if (v != null) { setDialog(() => outcome = v); } },
              ),
              const SizedBox(height: 10),
              TextField(controller: notes, minLines: 3, maxLines: 5, maxLength: 6000,
                decoration: const InputDecoration(labelText: 'Inspection findings', border: OutlineInputBorder())),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialog, notes.text.trim().isNotEmpty),
              child: const Text('Save inspection')),
          ],
        ),
      ),
    );
    if (submit != true) {
      notes.dispose();
      return;
    }
    try {
      await supabase.from('case_inspections').insert({
        'request_id': widget.requestId, 'inspection_type': type,
        'outcome': outcome, 'notes': notes.text.trim(), 'inspected_by': user.id,
      });
      _toast('Inspection saved.');
    } on PostgrestException catch (e) {
      _toast('Inspection not saved: ${e.message}');
    } catch (_) {
      _toast('Unable to save inspection. Confirm the case is assigned to your department.');
    } finally {
      notes.dispose();
    }
  }

  Future<void> _runAi(String purpose) async {
    if (!_staff || _aiBusy) return;
    setState(() => _aiBusy = true);
    try {
      final result = await supabase.functions.invoke('samanvay-case-assistant',
        body: {'request_id': widget.requestId, 'purpose': purpose});
      final data = result.data;
      if (data is! Map || data['assessment'] is! Map) {
        _toast(data is Map && data['error'] == 'AI_NOT_CONFIGURED'
          ? 'AI is deployed but needs the OPENAI_API_KEY secret.'
          : 'No valid assessment returned by the AI service.');
        return;
      }
      final assessment = Map<String,dynamic>.from(data['assessment'] as Map);
      final assessmentId = data['assessment_id']?.toString();
      final category = (assessment['category'] ?? 'Not provided').toString();
      final priority = (assessment['priority_band'] ?? 'Not provided').toString();
      final confidence = (assessment['confidence'] ?? 'Not provided').toString();
      final assessmentTitle = switch (purpose) {
        'summary' => 'AI case summary',
        'coordination' => 'AI coordination analysis',
        _ => 'AI case triage',
      };
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(assessmentTitle),
          content: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text((assessment['summary'] ?? 'No summary returned.').toString(),
                style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Text('Category: $category'),
              Text('Priority suggestion: $priority'),
              Text('Confidence: $confidence'),
              _arrayText('Suggested departments', assessment['suggested_departments']),
              _arrayText('Coordination flags', assessment['coordination_flags']),
              _arrayText('Missing information', assessment['missing_information']),
              _arrayText('Recommended checks', assessment['recommended_checks']),
              const SizedBox(height: 10),
              const Text('Advisory only. Authorised officers must verify information and make official decisions.',
                style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Close')),
            if (assessmentId != null && ['admin', 'coordinator'].contains(_role))
              TextButton(
                onPressed: () {
                  Navigator.pop(dialog);
                  _reviewAiAssessment(assessmentId, 'dismissed');
                },
                child: const Text('Dismiss suggestion'),
              ),
            if (assessmentId != null && ['admin', 'coordinator'].contains(_role))
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialog);
                  _reviewAiAssessment(assessmentId, 'accepted');
                },
                child: const Text('Accept suggestion'),
              ),
          ],
        ),
      );
    } on FunctionException catch (e) {
      _toast('AI service unavailable: ${e.reasonPhrase ?? e.status.toString()}');
    } catch (_) {
      _toast('AI assessment failed. Check Edge Function and provider configuration.');
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  Future<void> _runCoordinationCheck() async {
    try {
      final raw = await supabase.rpc(
        'run_request_coordination_check',
        params: {'p_request_id': widget.requestId},
      );
      final result = Map<String, dynamic>.from(raw as Map);
      final possibleOverlap = result['possible_overlap'] == true;
      final status = (result['assessment_status'] ?? '').toString();
      final advisory = (result['advisory'] ?? 'No assessment details returned.').toString();

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: Icon(
            possibleOverlap ? Icons.warning_amber_rounded : Icons.info_outline,
            color: possibleOverlap ? Colors.deepOrange : const Color(0xFF087F83),
            size: 34,
          ),
          title: Text(
            possibleOverlap
                ? 'Possible recorded utility proximity'
                : status == 'completed'
                    ? 'No recorded overlap detected'
                    : 'Coordination check incomplete',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(advisory),
                const SizedBox(height: 12),
                const Text(
                  'This check uses only the records currently available to SAMANVAY. It is not a utility-location certificate, permit, site clearance or guarantee of safety. Obtain clearance from utility owners and complete required field verification before work.',
                  style: TextStyle(fontSize: 11, color: Colors.blueGrey),
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Understood'),
            ),
          ],
        ),
      );
    } on PostgrestException catch (e) {
      _toast('Coordination check unavailable: ${e.message}');
    } catch (_) {
      _toast('Unable to run the coordination check. Confirm the case location, work radius and access permissions.');
    }
  }

  Future<void> _viewCoordinationChecks() async {
    try {
      final raw = await supabase.from('case_coordination_checks')
          .select('assessment_status,possible_overlap,advisory,checked_at')
          .eq('request_id', widget.requestId)
          .order('checked_at', ascending: false);
      if (!mounted) return;
      final checks = List<Map<String, dynamic>>.from(raw);
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        builder: (sheet) => SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheet).size.height * 0.62,
            child: checks.isEmpty
                ? const Center(child: Text('No coordination checks have been run for this case.'))
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text('COORDINATION CHECK HISTORY',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      ...checks.map((item) {
                        final overlap = item['possible_overlap'] == true;
                        final date = DateTime.tryParse(item['checked_at']?.toString() ?? '');
                        final dateLabel = date == null
                            ? ''
                            : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
                        return Card(
                          child: ListTile(
                            leading: Icon(
                              overlap ? Icons.warning_amber_rounded : Icons.fact_check_outlined,
                              color: overlap ? Colors.deepOrange : const Color(0xFF087F83),
                            ),
                            title: Text(overlap
                                ? 'Possible recorded overlap'
                                : (item['assessment_status'] == 'completed'
                                    ? 'No recorded overlap detected'
                                    : 'Check incomplete')),
                            subtitle: Text('${item['advisory'] ?? ''}\n$dateLabel'),
                            isThreeLine: true,
                          ),
                        );
                      }),
                    ],
                  ),
          ),
        ),
      );
    } catch (_) {
      _toast('Unable to load coordination-check history.');
    }
  }

  Future<void> _reviewAiAssessment(String assessmentId, String decision) async {
    final user = supabase.auth.currentUser;
    if (user == null || !['admin', 'coordinator'].contains(_role)) return;
    try {
      await supabase.from('case_ai_assessments').update({
        'review_status': decision,
        'reviewed_by': user.id,
        'reviewed_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', assessmentId).eq('review_status', 'suggested');
      _toast(decision == 'accepted'
        ? 'AI suggestion marked as reviewed and accepted.'
        : 'AI suggestion dismissed.');
    } on PostgrestException catch (e) {
      _toast('Unable to save the review decision: ${e.message}');
    } catch (_) {
      _toast('Unable to save the AI review decision.');
    }
  }

  Future<void> _viewInspections() async {
    try {
      final rows = await supabase.from('case_inspections')
        .select('inspection_type,outcome,notes,inspected_at')
        .eq('request_id', widget.requestId)
        .order('inspected_at', ascending: false);
      if (!mounted) return;
      final items = List<Map<String,dynamic>>.from(rows);
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        builder: (sheet) => SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheet).size.height * .62,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('INSPECTION RECORDS', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: items.isEmpty
                    ? const Center(child: Text('No inspection records are available.'))
                    : ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final date = DateTime.tryParse(item['inspected_at']?.toString() ?? '');
                          final day = date?.day.toString().padLeft(2, '0') ?? '';
                          final month = date?.month.toString().padLeft(2, '0') ?? '';
                          final year = date?.year.toString() ?? '';
                          final dateLabel = date == null ? '' : '$day/$month/$year';
                          final outcome = (item['outcome'] ?? '').toString().replaceAll('_', ' ');
                          final notes = (item['notes'] ?? '').toString();
                          return ListTile(
                            leading: const Icon(Icons.fact_check_outlined, color: teal),
                            title: Text((item['inspection_type'] ?? 'Inspection').toString().replaceAll('_', ' ').toUpperCase()),
                            subtitle: Text(
                              '$outcome${dateLabel.isEmpty ? '' : ' · $dateLabel'}\n$notes',
                            ),
                            isThreeLine: true,
                          );
                        },
                      ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (_) {
      _toast('Unable to load inspections for this case.');
    }
  }

  Future<void> _viewTimeline() async {
    try {
      final rows = await supabase.from('request_status_history')
        .select('old_status,new_status,remarks,created_at')
        .eq('request_id', widget.requestId)
        .order('created_at', ascending: false);
      if (!mounted) return;
      final items = List<Map<String,dynamic>>.from(rows);
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        builder: (sheet) => SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheet).size.height * .55,
            child: items.isEmpty
              ? const Center(child: Text('No status history has been recorded yet.'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text('CASE ACTIVITY', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ...items.map((item) {
                      final oldStatus = (item['old_status'] ?? 'Created').toString().replaceAll('_', ' ');
                      final newStatus = (item['new_status'] ?? '').toString().replaceAll('_', ' ');
                      return ListTile(
                        leading: const Icon(Icons.timeline, color: teal),
                        title: Text('$oldStatus → $newStatus'),
                        subtitle: Text((item['remarks'] ?? 'No remarks').toString()),
                      );
                    }),
                  ],
                ),
          ),
        ),
      );
    } catch (_) {
      _toast('Unable to load case activity history.');
    }
  }

  Widget _arrayText(String label, dynamic raw) {
    final items = raw is List ? raw.map((x) => x.toString()).toList() : <String>[];
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        ...items.map((x) => Padding(padding: const EdgeInsets.only(left: 8, top: 3), child: Text('• $x'))),
      ]),
    );
  }

  Widget _bubble(Map<String,dynamic> item, String? uid) {
    final mine = item['sender_id']?.toString() == uid;
    final when = DateTime.tryParse(item['created_at']?.toString() ?? '');
    final hour = when?.hour.toString().padLeft(2,'0') ?? '';
    final minute = when?.minute.toString().padLeft(2,'0') ?? '';
    final time = when == null ? '' : '$hour:$minute';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 310),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: mine ? const Color(0xFFDDF7F2) : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: mine ? const Color(0xFFBCEBE3) : const Color(0xFFE3EAF1)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(mine ? 'You' : 'Case participant',
            style: const TextStyle(fontSize: 9, color: mutedInk, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(item['body']?.toString() ?? '', style: const TextStyle(color: ink)),
          if (time.isNotEmpty) Align(alignment: Alignment.bottomRight,
            child: Text(time, style: const TextStyle(fontSize: 9, color: mutedInk))),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = supabase.auth.currentUser?.id;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F6FA),
      appBar: AppBar(
        title: Text(widget.requestTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(tooltip: 'View evidence', onPressed: _viewEvidence, icon: const Icon(Icons.attach_file)),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'upload') _upload();
              if (v == 'view') _viewEvidence();
              if (v == 'run_check') _runCoordinationCheck();
              if (v == 'check_history') _viewCoordinationChecks();
              if (v == 'inspection') _addInspection();
              if (v == 'inspections') _viewInspections();
              if (v == 'timeline') _viewTimeline();
              if (v == 'ai_triage') _runAi('triage');
              if (v == 'ai_summary') _runAi('summary');
              if (v == 'ai_coordination') _runAi('coordination');
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'upload', child: Text('Upload evidence')),
              const PopupMenuItem(value: 'view', child: Text('View evidence')),
              const PopupMenuItem(value: 'run_check', child: Text('Run utility coordination check')),
              const PopupMenuItem(value: 'check_history', child: Text('View coordination-check history')),
              const PopupMenuItem(value: 'inspections', child: Text('View inspections')),
              const PopupMenuItem(value: 'timeline', child: Text('Case activity history')),
              if (_staff) ...[
                const PopupMenuItem(value: 'inspection', child: Text('Record inspection')),
                const PopupMenuItem(value: 'ai_triage', child: Text('AI: classify and prioritise case')),
                const PopupMenuItem(value: 'ai_summary', child: Text('AI: summarise case')),
                const PopupMenuItem(value: 'ai_coordination', child: Text('AI: coordination risks and missing information')),
              ],
            ],
          ),
        ],
      ),
      body: Column(children: [
        Container(
          width: double.infinity, padding: const EdgeInsets.all(10),
          color: const Color(0xFFE7F1F7),
          child: Row(children: [
            const Icon(Icons.shield_outlined, color: Color(0xFF087F83), size: 18),
            const SizedBox(width: 8),
            const Expanded(child: Text(
              'Case messages and evidence are restricted to authenticated participants.',
              style: TextStyle(fontSize: 10, color: Color(0xFF42627E)))),
            if (_uploading || _aiBusy) const SizedBox(width: 15, height: 15,
              child: CircularProgressIndicator(strokeWidth: 2)),
          ]),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String,dynamic>>>(
            stream: _messages,
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Center(child: Text('Discussion is unavailable for this account.'));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final rows = snapshot.data!;
              if (rows.isEmpty) return const Center(child: Text('No messages yet. Start the case discussion.'));
              return ListView.builder(
                padding: const EdgeInsets.all(14), itemCount: rows.length,
                itemBuilder: (context, index) => _bubble(rows[index], uid));
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
            color: Colors.white,
            child: Row(children: [
              IconButton(tooltip: 'Upload evidence', onPressed: _uploading ? null : _upload,
                icon: const Icon(Icons.attach_file, color: Color(0xFF087F83))),
              Expanded(child: TextField(
                controller: _message, minLines: 1, maxLines: 4, maxLength: 4000,
                decoration: const InputDecoration(
                  hintText: 'Write a case message…', counterText: '', isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(18))),
                  contentPadding: EdgeInsets.symmetric(horizontal: 13, vertical: 10)),
              )),
              const SizedBox(width: 6),
              IconButton.filled(
                onPressed: _sending ? null : _send,
                icon: _sending
                  ? const SizedBox(width: 17, height: 17,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded)),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ==========================================
// REALTIME USER NOTIFICATIONS
// ==========================================
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late final Stream<List<Map<String,dynamic>>> _stream;

  @override
  void initState() {
    super.initState();
    final user = supabase.auth.currentUser;
    _stream = user == null
      ? Stream.value(<Map<String,dynamic>>[])
      : supabase.from('user_notifications').stream(primaryKey: ['id'])
        .eq('recipient_id', user.id).order('created_at', ascending: false);
  }

  Future<void> _openNotification(Map<String,dynamic> item) async {
    await _markRead(item);
    final requestId = item['request_id']?.toString();
    if (requestId == null || requestId.isEmpty || !mounted) return;
    var title = 'Infrastructure case';
    try {
      final row = await supabase.from('excavation_requests')
        .select('title').eq('id', requestId).maybeSingle();
      title = (row?['title'] ?? title).toString();
    } catch (_) {}
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CaseWorkspacePage(
          requestId: requestId,
          requestTitle: title,
        ),
      ),
    );
  }

  Future<void> _markRead(Map<String,dynamic> item) async {
    final user = supabase.auth.currentUser;
    if (user == null || item['read_at'] != null) return;
    try {
      await supabase.from('user_notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', item['id'].toString()).eq('recipient_id', user.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to mark notification as read.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: StreamBuilder<List<Map<String,dynamic>>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Notifications could not be loaded.'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final rows = snapshot.data!;
          final unread = rows.where((x) => x['read_at'] == null).length;
          if (rows.isEmpty) return const Center(child: Text('You are all caught up.'));
          final total = rows.length;
          return ListView(padding: const EdgeInsets.all(14), children: [
            Text('$unread unread · $total total',
              style: const TextStyle(color: mutedInk, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            ...rows.map((item) {
              final fresh = item['read_at'] == null;
              final date = DateTime.tryParse(item['created_at']?.toString() ?? '');
              final day = date?.day.toString().padLeft(2,'0') ?? '';
              final month = date?.month.toString().padLeft(2,'0') ?? '';
              final year = date?.year.toString() ?? '';
              final dateText = date == null ? '' : '$day/$month/$year';
              final notificationBody = (item['body'] ?? '').toString();
              final type = (item['notification_type'] ?? '').toString();
              final icon = switch (type) {
                'assignment' => Icons.account_tree_outlined,
                'review' => Icons.rate_review_outlined,
                'status' => Icons.sync_alt,
                'message' => Icons.forum_outlined,
                _ => Icons.notifications_outlined,
              };
              return Card(
                color: fresh ? const Color(0xFFEAF8F6) : Colors.white,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: fresh ? const Color(0xFFD1F0EA) : const Color(0xFFEAF0F5),
                    child: Icon(icon, color: const Color(0xFF087F83))),
                  title: Text(item['title']?.toString() ?? 'SAMANVAY update',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('$notificationBody\n$dateText'),
                  isThreeLine: true,
                  trailing: fresh
                    ? const Icon(Icons.circle, color: Color(0xFF13A89E), size: 10)
                    : const Icon(Icons.check, color: mutedInk, size: 18),
                  onTap: () => _openNotification(item),
                ),
              );
            }),
          ]);
        },
      ),
    );
  }
}

// ==========================================
// ADMINISTRATION CONSOLE
// ==========================================
class AdminManagementPage extends StatefulWidget {
  const AdminManagementPage({super.key});
  @override
  State<AdminManagementPage> createState() => _AdminManagementPageState();
}

class _AdminManagementPageState extends State<AdminManagementPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _audit = [];
  List<Map<String, dynamic>> _routes = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _toast(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final userRows = await supabase.rpc('admin_user_directory');
      final departmentRows = await supabase.from('departments')
          .select('id,name,description').order('name');
      final auditRows = await supabase.from('admin_audit_events')
          .select('event_type,details,created_at')
          .order('created_at', ascending: false).limit(40);
      final routeRows = await supabase.from('department_service_domains')
          .select('department_id,case_category,route_priority')
          .order('case_category');
      if (!mounted) return;
      setState(() {
        _users = List<Map<String, dynamic>>.from(userRows as List);
        _departments = List<Map<String, dynamic>>.from(departmentRows);
        _audit = List<Map<String, dynamic>>.from(auditRows);
        _routes = List<Map<String, dynamic>>.from(routeRows);
        _loading = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;
      setState(() { _loading = false; _error = error.message; });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load administration records. Verify administrator permissions.';
      });
    }
  }

  Future<void> _editUser(Map<String, dynamic> user) async {
    final currentUserId = supabase.auth.currentUser?.id;
    final userId = user['user_id'].toString();
    if (userId == currentUserId) {
      _toast('Your own administrator role cannot be changed here.');
      return;
    }

    String selectedRole = (user['role'] ?? 'requester').toString();
    String? selectedDepartment = user['department_id']?.toString();
    if (selectedRole == 'department' && selectedDepartment == null && _departments.isNotEmpty) {
      selectedDepartment = _departments.first['id'].toString();
    }

    final result = await showDialog<Map<String, String?>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Update account access'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text((user['display_name'] ?? 'SAMANVAY user').toString(),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  'Account reference: ${userId.substring(0, userId.length > 8 ? 8 : userId.length)}',
                  style: const TextStyle(fontSize: 10, color: mutedInk),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Platform role', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'requester', child: Text('Requester')),
                    DropdownMenuItem(value: 'department', child: Text('Department officer')),
                    DropdownMenuItem(value: 'coordinator', child: Text('Coordinator')),
                    DropdownMenuItem(value: 'admin', child: Text('Administrator')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() {
                      selectedRole = value;
                      if (value != 'department') selectedDepartment = null;
                      if (value == 'department' && _departments.isNotEmpty) {
                        selectedDepartment ??= _departments.first['id'].toString();
                      }
                    });
                  },
                ),
                if (selectedRole == 'department') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedDepartment,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Assigned department', border: OutlineInputBorder()),
                    items: _departments.map((item) => DropdownMenuItem<String>(
                      value: item['id'].toString(),
                      child: Text(item['name'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (value) => setDialogState(() => selectedDepartment = value),
                  ),
                ],
                const SizedBox(height: 12),
                const Text(
                  'Changes are checked and recorded by the database. Users cannot assign roles to themselves.',
                  style: TextStyle(fontSize: 11, color: mutedInk),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(
              onPressed: selectedRole == 'department' && selectedDepartment == null
                ? null
                : () => Navigator.pop(dialogContext, {
                    'role': selectedRole,
                    'department_id': selectedDepartment,
                  }),
              child: const Text('Save access'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;
    try {
      await supabase.rpc('admin_update_profile_role', params: {
        'p_user_id': userId,
        'p_role': result['role'],
        'p_department_id': result['department_id'],
      });
      _toast('Account access updated and audit entry recorded.');
      await _load();
    } on PostgrestException catch (error) {
      _toast('Access update rejected: ${error.message}');
    } catch (_) {
      _toast('Unable to update account access.');
    }
  }

  Future<void> _addDepartment() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add department / routing group'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Department name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(labelText: 'Description / responsibility', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              const Text(
                'Use the official department name for the relevant city/state jurisdiction. Creating a routing group does not establish statutory authority.',
                style: TextStyle(fontSize: 11, color: mutedInk),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, nameController.text.trim().isNotEmpty),
            child: const Text('Create department'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await supabase.rpc('admin_create_department', params: {
          'p_name': nameController.text.trim(),
          'p_description': descriptionController.text.trim(),
        });
        _toast('Department added.');
        await _load();
      } on PostgrestException catch (error) {
        _toast('Department not created: ${error.message}');
      } catch (_) {
        _toast('Unable to create department.');
      }
    }
    nameController.dispose();
    descriptionController.dispose();
  }


  Future<void> _manageServiceRoute() async {
    if (_departments.isEmpty) {
      _toast('Create a department before configuring a service route.');
      return;
    }
    const categories = <String, String>{
      'road_reconstruction': 'Road reconstruction',
      'water_supply': 'Water supply',
      'sewerage': 'Sewerage',
      'stormwater_drainage': 'Stormwater and drainage',
      'electricity': 'Electricity',
      'telecom': 'Telecommunications',
      'gas': 'Gas network',
      'borewell_groundwater': 'Borewell and groundwater',
      'building_planning': 'Building planning / regulation',
      'public_health_engineering': 'Public health engineering',
      'other': 'Other infrastructure issue',
    };
    String category = categories.keys.first;
    String departmentId = _departments.first['id'].toString();
    String priority = 'primary';
    bool enabled = true;
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Configure service routing'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: category,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Infrastructure domain'),
                  items: categories.entries.map((entry) => DropdownMenuItem<String>(
                    value: entry.key, child: Text(entry.value),
                  )).toList(),
                  onChanged: (value) {
                    if (value != null) setDialogState(() => category = value);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: departmentId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Department / routing group'),
                  items: _departments.map((item) => DropdownMenuItem<String>(
                    value: item['id'].toString(),
                    child: Text(item['name'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
                  )).toList(),
                  onChanged: (value) {
                    if (value != null) setDialogState(() => departmentId = value);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: priority,
                  decoration: const InputDecoration(labelText: 'Suggestion level'),
                  items: const [
                    DropdownMenuItem(value: 'primary', child: Text('Primary suggestion')),
                    DropdownMenuItem(value: 'supporting', child: Text('Supporting department')),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => priority = value);
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: enabled,
                  title: const Text('Enable this routing suggestion'),
                  onChanged: (value) => setDialogState(() => enabled = value),
                ),
                const Text(
                  'This configures a suggestion only. It does not automatically assign a case or establish statutory authority.',
                  style: TextStyle(fontSize: 11, color: mutedInk),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save routing')),
          ],
        ),
      ),
    );
    if (save != true) return;
    try {
      await supabase.rpc('admin_set_service_domain_route', params: {
        'p_department_id': departmentId,
        'p_case_category': category,
        'p_route_priority': priority,
        'p_enabled': enabled,
      });
      _toast('Service routing updated and audit event recorded.');
      await _load();
    } on PostgrestException catch (error) {
      _toast('Routing update rejected: ${error.message}');
    } catch (_) {
      _toast('Unable to update service routing.');
    }
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: navy)),
          const SizedBox(height: 3),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: mutedInk)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = supabase.auth.currentUser?.id;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administration'),
        actions: [IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh))],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0B1728), Color(0xFF14515E)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.admin_panel_settings_outlined, color: Colors.white, size: 30),
                  SizedBox(height: 10),
                  Text('PLATFORM GOVERNANCE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                  SizedBox(height: 5),
                  Text(
                    'Manage platform access, routing groups and audit history. Statutory authority remains with the responsible government organisation.',
                    style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_error != null)
              Card(child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              )),
            if (_loading)
              const Center(child: Padding(
                padding: EdgeInsets.all(28), child: CircularProgressIndicator(),
              ))
            else ...[
              _sectionTitle('User and access directory', '${_users.length} account(s)'),
              ..._users.map((user) {
                final isSelf = user['user_id']?.toString() == currentUserId;
                final role = (user['role'] ?? 'requester').toString();
                final name = (user['display_name'] ?? 'SAMANVAY user').toString();
                final dept = user['department_name']?.toString();
                final subtitle = '${role.toUpperCase()}'
                  '${dept == null ? '' : ' · $dept'}'
                  '${isSelf ? ' · CURRENT ACCOUNT' : ''}';
                final icon = role == 'admin' ? Icons.admin_panel_settings_outlined :
                  role == 'coordinator' ? Icons.hub_outlined :
                  role == 'department' ? Icons.account_tree_outlined : Icons.person_outline;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFE7F8F6),
                      child: Icon(icon, color: const Color(0xFF087F83)),
                    ),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(subtitle, style: const TextStyle(fontSize: 10)),
                    trailing: IconButton(
                      tooltip: isSelf ? 'Own role is locked' : 'Edit role and department',
                      onPressed: isSelf ? null : () => _editUser(user),
                      icon: Icon(isSelf ? Icons.lock_outline : Icons.edit_outlined),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: _sectionTitle('Departments and routing groups', '${_departments.length} group(s)')),
                  FilledButton.icon(
                    onPressed: _addDepartment,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
                  ),
                ],
              ),
              ..._departments.map((department) => Card(
                margin: const EdgeInsets.only(bottom: 7),
                child: ListTile(
                  leading: const Icon(Icons.account_tree_outlined, color: Color(0xFF087F83)),
                  title: Text(department['name'].toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    (department['description'] ?? 'No description recorded').toString(),
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                  ),
                ),
              )),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: _sectionTitle('Case-domain routing', '${_routes.length} suggestion(s)')),
                  FilledButton.icon(
                    onPressed: _manageServiceRoute,
                    icon: const Icon(Icons.tune, size: 18),
                    label: const Text('Configure'),
                  ),
                ],
              ),
              ..._routes.map((route) {
                final department = _departments.firstWhere(
                  (item) => item['id'].toString() == route['department_id'].toString(),
                  orElse: () => {'name': 'Unknown department'},
                );
                final categoryName = route['case_category'].toString().replaceAll('_', ' ').toUpperCase();
                final priorityName = route['route_priority'] == 'primary' ? 'PRIMARY' : 'SUPPORTING';
                return Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.route_outlined, color: Color(0xFF087F83)),
                    title: Text(department['name'].toString(),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('$categoryName · $priorityName',
                      style: const TextStyle(fontSize: 10)),
                  ),
                );
              }),
              const SizedBox(height: 18),
              _sectionTitle('Administrative audit trail', '${_audit.length} recent event(s)'),
              if (_audit.isEmpty)
                const Card(child: Padding(
                  padding: EdgeInsets.all(15),
                  child: Text('No administrative changes have been recorded yet.'),
                ))
              else
                ..._audit.map((event) {
                  final details = event['details'] is Map
                    ? Map<String, dynamic>.from(event['details'] as Map)
                    : <String, dynamic>{};
                  final when = DateTime.tryParse(event['created_at']?.toString() ?? '');
                  final dateText = when == null ? '' :
                    '${when.day.toString().padLeft(2, '0')}/${when.month.toString().padLeft(2, '0')}/${when.year}';
                  final type = (event['event_type'] ?? '').toString();
                  final label = type == 'profile_role_changed'
                    ? 'Account role / department updated'
                    : 'Department routing group created';
                  final detail = (details['department_name'] ?? details['new_role'] ?? '').toString();
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.history, color: mutedInk),
                      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('$detail${dateText.isEmpty ? '' : ' · $dateText'}'),
                    ),
                  );
                }),
            ],
          ],
        ),
      ),
    );
  }
}

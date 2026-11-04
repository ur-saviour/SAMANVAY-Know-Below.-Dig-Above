
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

const Color navy = Color(0xFF10243A);
const Color teal = Color(0xFF13A89E);
const Color background = Color(0xFFF4F7FA);

class SamanvayApp extends StatelessWidget {
  const SamanvayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SAMANVAY',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: teal,
          primary: teal,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: navy,
          foregroundColor: Colors.white,
        ),
      ),
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
    );
  }
}

class _OperationalPortal extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String? departmentId;
  final bool isDepartment;

  const _OperationalPortal({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.departmentId,
    this.isDepartment = false,
  });

  @override
  State<_OperationalPortal> createState() =>
      _OperationalPortalState();
}

class _OperationalPortalState extends State<_OperationalPortal> {
  List<Map<String, dynamic>> requests = [];
  List<Map<String, dynamic>> departments = [];
  Map<String, List<Map<String, dynamic>>> reviewsByRequest = {};

  bool loading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    loadRequests();
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

    String? selectedDepartment =
        availableDepartments.first['id'].toString();

    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Assign department'),
              content: DropdownButtonFormField<String>(
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

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final name = user?.userMetadata?['display_name'] ?? 'User';

    return Scaffold(
      appBar: AppBar(
        title: const Text('SAMANVAY'),
      ),
      body: ListView(
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
                const Text(
                  'WELCOME',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Text(
                  name.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Connected infrastructure. Coordinated development.',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Platform Overview',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: navy,
            ),
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'Database',
                  value: 'Connected',
                  icon: Icons.cloud_done,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  title: 'Account',
                  value: 'Active',
                  icon: Icons.verified_user,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Departments',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: navy,
            ),
          ),
          const SizedBox(height: 12),
          const DepartmentTile(
            title: 'Water Supply',
            icon: Icons.water_drop,
          ),
          const DepartmentTile(
            title: 'Electricity',
            icon: Icons.bolt,
          ),
          const DepartmentTile(
            title: 'Sewage and Drainage',
            icon: Icons.water,
          ),
          const DepartmentTile(
            title: 'Telecommunications',
            icon: Icons.cell_tower,
          ),
          const DepartmentTile(
            title: 'Gas Infrastructure',
            icon: Icons.local_fire_department,
          ),
        ],
      ),
    );
  }
}

// ==========================================
// STAT CARD
// ==========================================

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
  List<Map<String, dynamic>> requests = [];
  bool loading = true;
  String? errorMessage;
  String selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    loadRequests();
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
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _roadController = TextEditingController();
  final _cityController = TextEditingController(
    text: 'Coimbatore',
  );

  DateTime? startDate;
  DateTime? endDate;

  bool submitting = false;
  String? formError;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _roadController.dispose();
    _cityController.dispose();
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
          content: Text('Excavation request submitted successfully.'),
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
        title: const Text('New Excavation Request'),
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
              'Provide the details of the proposed excavation work.',
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
              label: 'Work description',
              icon: Icons.description_outlined,
              maxLines: 4,
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
                'Your request number will be generated '
                'automatically after submission.',
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

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Infrastructure Map'),
      ),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.map_outlined,
              size: 75,
              color: teal,
            ),
            SizedBox(height: 16),
            Text(
              'GIS integration',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text('Geographic infrastructure mapping is planned.'),
          ],
        ),
      ),
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

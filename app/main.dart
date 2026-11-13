
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

        if (snapshot.hasData &&
            snapshot.data!.event == AuthChangeEvent.passwordRecovery) {
          return const ResetPasswordPage();
        }

        if (session == null) {
          return const AuthPage();
        }

        return const MainScreen();
      },
    );
  }
}

// ==========================================
// LOGIN, REGISTRATION AND EMAIL CONFIRMATION
// ==========================================

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
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _accessReasonController = TextEditingController();

  late final Future<List<Map<String, dynamic>>> departmentsFuture;
  String requestedRole = 'requester';
  String? requestedDepartmentId;

  bool usePhone = false;
  bool otpSent = false;
  bool isLogin = true;
  bool loading = false;
  bool hidePassword = true;

  String message = '';
  bool messageIsSuccess = false;

  @override
  void initState() {
    super.initState();
    departmentsFuture = supabase
        .from('departments')
        .select('id, name')
        .order('name')
        .then((rows) => List<Map<String, dynamic>>.from(rows));
  }

  Map<String, dynamic> registrationMetadata() => {
        'display_name': _nameController.text.trim(),
        'requested_role': requestedRole,
        'requested_department_id':
            requestedRole == 'department' ? requestedDepartmentId : null,
        'access_reason': _accessReasonController.text.trim(),
      };

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _accessReasonController.dispose();
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
      if (usePhone) {
        final phone = _phoneController.text.trim();
        if (!otpSent) {
          await supabase.auth.signInWithOtp(
            phone: phone,
            shouldCreateUser: !isLogin,
            data: isLogin ? null : registrationMetadata(),
          );
          if (mounted) {
            setState(() => otpSent = true);
          }
          showMessage('OTP request submitted. Enter the SMS code to continue.', success: true);
        } else {
          await supabase.auth.verifyOTP(
            phone: phone,
            token: _otpController.text.trim(),
            type: OtpType.sms,
          );
          showMessage('Mobile number verified. Login successful.', success: true);
          if (mounted) setState(() => otpSent = false);
        }
      } else {
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
          data: registrationMetadata(),
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

  Future<void> sendPasswordReset() async {
    final email = _emailController.text.trim();
    if (!email.contains('@') || !email.contains('.')) {
      showMessage('Enter your registered email address first.');
      return;
    }
    setState(() {
      loading = true;
      message = '';
      messageIsSuccess = false;
    });
    try {
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: redirectUrl,
      );
      showMessage('Password reset instructions have been requested. Check your email.', success: true);
    } on AuthException catch (error) {
      showMessage(error.message);
    } catch (_) {
      showMessage('Unable to request password reset. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => loading = false);
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

                  if (!isLogin) ...[
                    DropdownButtonFormField<String>(
                      value: requestedRole,
                      decoration: const InputDecoration(
                        labelText: 'Account type',
                        helperText: 'Official access is enabled only after administrator approval.',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'requester', child: Text('Citizen')),
                        DropdownMenuItem(value: 'department', child: Text('Department Officer')),
                        DropdownMenuItem(value: 'coordinator', child: Text('Coordinator')),
                        DropdownMenuItem(value: 'admin', child: Text('Administrator')),
                      ],
                      onChanged: (value) => setState(() {
                        requestedRole = value ?? 'requester';
                        if (requestedRole != 'department') requestedDepartmentId = null;
                      }),
                    ),
                    if (requestedRole == 'department') ...[
                      const SizedBox(height: 14),
                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: departmentsFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState != ConnectionState.done) {
                            return const LinearProgressIndicator();
                          }
                          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                            return const Text('Department list unavailable. You can submit a request after contacting an administrator.');
                          }
                          return DropdownButtonFormField<String>(
                            value: requestedDepartmentId,
                            decoration: const InputDecoration(
                              labelText: 'Department',
                              border: OutlineInputBorder(),
                            ),
                            items: snapshot.data!
                                .map((department) => DropdownMenuItem<String>(
                                      value: department['id'].toString(),
                                      child: Text(department['name'].toString()),
                                    ))
                                .toList(),
                            onChanged: (value) => setState(() => requestedDepartmentId = value),
                            validator: (value) => requestedRole == 'department' && value == null
                                ? 'Select your department'
                                : null,
                          );
                        },
                      ),
                    ],
                    if (requestedRole != 'requester') ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _accessReasonController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Official access reason',
                          hintText: 'Enter your department or coordination responsibility',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => requestedRole != 'requester' &&
                                (value == null || value.trim().length < 10)
                            ? 'Provide at least 10 characters'
                            : null,
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: loading ? null : () {
                        setState(() {
                          usePhone = !usePhone;
                          otpSent = false;
                          message = '';
                        });
                      },
                      child: Text(usePhone ? 'Use email instead' : 'Use mobile OTP instead'),
                    ),
                  ),

                  if (usePhone) ...[
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Mobile number with country code',
                        hintText: '+91XXXXXXXXXX',
                        prefixIcon: Icon(Icons.phone_android),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (!usePhone) return null;
                        final digits = (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                        if (digits.length < 10 || digits.length > 15) {
                          return 'Enter a valid mobile number with country code';
                        }
                        return null;
                      },
                    ),
                    if (otpSent) ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 8,
                        decoration: const InputDecoration(
                          labelText: 'SMS verification code',
                          prefixIcon: Icon(Icons.password),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (usePhone && otpSent &&
                              (value == null || value.trim().length < 4)) {
                            return 'Enter the verification code';
                          }
                          return null;
                        },
                      ),
                    ],
                  ] else ...[
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (usePhone) return null;
                        if (value == null || !value.contains('@') || !value.contains('.')) {
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
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => hidePassword = !hidePassword),
                          icon: Icon(hidePassword ? Icons.visibility : Icons.visibility_off),
                        ),
                      ),
                      validator: (value) {
                        if (usePhone) return null;
                        if (value == null || value.length < 8) {
                          return 'Password must contain at least 8 characters';
                        }
                        return null;
                      },
                    ),
                  ],

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
                            usePhone
                                ? (otpSent ? 'VERIFY OTP' : 'SEND OTP')
                                : (isLogin ? 'LOGIN' : 'CREATE ACCOUNT'),
                          ),
                  ),

                  if (isLogin && !usePhone) ...[
                    TextButton(
                      onPressed: loading ? null : sendPasswordReset,
                      child: const Text('Forgot password?'),
                    ),
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
                              otpSent = false;
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

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool loading = false;
  bool hidePassword = true;
  String? errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> updatePassword() async {
    final password = _passwordController.text;
    if (password.length < 8) {
      setState(() => errorMessage = 'Use at least 8 characters.');
      return;
    }
    if (password != _confirmController.text) {
      setState(() => errorMessage = 'The passwords do not match.');
      return;
    }
    setState(() {
      loading = true;
      errorMessage = null;
    });
    try {
      await supabase.auth.updateUser(UserAttributes(password: password));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully.')),
      );
    } on AuthException catch (error) {
      if (mounted) setState(() => errorMessage = error.message);
    } catch (_) {
      if (mounted) setState(() => errorMessage = 'Unable to update password. Please try again.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set a new password')),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          const Text(
            'Choose a new password for your SAMANVAY account.',
            style: TextStyle(color: navy, fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _passwordController,
            obscureText: hidePassword,
            decoration: InputDecoration(
              labelText: 'New password',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                onPressed: () => setState(() => hidePassword = !hidePassword),
                icon: Icon(hidePassword ? Icons.visibility : Icons.visibility_off),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _confirmController,
            obscureText: hidePassword,
            decoration: const InputDecoration(
              labelText: 'Confirm new password',
              border: OutlineInputBorder(),
            ),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(errorMessage!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: loading ? null : updatePassword,
            child: Text(loading ? 'UPDATING...' : 'UPDATE PASSWORD'),
          ),
        ],
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
  late final Future<Map<String, dynamic>> profileFuture;

  @override
  void initState() {
    super.initState();
    final user = supabase.auth.currentUser;
    profileFuture = user == null
        ? Future.error('No authenticated user')
        : supabase
            .from('profiles')
            .select('display_name, role, department_id')
            .eq('id', user.id)
            .single()
            .then((row) => Map<String, dynamic>.from(row));
    if (user != null) {
      profileFuture.then((_) => _queueOfficialAccessRequest(user)).catchError((_) {});
    }
  }

  Future<void> _queueOfficialAccessRequest(User user) async {
    final metadata = user.userMetadata ?? <String, dynamic>{};
    final requested = metadata['requested_role']?.toString();
    if (!['department', 'coordinator', 'admin'].contains(requested)) return;
    final departmentId = metadata['requested_department_id']?.toString();
    if (requested == 'department' && (departmentId == null || departmentId.isEmpty)) return;
    try {
      final existing = await supabase
          .from('account_access_requests')
          .select('id')
          .eq('user_id', user.id)
          .eq('status', 'pending')
          .maybeSingle();
      if (existing != null) return;
      final reason = (metadata['access_reason']?.toString() ?? '').trim();
      await supabase.from('account_access_requests').insert({
        'user_id': user.id,
        'requested_role': requested,
        'department_id': requested == 'department' ? departmentId : null,
        'reason': reason.length >= 10
            ? reason
            : 'Official account access request submitted during registration.',
      });
    } catch (_) {
      // A failed request never grants a role. The account remains a Citizen.
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('SAMANVAY')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 42, color: navy),
                    const SizedBox(height: 12),
                    const Text(
                      'Your account profile could not be loaded.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Access is not being guessed from the device. '
                      'Please sign out and try again, or contact the administrator.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => supabase.auth.signOut(),
                      child: const Text('SIGN OUT'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final profile = snapshot.data!;
        final role = (profile['role'] ?? 'requester').toString();
        final isCitizen = role == 'requester';
        final pages = isCitizen
            ? <Widget>[
                const DashboardPage(),
                const RequestsPage(),
                const MapPage(),
                ProfilePage(profile: profile),
              ]
            : <Widget>[
                RoleWorkspacePage(profile: profile),
                const MapPage(),
                ProfilePage(profile: profile),
              ];
        final destinations = isCitizen
            ? const <NavigationDestination>[
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
                  label: 'GIS Map',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ]
            : const <NavigationDestination>[
                NavigationDestination(
                  icon: Icon(Icons.workspaces_outline),
                  selectedIcon: Icon(Icons.workspaces),
                  label: 'Workspace',
                ),
                NavigationDestination(
                  icon: Icon(Icons.map_outlined),
                  selectedIcon: Icon(Icons.map),
                  label: 'GIS Map',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ];

        return Scaffold(
          body: IndexedStack(index: selectedIndex, children: pages),
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) =>
                setState(() => selectedIndex = index),
            destinations: destinations,
          ),
        );
      },
    );
  }
}

class AdminAccessRequestsPanel extends StatefulWidget {
  const AdminAccessRequestsPanel({super.key});

  @override
  State<AdminAccessRequestsPanel> createState() => _AdminAccessRequestsPanelState();
}

class _AdminAccessRequestsPanelState extends State<AdminAccessRequestsPanel> {
  late Future<List<Map<String, dynamic>>> requestsFuture;
  bool working = false;

  @override
  void initState() {
    super.initState();
    requestsFuture = loadRequests();
  }

  Future<List<Map<String, dynamic>>> loadRequests() async {
    final rows = await supabase.rpc('admin_access_request_directory');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<void> refreshRequests() async {
    setState(() => requestsFuture = loadRequests());
    await requestsFuture;
  }

  Future<void> review(Map<String, dynamic> request, String decision) async {
    setState(() => working = true);
    try {
      await supabase.rpc('admin_review_access_request', params: {
        'p_request_id': request['request_id'],
        'p_decision': decision,
        'p_review_notes': null,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(decision == 'approve'
            ? 'Official access approved.'
            : 'Access request rejected.'),
      ));
      await refreshRequests();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Review failed: $error')),
      );
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        const Text('Pending official access requests',
            style: TextStyle(color: navy, fontSize: 19, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('Approving a request assigns the role through the protected database function.',
            style: TextStyle(color: Colors.blueGrey, fontSize: 12)),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: requestsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Card(child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text('Requests unavailable: ${snapshot.error}'),
              ));
            }
            final requests = snapshot.data ?? [];
            if (requests.isEmpty) {
              return const Card(child: Padding(
                padding: EdgeInsets.all(14),
                child: Text('No pending official access requests.'),
              ));
            }
            return Column(
              children: requests.map((request) {
                final name = request['display_name']?.toString().trim().isNotEmpty == true
                    ? request['display_name'].toString()
                    : 'Unnamed applicant';
                final role = request['requested_role'] == 'department'
                    ? 'Department Officer'
                    : request['requested_role'] == 'coordinator'
                        ? 'Coordinator'
                        : 'Administrator';
                final department = request['department_name']?.toString();
                return Card(
                  margin: const EdgeInsets.only(top: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(color: navy, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(department == null ? role : '$role · $department',
                            style: const TextStyle(fontSize: 12, color: teal, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(request['reason']?.toString() ?? ''),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: working ? null : () => review(request, 'reject'),
                                child: const Text('REJECT'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton(
                                onPressed: working ? null : () => review(request, 'approve'),
                                child: const Text('APPROVE'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class AdminAccountsPanel extends StatefulWidget {
  const AdminAccountsPanel({super.key});

  @override
  State<AdminAccountsPanel> createState() => _AdminAccountsPanelState();
}

class _AdminAccountsPanelState extends State<AdminAccountsPanel> {
  late Future<Map<String, dynamic>> directoryFuture;

  @override
  void initState() {
    super.initState();
    directoryFuture = loadDirectory();
  }

  Future<Map<String, dynamic>> loadDirectory() async {
    final usersResult = await supabase.rpc('admin_user_directory');
    final departmentsResult =
        await supabase.from('departments').select('id, name').order('name');
    return {
      'users': List<Map<String, dynamic>>.from(usersResult as List),
      'departments': List<Map<String, dynamic>>.from(departmentsResult),
    };
  }

  Future<void> reload() async {
    setState(() => directoryFuture = loadDirectory());
    await directoryFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text('Account and role administration',
            style: TextStyle(
                color: navy, fontSize: 19, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text(
          'Role changes are submitted to the protected administrator RPC and recorded in the audit log. You cannot change your own role.',
          style: TextStyle(color: Colors.blueGrey, fontSize: 12),
        ),
        const SizedBox(height: 10),
        FutureBuilder<Map<String, dynamic>>(
          future: directoryFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                  child: Padding(
                      padding: EdgeInsets.all(18),
                      child: CircularProgressIndicator()));
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                      'Administrator directory unavailable: ${snapshot.error}'),
                ),
              );
            }
            final users =
                snapshot.data!['users'] as List<Map<String, dynamic>>;
            final departments =
                snapshot.data!['departments'] as List<Map<String, dynamic>>;
            if (users.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('No registered accounts found.'),
                ),
              );
            }
            return Column(
              children: users
                  .map((user) => AdminAccountEditor(
                        key: ValueKey(user['user_id']),
                        user: user,
                        departments: departments,
                        onSaved: reload,
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class AdminAccountEditor extends StatefulWidget {
  final Map<String, dynamic> user;
  final List<Map<String, dynamic>> departments;
  final Future<void> Function() onSaved;

  const AdminAccountEditor({
    super.key,
    required this.user,
    required this.departments,
    required this.onSaved,
  });

  @override
  State<AdminAccountEditor> createState() => _AdminAccountEditorState();
}

class _AdminAccountEditorState extends State<AdminAccountEditor> {
  late String selectedRole;
  String? selectedDepartment;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    selectedRole = (widget.user['role'] ?? 'requester').toString();
    selectedDepartment = widget.user['department_id']?.toString();
  }

  Future<void> save() async {
    if (selectedRole == 'department' && selectedDepartment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a department for this officer.')),
      );
      return;
    }
    setState(() => saving = true);
    try {
      await supabase.rpc('admin_update_profile_role', params: {
        'p_user_id': widget.user['user_id'],
        'p_role': selectedRole,
        'p_department_id':
            selectedRole == 'department' ? selectedDepartment : null,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account role updated and audit recorded.')),
      );
      await widget.onSaved();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Role update rejected: $error')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = widget.user['user_id']?.toString() ?? '';
    final name = widget.user['display_name']?.toString().trim().isNotEmpty == true
        ? widget.user['display_name'].toString()
        : 'Unnamed account';
    final departmentItems = widget.departments
        .map((d) => DropdownMenuItem<String>(
              value: d['id'].toString(),
              child: Text(d['name'].toString(),
                  overflow: TextOverflow.ellipsis),
            ))
        .toList();
    final currentDepartmentExists = departmentItems
        .any((item) => item.value == selectedDepartment);
    final isSelf = userId == supabase.auth.currentUser?.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name,
                style: const TextStyle(
                    color: navy, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Text('Account ID: $userId',
                style: const TextStyle(
                    color: Colors.blueGrey, fontSize: 10)),
            const SizedBox(height: 10),
            if (isSelf)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Your own administrator role is locked against self-change.',
                  style: TextStyle(color: Colors.blueGrey, fontSize: 11),
                ),
              ),
            DropdownButtonFormField<String>(
              value: selectedRole,
              decoration: const InputDecoration(
                labelText: 'Platform role',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: 'requester', child: Text('Citizen')),
                DropdownMenuItem(
                    value: 'department', child: Text('Department Officer')),
                DropdownMenuItem(
                    value: 'coordinator', child: Text('Coordinator')),
                DropdownMenuItem(value: 'admin', child: Text('Administrator')),
              ],
              onChanged: saving || isSelf
                  ? null
                  : (value) {
                      if (value != null) setState(() => selectedRole = value);
                    },
            ),
            if (selectedRole == 'department') ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: currentDepartmentExists ? selectedDepartment : null,
                decoration: const InputDecoration(
                  labelText: 'Assigned department',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: departmentItems,
                onChanged: saving
                    ? null
                    : (value) => setState(() => selectedDepartment = value),
              ),
            ],
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: saving || isSelf ? null : save,
                icon: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_outlined),
                label: Text(saving ? 'SAVING' : 'SAVE ROLE'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Official workspaces use the role already assigned in the protected
// profiles table. The app never lets a user select or promote their own role.
class RoleWorkspacePage extends StatefulWidget {
  final Map<String, dynamic> profile;

  const RoleWorkspacePage({super.key, required this.profile});

  @override
  State<RoleWorkspacePage> createState() => _RoleWorkspacePageState();
}

class _RoleWorkspacePageState extends State<RoleWorkspacePage> {
  late Future<List<Map<String, dynamic>>> requestsFuture;

  String get role => (widget.profile['role'] ?? '').toString();

  String get roleTitle {
    switch (role) {
      case 'department':
        return 'Department Officer Portal';
      case 'coordinator':
        return 'Coordination Portal';
      case 'admin':
        return 'Administrator Portal';
      default:
        return 'Official Workspace';
    }
  }

  String get roleDescription {
    switch (role) {
      case 'department':
        return 'Review cases visible to your assigned department and track their progress.';
      case 'coordinator':
        return 'Monitor authorised cross-department cases and coordination status.';
      case 'admin':
        return 'Monitor platform activity. Account privileges remain controlled by server-side administrator authorisation.';
      default:
        return 'Your account does not have an official workspace role.';
    }
  }

  @override
  void initState() {
    super.initState();
    requestsFuture = loadAuthorisedRequests();
  }

  Future<List<Map<String, dynamic>>> loadAuthorisedRequests() async {
    final rows = await supabase
        .from('excavation_requests')
        .select('id, request_number, title, city, status, case_category, created_at')
        .order('created_at', ascending: false)
        .limit(30);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> refresh() async {
    setState(() => requestsFuture = loadAuthorisedRequests());
    await requestsFuture;
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.profile['display_name']?.toString() ?? 'Official';
    return Scaffold(
      appBar: AppBar(
        title: const Text('SAMANVAY'),
        actions: [
          IconButton(
            tooltip: 'Refresh cases',
            onPressed: refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: navy,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('AUTHENTICATED WORKSPACE',
                      style: TextStyle(color: Colors.white70, fontSize: 11)),
                  const SizedBox(height: 8),
                  Text(roleTitle,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(name,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(roleDescription,
                      style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.verified_user_outlined, color: teal),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Access is enforced by Supabase Row Level Security. '
                    'Only records authorised for this account are returned.',
                    style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Authorised cases',
                style: TextStyle(
                    color: navy, fontSize: 19, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: requestsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Cases could not be loaded: ${snapshot.error}'),
                    ),
                  );
                }
                final rows = snapshot.data ?? [];
                if (rows.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text('No cases are currently visible to this account.'),
                    ),
                  );
                }
                return Column(
                  children: rows.map((item) {
                    final number = item['request_number']?.toString() ?? '—';
                    final title = item['title']?.toString() ?? 'Untitled case';
                    final city = item['city']?.toString() ?? 'Location unavailable';
                    final status = item['status']?.toString() ?? 'unknown';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 9),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFE5F4F1),
                          child: Icon(Icons.assignment_outlined, color: teal),
                        ),
                        title: Text(title,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Case #$number · $city'),
                        trailing: Text(status.replaceAll('_', ' ').toUpperCase(),
                            style: const TextStyle(
                                fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            if (role == 'admin') ...[
              const AdminAccessRequestsPanel(),
              const AdminAccountsPanel(),
            ],
          ],
        ),
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

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final Map<String, bool> layers = {
    'Water': true,
    'Sewer': true,
    'Electricity': true,
    'Telecom': false,
    'Gas': false,
  };
  bool showSection = true;
  double depth = 1.5;
  String area = 'Coimbatore · Demo sector';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Infrastructure GIS'),
        actions: [
          IconButton(
            tooltip: 'Map information',
            icon: const Icon(Icons.info_outline),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Demonstration map'),
                content: const Text(
                  'This is a schematic demonstration, not a live survey map. '
                  'All utility lines and depths are synthetic DEMO DATA. '
                  'They do not show actual underground services.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF2D9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE3B45C)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFF8A5100)),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'DEMO DATA — Not for excavation or safety decisions. '
                    'Verified utility records are not loaded.',
                    style: TextStyle(
                      color: Color(0xFF714400),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 13),
          DropdownButtonFormField<String>(
            value: area,
            decoration: const InputDecoration(
              labelText: 'Map area',
              prefixIcon: Icon(Icons.location_on_outlined),
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
            items: const [
              DropdownMenuItem(
                value: 'India · National overview',
                child: Text('India · National overview'),
              ),
              DropdownMenuItem(
                value: 'Tamil Nadu · State overview',
                child: Text('Tamil Nadu · State overview'),
              ),
              DropdownMenuItem(
                value: 'Coimbatore · Demo sector',
                child: Text('Coimbatore · Demo sector'),
              ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => area = value);
            },
          ),
          const SizedBox(height: 15),
          const Text(
            'Utility layers',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: navy),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 7,
            children: layers.keys.map((name) {
              return FilterChip(
                label: Text(name),
                selected: layers[name]!,
                onSelected: (value) => setState(() => layers[name] = value),
              );
            }).toList(),
          ),
          const SizedBox(height: 9),
          Container(
            height: 285,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFFB7C6BE)),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _SamanvayMapPainter(layers: layers),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Text(
                      'SCHEMATIC · DEMO',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: navy),
                    ),
                  ),
                ),
                const Positioned(
                  right: 10,
                  bottom: 10,
                  child: Icon(Icons.my_location, color: navy),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Wrap(
            spacing: 12,
            runSpacing: 7,
            children: [
              _SamanvayLegend(color: Color(0xFF1677D2), label: 'Water'),
              _SamanvayLegend(color: Color(0xFF8A5A32), label: 'Sewer'),
              _SamanvayLegend(color: Color(0xFFE5A000), label: 'Electricity'),
              _SamanvayLegend(color: Color(0xFF8055B7), label: 'Telecom'),
              _SamanvayLegend(color: Color(0xFFD34C43), label: 'Gas'),
            ],
          ),
          const SizedBox(height: 17),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Underground cross-section',
                style: TextStyle(fontWeight: FontWeight.bold, color: navy)),
            subtitle: const Text('Illustrative layers · not surveyed'),
            value: showSection,
            onChanged: (value) => setState(() => showSection = value),
          ),
          if (showSection) ...[
            Container(
              height: 215,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: const Color(0xFFB7C6CE)),
              ),
              child: CustomPaint(
                painter: _SamanvaySectionPainter(depth: depth, layers: layers),
                child: const SizedBox.expand(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Illustrative depth'),
                const Spacer(),
                Text(depth.toStringAsFixed(1) + ' m',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: navy)),
              ],
            ),
            Slider(
              value: depth,
              min: 0.5,
              max: 4,
              divisions: 7,
              onChanged: (value) => setState(() => depth = value),
            ),
          ],
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.verified_outlined, color: teal),
            title: Text('Data confidence'),
            subtitle: Text(
              'No verified utility geometry or depth is loaded. '
              'Owner-authorised survey data is required before operational use.',
            ),
          ),
        ],
      ),
    );
  }
}

class _SamanvayLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _SamanvayLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 12, color: navy)),
      ],
    );
  }
}

class _SamanvayMapPainter extends CustomPainter {
  final Map<String, bool> layers;
  _SamanvayMapPainter({required this.layers});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFE7EBDD));
    final park = Paint()..color = const Color(0xFFC5D9B5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * .04, size.height * .08, size.width * .25, size.height * .22),
        const Radius.circular(12)),
      park);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * .70, size.height * .68, size.width * .24, size.height * .22),
        const Radius.circular(12)),
      park);

    final road = Paint()
      ..color = const Color(0xFFFCFBF6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22
      ..strokeCap = StrokeCap.round;
    final edge = Paint()
      ..color = const Color(0xFFBFC5BC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final roads = [
      Path()..moveTo(-5, size.height * .48)..lineTo(size.width + 5, size.height * .48),
      Path()..moveTo(size.width * .50, -5)..lineTo(size.width * .58, size.height + 5),
      Path()..moveTo(size.width * .08, size.height * .92)..lineTo(size.width * .92, size.height * .10),
    ];
    for (final path in roads) {
      canvas.drawPath(path, road);
      canvas.drawPath(path, edge);
    }

    final building = Paint()..color = const Color(0xFFD2D8D0);
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 4; col++) {
        final rect = Rect.fromLTWH(
          size.width * (.08 + col * .22),
          size.height * (.12 + row * .25),
          size.width * .10,
          size.height * .08);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)), building);
      }
    }

    void line(String key, Color color, List<Offset> points) {
      if (layers[key] != true) return;
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = Path()
        ..moveTo(points.first.dx * size.width, points.first.dy * size.height);
      for (final p in points.skip(1)) {
        path.lineTo(p.dx * size.width, p.dy * size.height);
      }
      canvas.drawPath(path, paint);
    }

    line('Water', const Color(0xFF1677D2), [
      const Offset(.04, .68), const Offset(.30, .68),
      const Offset(.49, .48), const Offset(.96, .48)]);
    line('Sewer', const Color(0xFF8A5A32), [
      const Offset(.05, .82), const Offset(.32, .82),
      const Offset(.58, .48), const Offset(.91, .17)]);
    line('Electricity', const Color(0xFFE5A000), [
      const Offset(.22, .05), const Offset(.22, .48),
      const Offset(.58, .75), const Offset(.95, .75)]);
    line('Telecom', const Color(0xFF8055B7), [
      const Offset(.05, .25), const Offset(.48, .25),
      const Offset(.72, .48), const Offset(.95, .48)]);
    line('Gas', const Color(0xFFD34C43), [
      const Offset(.12, .92), const Offset(.42, .62),
      const Offset(.75, .62), const Offset(.92, .35)]);

    final center = Offset(size.width * .58, size.height * .48);
    canvas.drawCircle(center, 7, Paint()..color = navy);
    canvas.drawCircle(center, 12, Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant _SamanvayMapPainter oldDelegate) => true;
}

class _SamanvaySectionPainter extends CustomPainter {
  final double depth;
  final Map<String, bool> layers;

  _SamanvaySectionPainter({required this.depth, required this.layers});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFEAF0F2));
    final top = size.height * .30;
    canvas.drawRect(Rect.fromLTWH(0, top, size.width, size.height - top),
        Paint()..color = const Color(0xFFD9C6A5));
    canvas.drawRect(Rect.fromLTWH(0, top + 45, size.width, size.height - top - 45),
        Paint()..color = const Color(0xFFC8B18C));
    canvas.drawLine(Offset(0, top), Offset(size.width, top),
        Paint()..color = const Color(0xFF536D46)..strokeWidth = 5);

    final tp = TextPainter(textDirection: TextDirection.ltr);
    void label(String value, Offset at) {
      tp.text = TextSpan(text: value, style: const TextStyle(
        color: navy, fontSize: 10, fontWeight: FontWeight.bold));
      tp.layout(maxWidth: size.width - 12);
      tp.paint(canvas, at);
    }
    label('GROUND SURFACE · ILLUSTRATIVE', const Offset(9, 8));
    label('SOIL LAYER', Offset(9, top + 10));
    label('DEEPER SOIL', Offset(9, top + 58));

    final colors = <String, Color>{
      'Water': const Color(0xFF1677D2),
      'Sewer': const Color(0xFF8A5A32),
      'Electricity': const Color(0xFFE5A000),
      'Telecom': const Color(0xFF8055B7),
      'Gas': const Color(0xFFD34C43),
    };
    var lane = 0;
    final y = top + 30 + depth / 4 * 90;
    for (final entry in colors.entries) {
      if (layers[entry.key] != true) continue;
      final laneY = y + lane * 16;
      canvas.drawLine(Offset(size.width * .47, laneY),
          Offset(size.width * .91, laneY),
          Paint()..color = entry.value..strokeWidth = 6..strokeCap = StrokeCap.round);
      label(entry.key.toUpperCase() + ' · DEMO', Offset(size.width * .49, laneY - 13));
      lane++;
    }
    label('DEPTH CONTROL IS A DEMO VALUE', Offset(9, size.height - 19));
  }

  @override
  bool shouldRepaint(covariant _SamanvaySectionPainter oldDelegate) => true;
}

// PROFILE
// ==========================================

class ProfilePage extends StatelessWidget {
  final Map<String, dynamic>? profile;

  const ProfilePage({super.key, this.profile});

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
    final name = profile?['display_name'] ??
        user?.userMetadata?['display_name'] ?? 'User';
    final rawRole = (profile?['role'] ?? 'requester').toString();
    final roleLabel = switch (rawRole) {
      'department' => 'Department Officer',
      'coordinator' => 'Coordinator',
      'admin' => 'Administrator',
      _ => 'Citizen',
    };

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
          const SizedBox(height: 14),
          ListTile(
            leading: const Icon(Icons.badge_outlined, color: teal),
            title: const Text('Verified platform role'),
            subtitle: Text(roleLabel,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
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

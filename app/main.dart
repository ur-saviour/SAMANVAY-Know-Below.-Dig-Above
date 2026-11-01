
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
    anonKey: supabasePublishableKey,
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

        return const MainScreen();
      },
    );
  }
}

// ==========================================
// LOGIN AND REGISTRATION
// ==========================================

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool isLogin = true;
  bool loading = false;
  bool hidePassword = true;

  String message = '';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      loading = true;
      message = '';
    });

    try {
      if (isLogin) {
        await supabase.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        if (!mounted) return;

        setState(() {
          message = 'Login successful.';
        });
      } else {
        final response = await supabase.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          data: {
            'display_name': _nameController.text.trim(),
          },
        );

        if (!mounted) return;

        if (response.session == null) {
          setState(() {
            message =
                'Registration successful. Please check your email '
                'and confirm your account before logging in.';
          });
        } else {
          setState(() {
            message = 'Account created successfully.';
          });
        }
      }
    } on AuthException catch (error) {
      if (!mounted) return;

      setState(() {
        message = error.message;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        message = 'Something went wrong. Please try again.';
      });
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
                    style: TextStyle(color: Colors.blueGrey),
                  ),

                  const SizedBox(height: 36),

                  Text(
                    isLogin ? 'Welcome back' : 'Create your account',
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
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter your name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      prefixIcon: Icon(Icons.email_outlined),
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
                      prefixIcon: const Icon(Icons.lock_outline),
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
                      if (value == null || value.length < 8) {
                        return 'Password must contain at least 8 characters';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 20),

                  if (message.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: message.toLowerCase().contains('success') ||
                                message.toLowerCase().contains('check your email')
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        message,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),

                  const SizedBox(height: 16),

                  FilledButton(
                    onPressed: loading ? null : submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: navy,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            isLogin ? 'LOGIN' : 'CREATE ACCOUNT',
                          ),
                  ),

                  const SizedBox(height: 12),

                  TextButton(
                    onPressed: loading
                        ? null
                        : () {
                            setState(() {
                              isLogin = !isLogin;
                              message = '';
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
// REQUESTS
// ==========================================

class RequestsPage extends StatelessWidget {
  const RequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Excavation Requests'),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.assignment_outlined,
                size: 65,
                color: teal,
              ),
              SizedBox(height: 16),
              Text(
                'Your requests will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Live excavation request management '
                'will be added in the next development phase.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
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


import 'package:flutter/material.dart';

void main() {
  runApp(const SamanvayApp());
}

const Color navy = Color(0xFF10243A);
const Color teal = Color(0xFF087E8B);
const Color background = Color(0xFFF3F6F9);

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
        fontFamily: 'Roboto',
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int selectedIndex = 0;

  final List<Widget> pages = const [
    DashboardPage(),
    RequestsPage(),
    MapPage(),
    ProfilePage(),
  ];

  final List<String> titles = [
    'Dashboard',
    'Excavation Requests',
    'Infrastructure Map',
    'Profile',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            const Icon(Icons.account_tree_rounded, size: 27),
            const SizedBox(width: 10),
            const Text(
              'SAMANVAY',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Notifications will be added later.'),
                ),
              );
            },
            icon: const Icon(Icons.notifications_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: pages[selectedIndex],
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
            label: 'Home',
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

// DASHBOARD

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'Welcome to SAMANVAY',
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.bold,
            color: navy,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Municipal Infrastructure Coordination Platform',
          style: TextStyle(color: Colors.blueGrey),
        ),
        const SizedBox(height: 22),

        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: navy,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.account_tree_rounded,
                color: Colors.white,
                size: 35,
              ),
              SizedBox(height: 15),
              Text(
                'Coordinate before you excavate.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Connecting utility departments for smarter '
                'infrastructure planning.',
                style: TextStyle(
                  color: Colors.white70,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 22),

        const Text(
          'Project Overview',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: navy,
          ),
        ),
        const SizedBox(height: 12),

        const Row(
          children: [
            Expanded(
              child: StatCard(
                title: 'Requests',
                value: '12',
                icon: Icons.assignment,
                color: teal,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: StatCard(
                title: 'Under Review',
                value: '04',
                icon: Icons.hourglass_top,
                color: Colors.orange,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        const Row(
          children: [
            Expanded(
              child: StatCard(
                title: 'Approved',
                value: '06',
                icon: Icons.verified,
                color: Colors.green,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: StatCard(
                title: 'Conflicts',
                value: '02',
                icon: Icons.warning_amber,
                color: Colors.red,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        const Text(
          'Infrastructure Departments',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: navy,
          ),
        ),
        const SizedBox(height: 12),

        const DepartmentTile(
          name: 'Water Supply',
          icon: Icons.water_drop,
        ),
        const DepartmentTile(
          name: 'Electricity',
          icon: Icons.electric_bolt,
        ),
        const DepartmentTile(
          name: 'Sewage and Drainage',
          icon: Icons.water,
        ),
        const DepartmentTile(
          name: 'Telecommunications',
          icon: Icons.cell_tower,
        ),
        const DepartmentTile(
          name: 'Gas Pipeline',
          icon: Icons.local_fire_department,
        ),

        const SizedBox(height: 20),
        const Text(
          'DEMO DATA — NOT LIVE MUNICIPAL RECORDS',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1,
            color: Colors.blueGrey,
          ),
        ),
      ],
    );
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 25),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
              color: navy,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              color: Colors.blueGrey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class DepartmentTile extends StatelessWidget {
  final String name;
  final IconData icon;

  const DepartmentTile({
    super.key,
    required this.name,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE5F3F4),
          child: Icon(icon, color: teal),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

// EXCAVATION REQUESTS

class RequestsPage extends StatelessWidget {
  const RequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final requests = [
      {
        'id': 'SAM-001',
        'department': 'Water Supply',
        'location': 'Sample Road A',
        'status': 'Under Review',
      },
      {
        'id': 'SAM-002',
        'department': 'Electricity',
        'location': 'Sample Road B',
        'status': 'Approved',
      },
      {
        'id': 'SAM-003',
        'department': 'Sewage',
        'location': 'Sample Road C',
        'status': 'Conflict Detected',
      },
    ];

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'Excavation Requests',
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.bold,
            color: navy,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Illustrative requests for the prototype.',
          style: TextStyle(color: Colors.blueGrey),
        ),
        const SizedBox(height: 16),

        ...requests.map((request) {
          final status = request['status']!;

          final Color statusColor = status == 'Approved'
              ? Colors.green
              : status == 'Conflict Detected'
                  ? Colors.red
                  : Colors.orange;

          return Card(
            color: Colors.white,
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        request['id']!,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: navy,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withAlpha(25),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(request['department']!),
                  const SizedBox(height: 5),
                  Text(
                    request['location']!,
                    style: const TextStyle(
                      color: Colors.blueGrey,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),

        const SizedBox(height: 10),
        const Text(
          'These sample requests are not connected to an approval system.',
          style: TextStyle(
            fontSize: 11,
            color: Colors.blueGrey,
          ),
        ),
      ],
    );
  }
}

// INFRASTRUCTURE MAP

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.map_outlined,
            size: 85,
            color: teal,
          ),
          const SizedBox(height: 20),
          const Text(
            'Infrastructure GIS Map',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: navy,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'The live map will be introduced in the next '
            'development phase. It will display registered '
            'underground utility assets and proposed excavation '
            'locations.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.blueGrey,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'GIS integration is planned for Phase 2.',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.layers),
            label: const Text('GIS integration coming next'),
          ),
        ],
      ),
    );
  }
}

// PROFILE

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 20),
        const CircleAvatar(
          radius: 42,
          backgroundColor: navy,
          child: Icon(
            Icons.account_circle,
            size: 65,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 15),
        const Text(
          'SAMANVAY User',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.bold,
            color: navy,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Demo Account',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.blueGrey),
        ),
        const SizedBox(height: 30),
        const ListTile(
          leading: Icon(Icons.business, color: teal),
          title: Text('Department'),
          subtitle: Text('Not assigned'),
        ),
        const Divider(),
        const ListTile(
          leading: Icon(Icons.security, color: teal),
          title: Text('Account permissions'),
          subtitle: Text('Demo mode — no authentication'),
        ),
        const Divider(),
        const ListTile(
          leading: Icon(Icons.info_outline, color: teal),
          title: Text('Application version'),
          subtitle: Text('SAMANVAY Alpha 0.1'),
        ),
        const Divider(),
        const SizedBox(height: 20),
        const Text(
          'A municipal infrastructure coordination concept.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.blueGrey),
        ),
      ],
    );
  }
}

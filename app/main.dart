import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:crypto/crypto.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'asset_evidence_page.dart';
import 'public_excavation_tracker_page.dart';
import 'ai_assistant_page.dart';
import 'coordinated_work_calendar_page.dart';
import 'public_transparency_dashboard_page.dart';

const String supabaseUrl =
    String.fromEnvironment('SUPABASE_URL');

const String supabasePublishableKey =
    String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

// Render the branded opening immediately. Backend startup runs in parallel,
// so slow storage/network initialization cannot hide the opening animation.
Future<void> _samanvayBootFuture = Future<void>.value();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SamanvayApp());
  _samanvayBootFuture = _initialiseSamanvayServices();
}

Future<void> _initialiseSamanvayServices() async {
  final preferences = await SharedPreferences.getInstance();
  samanvayThemeMode.value = preferences.getBool('samanvay_light_mode') == true
      ? ThemeMode.light
      : ThemeMode.dark;

  if (supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) {
    throw StateError(
      'Supabase configuration is missing. '
      'Check the GitHub Actions public configuration secrets.',
    );
  }

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );
}

final supabase = Supabase.instance.client;

final ValueNotifier<ThemeMode> samanvayThemeMode = ValueNotifier(ThemeMode.dark);


bool get _usesLegacyLightPalette => samanvayThemeMode.value == ThemeMode.light;

// Shared semantic colours. These values reproduce Alpha 0.2's light-mode
// navy / teal / soft-grey palette while keeping the current dark palette.
Color get navy => _usesLegacyLightPalette
    ? const Color(0xFF10243A)
    : const Color(0xFF08182B);
Color get teal => _usesLegacyLightPalette
    ? const Color(0xFF13A89E)
    : const Color(0xFF20D6C2);
Color get electricBlue => _usesLegacyLightPalette
    ? const Color(0xFF13A89E)
    : const Color(0xFF3D83F6);
Color get cyanAccent => _usesLegacyLightPalette
    ? const Color(0xFF13A89E)
    : const Color(0xFF35D7F2);
Color get panelNavy => _usesLegacyLightPalette
    ? const Color(0xFFFFFFFF)
    : const Color(0xFF102842);
Color get background => _usesLegacyLightPalette
    ? const Color(0xFFF4F7FA)
    : const Color(0xFF061426);
Color get ink => _usesLegacyLightPalette
    ? const Color(0xFF000000)
    : const Color(0xFFE8F1FA);
Color get mutedInk => _usesLegacyLightPalette
    ? const Color(0xFF000000)
    : const Color(0xFFA6B9CA);
Color get borderColor => _usesLegacyLightPalette
    ? const Color(0xFFDCE5EC)
    : const Color(0xFF25415E);

String _displayRoleName(String role) => switch (role) {
  'requester' => 'Citizen',
  'department' => 'Department officer',
  'coordinator' => 'Coordinator',
  'admin' => 'Administrator',
  _ => role.replaceAll('_', ' '),
};

const Map<String, String> _publicDemoStaffIds = {
  'department': 'PUBLIC-OFFICER-DEMO',
  'coordinator': 'PUBLIC-COORDINATOR-DEMO',
  'admin': 'PUBLIC-ADMIN-DEMO',
};

Future<String?> _showProfileSwitcher(
  BuildContext context, {
  required String currentRole,
}) {
  const options = <Map<String, Object>>[
    {
      'role': 'requester',
      'title': 'Citizen',
      'description': 'Submit and track civic infrastructure requests',
      'icon': Icons.person_outline_rounded,
    },
    {
      'role': 'department',
      'title': 'Department Officer',
      'description': 'Assigned works, inspections and field evidence demo',
      'icon': Icons.account_tree_outlined,
    },
    {
      'role': 'coordinator',
      'title': 'Coordinator',
      'description': 'Cross-department planning and coordination demo',
      'icon': Icons.hub_outlined,
    },
    {
      'role': 'admin',
      'title': 'Administrator',
      'description': 'National overview and platform governance demo',
      'icon': Icons.admin_panel_settings_outlined,
    },
  ];

  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    isScrollControlled: true,
    builder: (sheetContext) {
      final scheme = Theme.of(sheetContext).colorScheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SWITCH PROFILES',
                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .5,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Choose a workspace to demonstrate. Official workspaces open in clearly marked demo mode.',
                style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              ...options.map((option) {
                final role = option['role']! as String;
                final selected = role == currentRole;
                final icon = option['icon']! as IconData;
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 7),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    leading: CircleAvatar(
                      backgroundColor: scheme.primary.withValues(alpha: .12),
                      child: Icon(icon, color: scheme.primary),
                    ),
                    title: Text(
                      option['title']! as String,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(option['description']! as String),
                    trailing: selected
                        ? Icon(Icons.check_circle_rounded, color: scheme.primary)
                        : const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(sheetContext).pop(role),
                  ),
                );
              }),
              const SizedBox(height: 4),
              Text(
                'Demo role switching does not alter your authenticated account or production permissions.',
                style: Theme.of(sheetContext).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

String _normalisePhoneForAuth(String input) {
  final compact = input.trim().replaceAll(RegExp(r'[\s()\-]'), '');
  if (compact.startsWith('+')) return compact;
  final digits = compact.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 10) return '+91$digits';
  if (digits.length == 11 && digits.startsWith('0')) {
    return '+91${digits.substring(1)}';
  }
  if (digits.length == 12 && digits.startsWith('91')) return '+$digits';
  return compact;
}

// Numeric aliases for the existing staff test accounts. These resolve to
// their original Supabase Auth identifiers; password verification, sessions,
// profile roles and RLS are unchanged.
const Map<String, String> _existingTestAccountAliases = {
  '9013': '9013.cis25@gmail.com',
  '10011': '10011.cis25@gmail.com',
  '10021': '10021.cis25@gmail.com',
};

// These IDs open local, read-only previews only. They do not authenticate
// with Supabase, impersonate users, or grant access to protected records.
const Map<String, String> _readOnlyStaffPreviewRoles = {
  '9013': 'admin',
  '10011': 'coordinator',
  '10021': 'department',
};

class SamanvayApp extends StatelessWidget {
  const SamanvayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: samanvayThemeMode,
      builder: (context, mode, _) {
          final theme = ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: background,
            colorScheme: ColorScheme.fromSeed(
              seedColor: electricBlue,
              brightness: Brightness.dark,
              primary: electricBlue,
              secondary: cyanAccent,
              surface: panelNavy,
            ),
            fontFamily: 'Inter',
            appBarTheme: AppBarTheme(
              backgroundColor: navy,
              foregroundColor: Colors.white,
              elevation: 0,
              titleTextStyle: GoogleFonts.spaceGrotesk(
                color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700),
            ),
            navigationBarTheme: NavigationBarThemeData(
              backgroundColor: navy,
              indicatorColor: cyanAccent.withValues(alpha: 0.18),
              labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) =>
                GoogleFonts.inter(
                  color: states.contains(WidgetState.selected) ? cyanAccent : mutedInk,
                  fontSize: 10,
                  fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
                )),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: panelNavy,
              contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:  BorderSide(color: cyanAccent, width: 1.7),
              ),
              labelStyle:  TextStyle(color: mutedInk),
              hintStyle:  TextStyle(color: mutedInk),
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                backgroundColor: electricBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              ),
            ),
            cardTheme: CardThemeData(
              color: panelNavy, elevation: 0, margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: borderColor)),
            ),
          );
          final lightTheme = ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            scaffoldBackgroundColor: background,
            colorScheme: ColorScheme.fromSeed(
              seedColor: teal,
              brightness: Brightness.light,
              primary: teal,
              secondary: teal,
              surface: Colors.white,
              onSurface: navy,
            ),
            fontFamily: 'Inter',
            textTheme: const TextTheme(
              bodyLarge: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
              bodyMedium: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
              bodySmall: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
              labelLarge: TextStyle(color: Colors.black, fontWeight: FontWeight.w800),
              labelMedium: TextStyle(color: Colors.black, fontWeight: FontWeight.w800),
              labelSmall: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
              titleLarge: TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
              titleMedium: TextStyle(color: Colors.black, fontWeight: FontWeight.w800),
              titleSmall: TextStyle(color: Colors.black, fontWeight: FontWeight.w800),
            ),
            appBarTheme: AppBarTheme(
              backgroundColor: navy,
              foregroundColor: Colors.white,
              elevation: 0,
              titleTextStyle: GoogleFonts.spaceGrotesk(
                color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700),
            ),
            cardTheme: CardThemeData(
              color: Colors.white,
              elevation: 1,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: borderColor),
              ),
            ),
            navigationBarTheme: NavigationBarThemeData(
              backgroundColor: Colors.white,
              indicatorColor: const Color(0xFFDCEFEB),
              labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) =>
                GoogleFonts.inter(
                  color: states.contains(WidgetState.selected) ? teal : mutedInk,
                  fontSize: 10,
                  fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
                )),
            ),
            navigationRailTheme: NavigationRailThemeData(
              backgroundColor: Colors.white,
              indicatorColor: const Color(0xFFDCEFEB),
              selectedIconTheme: IconThemeData(color: teal),
              unselectedIconTheme: IconThemeData(color: mutedInk),
              selectedLabelTextStyle: TextStyle(color: teal, fontWeight: FontWeight.w800, fontSize: 10),
              unselectedLabelTextStyle: TextStyle(color: mutedInk, fontSize: 10),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: teal, width: 1.7),
              ),
              labelStyle: TextStyle(color: mutedInk),
              hintStyle: TextStyle(color: mutedInk),
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                backgroundColor: teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: teal,
                side: BorderSide(color: teal.withValues(alpha: .65)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
              ),
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
            ),
            bottomSheetTheme: const BottomSheetThemeData(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
            ),
            dividerTheme: DividerThemeData(color: borderColor, thickness: 1),
            snackBarTheme: SnackBarThemeData(
              backgroundColor: navy,
              contentTextStyle: const TextStyle(color: Colors.white),
            ),
          );
      return MaterialApp(
        title: 'SAMANVAY | Towards Our Development',
        debugShowCheckedModeBanner: false,
        theme: lightTheme,
        darkTheme: theme,
        themeMode: mode,
        home: const OpeningExperience(),
      );
    },
    );
  }
}



class _SamanvayBrandLogo extends StatelessWidget {
  const _SamanvayBrandLogo({this.size = 100, this.radius = 22});
  final double size;
  final double radius;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: Image.asset(
      'assets/brand/samanvay_logo.jpg',
      width: size, height: size, fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => Container(
        width: size, height: size, color: const Color(0xFF071A34),
        alignment: Alignment.center,
        child: const Icon(Icons.hub_rounded, color: Color(0xFF38D9E7), size: 42),
      ),
    ),
  );
}

class _AnimatedDevelopmentTagline extends StatefulWidget {
  const _AnimatedDevelopmentTagline({this.fontSize = 14, this.textAlign = TextAlign.center});
  final double fontSize;
  final TextAlign textAlign;
  @override
  State<_AnimatedDevelopmentTagline> createState() => _AnimatedDevelopmentTaglineState();
}
class _AnimatedDevelopmentTaglineState extends State<_AnimatedDevelopmentTagline>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  @override
  void initState() {
    super.initState();
    controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))..repeat();
  }
  @override
  void dispose() { controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (_, __) => ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment(-1 + 2 * controller.value, 0),
        end: Alignment(1 + 2 * controller.value, 0),
        colors: _usesLegacyLightPalette
          ? const [Color(0xFFFF9933), Color(0xFF111827), Color(0xFF138808)]
          : const [Color(0xFFFF9933), Color(0xFFFFFFFF), Color(0xFF138808)],
      ).createShader(bounds),
      child: Text('TOWARDS OUR DEVELOPMENT 📈', textAlign: widget.textAlign,
        style: GoogleFonts.inter(fontSize: widget.fontSize, fontWeight: FontWeight.w900, letterSpacing: .45)),
    ),
  );
}

class _SamanvaySplashReveal extends StatelessWidget {
  const _SamanvaySplashReveal({super.key, required this.controller});
  final AnimationController controller;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (_, __) {
      final p = controller.value;
      final orbit = (p / .70).clamp(0.0, 1.0).toDouble();
      final flag = ((p - .70) / .30).clamp(0.0, 1.0).toDouble();
      final scale = 1 + Curves.easeInCubic.transform(flag) * 2.5;
      final opacity = (1 - Curves.easeInCubic.transform(flag) * .94).clamp(.06, 1.0).toDouble();
      final size = math.min(296.0, math.min(MediaQuery.sizeOf(context).width, MediaQuery.sizeOf(context).height) * .70);
      return Scaffold(
        backgroundColor: const Color(0xFF030D1C),
        body: Stack(fit: StackFit.expand, children: [
          const DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(
            center: Alignment(0, -.12), radius: .9,
            colors: [Color(0xFF173B67), Color(0xFF07182D), Color(0xFF020916)],
            stops: [0, .58, 1]))),
          Center(child: Opacity(
            opacity: 1.0 - Curves.easeInOut.transform(flag),
            child: CustomPaint(
              size: Size.square(size + 30),
              painter: _TricolourBorderPainter(progress: orbit),
            ),
          )),
          Center(child: Transform.scale(scale: scale, alignment: const Alignment(0, .22),
            child: Opacity(opacity: opacity, child: _SamanvayBrandLogo(size: size, radius: size * .14)))),
          Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _WavingFlagPainter(progress: flag)))),
        ]),
      );
    },
  );
}

class _TricolourBorderPainter extends CustomPainter {
  const _TricolourBorderPainter({required this.progress});
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRRect(RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(9), const Radius.circular(38)));
    final metric = path.computeMetrics().first;
    final total = metric.length;
    canvas.drawPath(path, Paint()..color = const Color(0xFF4B9EDB).withValues(alpha: .2)
      ..style = PaintingStyle.stroke..strokeWidth = 1.5);
    const colors = [Color(0xFFFF9933), Color(0xFFFFFFFF), Color(0xFF138808)];
    for (var i = 0; i < 3; i++) {
      final start = (progress * total * 3 + total * i / 3) % total;
      final end = start + total * .095;
      final pieces = end <= total
        ? [metric.extractPath(start, end)]
        : [metric.extractPath(start, total), metric.extractPath(0, end - total)];
      for (final piece in pieces) {
        canvas.drawPath(piece, Paint()..color = colors[i].withValues(alpha: .85)
          ..style = PaintingStyle.stroke..strokeWidth = 8..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
        canvas.drawPath(piece, Paint()..color = colors[i]
          ..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round);
      }
    }
  }
  @override
  bool shouldRepaint(covariant _TricolourBorderPainter old) => old.progress != progress;
}

class _WavingFlagPainter extends CustomPainter {
  const _WavingFlagPainter({
    required this.progress,
    this.opacity = 1,
    this.ambientBackground = false,
  });
  final double progress;
  final double opacity;
  final bool ambientBackground;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || opacity <= 0) return;
    final t = progress.clamp(0.0, 1.0).toDouble();
    final reveal = ambientBackground ? 1.0 : Curves.easeOutCubic.transform(t);
    final width = (ambientBackground
        ? math.min(560.0, size.width * .78)
        : math.min(300.0, size.width * .70)) * reveal;
    if (width < 2) return;
    final height = width * 2 / 3;
    final poleX = ambientBackground ? size.width * .105 : size.width * .27;
    final top = ambientBackground ? size.height * .105 : size.height * .34;
    final phase = t * math.pi * 4.0;
    final safeWidth = math.max(width, 1.0);

    // A planted mast, cap, finial and soft cast shadow.
    final pole = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF52677C), Color(0xFFE8F1F8), Color(0xFF7E91A6)],
      ).createShader(Rect.fromLTWH(poleX - 2, top - 20, 5, height + 42))
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(poleX + 1.8, top - 18), Offset(poleX + 1.8, top + height + 18), pole);
    canvas.drawCircle(Offset(poleX + 1.8, top - 20), 3.2,
      Paint()..color = const Color(0xFFDDE8F1));
    canvas.drawLine(Offset(poleX - 4, top + height + 18),
      Offset(poleX + 8, top + height + 18),
      Paint()..color = const Color(0xFF9FB1C0)..strokeWidth = 2.5..strokeCap = StrokeCap.round);

    double waveY(double u) {
      final amplitude = height * (ambientBackground ? .10 : .082);
      final primary = math.sin(u * math.pi * 2.15 + phase);
      final secondary = math.sin(u * math.pi * 4.3 + phase * .72) * .23;
      return (primary + secondary) * amplitude * u;
    }
    double waveX(double u) =>
        math.sin(u * math.pi * 2.0 + phase * .82) * height * .016 * u;

    // Curved flag hem, sampled cloth surface and gently tapered free edge.
    final cloth = Path();
    const samples = 64;
    for (var i = 0; i <= samples; i++) {
      final u = i / samples;
      final x = poleX + 5 + width * u + waveX(u);
      final y = top + waveY(u);
      if (i == 0) {
        cloth.moveTo(x, y);
      } else {
        cloth.lineTo(x, y);
      }
    }
    for (var i = samples; i >= 0; i--) {
      final u = i / samples;
      final x = poleX + 5 + width * u + waveX(u);
      final y = top + height + waveY(u) + height * .012 * math.sin(u * math.pi);
      cloth.lineTo(x, y);
    }
    cloth.close();
    canvas.save();
    canvas.clipPath(cloth);

    const bands = [
      Color(0xFFFF9933),
      Color(0xFFFFFFFF),
      Color(0xFF138808),
    ];
    for (var stripe = 0; stripe < 3; stripe++) {
      final bandHeight = height / 3;
      final stripePath = Path();
      for (var i = 0; i <= samples; i++) {
        final u = i / samples;
        final x = poleX + 5 + width * u + waveX(u);
        final y = top + stripe * bandHeight + waveY(u);
        if (i == 0) {
          stripePath.moveTo(x, y);
        } else {
          stripePath.lineTo(x, y);
        }
      }
      for (var i = samples; i >= 0; i--) {
        final u = i / samples;
        final x = poleX + 5 + width * u + waveX(u);
        final y = top + (stripe + 1) * bandHeight + waveY(u);
        stripePath.lineTo(x, y);
      }
      stripePath.close();
      final base = bands[stripe];
      canvas.drawPath(
        stripePath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(base, Colors.black, .12)!,
              base,
              Color.lerp(base, Colors.black, .16)!,
            ],
          ).createShader(Rect.fromLTWH(poleX, top, width, height))
          ..color = Colors.white.withValues(alpha: opacity),
      );
    }

    // Moving folds: alternating highlights and shadows create a woven-cloth read.
    for (var i = 0; i < 26; i++) {
      final u = i / 25;
      final x = poleX + 5 + width * u + waveX(u);
      final fold = Paint()
        ..color = (i.isEven ? Colors.white : const Color(0xFF06172C))
            .withValues(alpha: (i.isEven ? .12 : .10) * opacity * u)
        ..strokeWidth = math.max(1.2, width * .0028)
        ..strokeCap = StrokeCap.round;
      final bend = waveY(u);
      canvas.drawLine(
        Offset(x, top + bend - height * .012),
        Offset(x + waveX(u) * .45, top + height + bend + height * .012),
        fold,
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(poleX + 5, top, width, height),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.black.withValues(alpha: .16 * opacity),
            Colors.transparent,
            Colors.white.withValues(alpha: .12 * opacity),
            Colors.black.withValues(alpha: .20 * opacity),
          ],
          stops: const [0, .28, .62, 1],
        ).createShader(Rect.fromLTWH(poleX + 5, top, width, height)),
    );

    // Ashoka Chakra follows the local cloth wave, retaining the 24-spoke design.
    final chakraU = .49;
    final chakraX = poleX + 5 + width * chakraU + waveX(chakraU);
    final chakraY = top + height * .5 + waveY(chakraU);
    final radius = height * .105;
    final chakraPaint = Paint()
      ..color = const Color(0xFF000080).withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, height * .009);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(chakraX, chakraY), width: radius * 2,
        height: radius * 1.93),
      chakraPaint,
    );
    for (var i = 0; i < 24; i++) {
      final a = math.pi * 2 * i / 24 - math.pi / 2;
      canvas.drawLine(
        Offset(chakraX + math.cos(a) * radius * .10,
          chakraY + math.sin(a) * radius * .10),
        Offset(chakraX + math.cos(a) * radius * .91,
          chakraY + math.sin(a) * radius * .91),
        chakraPaint,
      );
    }
    canvas.drawCircle(Offset(chakraX, chakraY), radius * .10,
      Paint()..color = const Color(0xFF000080).withValues(alpha: opacity));
    canvas.restore();

    // Cloth silhouette and a restrained luminous edge.
    canvas.drawPath(cloth, Paint()
      ..color = Colors.white.withValues(alpha: .34 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1);
    canvas.drawPath(cloth, Paint()
      ..color = const Color(0xFF56BDF4).withValues(alpha: .08 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
  }

  @override
  bool shouldRepaint(covariant _WavingFlagPainter old) =>
      old.progress != progress || old.opacity != opacity ||
      old.ambientBackground != ambientBackground;
}


// ==========================================
// SAMANVAY ANIMATED WELCOME / OPENING SCREEN
// ==========================================
//
// Branded opening shown before the existing AuthGate. The welcome screen
// animates the road-and-pipeline mark, city lights, underground networks,
// flowing utility signals, wordmark and tagline. "Get Started" then opens
// the original authentication flow; no role or Supabase access is bypassed.

class OpeningExperience extends StatefulWidget {
  const OpeningExperience({super.key});

  @override
  State<OpeningExperience> createState() => _OpeningExperienceState();
}

class _OpeningExperienceState extends State<OpeningExperience>
    with TickerProviderStateMixin {
  late final AnimationController _introController;
  late final AnimationController _ambientController;
  late final AnimationController _splashController;
  bool _splashFinished = false;
  bool _showApplication = false;
  bool _startingApplication = false;
  String? _startupError;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4600),
    );
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
    _splashController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _splashFinished = true);
        _introController.forward();
      }
    });
    _splashController.forward();
  }

  @override
  void dispose() {
    _introController.dispose();
    _ambientController.dispose();
    _splashController.dispose();
    super.dispose();
  }

  Future<void> _startApplication() async {
    if (!mounted || _showApplication || _startingApplication) return;
    setState(() {
      _startingApplication = true;
      _startupError = null;
    });
    try {
      await _samanvayBootFuture;
      if (!mounted) return;
      setState(() {
        _showApplication = true;
        _startingApplication = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _startingApplication = false;
        _startupError = 'Secure services could not initialise. Check your connection and app configuration, then restart.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 680),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: .94, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      ),
      child: _showApplication
          ? const AuthGate(key: ValueKey<String>('samanvay-auth-gate'))
          : !_splashFinished
              ? _SamanvaySplashReveal(
                  key: const ValueKey<String>('samanvay-splash-reveal'),
                  controller: _splashController,
                )
              : _SamanvayOpeningScreen(
              key: const ValueKey<String>('samanvay-opening-screen'),
              introController: _introController,
              ambientController: _ambientController,
              onGetStarted: _startApplication,
              isStarting: _startingApplication,
              startupError: _startupError,
            ),
    );
  }
}

class _SamanvayOpeningScreen extends StatelessWidget {
  const _SamanvayOpeningScreen({
    super.key,
    required this.introController,
    required this.ambientController,
    required this.onGetStarted,
    required this.isStarting,
    required this.startupError,
  });

  final AnimationController introController;
  final AnimationController ambientController;
  final VoidCallback onGetStarted;
  final bool isStarting;
  final String? startupError;

  double _reveal(double value, double start, double end) {
    final amount = ((value - start) / (end - start))
        .clamp(0.0, 1.0)
        .toDouble();
    return Curves.easeOutCubic.transform(amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 700;
          final markSize = math.min(
            compact ? 216.0 : 258.0,
            constraints.maxWidth * 0.70,
          ).toDouble();

          return AnimatedBuilder(
            animation: Listenable.merge([introController, ambientController]),
            builder: (context, _) {
              final progress = introController.value;
              final ambient = ambientController.value;
              final logoReveal = _reveal(progress, 0.04, 0.54);
              final titleReveal = _reveal(progress, 0.30, 0.68);
              final taglineReveal = _reveal(progress, 0.48, 0.78);
              final featureReveal = _reveal(progress, 0.64, 0.88);
              final buttonReveal = _reveal(progress, 0.76, 1.0);

              return Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: _SamanvayOpeningCityPainter(
                      progress: progress,
                      ambient: ambient,
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: constraints.maxHeight * .40,
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: .92 * featureReveal,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.asset(
                              'assets/brand/splash_city.jpg',
                              fit: BoxFit.cover,
                              alignment: Alignment.center,
                            ),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    const Color(0xFF061629).withValues(alpha: .04),
                                    const Color(0xFF061629).withValues(alpha: .28),
                                    const Color(0xFF020916).withValues(alpha: .78),
                                  ],
                                  stops: const [0, .55, 1],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // A soft, continuous flag layer remains behind the welcome
                  // content after the opening reveal, like a real flag in the wind.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _WavingFlagPainter(
                          progress: ambient,
                          opacity: .22,
                          ambientBackground: true,
                        ),
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          background.withValues(alpha: 0.10),
                          background.withValues(alpha: 0.02),
                          background.withValues(alpha: 0.32),
                          const Color(0xFF020916).withValues(alpha: 0.78),
                        ],
                        stops: const [0, 0.43, 0.76, 1],
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            25,
                            compact ? 18 : 28,
                            25,
                            compact ? 18 : 26,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const SizedBox(height: 2),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Opacity(
                                    opacity: logoReveal,
                                    child: Transform.translate(
                                      offset: Offset(0, 22 * (1 - logoReveal)),
                                      child: Transform.scale(
                                        scale: 0.70 + (0.30 * logoReveal),
                                        child: SizedBox(
                                          width: markSize,
                                          height: markSize,
                                          child: _SamanvayBrandLogo(
                                            size: markSize,
                                            radius: markSize * .14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: compact ? 8 : 16),
                                  Opacity(
                                    opacity: titleReveal,
                                    child: Transform.translate(
                                      offset: Offset(0, 16 * (1 - titleReveal)),
                                      child: SizedBox(
                                        width: constraints.maxWidth * 0.90,
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            'SAMANVAY',
                                            maxLines: 1,
                                            style: GoogleFonts.spaceGrotesk(
                                              color: const Color(0xFFF5FAFF),
                                              fontSize: 42,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 5.5,
                                              height: 1.0,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Opacity(
                                    opacity: taglineReveal,
                                    child: Column(
                                      children: [
                                        _AnimatedDevelopmentTagline(fontSize: compact ? 13 : 15),
                                        const SizedBox(height: 9),
                                        Container(
                                          width: 116 * taglineReveal,
                                          height: 2,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(8),
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFF25BDF4),
                                                Color(0xFF34E0C2),
                                              ],
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF34E0C2)
                                                    .withValues(alpha: 0.5),
                                                blurRadius: 12,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Opacity(
                                    opacity: featureReveal,
                                    child: Text(
                                      'SMART COORDINATION   •   TRANSPARENT GOVERNANCE   •   A DEVELOPED INDIA',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFFB5C9DD),
                                        fontSize: compact ? 8 : 9,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.15,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: compact ? 15 : 22),
                                  Opacity(
                                    opacity: buttonReveal,
                                    child: Transform.translate(
                                      offset: Offset(0, 12 * (1 - buttonReveal)),
                                      child: SizedBox(
                                        width: 225,
                                        height: 52,
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(30),
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFF13B9F4),
                                                Color(0xFF5365F5),
                                                Color(0xFF843CF4),
                                              ],
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF4478F8)
                                                    .withValues(alpha: 0.30 + 0.16 * math.sin(ambient * math.pi * 2).abs()),
                                                blurRadius: 22,
                                                spreadRadius: 1,
                                              ),
                                            ],
                                          ),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              borderRadius: BorderRadius.circular(30),
                                              onTap: progress >= 0.82 && !isStarting
                                                  ? onGetStarted
                                                  : null,
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    isStarting ? 'CONNECTING SECURE PORTAL' : 'GET STARTED',
                                                    style: GoogleFonts.inter(
                                                      color: Colors.white,
                                                      fontSize: isStarting ? 10 : 13,
                                                      fontWeight: FontWeight.w800,
                                                      letterSpacing: 1.1,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 11),
                                                  AnimatedSwitcher(
                                                    duration: const Duration(milliseconds: 620),
                                                    switchInCurve: Curves.elasticOut,
                                                    switchOutCurve: Curves.easeInCubic,
                                                    transitionBuilder: (child, animation) =>
                                                        ScaleTransition(
                                                      scale: animation,
                                                      child: FadeTransition(opacity: animation, child: child),
                                                    ),
                                                    child: Icon(
                                                      isStarting ? Icons.location_on_rounded : Icons.arrow_forward_rounded,
                                                      key: ValueKey<bool>(isStarting),
                                                      color: Colors.white,
                                                      size: isStarting ? 27 : 19,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (startupError != null) ...[
                                    const SizedBox(height: 10),
                                    Text(
                                      startupError!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Color(0xFFFFB9A9),
                                        fontSize: 10,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 13),
                                  Opacity(
                                    opacity: _reveal(progress, 0.90, 1.0),
                                    child: Text(
                                      'SMART LIVING  •  URBAN INTELLIGENCE',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF7893AA),
                                        fontSize: 8,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1.65,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _SamanvayRoadPipeMarkPainter extends CustomPainter {
  const _SamanvayRoadPipeMarkPainter({
    required this.progress,
    required this.ambient,
  });

  final double progress;
  final double ambient;

  Path _sPath(Size size, double verticalShift) {
    return Path()
      ..moveTo(size.width * 0.79, size.height * 0.17 + verticalShift)
      ..cubicTo(
        size.width * 0.99, size.height * 0.12 + verticalShift,
        size.width * 0.96, size.height * 0.39 + verticalShift,
        size.width * 0.69, size.height * 0.43 + verticalShift,
      )
      ..cubicTo(
        size.width * 0.39, size.height * 0.47 + verticalShift,
        size.width * 0.20, size.height * 0.54 + verticalShift,
        size.width * 0.34, size.height * 0.66 + verticalShift,
      )
      ..cubicTo(
        size.width * 0.47, size.height * 0.79 + verticalShift,
        size.width * 0.76, size.height * 0.70 + verticalShift,
        size.width * 0.72, size.height * 0.83 + verticalShift,
      )
      ..cubicTo(
        size.width * 0.69, size.height * 0.98 + verticalShift,
        size.width * 0.42, size.height * 0.91 + verticalShift,
        size.width * 0.25, size.height * 0.89 + verticalShift,
      );
  }

  Path _drawProgress(Path path, double amount) {
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty || amount <= 0) return Path();
    final metric = metrics.first;
    return metric.extractPath(0, metric.length * amount.clamp(0.0, 1.0).toDouble());
  }

  void _drawPipe(Canvas canvas, Path path, Color color, double width, double amount) {
    final visiblePath = _drawProgress(path, amount);
    if (visiblePath.computeMetrics().isEmpty) return;
    canvas.drawPath(
      visiblePath,
      Paint()
        ..color = background
        ..style = PaintingStyle.stroke
        ..strokeWidth = width + 7
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      visiblePath,
      Paint()
        ..color = color.withValues(alpha: 0.84)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      visiblePath,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.32)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, width * 0.20).toDouble()
        ..strokeCap = StrokeCap.round,
    );
    final metric = path.computeMetrics().first;
    final dot = metric.getTangentForOffset(
      metric.length * ((ambient + 0.12) % 1.0),
    );
    if (dot != null && amount >= 0.96) {
      canvas.drawCircle(
        dot.position,
        width * 0.85,
        Paint()
          ..color = color.withValues(alpha: 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawCircle(dot.position, width * 0.24, Paint()..color = Colors.white);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final centerPath = _sPath(size, 0);
    final cyanPipe = _sPath(size, size.height * 0.055);
    final greenPipe = _sPath(size, -size.height * 0.055);
    final pipeProgress = Curves.easeInOutCubic.transform(
      ((progress - 0.08) / 0.80).clamp(0.0, 1.0),
    );

    final halo = Paint()
      ..color = const Color(0xFF21D9CB).withValues(alpha: 0.10 + 0.08 * math.sin(ambient * math.pi * 2).abs())
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22);
    canvas.drawCircle(
      Offset(size.width * 0.52, size.height * 0.52),
      size.width * 0.43,
      halo,
    );

    _drawPipe(canvas, greenPipe, const Color(0xFF21C783), 7, pipeProgress);
    _drawPipe(canvas, cyanPipe, const Color(0xFF18C9F5), 7, pipeProgress);
    _drawPipe(canvas, centerPath, const Color(0xFFE5A34B), 5, pipeProgress);

    final roadProgress = Curves.easeOutCubic.transform(
      ((progress - 0.02) / 0.66).clamp(0.0, 1.0),
    );
    final road = _drawProgress(centerPath, roadProgress);
    canvas.drawPath(
      road,
      Paint()
        ..color = const Color(0xFF9EABB7).withValues(alpha: 0.96)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.16
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      road,
      Paint()
        ..color = const Color(0xFF263544)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.13
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Animated center markings make the road itself draw in, rather than
    // simply fading a static monogram onto the screen.
    final metrics = centerPath.computeMetrics().toList();
    if (metrics.isNotEmpty && roadProgress > 0.08) {
      final metric = metrics.first;
      final dashPaint = Paint()
        ..color = const Color(0xFFFFD36A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      final travelled = metric.length * roadProgress;
      for (double d = 0; d < travelled; d += 12) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + 5, travelled).toDouble()),
          dashPaint,
        );
      }
    }

    if (progress > 0.35) {
      final pinProgress = Curves.easeOutBack.transform(
        ((progress - 0.35) / 0.35).clamp(0.0, 1.0),
      );
      final pin = Offset(size.width * 0.79, size.height * 0.17);
      canvas.drawCircle(
        pin,
        size.width * 0.055 * pinProgress,
        Paint()
          ..color = const Color(0xFFFF4E69).withValues(alpha: 0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
      canvas.drawCircle(
        pin,
        size.width * 0.034 * pinProgress,
        Paint()..color = const Color(0xFFFF4E69),
      );
      canvas.drawCircle(
        pin,
        size.width * 0.012 * pinProgress,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SamanvayRoadPipeMarkPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.ambient != ambient;
}

class _SamanvayOpeningCityPainter extends CustomPainter {
  const _SamanvayOpeningCityPainter({
    required this.progress,
    required this.ambient,
  });

  final double progress;
  final double ambient;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            background,
            Color(0xFF0B2440),
            Color(0xFF102E49),
            Color(0xFF061626),
          ],
        ).createShader(Offset.zero & size),
    );

    final reveal = Curves.easeOutCubic.transform(progress);
    final horizon = size.height * 0.70;

    // Distant skyline glow.
    canvas.drawCircle(
      Offset(size.width * 0.5, horizon - size.height * 0.02),
      size.width * 0.62,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF1A91AE).withValues(alpha: 0.19 * reveal),
            const Color(0xFF163D5C).withValues(alpha: 0.08 * reveal),
            background.withValues(alpha: 0),
          ],
        ).createShader(
          Rect.fromCircle(
            center: Offset(size.width * 0.5, horizon - size.height * 0.02),
            radius: size.width * 0.62,
          ),
        ),
    );

    // City skyline with animated windows.
    const buildings = <List<double>>[
      [0.00, 0.15, 0.18], [0.11, 0.10, 0.23], [0.20, 0.12, 0.34],
      [0.32, 0.09, 0.27], [0.41, 0.10, 0.42], [0.53, 0.12, 0.31],
      [0.65, 0.08, 0.46], [0.74, 0.12, 0.29], [0.86, 0.10, 0.36],
      [0.95, 0.12, 0.22],
    ];
    for (int i = 0; i < buildings.length; i++) {
      final building = buildings[i];
      final x = size.width * building[0];
      final width = size.width * building[1];
      final height = size.height * building[2] * reveal;
      final top = horizon - height;
      final rect = Rect.fromLTWH(x, top, width, height);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        Paint()
          ..shader = LinearGradient(
            colors: [
              const Color(0xFF213F5B),
              const Color(0xFF0C1F35),
            ],
          ).createShader(rect),
      );
      canvas.drawRect(
        Rect.fromLTWH(x, top, width, 2),
        Paint()..color = const Color(0xFF53CDE4).withValues(alpha: 0.42 * reveal),
      );
      final columns = math.max(2, (width / 9).floor());
      final rows = math.max(2, (height / 15).floor());
      for (int row = 0; row < rows; row++) {
        for (int column = 0; column < columns; column++) {
          final seed = (i * 17 + row * 7 + column * 11) % 9;
          final lit = ((seed / 9) < (0.30 + 0.10 * math.sin(ambient * math.pi * 2 + i).abs()));
          final window = Rect.fromLTWH(
            x + 4 + column * (width - 8) / columns,
            top + 7 + row * 13,
            math.max(1.8, width / columns * 0.28).toDouble(),
            3.2,
          );
          canvas.drawRect(
            window,
            Paint()
              ..color = (lit
                      ? const Color(0xFF76E7E6)
                      : const Color(0xFF49627A))
                  .withValues(alpha: (lit ? 0.56 : 0.14) * reveal),
          );
        }
      }
    }

    // Rooftop antennas and a few lit towers.
    final antennaPaint = Paint()
      ..color = const Color(0xFF58B9D4).withValues(alpha: 0.54 * reveal)
      ..strokeWidth = 1.3;
    for (final x in [0.25, 0.46, 0.69, 0.88]) {
      final px = size.width * x;
      final ph = size.height * (0.30 + x * 0.08);
      canvas.drawLine(
        Offset(px, horizon - ph),
        Offset(px, horizon - ph - 11 * reveal),
        antennaPaint,
      );
      canvas.drawCircle(
        Offset(px, horizon - ph - 12 * reveal),
        2.1,
        Paint()
          ..color = const Color(0xFF41D9E5)
              .withValues(alpha: 0.40 + 0.44 * math.sin(ambient * math.pi * 2).abs())
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    // Road surface across the city.
    final roadTop = horizon - size.height * 0.015;
    final roadBottom = horizon + size.height * 0.11;
    final road = Path()
      ..moveTo(size.width * 0.38, roadTop)
      ..lineTo(size.width * 0.62, roadTop)
      ..lineTo(size.width * 0.95, roadBottom)
      ..lineTo(size.width * 0.05, roadBottom)
      ..close();
    canvas.drawPath(
      road,
      Paint()..color = const Color(0xFF182A3B).withValues(alpha: 0.92 * reveal),
    );
    final roadLine = Paint()
      ..color = const Color(0xFF77CDE0).withValues(alpha: 0.55 * reveal)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(size.width * 0.38, roadTop),
      Offset(size.width * 0.05, roadBottom),
      roadLine,
    );
    canvas.drawLine(
      Offset(size.width * 0.62, roadTop),
      Offset(size.width * 0.95, roadBottom),
      roadLine,
    );
    for (int i = 0; i < 7; i++) {
      final y = roadTop + (roadBottom - roadTop) * (i + 1) / 8;
      final half = size.width * (0.015 + (i / 7) * 0.06);
      canvas.drawLine(
        Offset(size.width * 0.5 - half, y),
        Offset(size.width * 0.5 + half, y),
        Paint()
          ..color = const Color(0xFFFFC867).withValues(alpha: 0.7 * reveal)
          ..strokeWidth = 1.5,
      );
    }

    // Exposed ground cross-section: the underground system is visible below
    // the street, matching the central SAMANVAY product idea.
    final groundTop = horizon + size.height * 0.11;
    final groundPath = Path()
      ..moveTo(0, groundTop)
      ..lineTo(size.width, groundTop)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      groundPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF213D50),
            Color(0xFF112A3C),
            Color(0xFF081B2B),
          ],
        ).createShader(Rect.fromLTWH(0, groundTop, size.width, size.height - groundTop)),
    );
    for (int layer = 0; layer < 4; layer++) {
      final y = groundTop + size.height * (0.035 + layer * 0.055);
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = const Color(0xFF8AA0AE).withValues(alpha: 0.13 * reveal)
          ..strokeWidth = 1,
      );
    }

    void drawNetwork(Color color, double y, double phase) {
      final path = Path()
        ..moveTo(-size.width * 0.06, y)
        ..cubicTo(
          size.width * 0.20,
          y - size.height * 0.035,
          size.width * 0.34,
          y + size.height * 0.026,
          size.width * 0.53,
          y - size.height * 0.002,
        )
        ..cubicTo(
          size.width * 0.72,
          y - size.height * 0.028,
          size.width * 0.84,
          y + size.height * 0.036,
          size.width * 1.06,
          y + size.height * 0.004,
        );
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF03101C)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.91 * reveal)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );
      final metric = path.computeMetrics().first;
      for (int i = 0; i < 3; i++) {
        final offset = ((ambient + phase + i / 3) % 1.0) * metric.length;
        final tangent = metric.getTangentForOffset(offset);
        if (tangent != null) {
          canvas.drawCircle(
            tangent.position,
            2.5,
            Paint()
              ..color = color.withValues(alpha: 0.26 * reveal)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
          );
          canvas.drawCircle(
            tangent.position,
            1.1,
            Paint()..color = Colors.white.withValues(alpha: 0.92 * reveal),
          );
        }
      }
    }

    drawNetwork(const Color(0xFF23C8F2), groundTop + size.height * 0.055, 0.0);
    drawNetwork(const Color(0xFFF4A64D), groundTop + size.height * 0.12, 0.33);
    drawNetwork(const Color(0xFF29D28B), groundTop + size.height * 0.185, 0.66);

    // Small city/utility connection markers.
    for (int i = 0; i < 7; i++) {
      final x = size.width * (0.08 + i * 0.14);
      final y = groundTop + size.height * (0.04 + (i % 3) * 0.055);
      canvas.drawCircle(
        Offset(x, y),
        3.2,
        Paint()
          ..color = const Color(0xFF5BE9D5).withValues(alpha: 0.22 * reveal)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(
        Offset(x, y),
        1.4,
        Paint()..color = const Color(0xFFA4FFF0).withValues(alpha: 0.86 * reveal),
      );
    }

    // Floating city lights.
    for (int i = 0; i < 24; i++) {
      final x = size.width * ((i * 0.173 + 0.07) % 1.0);
      final y = size.height * (0.12 + ((i * 0.117) % 0.47));
      final pulse = 0.25 + 0.55 * math.sin((ambient + i * 0.09) * math.pi * 2).abs();
      canvas.drawCircle(
        Offset(x, y),
        1.1 + pulse,
        Paint()..color = const Color(0xFF8AE9F3).withValues(alpha: pulse * 0.30 * reveal),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SamanvayOpeningCityPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.ambient != ambient;
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

class RoleGate extends StatefulWidget {
  const RoleGate({super.key});

  @override
  State<RoleGate> createState() => _RoleGateState();
}

class _RoleGateState extends State<RoleGate> {
  late Future<Map<String, dynamic>> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }

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
      throw StateError('Profile not found for this authenticated user. Contact an administrator.');
    }

    return Map<String, dynamic>.from(row);
  }

  void _retryProfileLoad() {
    setState(() {
      _profileFuture = _loadProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return _PortalError(
            message: snapshot.error.toString(),
            onRetry: _retryProfileLoad,
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
                message: 'No department is assigned to this account. Contact an administrator.',
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
  final VoidCallback? onRetry;

  const _PortalError({required this.message, this.onRetry});

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
              if (onRetry != null) ...[
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('RETRY PROFILE CHECK'),
                ),
                const SizedBox(height: 8),
              ],
              OutlinedButton.icon(
                onPressed: () async {
                  await supabase.auth.signOut();
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('LOG OUT'),
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

  final GlobalKey _overviewAnchor = GlobalKey(debugLabel: 'ops-overview');
  final GlobalKey _analyticsAnchor = GlobalKey(debugLabel: 'ops-analytics');
  final GlobalKey _publicWorksAnchor = GlobalKey(debugLabel: 'ops-public-works');
  final GlobalKey _coordinationAnchor = GlobalKey(debugLabel: 'ops-coordination');
  final GlobalKey _roadworksAnchor = GlobalKey(debugLabel: 'ops-roadworks');
  final GlobalKey _nationalAnchor = GlobalKey(debugLabel: 'ops-national-coverage');
  final GlobalKey _groundwaterAnchor = GlobalKey(debugLabel: 'ops-groundwater');
  final GlobalKey _requestsAnchor = GlobalKey(debugLabel: 'ops-case-register');

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
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _jumpToSection(String section) {
    final anchor = switch (section) {
      'analytics' => _analyticsAnchor,
      'public-works' || 'clearance' => _publicWorksAnchor,
      'coordination' => _coordinationAnchor,
      'roadworks' => _roadworksAnchor,
      'national' => _nationalAnchor,
      'groundwater' => _groundwaterAnchor,
      'cases' => _requestsAnchor,
      _ => _overviewAnchor,
    };
    final target = anchor.currentContext;
    if (target == null) {
      notify('That section is not currently available.');
      return;
    }
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
      alignment: 0.04,
    );
  }

  void _selectPortalTab(String section) {
    if (section == 'clash') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ClashVisualizerPage(candidates: _repeatedWorkCandidates()),
        ),
      );
      return;
    }
    if (section == 'gis') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const MapPage()),
      );
      return;
    }
    if (section == 'audit') {
      if (!widget.isAdmin) {
        notify('Audit logs are restricted to administrator accounts.');
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AdminManagementPage()),
      );
      return;
    }
    _jumpToSection(section);
  }

  Widget _sectionChip(String label, IconData icon, String section) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: OutlinedButton.icon(
        onPressed: () => _selectPortalTab(section),
        icon: Icon(icon, size: 15),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: _usesLegacyLightPalette ? teal : const Color(0xFFB5F2E7),
          side: BorderSide(color: _usesLegacyLightPalette ? teal.withValues(alpha: .55) : const Color(0x6647BDB3)),
          backgroundColor: panelNavy,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        ),
      ),
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

        // Include cases assigned directly to this department, not only review rows.
        final directRows = await supabase
            .from('excavation_requests')
            .select()
            .eq('department_id', widget.departmentId!)
            .order('created_at', ascending: false)
            .limit(200);
        final mergedRequests = <String, Map<String, dynamic>>{};
        for (final request in loadedRequests) {
          mergedRequests[request['id'].toString()] = request;
        }
        for (final request in List<Map<String, dynamic>>.from(directRows)) {
          mergedRequests[request['id'].toString()] = request;
        }
        loadedRequests = mergedRequests.values.toList()
          ..sort((a, b) => (b['created_at'] ?? '').toString()
              .compareTo((a['created_at'] ?? '').toString()));

        final rawDepartments = await supabase
            .from('departments')
            .select('id,name')
            .eq('id', widget.departmentId!);
        loadedDepartments = List<Map<String, dynamic>>.from(rawDepartments);
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

  double _distanceMetres(Map<String, dynamic> a, Map<String, dynamic> b) {
    final lat1 = (a['latitude'] as num).toDouble() * math.pi / 180;
    final lat2 = (b['latitude'] as num).toDouble() * math.pi / 180;
    final dLat = lat2 - lat1;
    final dLon = ((b['longitude'] as num).toDouble() -
        (a['longitude'] as num).toDouble()) * math.pi / 180;
    final h = math.pow(math.sin(dLat / 2), 2) +
        math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLon / 2), 2);
    return 6371000 * 2 * math.asin(math.sqrt(h));
  }

  List<Map<String, dynamic>> _repeatedWorkCandidates() {
    final candidates = <Map<String, dynamic>>[];
    for (var i = 0; i < requests.length; i++) {
      final a = requests[i];
      if (a['latitude'] is! num || a['longitude'] is! num) continue;
      final aStart = DateTime.tryParse((a['planned_start_date'] ?? '').toString());
      final aEnd = DateTime.tryParse((a['planned_end_date'] ?? '').toString());
      if (aStart == null || aEnd == null) continue;

      for (var j = i + 1; j < requests.length; j++) {
        final b = requests[j];
        if (b['latitude'] is! num || b['longitude'] is! num) continue;
        final bStart = DateTime.tryParse((b['planned_start_date'] ?? '').toString());
        final bEnd = DateTime.tryParse((b['planned_end_date'] ?? '').toString());
        if (bStart == null || bEnd == null) continue;
        if (valueOf(a, 'id') == valueOf(b, 'id')) continue;

        final categoryA = valueOf(a, 'case_category', fallback: '');
        final categoryB = valueOf(b, 'case_category', fallback: '');
        if (categoryA == categoryB) continue;

        final distance = _distanceMetres(a, b);
        final datesOverlap = !aStart.isAfter(bEnd) && !bStart.isAfter(aEnd);
        if (distance <= 100 && datesOverlap) {
          candidates.add({
            'first': a,
            'second': b,
            'distance': distance,
            'start': aStart.isAfter(bStart) ? aStart : bStart,
            'end': aEnd.isBefore(bEnd) ? aEnd : bEnd,
          });
        }
      }
    }
    candidates.sort((a, b) =>
        (a['distance'] as double).compareTo(b['distance'] as double));
    return candidates;
  }

  Widget repeatedWorkCoordinationPanel() {
    final candidates = _repeatedWorkCandidates();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.alt_route, color: teal),
              const SizedBox(width: 9),
               Expanded(child: Text('Potential clash screening & joint-work opportunities',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: ink))),
              Chip(label: Text('${candidates.length}')),
            ]),
            const SizedBox(height: 5),
             Text(
              'Rule-based advisory: different infrastructure domains within 100 m with overlapping planned dates. This is not a verified underground-utility intersection map; review every match before coordinating.',
              style: TextStyle(fontSize: 11, color: mutedInk),
            ),
            const SizedBox(height: 10),
            if (candidates.isEmpty)
               Text(
                'No qualifying matches in the currently loaded records. Cases without coordinates or planned dates are not assessed.',
                style: TextStyle(fontSize: 12, color: mutedInk),
              )
            else
              ...candidates.take(5).map((match) {
                final first = match['first'] as Map<String, dynamic>;
                final second = match['second'] as Map<String, dynamic>;
                final metres = (match['distance'] as double).round();
                final start = (match['start'] as DateTime);
                final end = (match['end'] as DateTime);
                String label(Map<String, dynamic> row) =>
                    (row['title'] ?? row['case_category'] ?? 'Infrastructure case').toString();
                return Container(
                  margin: const EdgeInsets.only(top: 9),
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: panelNavy,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${label(first)}  ↔  ${label(second)}',
                      style:  TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ink)),
                    const SizedBox(height: 4),
                    Text('$metres m apart · overlapping dates: ${start.day.toString().padLeft(2, '0')}/${start.month.toString().padLeft(2, '0')}/${start.year}–${end.day.toString().padLeft(2, '0')}/${end.month.toString().padLeft(2, '0')}/${end.year}',
                      style:  TextStyle(fontSize: 10, color: mutedInk)),
                    Text('Suggested action: coordinator review for possible joint execution.',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: teal)),
                  ]),
                );
              }),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MapPage()),
                ),
                icon: const Icon(Icons.map_outlined, size: 16),
                label: const Text('Open GIS mapping workspace'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget departmentCoordinationPanel() {
    final allReviews = reviewsByRequest.values.expand((rows) => rows).toList();
    final jointCases = requests.where((request) {
      final id = request['id'].toString();
      final assigned = (reviewsByRequest[id] ?? [])
          .map((review) => review['department_id'].toString())
          .toSet();
      return assigned.length >= 2;
    }).length;

    final workload = departments.map((department) {
      final id = department['id'].toString();
      return <String, dynamic>{
        'name': department['name'].toString(),
        'count': allReviews.where((review) =>
          review['department_id']?.toString() == id).length,
      };
    }).toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    final maxCount = workload.isEmpty
        ? 0
        : workload.map((item) => item['count'] as int).reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.hub_outlined, color: Color(0xFF20B7A4)),
              const SizedBox(width: 9),
               Expanded(child: Text('Department coordination & activity',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: ink))),
              Chip(label: Text('${departments.length}')),
            ]),
            const SizedBox(height: 5),
            Text(
              '$jointCases case(s) have review assignments from at least two departments.',
              style:  TextStyle(fontSize: 11, color: mutedInk),
            ),
            const SizedBox(height: 13),
            if (workload.isEmpty)
               Text(
                'No department directory records are available in this account view yet.',
                style: TextStyle(fontSize: 12, color: mutedInk),
              )
            else
              ...workload.take(6).map((item) {
                final count = item['count'] as int;
                final ratio = maxCount == 0 ? 0.0 : count / maxCount;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(child: Text(item['name'].toString(),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                        Text('$count reviews',
                          style:  TextStyle(fontSize: 10, color: mutedInk)),
                      ]),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 7,
                          backgroundColor: const Color(0xFF1C354A),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF20B7A4)),
                        ),
                      ),
                    ],
                  ),
                );
              }),
             Text(
              'Bars compare review counts within the currently loaded records; they are not performance ratings.',
              style: TextStyle(fontSize: 10, color: mutedInk, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }

  Widget dashboardAnalysisRow() {
    return LayoutBuilder(builder: (context, constraints) {
      const gap = 12.0;
      final columns = constraints.maxWidth >= 980 ? 2 : 1;
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          SizedBox(width: width, child: repeatedWorkCoordinationPanel()),
          SizedBox(width: width, child: departmentCoordinationPanel()),
        ],
      );
    });
  }

  Widget clearanceWorkflowPanel() {
    const steps = [
      ('01', 'Register assets', 'Attach survey and ownership evidence'),
      ('02', 'Submit request', 'Create a location-linked infrastructure case'),
      ('03', 'Spatial screening', 'Review nearby work and available records'),
      ('04', 'Decision / approval', 'Authorised department action'),
      ('05', 'GIS reconciliation', 'Update only against verified evidence'),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.route_outlined, color: Color(0xFF20B7A4)),
              const SizedBox(width: 9),
               Expanded(child: Text('Clearance request workflow',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: ink))),
              const Text('5 STEPS',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF20B7A4))),
            ]),
            const SizedBox(height: 5),
             Text(
              'Reference lifecycle. A step is complete only when the corresponding case, approval or verified GIS record exists.',
              style: TextStyle(fontSize: 11, color: mutedInk, height: 1.35),
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var index = 0; index < steps.length; index++) ...[
                    Container(
                      width: 158,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: panelNavy,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 28, height: 28,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: Color(0x2231C7B0), shape: BoxShape.circle),
                            child: Text(steps[index].$1,
                              style: const TextStyle(fontSize: 10,
                                fontWeight: FontWeight.w900, color: Color(0xFF73E2D2))),
                          ),
                          const SizedBox(height: 9),
                          Text(steps[index].$2,
                            style: const TextStyle(fontSize: 11,
                              fontWeight: FontWeight.w800, color: Colors.white)),
                          const SizedBox(height: 5),
                          Text(steps[index].$3,
                            style: TextStyle(fontSize: 10,
                              color: mutedInk, height: 1.35)),
                        ],
                      ),
                    ),
                    if (index < steps.length - 1)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 5),
                        child: Icon(Icons.arrow_forward_ios_rounded,
                          size: 13, color: Color(0xFF66869B)),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
             Text('Cases by infrastructure domain',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: ink)),
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
          color: panelNavy,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: borderColor),
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
                  Text(title.toUpperCase(), style:  TextStyle(
                    color: mutedInk, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.65)),
                  const SizedBox(height: 7),
                  Text(value, style: GoogleFonts.robotoMono(
                    color: ink, fontSize: value.length > 11 ? 14 : 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  Text(note, style:  TextStyle(color: mutedInk, fontSize: 10, height: 1.35)),
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
        const Text('Live operations metrics',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 4),
        Text('Counts are calculated from records visible to the signed-in role.',
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
                  title: 'Active projects / cases', value: activeCases.toString(),
                  note: 'Approved or currently in progress',
                  icon: Icons.engineering_outlined, accent: const Color(0xFF20B7A4), width: cardWidth),
                _executiveMetricCard(
                  title: 'Pending clearances', value: pendingResponses.toString(),
                  note: 'Pending or under department review',
                  icon: Icons.hourglass_top_rounded, accent: const Color(0xFFD9A441), width: cardWidth),
                _executiveMetricCard(
                  title: 'Joint-work cases', value: multiDepartmentCases.toString(),
                  note: 'Two or more departments assigned',
                  icon: Icons.account_tree_outlined, accent: const Color(0xFF56A6E8), width: cardWidth),
                _executiveMetricCard(
                  title: 'Clashes flagged', value: conflictRequestIds.length.toString(),
                  note: 'Recorded case or review status flags',
                  icon: Icons.warning_amber_rounded, accent: const Color(0xFFE47E63), width: cardWidth),
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

  Widget metric(String label, int value, IconData icon, {required double width}) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: cyanAccent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: cyanAccent, size: 20),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value.toString(),
                      style:  TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                    Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:  TextStyle(fontSize: 10, color: mutedInk),
                    ),
                  ],
                ),
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
                       Text('No routing suggestions are configured. Use manual assignment.',
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
                            color: isPrimary ? teal : mutedInk,
                          ),
                          title: Text(department['name'].toString(),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          subtitle: Text(isPrimary ? 'Primary suggested department' : 'Supporting department',
                            style: const TextStyle(fontSize: 10)),
                          trailing: selectedDepartment == departmentId
                              ? Icon(Icons.check_circle, color: teal)
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
            color: mutedInk,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style:  TextStyle(
                fontSize: 12,
                color: mutedInk,
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
                    style:  TextStyle(
                      fontWeight: FontWeight.bold,
                      color: ink,
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
      backgroundColor: background,
      appBar: AppBar(
        toolbarHeight: 72,
        backgroundColor: navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SAMANVAY',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
            Text('INTEGRATED INFRASTRUCTURE CLEARANCE PORTAL',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700,
                letterSpacing: 0.65, color: Color(0xFF9DB6C8))),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0x2230C6A7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0x6649CDB8)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.circle, size: 7, color: Color(0xFF50D5A5)),
                  SizedBox(width: 6),
                  Text('LIVE', style: TextStyle(fontSize: 9,
                    fontWeight: FontWeight.w900, color: Color(0xFFB9F3DC))),
                ]),
              ),
            ),
          ),
          IconButton(
            tooltip: 'My profile',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfilePage()),
            ),
            icon: const Icon(Icons.person_outline_rounded),
          ),
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1540),
            child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(18),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _usesLegacyLightPalette
                      ? [const Color(0xFFE5F4F1), const Color(0xFFF4F7FA), Colors.white]
                      : [navy, const Color(0xFF11485A), const Color(0xFF0B5E62)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0x4438B6AA)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0x2238C7B0),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: const Color(0x664ED1BF)),
                      ),
                      child: Icon(widget.icon, color: _usesLegacyLightPalette ? teal : const Color(0xFFB9F3E8), size: 25),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SAMANVAY',
                          style: TextStyle(color: _usesLegacyLightPalette ? navy : Colors.white, fontSize: 20,
                            fontWeight: FontWeight.w900, letterSpacing: 1.15)),
                        SizedBox(height: 3),
                        Text('INTEGRATED INFRASTRUCTURE CLEARANCE PORTAL',
                          style: TextStyle(color: _usesLegacyLightPalette ? mutedInk : const Color(0xFFB4D1DB), fontSize: 8,
                            fontWeight: FontWeight.w800, letterSpacing: 0.7)),
                      ],
                    )),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0x2230C6A7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0x6649CDB8)),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.circle, size: 7, color: Color(0xFF50D5A5)),
                        SizedBox(width: 6),
                        Text('LIVE', style: TextStyle(fontSize: 9,
                          fontWeight: FontWeight.w900, color: Color(0xFFB9F3DC))),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 15),
                  Text(
                    widget.title,
                    style: TextStyle(color: _usesLegacyLightPalette ? navy : Colors.white, fontSize: 22,
                      fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text('Welcome, $displayName',
                    style: TextStyle(color: _usesLegacyLightPalette ? mutedInk : const Color(0xFFD0E3E8), fontSize: 12)),
                  const SizedBox(height: 8),
                  Text(widget.subtitle,
                    style: TextStyle(color: mutedInk, fontSize: 11, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'WORKSPACE QUICK NAVIGATION',
              style: TextStyle(
                color: cyanAccent,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _sectionChip('Overview', Icons.dashboard_outlined, 'overview'),
                  _sectionChip('Analytics', Icons.query_stats_outlined, 'analytics'),
                  _sectionChip('Clearance Gateway', Icons.fact_check_outlined, 'clearance'),
                  _sectionChip('Clash Checks', Icons.warning_amber_rounded, 'clash'),
                  _sectionChip('GIS Mapping', Icons.map_outlined, 'gis'),
                  if (widget.isAdmin)
                    _sectionChip('Audit Logs', Icons.history_rounded, 'audit')
                  else
                    _sectionChip('Case Register', Icons.assignment_outlined, 'cases'),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(key: _overviewAnchor, height: 1),
            SizedBox(key: _analyticsAnchor, height: 1),
            executiveSnapshot(),
            const SizedBox(height: 14),
            dashboardAnalysisRow(),
            const SizedBox(height: 14),
            clearanceWorkflowPanel(),
            const SizedBox(height: 14),
            domainBreakdown(),
            const SizedBox(height: 14),
            SizedBox(key: _publicWorksAnchor, height: 1),
            PublicWorksOperationsBoard(
              departments: departments,
              isDepartment: widget.isDepartment,
              departmentId: widget.departmentId,
            ),
            const SizedBox(height: 14),
            SizedBox(key: _coordinationAnchor, height: 1),
            CommandCentreActivityBoard(isAdmin: widget.isAdmin),
            const SizedBox(height: 7),
            Text(
              'Live metrics reflect records visible to this role and the current query window. They are not national totals.',
              style: TextStyle(color: mutedInk, fontSize: 10, height: 1.35),
            ),
            const SizedBox(height: 16),
            SizedBox(key: _roadworksAnchor, height: 1),
            RoadCutPermitBoard(
              requests: requests,
              departments: departments,
              isDepartment: widget.isDepartment,
              departmentId: widget.departmentId,
            ),
            const SizedBox(height: 16),
            RoadWorkScheduleBoard(),
            const SizedBox(height: 16),
            RoadRestorationBoard(
              requests: requests,
              departments: departments,
              isDepartment: widget.isDepartment,
              departmentId: widget.departmentId,
            ),
            const SizedBox(height: 16),
            DrainageInspectionBoard(
              requests: requests,
              departments: departments,
              isDepartment: widget.isDepartment,
              departmentId: widget.departmentId,
            ),
            const SizedBox(height: 16),
            BuildingComplianceInspectionBoard(
              requests: requests,
              departments: departments,
              isDepartment: widget.isDepartment,
              departmentId: widget.departmentId,
            ),
            const SizedBox(height: 16),
            SizedBox(key: _nationalAnchor, height: 1),
            const NationalDataCoverageBoard(),
            const SizedBox(height: 16),
            const BuildingApprovalRegisterBoard(),
            const SizedBox(height: 16),
            SizedBox(key: _groundwaterAnchor, height: 1),
            const GroundwaterTelemetryDashboard(),
            const SizedBox(height: 16),
            GroundwaterObservationBoard(
              requests: requests,
              departments: departments,
              isDepartment: widget.isDepartment,
              departmentId: widget.departmentId,
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SamanvayAiAssistantPage()),
                ),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('OPEN SAMANVAY AI ASSISTANT'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF347FF2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
            const SizedBox(height: 10),
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
            if (widget.isDepartment) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const UtilityAssetEvidenceSubmissionPage()),
                  ),
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('SUBMIT SURVEY EVIDENCE'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0B5B67),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
            ],
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
            SizedBox(key: _requestsAnchor, height: 1),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Infrastructure requests',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: ink,
                    ),
                  ),
                ),
                Text(
                  '${requests.length} records',
                  style: TextStyle(
                    color: mutedInk,
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
               Card(
                child: Padding(
                  padding: EdgeInsets.all(22),
                  child: Column(
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 40,
                        color: mutedInk,
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
             Card(
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
  String message = '';
  bool messageIsSuccess = false;
  String? demoPreviewRole;
  String? demoPreviewStaffId;

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
      final rawIdentifier = _emailController.text.trim();
      final identifier = _existingTestAccountAliases[
            rawIdentifier.toLowerCase()] ??
          rawIdentifier;

      if (isLogin) {
        if (identifier.contains('@')) {
          await supabase.auth.signInWithPassword(
            email: identifier,
            password: _passwordController.text,
          );
        } else {
          final phone = _normalisePhoneForAuth(identifier);
          if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phone)) {
            throw const AuthException(
              'Enter a valid email address or mobile number with country code.',
            );
          }
          await supabase.auth.signInWithPassword(
            phone: phone,
            password: _passwordController.text,
          );
        }
        showMessage('Login successful.', success: true);
      } else {
        if (!identifier.contains('@') || !identifier.contains('.')) {
          throw const AuthException(
            'New account registration currently requires an email address.',
          );
        }
        final response = await supabase.auth.signUp(
          email: identifier,
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
        'Unexpected request error (' + error.runtimeType.toString() + '). ' +
        error.toString(),
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  void openStaffDemoPreview({String? selectedRole}) {
    final enteredStaffId = _emailController.text.trim();
    final role = selectedRole ?? _readOnlyStaffPreviewRoles[enteredStaffId];
    if (role == null) {
      showMessage('Choose Department Officer, Coordinator or Administrator to open a public demo workspace.');
      return;
    }
    final staffId = selectedRole == null
        ? enteredStaffId
        : switch (role) {
            'admin' => 'PUBLIC-ADMIN-DEMO',
            'coordinator' => 'PUBLIC-COORDINATOR-DEMO',
            'department' => 'PUBLIC-OFFICER-DEMO',
            _ => 'PUBLIC-STAFF-DEMO',
          };
    setState(() {
      demoPreviewRole = role;
      demoPreviewStaffId = staffId;
      message = '';
      messageIsSuccess = false;
    });
  }

  Future<void> requestLoginPasswordReset() async {
    final rawIdentifier = _emailController.text.trim();
    final email = _existingTestAccountAliases[rawIdentifier.toLowerCase()] ??
        rawIdentifier;
    if (!email.contains('@') || !email.contains('.')) {
      showMessage('Enter a registered email address or one of the staff IDs shown by your administrator.');
      return;
    }
    setState(() { loading = true; message = ''; messageIsSuccess = false; });
    try {
      await supabase.auth.resetPasswordForEmail(email, redirectTo: redirectUrl);
      showMessage('Password reset instructions requested. Check the registered email inbox.', success: true);
    } on AuthException catch (error) {
      showMessage(error.message);
    } catch (_) {
      showMessage('Unable to request a password reset. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // Resend the confirmation email to an existing
  // unconfirmed Supabase signup.

  Future<void> resendConfirmationEmail() async {
    final rawIdentifier = _emailController.text.trim();
    final email = _existingTestAccountAliases[rawIdentifier.toLowerCase()] ?? rawIdentifier;

    if (!email.contains('@') || !email.contains('.')) {
      showMessage(
        'Enter your registered email address or a listed staff ID first.',
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
    if (demoPreviewRole != null) {
      return _StaffDemoPreview(
        role: demoPreviewRole!,
        staffId: demoPreviewStaffId ?? '',
        onExit: () {
          setState(() {
            demoPreviewRole = null;
            demoPreviewStaffId = null;
            _passwordController.clear();
          });
        },
      );
    }
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/brand/splash_city.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xD9071425),
                      Color(0xC6071425),
                      Color(0xF0071425),
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: panelNavy,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF24445F)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 28,
                      offset: Offset(0, 14),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 104,
                    height: 104,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A1B36),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: cyanAccent.withValues(alpha: .55),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: cyanAccent.withValues(alpha: .18),
                          blurRadius: 26,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const _SamanvayBrandLogo(size: 102, radius: 27),
                  ),

                  const SizedBox(height: 14),

                  Text(
                    'SAMANVAY',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: ink,
                      letterSpacing: 2.2,
                    ),
                  ),

                  const SizedBox(height: 5),

                  const _AnimatedDevelopmentTagline(fontSize: 10),

                  const SizedBox(height: 8),

                  Text(
                    'National Infrastructure Coordination Platform',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: mutedInk,
                      fontSize: 12,
                    ),
                  ),

                  const SizedBox(height: 36),

                  Text(
                    isLogin
                        ? 'Welcome back'
                        : 'Create your account',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: ink,
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
                  Text(
                    'PORTAL ACCESS',
                    style: TextStyle(color: cyanAccent, fontSize: 10, letterSpacing: 1.1, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  LayoutBuilder(builder: (context, constraints) {
                    final twoColumns = constraints.maxWidth >= 600;
                    final cardWidth = twoColumns ? (constraints.maxWidth - 9) / 2 : constraints.maxWidth;
                    Widget roleCard(
                      String title,
                      String detail,
                      IconData icon,
                      bool standard, {
                      String? demoRole,
                    }) {
                      final canOpenDemo = demoRole != null;
                      return SizedBox(
                        width: cardWidth,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: canOpenDemo
                                ? () => openStaffDemoPreview(selectedRole: demoRole)
                                : null,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(13),
                              decoration: BoxDecoration(
                                color: _usesLegacyLightPalette
                                    ? (standard ? const Color(0xFFE5F4F1) : Colors.white)
                                    : null,
                                gradient: _usesLegacyLightPalette
                                    ? null
                                    : LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: standard
                                            ? const [Color(0xFF1353A5), Color(0xFF4236A6)]
                                            : canOpenDemo
                                                ? const [Color(0xFF174A60), Color(0xFF233A61)]
                                                : const [Color(0xFF152944), Color(0xFF1B2946)],
                                      ),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: canOpenDemo
                                      ? cyanAccent.withValues(alpha: .72)
                                      : (standard
                                          ? cyanAccent.withValues(alpha: .65)
                                          : borderColor),
                                ),
                                boxShadow: _usesLegacyLightPalette
                                    ? const []
                                    : [
                                        BoxShadow(
                                          color: (standard ? const Color(0xFF2869F5) : cyanAccent)
                                              .withValues(alpha: standard ? .20 : .08),
                                          blurRadius: 16,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                              ),
                              child: Row(children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: (standard || canOpenDemo
                                            ? cyanAccent
                                            : const Color(0xFF9FB2C9))
                                        .withValues(alpha: .15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    icon,
                                    color: standard || canOpenDemo
                                        ? cyanAccent
                                        : const Color(0xFFB5C8D8),
                                    size: 21,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: TextStyle(
                                          color: ink,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        canOpenDemo
                                            ? 'Open official demonstration portal'
                                            : detail,
                                        style: TextStyle(
                                          color: mutedInk,
                                          fontSize: 9,
                                          height: 1.25,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  canOpenDemo
                                      ? Icons.open_in_new_rounded
                                      : (standard
                                          ? Icons.check_circle
                                          : Icons.chevron_right_rounded),
                                  color: canOpenDemo || standard
                                      ? cyanAccent
                                      : const Color(0xFF849BB0),
                                  size: 16,
                                ),
                              ]),
                            ),
                          ),
                        ),
                      );
                    }
                    return Wrap(spacing: 9, runSpacing: 9, children: [
                      roleCard(
                        'Citizen',
                        'Public services and request tracking',
                        Icons.person_outline,
                        true,
                      ),
                      roleCard(
                        'Department officer',
                        'Department workspace',
                        Icons.account_balance_outlined,
                        false,
                        demoRole: 'department',
                      ),
                      roleCard(
                        'Coordinator',
                        'Coordination workspace',
                        Icons.hub_outlined,
                        false,
                        demoRole: 'coordinator',
                      ),
                      roleCard(
                        'Administrator',
                        'Administration workspace',
                        Icons.admin_panel_settings_outlined,
                        false,
                        demoRole: 'admin',
                      ),
                    ]);
                  }),
                  const SizedBox(height: 8),
                  Text(
                    'Tap an official role to open its interactive demonstration portal. Sample case updates and assignments are simulated locally; live records and protected actions still require an authorised account.',
                    style: TextStyle(fontSize: 10, color: mutedInk, height: 1.35),
                  ),
                  const SizedBox(height: 16),
                                    const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: isLogin
                        ? TextInputType.text
                        : TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: isLogin ? 'Email, mobile number or staff ID' : 'Email address',
                      hintText: isLogin ? 'name@example.com, 9876543210 or 9013' : 'name@example.com',
                      prefixIcon: Icon(isLogin ? Icons.alternate_email_rounded : Icons.email_outlined),
                      border: const OutlineInputBorder(),
                      helperText: isLogin
                          ? 'Use your registered credentials for live access, or tap an official role above to open its interactive demonstration portal.'
                          : null,
                      helperMaxLines: 2,
                    ),
                    validator: (value) {
                      final input = (value ?? '').trim();
                      if (!isLogin) {
                        return input.contains('@') && input.contains('.')
                            ? null : 'Enter a valid email address';
                      }
                      if (input.contains('@')) {
                        return input.contains('.') ? null : 'Enter a valid email address';
                      }
                      if (_existingTestAccountAliases.containsKey(input.toLowerCase())) {
                        return null;
                      }
                      final phone = _normalisePhoneForAuth(input);
                      return RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phone)
                          ? null
                          : 'Enter a valid email, staff test ID or mobile number';
                    },
                  ),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _passwordController,
                    obscureText: hidePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) {
                      if (isLogin && !loading) submit();
                    },
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
                      if (value == null || value.isEmpty) {
                        return 'Enter your password';
                      }
                      if (!isLogin && value.length < 8) {
                        return 'Password must contain '
                            'at least 8 characters';
                      }

                      return null;
                    },
                  ),

                  if (isLogin) ...[
                    OutlinedButton.icon(
                      onPressed: loading ? null : openStaffDemoPreview,
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('OPEN OFFICIAL DEMO PORTAL'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cyanAccent,
                        side: const BorderSide(color: Color(0xFF2D6A87)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                    const SizedBox(height: 10),
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
                      backgroundColor: electricBlue,
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
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: loading ? null : requestLoginPasswordReset,
                        child: const Text('Forgot password?'),
                      ),
                    ),
                    const SizedBox(height: 4),
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
                        foregroundColor: cyanAccent,
                        side: const BorderSide(color: Color(0xFF2D6A87)),
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

                  const SizedBox(height: 8),

                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PublicExcavationTrackerPage()),
                    ),
                    icon: const Icon(Icons.campaign_outlined),
                    label: const Text('VIEW PUBLIC WORK NOTICES'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cyanAccent,
                      side: const BorderSide(color: Color(0xFF2D6A87)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ],
                ),
              ),
            ),
          ),
        ),
      ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// READ-ONLY STAFF PREVIEW
// No Supabase session, private records, or operational writes are used.
// ==========================================

class _StaffDemoPreview extends StatefulWidget {
  final String role;
  final String staffId;
  final VoidCallback onExit;

  const _StaffDemoPreview({
    required this.role,
    required this.staffId,
    required this.onExit,
  });

  @override
  State<_StaffDemoPreview> createState() => _StaffDemoPreviewState();
}

class _StaffDemoPreviewState extends State<_StaffDemoPreview> {
  static const List<String> _departments = [
    'Water Supply / PHED',
    'Roads and Highways',
    'Urban Local Bodies',
    'Sewerage and Drainage',
    'Electricity Distribution',
    'Telecommunications',
    'Town Planning',
  ];

  late String _activeRole;
  late String _activeStaffId;
  String _section = 'Overview';
  final List<Map<String, dynamic>> _cases = [];
  final List<String> _activity = ['Demo workspace opened'];

  @override
  void initState() {
    super.initState();
    _activeRole = widget.role;
    _activeStaffId = widget.staffId;
    _cases.addAll([
      {
        'id': 'DEMO-2026-001',
        'title': 'Water pipeline replacement',
        'domain': 'Water supply',
        'department': 'Water Supply / PHED',
        'status': 'Under review',
        'priority': 'High',
        'location': 'Avinashi Road, Coimbatore',
        'assigned': ['Water Supply / PHED', 'Roads and Highways'],
        'description': 'Illustrative pipeline-renewal case linked to road restoration.',
      },
      {
        'id': 'DEMO-2026-002',
        'title': 'Road resurfacing and fibre duct work',
        'domain': 'Road reconstruction',
        'department': 'Roads and Highways',
        'status': 'Under coordination',
        'priority': 'Medium',
        'location': 'Gandhipuram, Coimbatore',
        'assigned': ['Roads and Highways', 'Telecommunications'],
        'description': 'Illustrative joint-work opportunity for resurfacing and telecom duct maintenance.',
      },
      {
        'id': 'DEMO-2026-003',
        'title': 'Stormwater drain obstruction',
        'domain': 'Drainage',
        'department': 'Urban Local Bodies',
        'status': 'Submitted',
        'priority': 'High',
        'location': 'RS Puram, Coimbatore',
        'assigned': ['Urban Local Bodies', 'Sewerage and Drainage'],
        'description': 'Illustrative drainage inspection request with a frontage-access observation.',
      },
      {
        'id': 'DEMO-2026-004',
        'title': 'Building floor compliance inspection',
        'domain': 'Building compliance',
        'department': 'Town Planning',
        'status': 'Assigned',
        'priority': 'Medium',
        'location': 'Peelamedu, Coimbatore',
        'assigned': ['Town Planning'],
        'description': 'Illustrative site-inspection record for comparison against an approved plan.',
      },
      {
        'id': 'DEMO-2026-005',
        'title': 'Groundwater and borewell observation',
        'domain': 'Groundwater',
        'department': 'Water Supply / PHED',
        'status': 'Submitted',
        'priority': 'Low',
        'location': 'Saravanampatti, Coimbatore',
        'assigned': ['Water Supply / PHED'],
        'description': 'Illustrative groundwater observation; not a regulatory determination.',
      },
    ]);
  }

  String get _roleTitle => switch (_activeRole) {
    'admin' => 'Administrator Portal',
    'coordinator' => 'Coordinator Portal',
    'department' => 'Department Officer Portal',
    _ => 'Official Demo Portal',
  };

  String get _roleDescription => switch (_activeRole) {
    'admin' => 'National overview, platform governance and department administration',
    'coordinator' => 'Cross-department coordination, escalations and work-conflict review',
    'department' => 'Assigned department cases, technical reviews and field-work coordination',
    _ => 'Official workspace demonstration',
  };

  List<List<String>> get _metrics => switch (_activeRole) {
    'admin' => [['36', 'States / UTs'], ['11', 'Service domains'], ['5', 'Sample cases'], ['7', 'Regions']],
    'coordinator' => [['5', 'Sample cases'], ['2', 'Joint-work links'], ['7', 'Departments'], ['36', 'Jurisdictions']],
    'department' => [['3', 'Assigned samples'], ['2', 'Review actions'], ['1', 'Field inspection'], ['1', 'Pending report']],
    _ => const [],
  };

  Future<void> _switchProfiles() async {
    final selected = await _showProfileSwitcher(context, currentRole: _activeRole);
    if (!mounted || selected == null) return;
    if (selected == 'requester') {
      widget.onExit();
      return;
    }
    setState(() {
      _activeRole = selected;
      _activeStaffId = _publicDemoStaffIds[selected]!;
      _section = 'Overview';
    });
  }

  Future<void> _toggleTheme() async {
    final enabled = samanvayThemeMode.value != ThemeMode.light;
    samanvayThemeMode.value = enabled ? ThemeMode.light : ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('samanvay_light_mode', enabled);
  }

  void _record(String message) {
    setState(() {
      _activity.insert(0, message);
      if (_activity.length > 10) _activity.removeLast();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message + ' · demo session only'), behavior: SnackBarBehavior.floating),
    );
  }

  Widget _metricCard(String value, String label) => SizedBox(
    width: 145,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(color: ink, fontSize: 23, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(color: mutedInk, fontSize: 10)),
          ],
        ),
      ),
    ),
  );

  Widget _panel(String title, String description, IconData icon, {String? status}) => Card(
    margin: const EdgeInsets.only(bottom: 9),
    child: Padding(
      padding: const EdgeInsets.all(13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: teal, size: 23),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 12)),
                const SizedBox(height: 4),
                Text(description, style: TextStyle(color: mutedInk, fontSize: 10, height: 1.4)),
                if (status != null) ...[
                  const SizedBox(height: 7),
                  Text(status, style: TextStyle(color: teal, fontSize: 9, fontWeight: FontWeight.w800)),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _sectionChip(String name) => Padding(
    padding: const EdgeInsets.only(right: 7),
    child: ChoiceChip(
      label: Text(name, style: TextStyle(fontSize: 10, color: _section == name ? teal : ink)),
      selected: _section == name,
      selectedColor: teal.withValues(alpha: .14),
      backgroundColor: panelNavy,
      side: BorderSide(color: _section == name ? teal : borderColor),
      onSelected: (_) => setState(() => _section = name),
    ),
  );

  Future<void> _showCase(Map<String, dynamic> item) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(item['title'].toString()),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('CASE ID: ' + item['id'].toString()),
              Text('Domain: ' + item['domain'].toString()),
              Text('Department: ' + item['department'].toString()),
              Text('Location: ' + item['location'].toString()),
              Text('Priority: ' + item['priority'].toString()),
              Text('Status: ' + item['status'].toString()),
              const SizedBox(height: 10),
              Text(item['description'].toString()),
              const SizedBox(height: 10),
              Text(
                'Synthetic demonstration record. No live citizen or department record is opened.',
                style: TextStyle(color: mutedInk, fontSize: 10),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _updateCase(Map<String, dynamic> item) async {
    final choices = _activeRole == 'department'
        ? const ['Under review', 'Approved', 'Clarification required']
        : const ['Under review', 'Approved', 'Conflict detected', 'Completed', 'Rejected'];
    var selected = choices.first;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Update demonstration case'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Current status: ' + item['status'].toString()),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selected,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Select status'),
                items: choices.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                onChanged: (value) {
                  if (value != null) setDialogState(() => selected = value);
                },
              ),
              const SizedBox(height: 8),
              Text('This updates the sample record in this device session only.', style: TextStyle(color: mutedInk, fontSize: 10)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(dialogContext).pop(selected), child: const Text('Save demo update')),
          ],
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() => item['status'] = result);
    _record(item['id'].toString() + ' status changed to ' + result);
  }

  Future<void> _assignDepartment(Map<String, dynamic> item) async {
    var selected = item['department'].toString();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Assign sample department'),
          content: DropdownButtonFormField<String>(
            initialValue: selected,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Department'),
            items: _departments.map((name) => DropdownMenuItem(value: name, child: Text(name))).toList(),
            onChanged: (value) {
              if (value != null) setDialogState(() => selected = value);
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(dialogContext).pop(selected), child: const Text('Save demo assignment')),
          ],
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      item['department'] = result;
      final assigned = List<String>.from(item['assigned'] as List);
      if (!assigned.contains(result)) assigned.add(result);
      item['assigned'] = assigned;
    });
    _record(item['id'].toString() + ' assigned to ' + result);
  }

  Widget _caseCard(Map<String, dynamic> item) {
    final isOfficer = _activeRole == 'department';
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(item['title'].toString(), style: TextStyle(color: ink, fontSize: 13, fontWeight: FontWeight.w800))),
                const SizedBox(width: 7),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(color: teal.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
                  child: Text(item['status'].toString().toUpperCase(), style: TextStyle(color: teal, fontSize: 8, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(item['id'].toString() + ' · ' + item['domain'].toString(), style: TextStyle(color: mutedInk, fontSize: 10)),
            const SizedBox(height: 4),
            Text(item['location'].toString() + ' · ' + item['department'].toString(), style: TextStyle(color: mutedInk, fontSize: 10)),
            const SizedBox(height: 9),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                OutlinedButton.icon(onPressed: () => _showCase(item), icon: const Icon(Icons.visibility_outlined, size: 15), label: const Text('Details')),
                FilledButton.tonalIcon(onPressed: () => _updateCase(item), icon: Icon(isOfficer ? Icons.rate_review_outlined : Icons.sync_alt, size: 15), label: Text(isOfficer ? 'Review' : 'Update status')),
                if (!isOfficer)
                  OutlinedButton.icon(onPressed: () => _assignDepartment(item), icon: const Icon(Icons.account_tree_outlined, size: 15), label: const Text('Assign')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _overview() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(spacing: 8, runSpacing: 8, children: _metrics.map((m) => _metricCard(m[0], m[1])).toList()),
      const SizedBox(height: 14),
      _panel('Role-based command dashboard', _roleDescription, Icons.dashboard_customize_outlined, status: 'DEMO WORKSPACE · SYNTHETIC RECORDS'),
      _panel('Multi-department case register', 'Road reconstruction, water supply, sewerage, drainage, electricity, telecom and building-compliance workflows.', Icons.assignment_outlined, status: '5 ILLUSTRATIVE CASES'),
      _panel('National GIS workspace', 'India-wide jurisdiction model, seven browsing regions and authority-owned evidence workflow.', Icons.map_outlined, status: '36 STATES / UNION TERRITORIES'),
      _panel('Alerts and audit trail', 'Review local demo assignments, status changes and sample activity history.', Icons.notifications_active_outlined, status: _activity.length.toString() + ' SESSION EVENTS'),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LpuCampusModelPage())),
          icon: const Icon(Icons.view_in_ar_rounded),
          label: const Text('OPEN 3D UNDERGROUND CAMPUS MODEL'),
        ),
      ),
    ],
  );

  Widget _caseQueue() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        _activeRole == 'department'
            ? 'Sample cases routed to the Water Supply / PHED workspace.'
            : 'Sample infrastructure cases across connected service departments.',
        style: TextStyle(color: mutedInk, fontSize: 10, height: 1.4),
      ),
      const SizedBox(height: 10),
      ...(_activeRole == 'department'
          ? _cases.where((item) => (item['assigned'] as List).contains('Water Supply / PHED'))
          : _cases).map(_caseCard),
    ],
  );

  Widget _coordination() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _panel('Potential repeated-work conflict', 'Road resurfacing overlaps with telecom duct maintenance. A coordinator can identify the overlap and recommend one joint execution window.', Icons.alt_route_rounded, status: '1 SAMPLE COORDINATION ALERT'),
      _panel('Joint-work proposal', 'Bundle water-pipeline replacement and road restoration into one work package, subject to each authority approval.', Icons.hub_outlined, status: '2 DEPARTMENTS LINKED'),
      _panel('Department workload', 'Sample workload split across water supply, roads, drainage, power, telecom and town planning.', Icons.query_stats_outlined),
      ..._departments.map((name) => _panel(name, 'Department directory entry for cross-agency routing and coordination.', Icons.account_balance_outlined)),
    ],
  );

  Widget _roadworks() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _panel('Road-cut permit compliance', 'Track permitted excavation windows, work completion, restoration deadlines and overdue notices.', Icons.construction_outlined, status: '2 SAMPLE PERMITS'),
      _panel('Coordinated road-work calendar', 'Compare schedules across departments to reduce repeated road cuts and overlapping works.', Icons.calendar_month_outlined, status: '1 PROPOSED JOINT WINDOW'),
      _panel('Road restoration quality assurance', 'Record reinstatement checks, material observations, photographs and inspection outcomes.', Icons.verified_outlined, status: '1 SAMPLE INSPECTION'),
      _panel('Stormwater drainage and frontage', 'Track drain obstructions, frontage access and inspection follow-up for municipal teams.', Icons.water_outlined, status: '1 SAMPLE OBSERVATION'),
      _panel('Public excavation tracker', 'Show published notices and planned works without exposing restricted utility geometry.', Icons.campaign_outlined, status: 'PUBLIC VIEW'),
    ],
  );

  Widget _gisCoverage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _panel('India-wide jurisdiction explorer', 'All 36 States and Union Territories are represented in the master jurisdiction model.', Icons.public_outlined, status: '36 JURISDICTIONS'),
      _panel('Infrastructure source coverage', 'Coverage rows indicate source readiness and data availability; they are not proof of verified underground assets.', Icons.layers_outlined, status: '11 SERVICE DOMAINS'),
      _panel('Underground asset verification', 'Owner-submitted GIS requires source authorisation, evidence review and independent verification before operational use.', Icons.verified_user_outlined, status: 'NO LIVE ASSET GEOMETRY IN THIS DEMO'),
      Wrap(
        spacing: 7,
        runSpacing: 7,
        children: const ['North', 'Northeast', 'East', 'Central', 'West', 'South', 'Islands']
            .map((region) => Chip(label: Text(region, style: const TextStyle(fontSize: 10)), backgroundColor: Color(0xFFE5F4F1), side: BorderSide(color: Color(0xFFB8DCD5))))
            .toList(),
      ),
    ],
  );

  Widget _groundwater() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _panel('Groundwater telemetry snapshot', 'View sample water-level observations, reporting dates and station metadata.', Icons.water_drop_outlined, status: 'ILLUSTRATIVE STATION DATA'),
      _panel('Borewell observation register', 'Flag clustered observations for authority review; the dashboard does not itself grant or deny borewell permissions.', Icons.sensors_outlined, status: 'REVIEW WORKFLOW'),
      _panel('Source verification', 'Separate official observations from reference data and unverified submissions.', Icons.fact_check_outlined, status: 'SOURCE STATUS VISIBLE'),
      _panel('Sample station', 'Observation: 14.2 m below ground level · Reporting period: illustrative 2026 snapshot.', Icons.location_on_outlined, status: 'SAMPLE ONLY · NOT A LIVE READING'),
    ],
  );

  Widget _buildings() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _panel('Building approval register', 'Link the sanctioned plan reference, permitted floor count and inspection history.', Icons.apartment_outlined, status: 'SAMPLE APPROVAL RECORDS'),
      _panel('Floor compliance inspection', 'Record observed floor count, site evidence, inspection outcome and authority follow-up.', Icons.domain_verification_outlined, status: '1 SAMPLE INSPECTION'),
      _panel('Drainage and setback review', 'Flag missing frontage drainage space and route the observation to the relevant local authority.', Icons.rule_folder_outlined, status: 'INSPECTION WORKFLOW'),
      _panel('Audit-ready decisions', 'Store responsible officer, decision date, source plan and supporting evidence for official decisions.', Icons.assignment_turned_in_outlined),
    ],
  );

  Widget _aiInsights() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _panel('Repeated-dig prevention signal', 'A sample AI-assisted recommendation groups pipeline replacement with scheduled road restoration to reduce repeat excavation.', Icons.auto_awesome_outlined, status: 'ILLUSTRATIVE AI OUTPUT'),
      _panel('Conflict-screening explanation', 'Explain which dates, locations and infrastructure domains caused a potential conflict alert for human review.', Icons.psychology_outlined),
      _panel('Evidence-aware summaries', 'The production assistant uses authorised case context and records generated assessments for accountable review.', Icons.summarize_outlined, status: 'LIVE AI REQUIRES AUTHENTICATED STAFF ACCESS'),
      _panel('Human approval remains mandatory', 'AI output is advisory. It does not approve permits, certify utility locations or replace a competent authority.', Icons.verified_user_outlined),
    ],
  );

  Widget _governance() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _panel('Role and department permissions', 'Production access is resolved from the authenticated Supabase profile. Demo profile selection does not grant live officer or administrator permissions.', Icons.admin_panel_settings_outlined),
      _panel('Source and evidence registry', 'Store originating authority, publication date, checksum and verification status with imported datasets.', Icons.source_outlined),
      _panel('Audit and approval history', 'Protected operations record actor, timestamp, case identifier and decision rationale.', Icons.history_edu_outlined),
      _panel('Data readiness', 'District and ULB records require validated official source imports. Underground asset geometry remains separate from directory and coverage records.', Icons.fact_check_outlined, status: 'AUTHORITY VERIFICATION REQUIRED'),
      _panel('Recent demo activity', _activity.take(6).join(' · '), Icons.history_rounded, status: 'LOCAL SESSION ONLY'),
    ],
  );

  Widget _selectedContent() {
    switch (_section) {
      case 'Case queue': return _caseQueue();
      case 'Coordination': return _coordination();
      case 'Roadworks': return _roadworks();
      case 'GIS & coverage': return _gisCoverage();
      case 'Groundwater': return _groundwater();
      case 'Buildings': return _buildings();
      case 'AI insights': return _aiInsights();
      case 'Governance': return _governance();
      default: return _overview();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('SAMANVAY OFFICIAL WORKSPACE'),
            Text('DEMO ID ' + _activeStaffId + ' · ' + _roleTitle.toUpperCase(), style: TextStyle(color: cyanAccent, fontSize: 9)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: isLight ? 'Switch to dark mode' : 'Switch to light mode',
            onPressed: _toggleTheme,
            icon: Icon(isLight ? Icons.dark_mode_outlined : Icons.light_mode_outlined),
          ),
          IconButton(tooltip: 'Switch profiles', onPressed: _switchProfiles, icon: const Icon(Icons.switch_account_rounded)),
          TextButton.icon(onPressed: widget.onExit, icon: const Icon(Icons.logout_rounded, size: 16), label: const Text('EXIT')),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(15),
          children: [
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: isLight ? const Color(0xFFE5F4F1) : const Color(0xFF3B2D14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isLight ? const Color(0xFFB8DCD5) : const Color(0xFF9C7428)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.visibility_outlined, color: isLight ? teal : const Color(0xFFFFD27A)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'DEMO PROFILE ACTIVE. This workspace uses synthetic sample records. Status updates and assignments work in this session only; no Supabase user is impersonated and no live citizen or department data is changed.',
                      style: TextStyle(color: isLight ? navy : const Color(0xFFFFE5AE), fontSize: 10, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(_roleTitle, style: TextStyle(color: ink, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(_roleDescription, style: TextStyle(color: mutedInk, fontSize: 11, height: 1.4)),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  'Overview', 'Case queue', 'Coordination', 'Roadworks',
                  'GIS & coverage', 'Groundwater', 'Buildings', 'AI insights', 'Governance',
                ].map(_sectionChip).toList(),
              ),
            ),
            const SizedBox(height: 14),
            _selectedContent(),
            const SizedBox(height: 8),
            Text(
              'Live officer functions and protected records require an authorised Supabase staff account. This interactive demonstration is designed for the five-minute presentation.',
              style: TextStyle(color: mutedInk, fontSize: 10, height: 1.4),
            ),
          ],
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
    DashboardPage(), RequestsPage(), MapPage(),
    PublicExcavationTrackerPage(), ProfilePage(),
  ];

  static const destinations = <NavigationRailDestination>[
    NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: Text('Home')),
    NavigationRailDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment_rounded), label: Text('Cases')),
    NavigationRailDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map_rounded), label: Text('GIS')),
    NavigationRailDestination(icon: Icon(Icons.campaign_outlined), selectedIcon: Icon(Icons.campaign_rounded), label: Text('Public works')),
    NavigationRailDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person_rounded), label: Text('Profile')),
  ];

  Future<void> _switchProfiles() async {
    final selected = await _showProfileSwitcher(
      context,
      currentRole: 'requester',
    );
    if (!mounted || selected == null || selected == 'requester') return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (previewContext) => _StaffDemoPreview(
          role: selected,
          staffId: _publicDemoStaffIds[selected]!,
          onExit: () => Navigator.of(previewContext).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 900;
      final extended = constraints.maxWidth >= 1200;
      return Scaffold(
        backgroundColor: background,
        body: Row(children: [
          if (wide) ...[
            Container(
              color: _usesLegacyLightPalette ? Colors.white : navy,
              child: SafeArea(
                child: NavigationRail(
                  extended: extended,
                  minWidth: 76,
                  minExtendedWidth: 205,
                  backgroundColor: _usesLegacyLightPalette ? Colors.white : navy,
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (index) => setState(() => selectedIndex = index),
                  labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
                  indicatorColor: cyanAccent.withValues(alpha: .18),
                  selectedIconTheme:  IconThemeData(color: cyanAccent),
                  unselectedIconTheme:  IconThemeData(color: mutedInk),
                  selectedLabelTextStyle:  TextStyle(color: cyanAccent, fontWeight: FontWeight.w800, fontSize: 10),
                  unselectedLabelTextStyle:  TextStyle(color: mutedInk, fontSize: 10),
                  leading: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 14, 8, 20),
                    child: extended
                      ? Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                          const _SamanvayBrandLogo(size: 42, radius: 11),
                          const SizedBox(width: 9),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('SAMANVAY', style: GoogleFonts.spaceGrotesk(color: _usesLegacyLightPalette ? ink : Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text('TOWARDS OUR DEVELOPMENT 📈', style: TextStyle(color: cyanAccent, fontSize: 7.5, letterSpacing: .45, fontWeight: FontWeight.w800)),
                          ])),
                        ])
                      : const _SamanvayBrandLogo(size: 48, radius: 13),
                  ),
                  destinations: destinations,
                ),
              ),
            ),
            VerticalDivider(width: 1, thickness: 1, color: borderColor),
          ],
          Expanded(child: IndexedStack(index: selectedIndex, children: pages)),
        ]),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'samanvay-switch-profile',
          tooltip: 'Switch between Citizen and official demo profiles',
          onPressed: _switchProfiles,
          icon: const Icon(Icons.switch_account_rounded),
          label: const Text('SWITCH PROFILE'),
        ),
        bottomNavigationBar: wide ? null : NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) => setState(() => selectedIndex = index),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment_rounded), label: 'Cases'),
            NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map_rounded), label: 'GIS'),
            NavigationDestination(icon: Icon(Icons.campaign_outlined), selectedIcon: Icon(Icons.campaign_rounded), label: 'Public works'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
          ],
        ),
      );
    },
  );
}

// ==========================================
// DASHBOARD
// ==========================================

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> requests = [];
  List<Map<String, dynamic>> departments = [];
  late final AnimationController _ambientFlag;

  @override
  void initState() {
    super.initState();
    _ambientFlag = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    )..repeat();
    refresh();
  }

  @override
  void dispose() {
    _ambientFlag.dispose();
    super.dispose();
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
      return  Text(
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
      decoration: BoxDecoration(color: panelNavy,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 10),
        Text(value, style: GoogleFonts.robotoMono(
          color: _usesLegacyLightPalette ? ink : Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
        Text(title, style: GoogleFonts.inter(
          color: mutedInk, fontSize: 10, fontWeight: FontWeight.w600)),
      ]),
    ));

  @override
  Widget build(BuildContext context) {
    final rawName = supabase.auth.currentUser?.userMetadata?['display_name'];
    final name = rawName == null || rawName.toString().trim().isEmpty
      ? 'there' : rawName.toString().trim();
    final resolved = requests.where((request) {
      final status = (request['status'] ?? '').toString().toLowerCase();
      return status == 'completed' || status == 'resolved';
    }).length;
    final inactive = {'completed', 'resolved', 'rejected', 'cancelled'};
    final active = requests.where((request) {
      final status = (request['status'] ?? '').toString().toLowerCase();
      return status.isNotEmpty && !inactive.contains(status);
    }).length;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text('SAMANVAY'),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsPage()),
            ),
          ),
          IconButton(
            tooltip: 'India data coverage',
            icon: const Icon(Icons.public_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const IndiaCoverageExplorerPage()),
            ),
          ),
          IconButton(onPressed: loading ? null : refresh,
            tooltip: 'Refresh', icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Container(
            padding: const EdgeInsets.all(21),
            decoration: BoxDecoration(
              image: const DecorationImage(
                image: AssetImage('assets/brand/home_city_banner.jpg'),
                fit: BoxFit.cover,
              ),
              gradient: LinearGradient(
                colors: [
                  navy.withValues(alpha: .72),
                  const Color(0xFF173B55).withValues(alpha: .58),
                  const Color(0xFF075E67).withValues(alpha: .66),
                ],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0x5534E5D1)),
              boxShadow: const [BoxShadow(color: Color(0x180B1728),
                blurRadius: 20, offset: Offset(0, 9))]),
            clipBehavior: Clip.antiAlias,
            child: AnimatedBuilder(
              animation: _ambientFlag,
              builder: (context, _) => Stack(
                fit: StackFit.expand,
                children: [
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _WavingFlagPainter(
                        progress: _ambientFlag.value,
                        opacity: .13,
                        ambientBackground: true,
                      ),
                    ),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
              const SizedBox(height: 3),
              const _SamanvayBrandLogo(size: 194, radius: 34),
              const SizedBox(height: 9),
              const _AnimatedDevelopmentTagline(fontSize: 14),
              const SizedBox(height: 6),
              const Text(
                'SMART COORDINATION  •  TRANSPARENT GOVERNANCE  •  A DEVELOPED INDIA',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFE3EDF7), fontSize: 8,
                  fontWeight: FontWeight.w900, letterSpacing: .55),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Hello, $name! 👋',
                      style: GoogleFonts.spaceGrotesk(color: Colors.white,
                        fontSize: 23, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('Towards a smarter, better-coordinated India',
                      style: GoogleFonts.inter(color: const Color(0xFFD1E0EA), fontSize: 10)),
                  ])),
                  const CircleAvatar(
                    radius: 22,
                    backgroundColor: Color(0xFF35D7F2),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundImage: AssetImage('assets/brand/profile_avatar.jpg'),
                      backgroundColor: Color(0xFF173B55),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MapPage())),
                icon: const Icon(Icons.layers_rounded),
                label: const Text('LIVE UNDERGROUND VIEW  ↗'),
                style: FilledButton.styleFrom(backgroundColor: teal,
                  foregroundColor: navy, padding: const EdgeInsets.symmetric(vertical: 14)),
              )),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text('My activity', style: GoogleFonts.spaceGrotesk(
            color: ink, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Live status of your infrastructure requests',
            style: GoogleFonts.inter(color: mutedInk, fontSize: 11)),
          const SizedBox(height: 11),
          Row(children: [
            metric('MY REQUESTS', loading ? '—' : '${requests.length}',
              Icons.assignment_outlined, teal),
            const SizedBox(width: 8),
            metric('IN PROGRESS', loading ? '—' : '$active',
              Icons.pending_actions, const Color(0xFFD28A28)),
            const SizedBox(width: 8),
            metric('RESOLVED', loading ? '—' : '$resolved',
              Icons.task_alt, const Color(0xFF25845C)),
          ]),
          const SizedBox(height: 20),
          Text('Quick actions', style: GoogleFonts.spaceGrotesk(
            color: ink, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (context, constraints) {
            final columns = constraints.maxWidth >= 650 ? 5 : 4;
            const spacing = 9.0;
            final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
            Widget action(String title, IconData icon, Color accent, Widget page) =>
              SizedBox(width: width, child: Material(
                color: panelNavy,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => page)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor)),
                    child: Column(children: [
                      Icon(icon, color: accent, size: 22),
                      const SizedBox(height: 7),
                      Text(title, textAlign: TextAlign.center,
                        style: TextStyle(color: ink, fontSize: 10, fontWeight: FontWeight.w800)),
                    ]),
                  ),
                ),
              ));
            return Wrap(spacing: spacing, runSpacing: spacing, children: [
              action('New request', Icons.add_circle_outline, cyanAccent, const NewRequestPage()),
              action('Track requests', Icons.track_changes_outlined, const Color(0xFF7FC8FF), const RequestsPage()),
              action('3D GIS map', Icons.layers_outlined, const Color(0xFF8B9DFF), const MapPage()),
              action('Notifications', Icons.notifications_none_rounded, const Color(0xFFBFA7FF), const NotificationsPage()),
            ]);
          }),
          const SizedBox(height: 19),
          Card(
            color: panelNavy,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                const _SamanvayBrandLogo(size: 52, radius: 13),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('PUBLIC TRANSPARENCY DASHBOARD',
                    style: TextStyle(color: ink, fontWeight: FontWeight.w900, fontSize: 11)),
                  const SizedBox(height: 4),
                  Text('Published projects, department activity and verified public impact across India.',
                    style: TextStyle(color: mutedInk, fontSize: 10, fontWeight: FontWeight.w600)),
                ])),
                IconButton(
                  tooltip: 'Open public transparency dashboard',
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => PublicTransparencyDashboardPage(
                      client: supabase,
                      onOpenMap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MapPage())),
                      onOpenNotices: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PublicExcavationTrackerPage())),
                    ),
                  )),
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
              ]),
            ),
          ),
          if (error != null) Padding(padding: const EdgeInsets.only(bottom: 10),
            child: Text(error!, style: const TextStyle(color: Colors.deepOrange))),
          const SizedBox(height: 22),
          Text('Cases by infrastructure domain', style: GoogleFonts.spaceGrotesk(
            color: ink, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Distribution of your submitted cases', style: GoogleFonts.inter(
            color: mutedInk, fontSize: 12)),
          const SizedBox(height: 13),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: panelNavy,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: loading && requests.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _categoryOverview(),
          ),
          const SizedBox(height: 24),
          Text('Department network', style: GoogleFonts.spaceGrotesk(
            color: ink, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Live directory from the SAMANVAY database',
            style: GoogleFonts.inter(color: mutedInk, fontSize: 12)),
          const SizedBox(height: 12),
          if (loading && departments.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(18),
              child: CircularProgressIndicator()))
          else if (departments.isEmpty)
             Text('No department directory records available.',
              style: TextStyle(color: mutedInk))
          else
            ...departments.map((d) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: panelNavy,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor)),
              child: ListTile(dense: true,
                leading:  CircleAvatar(
                  backgroundColor: Color(0xFFE7F8F6),
                  child: Icon(Icons.account_tree_outlined, color: teal)),
                title: Text((d['name'] ?? 'Department').toString(),
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                trailing:  Icon(Icons.chevron_right, color: mutedInk),
              ),
            )),
          const SizedBox(height: 14),
          Container(padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: panelNavy,
              borderRadius: BorderRadius.circular(14), border: Border.all(color: borderColor)),
            child: Text(
              'Underground visibility depends on verified survey records and access permissions. An empty layer does not prove that no utility exists.',
              style: GoogleFonts.inter(color: mutedInk,
                fontSize: 11, fontWeight: FontWeight.w700, height: 1.45))),
        ]),
      ),
    );
  }
}


// RLS-backed authoring and review desk for public excavation notices.
// Live activity feed. Status events follow case visibility RLS;
// admin audit events are queried only for an authenticated admin portal.
class CommandCentreActivityBoard extends StatefulWidget {
  final bool isAdmin;
  const CommandCentreActivityBoard({super.key, required this.isAdmin});
  @override
  State<CommandCentreActivityBoard> createState() => _CommandCentreActivityBoardState();
}

class _CommandCentreActivityBoardState extends State<CommandCentreActivityBoard> {
  List<Map<String, dynamic>> statusEvents = [];
  List<Map<String, dynamic>> auditEvents = [];
  bool loading = true;
  bool statusUnavailable = false;
  bool auditUnavailable = false;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    if (mounted) setState(() { loading = true; statusUnavailable = false; auditUnavailable = false; });
    try {
      final rows = await supabase.from('request_status_history')
        .select('request_id,old_status,new_status,created_at')
        .order('created_at', ascending: false).limit(15);
      if (mounted) statusEvents = List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      if (mounted) statusUnavailable = true;
    }

    if (widget.isAdmin) {
      try {
        final rows = await supabase.from('admin_audit_events')
          .select('event_type,created_at')
          .order('created_at', ascending: false).limit(15);
        if (mounted) auditEvents = List<Map<String, dynamic>>.from(rows);
      } catch (_) {
        if (mounted) auditUnavailable = true;
      }
    }
    if (mounted) setState(() => loading = false);
  }

  String _date(dynamic raw) {
    final date = DateTime.tryParse((raw ?? '').toString())?.toLocal();
    if (date == null) return 'Date not available';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return day + '/' + month + '/' + date.year.toString() + ' · ' + hour + ':' + minute;
  }

  String _label(dynamic value) =>
    (value ?? 'not recorded').toString().replaceAll('_', ' ').toUpperCase();

  Widget _event({
    required IconData icon,
    required Color accent,
    required String title,
    required String subtitle,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 30, height: 30,
        decoration: BoxDecoration(color: accent.withValues(alpha: .13), shape: BoxShape.circle),
        child: Icon(icon, color: accent, size: 16)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(subtitle, style:  TextStyle(color: mutedInk, fontSize: 9, height: 1.35)),
      ])),
    ]),
  );

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: panelNavy, borderRadius: BorderRadius.circular(17),
      border: Border.all(color: borderColor)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
         Icon(Icons.timeline_rounded, color: cyanAccent, size: 19),
        const SizedBox(width: 8),
        const Expanded(child: Text('Command-centre activity',
          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800))),
        IconButton(onPressed: loading ? null : refresh,
          tooltip: 'Refresh activity', icon:  Icon(Icons.refresh_rounded, color: cyanAccent)),
      ]),
       Text('Recent case status transitions visible to this account. Audit events are restricted to administrators.',
        style: TextStyle(color: mutedInk, fontSize: 10, height: 1.35)),
      const SizedBox(height: 11),
      Row(children: [
        Expanded(child: Text('CASE TIMELINE · ' + statusEvents.length.toString(),
          style:  TextStyle(color: cyanAccent, fontSize: 9, letterSpacing: .7, fontWeight: FontWeight.w900))),
        if (widget.isAdmin)
          Text('ADMIN AUDIT · ' + auditEvents.length.toString(),
            style: const TextStyle(color: Color(0xFF9FBCFF), fontSize: 9, letterSpacing: .5, fontWeight: FontWeight.w900)),
      ]),
       Divider(color: borderColor, height: 18),
      if (loading && statusEvents.isEmpty && auditEvents.isEmpty)
         Center(child: Padding(padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(color: cyanAccent)))
      else if (statusUnavailable)
        const Text('Case timeline is unavailable for this account. Check the case-access policy.',
          style: TextStyle(color: Color(0xFFFFB4AB), fontSize: 10))
      else if (statusEvents.isEmpty)
         Text('No case status transitions are recorded yet.',
          style: TextStyle(color: mutedInk, fontSize: 10))
      else
        ...statusEvents.map((event) {
          final requestId = (event['request_id'] ?? '').toString();
          final caseLabel = requestId.length >= 8 ? requestId.substring(0, 8).toUpperCase() : 'CASE';
          final oldStatus = event['old_status'] == null ? 'CREATED' : _label(event['old_status']);
          final newStatus = _label(event['new_status']);
          return _event(
            icon: Icons.sync_alt_rounded,
            accent: const Color(0xFF66D6CB),
            title: caseLabel + ' · ' + oldStatus + ' → ' + newStatus,
            subtitle: _date(event['created_at']),
          );
        }),
      if (widget.isAdmin) ...[
         Divider(color: borderColor, height: 20),
        const Text('ADMIN AUDIT LOG',
          style: TextStyle(color: Color(0xFF9FBCFF), fontSize: 9, letterSpacing: .7, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        if (auditUnavailable)
          const Text('Audit records could not be loaded. They are not substituted with case events.',
            style: TextStyle(color: Color(0xFFFFB4AB), fontSize: 10))
        else if (auditEvents.isEmpty)
           Text('No administrator audit events are recorded yet.',
            style: TextStyle(color: mutedInk, fontSize: 10))
        else
          ...auditEvents.map((event) => _event(
            icon: Icons.admin_panel_settings_outlined,
            accent: const Color(0xFF9FBCFF),
            title: _label(event['event_type']),
            subtitle: _date(event['created_at']),
          )),
      ],
    ]),
  );
}


class PublicWorksOperationsBoard extends StatefulWidget {
  final List<Map<String, dynamic>> departments;
  final bool isDepartment;
  final String? departmentId;
  const PublicWorksOperationsBoard({super.key, required this.departments, required this.isDepartment, this.departmentId});
  @override
  State<PublicWorksOperationsBoard> createState() => _PublicWorksOperationsBoardState();
}

class _PublicWorksOperationsBoardState extends State<PublicWorksOperationsBoard> {
  List<Map<String, dynamic>> notices = [];
  List<Map<String, dynamic>> reports = [];
  List<Map<String, dynamic>> departments = [];
  bool loading = true;
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    departments = List<Map<String, dynamic>>.from(widget.departments);
    refresh();
  }

  Future<void> refresh() async {
    if (mounted) setState(() { loading = true; error = null; });
    try {
      final rows = await Future.wait([
        supabase.from('public_excavation_notices')
          .select('id,notice_code,title,notice_type,city,district,ward_code,area_label,responsible_department_id,responsible_department_name,starts_on,ends_on,progress_percent,notice_status,source_reference,source_url,summary,published_at')
          .order('updated_at', ascending: false).limit(100),
        supabase.from('public_obstruction_reports')
          .select('id,city,district,ward_code,area_label,report_type,details,assigned_department_id,report_status,created_at')
          .order('created_at', ascending: false).limit(100),
      ]);
      if (!mounted) return;
      setState(() {
        notices = List<Map<String, dynamic>>.from(rows[0]);
        reports = List<Map<String, dynamic>>.from(rows[1]);
        loading = false;
      });
      if (departments.isEmpty) await loadDepartments();
    } catch (_) {
      if (!mounted) return;
      setState(() { loading = false; error = 'The queue could not be loaded. Supabase RLS still controls which records this account can see.'; });
    }
  }

  Future<void> loadDepartments() async {
    try {
      final rows = widget.isDepartment && widget.departmentId != null
        ? await supabase.from('departments').select('id,name').eq('id', widget.departmentId!).order('name')
        : await supabase.from('departments').select('id,name').order('name');
      if (mounted) setState(() => departments = List<Map<String, dynamic>>.from(rows));
    } catch (_) {}
  }

  String departmentName(String? id) {
    if (id == null || id.isEmpty) return 'Not assigned';
    for (final d in departments) {
      if (d['id'].toString() == id) return d['name'].toString();
    }
    return 'Assigned department';
  }

  String pretty(String value) => value.replaceAll('_', ' ').toUpperCase();

  void toast(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> createNotice() async {
    if (saving) return;
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final code = TextEditingController();
    final title = TextEditingController();
    final city = TextEditingController(text: 'Coimbatore');
    final area = TextEditingController();
    final starts = TextEditingController(text: DateTime.now().toIso8601String().substring(0, 10));
    final source = TextEditingController();
    final url = TextEditingController();
    final form = GlobalKey<FormState>();
    var type = 'work';
    String? departmentId = widget.isDepartment ? widget.departmentId
      : (departments.isEmpty ? null : departments.first['id'].toString());

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Create work / no-dig notice'),
          content: SizedBox(width: 520, child: SingleChildScrollView(
            child: Form(key: form, child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Notice type'),
                items: const [
                  DropdownMenuItem(value: 'work', child: Text('Excavation / public works')),
                  DropdownMenuItem(value: 'no_dig', child: Text('No-dig notice')),
                ],
                onChanged: (v) { if (v != null) setDialog(() => type = v); },
              ),
              TextFormField(controller: code, decoration: const InputDecoration(labelText: 'Official notice code / reference'),
                validator: (v) => v == null || v.trim().length < 3 ? 'Enter the source notice code' : null),
              TextFormField(controller: title, decoration: const InputDecoration(labelText: 'Notice title'),
                validator: (v) => v == null || v.trim().length < 5 ? 'Enter a descriptive title' : null),
              TextFormField(controller: city, decoration: const InputDecoration(labelText: 'City / town'),
                validator: (v) => v == null || v.trim().length < 2 ? 'Enter a city / town' : null),
              TextFormField(controller: area, decoration: const InputDecoration(labelText: 'Area / road / landmark')),
              TextFormField(controller: starts, decoration: const InputDecoration(labelText: 'Start date (YYYY-MM-DD)'),
                validator: (v) => v == null || DateTime.tryParse(v.trim()) == null ? 'Enter a valid date' : null),
              TextFormField(controller: source, decoration: const InputDecoration(labelText: 'Official source reference (required to publish)')),
              TextFormField(controller: url, decoration: const InputDecoration(labelText: 'Official HTTPS source URL (optional)'),
                validator: (v) => v != null && v.trim().isNotEmpty && !v.trim().toLowerCase().startsWith('https://') ? 'Use an HTTPS URL' : null),
              const SizedBox(height: 8),
              if (widget.isDepartment)
                Align(alignment: Alignment.centerLeft, child: Text('Responsible department: ' + departmentName(departmentId),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)))
              else
                DropdownButtonFormField<String>(
                  initialValue: departmentId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Responsible department'),
                  items: departments.map((d) => DropdownMenuItem<String>(
                    value: d['id'].toString(), child: Text(d['name'].toString()))).toList(),
                  onChanged: (v) => setDialog(() => departmentId = v),
                  validator: (v) => v == null ? 'Select a department' : null,
                ),
              const SizedBox(height: 8),
               Text('This creates a draft only. A source reference is required before a staff user can publish it.',
                style: TextStyle(fontSize: 10, color: mutedInk)),
            ])),
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
            FilledButton(onPressed: () {
              if (form.currentState!.validate() && departmentId != null) Navigator.pop(dialog, true);
            }, child: const Text('Save draft')),
          ],
        ),
      ),
    );

    if (ok == true) {
      setState(() => saving = true);
      try {
        Map<String, dynamic>? department;
        for (final d in departments) {
          if (d['id'].toString() == departmentId) department = d;
        }
        if (department == null) {
          final row = await supabase.from('departments').select('id,name')
            .eq('id', departmentId!).maybeSingle();
          if (row != null) department = Map<String, dynamic>.from(row);
        }
        if (department == null) throw StateError('Responsible department is unavailable.');
        final inserted = await supabase.from('public_excavation_notices').insert({
          'notice_code': code.text.trim(), 'title': title.text.trim(), 'notice_type': type,
          'city': city.text.trim(), 'area_label': area.text.trim().isEmpty ? null : area.text.trim(),
          'responsible_department_id': departmentId,
          'responsible_department_name': department['name'].toString(),
          'starts_on': starts.text.trim(),
          'source_reference': source.text.trim().isEmpty ? null : source.text.trim(),
          'source_url': url.text.trim().isEmpty ? null : url.text.trim(),
          'notice_status': 'draft', 'created_by': user.id,
        }).select('id').maybeSingle();
        if (inserted == null) throw StateError('The database did not confirm the draft insert.');
        toast('Notice draft saved. It is not public until an authorised publisher publishes it.');
        await refresh();
      } catch (e) {
        toast('Notice draft not saved: ' + e.toString());
      } finally {
        if (mounted) setState(() => saving = false);
      }
    }
    for (final c in [code,title,city,area,starts,source,url]) { c.dispose(); }
  }

  Future<void> editNotice(Map<String, dynamic> notice) async {
    if (saving) return;
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final source = TextEditingController(text: (notice['source_reference'] ?? '').toString());
    final progress = TextEditingController(text: notice['progress_percent']?.toString() ?? '');
    var status = (notice['notice_status'] ?? 'draft').toString();
    final form = GlobalKey<FormState>();
    final firstPublication = notice['published_at'] == null;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text('Update notice ' + notice['notice_code'].toString()),
          content: Form(key: form, child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              initialValue: status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                DropdownMenuItem(value: 'draft', child: Text('Draft')),
                DropdownMenuItem(value: 'published', child: Text('Published')),
                DropdownMenuItem(value: 'active', child: Text('Active work')),
                DropdownMenuItem(value: 'completed', child: Text('Completed')),
                DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
              ],
              onChanged: (v) { if (v != null) setDialog(() => status = v); },
            ),
            TextFormField(controller: source, decoration: const InputDecoration(labelText: 'Official source reference'),
              validator: (v) => status != 'draft' && (v == null || v.trim().isEmpty)
                ? 'A source reference is required before publication' : null),
            TextFormField(controller: progress, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Reported progress (0–100)'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final n = int.tryParse(v.trim());
                return n == null || n < 0 || n > 100 ? 'Enter 0–100' : null;
              }),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
            FilledButton(onPressed: () { if (form.currentState!.validate()) Navigator.pop(dialog, true); },
              child: const Text('Save update')),
          ],
        ),
      ),
    );
    if (ok == true) {
      setState(() => saving = true);
      try {
        final sourceValue = source.text.trim();
        final publishedNow = firstPublication && status != 'draft';
        final updated = await supabase.from('public_excavation_notices').update({
          'notice_status': status,
          'source_reference': sourceValue.isEmpty ? null : sourceValue,
          'progress_percent': progress.text.trim().isEmpty ? null : int.parse(progress.text.trim()),
          if (publishedNow) 'published_at': DateTime.now().toUtc().toIso8601String(),
          if (publishedNow) 'published_by': user.id,
        }).eq('id', notice['id'].toString()).select('id').maybeSingle();
        if (updated == null) throw StateError('The database did not confirm the authorised update.');
        final eventType = publishedNow ? 'published'
          : status == 'completed' ? 'work_completed'
          : status == 'cancelled' ? 'notice_cancelled'
          : status == 'active' ? 'work_started' : 'progress_update';
        await supabase.from('public_excavation_notice_events').insert({
          'notice_id': notice['id'].toString(), 'event_type': eventType,
          'title': publishedNow ? 'Notice published' : 'Notice updated: ' + pretty(status),
          'details': 'Recorded by an authorised department account. Source reference: ' + (sourceValue.isEmpty ? 'not provided' : sourceValue),
          'progress_percent': progress.text.trim().isEmpty ? null : int.parse(progress.text.trim()),
          'created_by': user.id,
        });
        toast(publishedNow ? 'Notice published with its source reference.' : 'Notice and timeline updated.');
        await refresh();
      } catch (e) {
        toast('Notice update failed: ' + e.toString());
        await refresh();
      } finally {
        if (mounted) setState(() => saving = false);
      }
    }
    source.dispose();
    progress.dispose();
  }

  Future<void> reviewReport(Map<String, dynamic> report) async {
    if (saving) return;
    var status = (report['report_status'] ?? 'submitted').toString();
    String? assigned = report['assigned_department_id']?.toString();
    final oldAssigned = assigned;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Review obstruction report'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Area: ' + (report['area_label'] ?? 'Not specified').toString()),
            DropdownButtonFormField<String>(
              initialValue: status,
              decoration: const InputDecoration(labelText: 'Review status'),
              items: const [
                DropdownMenuItem(value: 'submitted', child: Text('Submitted')),
                DropdownMenuItem(value: 'acknowledged', child: Text('Acknowledged')),
                DropdownMenuItem(value: 'in_progress', child: Text('In progress')),
                DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                DropdownMenuItem(value: 'dismissed', child: Text('Dismissed')),
              ],
              onChanged: (v) { if (v != null) setDialog(() => status = v); },
            ),
            if (!widget.isDepartment)
              DropdownButtonFormField<String>(
                initialValue: assigned,
                decoration: const InputDecoration(labelText: 'Assign department'),
                items: [
                  const DropdownMenuItem<String>(value: null, child: Text('Unassigned')),
                  ...departments.map((d) => DropdownMenuItem<String>(
                    value: d['id'].toString(), child: Text(d['name'].toString()))),
                ],
                onChanged: (v) => setDialog(() => assigned = v),
              )
            else
              Align(alignment: Alignment.centerLeft, child: Text('Assigned to: ' + departmentName(assigned))),
            const SizedBox(height: 6),
             Text('This list excludes reporter identity. Reports are visible only to the reporter and authorised reviewers.',
              style: TextStyle(fontSize: 10, color: mutedInk)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Save review')),
          ],
        ),
      ),
    );
    if (ok == true) {
      setState(() => saving = true);
      try {
        final changes = <String, dynamic>{'report_status': status};
        if (!widget.isDepartment) changes['assigned_department_id'] = assigned;
        final updated = await supabase.from('public_obstruction_reports').update(changes)
          .eq('id', report['id'].toString()).select('id').maybeSingle();
        if (updated == null) throw StateError('The database did not confirm an authorised report update.');
        toast(oldAssigned != assigned && !widget.isDepartment
          ? 'Report assignment and status saved.' : 'Report status updated.');
        await refresh();
      } catch (e) {
        toast('Report review failed: ' + e.toString());
      } finally {
        if (mounted) setState(() => saving = false);
      }
    }
  }

  Widget _sectionTitle(String value) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 5),
    child: Text(value, style:  TextStyle(color: cyanAccent, fontSize: 10,
      letterSpacing: .8, fontWeight: FontWeight.w900)),
  );

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: panelNavy, borderRadius: BorderRadius.circular(17),
      border: Border.all(color: borderColor)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
         Icon(Icons.campaign_outlined, color: cyanAccent, size: 19),
        const SizedBox(width: 8),
        const Expanded(child: Text('Public works publishing & review',
          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800))),
        IconButton(onPressed: loading ? null : refresh, icon:  Icon(Icons.refresh, color: cyanAccent)),
      ]),
       Text('Create department-owned drafts, publish source-backed notices, update work timelines and review reports using existing RLS rules.',
        style: TextStyle(color: mutedInk, fontSize: 10, height: 1.35)),
      const SizedBox(height: 8),
      SizedBox(width: double.infinity, child: FilledButton.icon(
        onPressed: saving || loading ? null : createNotice,
        icon: const Icon(Icons.add_circle_outline), label: const Text('CREATE NOTICE DRAFT'),
        style: FilledButton.styleFrom(backgroundColor: electricBlue, foregroundColor: Colors.white))),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 8),
        child: Text(error!, style: const TextStyle(color: Color(0xFFFFB4AB), fontSize: 10))),
      if (loading && notices.isEmpty && reports.isEmpty)
         Padding(padding: EdgeInsets.all(14), child: Center(child: CircularProgressIndicator(color: cyanAccent))),
      _sectionTitle('WORK / NO-DIG NOTICES'),
      if (notices.isEmpty)  Text('No notices are visible to this account. This does not imply that no public work is taking place.',
        style: TextStyle(color: mutedInk, fontSize: 10)),
      ...notices.map((notice) => Container(
        margin: const EdgeInsets.only(top: 7), padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(11),
          border: Border.all(color: borderColor)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text((notice['notice_code'] ?? 'Notice').toString(),
              style:  TextStyle(color: cyanAccent, fontSize: 10, fontWeight: FontWeight.w900))),
            Text(pretty((notice['notice_status'] ?? 'draft').toString()),
              style: const TextStyle(color: Color(0xFFF3C969), fontSize: 9, fontWeight: FontWeight.w900)),
          ]),
          Text((notice['title'] ?? 'Public works notice').toString(),
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
          Text((notice['city'] ?? '').toString() + ' · ' + (notice['responsible_department_name'] ?? 'Department not listed').toString(),
            style:  TextStyle(color: mutedInk, fontSize: 10)),
          Text('Source: ' + (notice['source_reference'] ?? 'Not yet recorded').toString(),
            style:  TextStyle(color: mutedInk, fontSize: 9)),
          Align(alignment: Alignment.centerRight, child: TextButton.icon(
            onPressed: saving ? null : () => editNotice(notice),
            icon: const Icon(Icons.edit_outlined, size: 15), label: const Text('Update / publish'))),
        ]),
      )),
       Divider(color: borderColor, height: 22),
      _sectionTitle('CITIZEN OBSTRUCTION REPORTS'),
      if (reports.isEmpty)  Text('No obstruction reports are visible to this account. Reports remain private to the reporter and authorised reviewers.',
        style: TextStyle(color: mutedInk, fontSize: 10)),
      ...reports.map((report) => Container(
        margin: const EdgeInsets.only(top: 7), padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(11),
          border: Border.all(color: borderColor)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(pretty((report['report_type'] ?? 'other').toString()),
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900))),
            Text(pretty((report['report_status'] ?? 'submitted').toString()),
              style: const TextStyle(color: Color(0xFFF3C969), fontSize: 9, fontWeight: FontWeight.w900)),
          ]),
          Text((report['area_label'] ?? '').toString() + ' · ' + (report['city'] ?? '').toString(),
            style:  TextStyle(color: cyanAccent, fontSize: 10)),
          Text((report['details'] ?? '').toString(), maxLines: 3, overflow: TextOverflow.ellipsis,
            style:  TextStyle(color: mutedInk, fontSize: 10)),
          Text('Assigned: ' + departmentName(report['assigned_department_id']?.toString()),
            style:  TextStyle(color: mutedInk, fontSize: 9)),
          Align(alignment: Alignment.centerRight, child: TextButton.icon(
            onPressed: saving ? null : () => reviewReport(report),
            icon: const Icon(Icons.fact_check_outlined, size: 15), label: const Text('Review report'))),
        ]),
      )),
      const SizedBox(height: 8),
       Text('A public notice or no-dig notice is not an excavation permit or underground-utility clearance.',
        style: TextStyle(color: mutedInk, fontSize: 9, height: 1.4)),
    ]),
  );
}


class RoadCutPermitBoard extends StatefulWidget {
  final List<Map<String, dynamic>> requests;
  final List<Map<String, dynamic>> departments;
  final bool isDepartment;
  final String? departmentId;

  const RoadCutPermitBoard({
    super.key,
    required this.requests,
    required this.departments,
    required this.isDepartment,
    this.departmentId,
  });

  @override
  State<RoadCutPermitBoard> createState() => _RoadCutPermitBoardState();
}

class _RoadCutPermitBoardState extends State<RoadCutPermitBoard> {
  List<Map<String, dynamic>> records = [];
  bool loading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    if (!mounted) return;
    setState(() { loading = true; errorMessage = ''; });
    try {
      final rows = await supabase.from('road_cut_permit_compliance')
          .select().order('updated_at', ascending: false).limit(100);
      if (!mounted) return;
      setState(() {
        records = List<Map<String, dynamic>>.from(rows);
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorMessage = 'Permit records could not be loaded for this account.';
      });
    }
  }

  String _requestLabel(String id) {
    for (final r in widget.requests) {
      if (r['id'].toString() == id) {
        final number = r['request_number']?.toString() ?? '';
        final title = (r['title'] ?? r['road_name'] ?? 'Infrastructure case').toString();
        return number.isEmpty ? title : 'Case #' + number + ' · ' + title;
      }
    }
    return 'Case ' + (id.length > 8 ? id.substring(0, 8) : id);
  }

  String _departmentLabel(String id) {
    for (final d in widget.departments) {
      if (d['id'].toString() == id) return (d['name'] ?? 'Department').toString();
    }
    return widget.isDepartment ? 'Your assigned department' : 'Department';
  }

  String _pretty(String value) => value.replaceAll('_', ' ').toUpperCase();

  Color _stateColor(String state) {
    if (state == 'closed' || state == 'not_required') return const Color(0xFF25845C);
    if (['restoration_overdue','permit_expired','revoked','work_outside_permit_window'].contains(state)) {
      return const Color(0xFFB54747);
    }
    if (['restoration_due_soon','awaiting_permit','suspended','review_required'].contains(state)) {
      return const Color(0xFFB7791F);
    }
    return const Color(0xFF3978B8);
  }

  DateTime? _date(String value) =>
      value.trim().isEmpty ? null : DateTime.tryParse(value.trim());

  String? _asDate(DateTime? value) {
    if (value == null) return null;
    return value.year.toString().padLeft(4, '0') + '-' +
        value.month.toString().padLeft(2, '0') + '-' +
        value.day.toString().padLeft(2, '0');
  }

  String? _asTimestamp(DateTime? value) {
    if (value == null) return null;
    return DateTime.utc(value.year, value.month, value.day).toIso8601String();
  }

  Future<void> _editRecord({Map<String, dynamic>? existing}) async {
    final user = supabase.auth.currentUser;
    if (user == null) { _message('Please sign in again.'); return; }
    if (widget.requests.isEmpty) { _message('No accessible cases are available.'); return; }

    final ids = widget.requests.map((r) => r['id'].toString()).toSet();
    var requestId = existing?['request_id']?.toString();
    if (requestId == null || !ids.contains(requestId)) requestId = widget.requests.first['id'].toString();
    var departmentId = existing?['responsible_department_id']?.toString()
        ?? widget.departmentId
        ?? (widget.departments.isNotEmpty ? widget.departments.first['id'].toString() : null);
    var status = (existing?['permit_status'] ?? 'pending').toString();
    var traffic = existing?['traffic_management_confirmed'] == true;
    var clearance = existing?['utility_clearance_confirmed'] == true;
    var safety = existing?['road_safety_plan_confirmed'] == true;
    var saving = false;

    final reference = TextEditingController(text: existing?['permit_reference']?.toString() ?? '');
    final authority = TextEditingController(text: existing?['issuing_authority']?.toString() ?? '');
    final fromText = TextEditingController(text: existing?['permit_valid_from']?.toString() ?? '');
    final untilText = TextEditingController(text: existing?['permit_valid_until']?.toString() ?? '');
    final dueText = TextEditingController(text: existing?['restoration_due_date']?.toString() ?? '');
    final startedText = TextEditingController(text: existing?['work_started_at'] == null ? '' : existing!['work_started_at'].toString().substring(0, 10));
    final completedText = TextEditingController(text: existing?['work_completed_at'] == null ? '' : existing!['work_completed_at'].toString().substring(0, 10));
    final notes = TextEditingController(text: existing?['notes']?.toString() ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Register road-cut permit' : 'Update road-cut permit'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: requestId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Linked infrastructure case'),
                    items: widget.requests.map((r) => DropdownMenuItem<String>(
                      value: r['id'].toString(),
                      child: Text('Case #' + (r['request_number']?.toString() ?? '') + ' · ' +
                          (r['title'] ?? r['road_name'] ?? 'Infrastructure case').toString(),
                          overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (v) => setDialogState(() => requestId = v),
                  ),
                  const SizedBox(height: 8),
                  if (widget.isDepartment)
                    Text('Responsible department: ' + (widget.departmentId ?? 'Not assigned'),
                      style:  TextStyle(fontSize: 12, color: mutedInk))
                  else
                    DropdownButtonFormField<String>(
                      initialValue: departmentId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Responsible department'),
                      items: widget.departments.map((d) => DropdownMenuItem<String>(
                        value: d['id'].toString(),
                        child: Text((d['name'] ?? 'Department').toString()),
                      )).toList(),
                      onChanged: (v) => setDialogState(() => departmentId = v),
                    ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Permit status'),
                    items: const [
                      DropdownMenuItem(value: 'pending', child: Text('Pending approval')),
                      DropdownMenuItem(value: 'issued', child: Text('Issued / active')),
                      DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
                      DropdownMenuItem(value: 'expired', child: Text('Expired')),
                      DropdownMenuItem(value: 'revoked', child: Text('Revoked')),
                      DropdownMenuItem(value: 'not_required', child: Text('Permit not required')),
                      DropdownMenuItem(value: 'closed', child: Text('Closed after restoration')),
                    ],
                    onChanged: (v) => setDialogState(() => status = v ?? status),
                  ),
                  TextField(controller: reference, decoration: const InputDecoration(labelText: 'Permit / approval reference')),
                  TextField(controller: authority, decoration: const InputDecoration(labelText: 'Issuing road authority')),
                  const SizedBox(height: 8),
                  const Text('Dates (YYYY-MM-DD)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  Row(children: [
                    Expanded(child: TextField(controller: fromText, decoration: const InputDecoration(labelText: 'Valid from'))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: untilText, decoration: const InputDecoration(labelText: 'Valid until'))),
                  ]),
                  TextField(controller: dueText, decoration: const InputDecoration(labelText: 'Restoration deadline')),
                  Row(children: [
                    Expanded(child: TextField(controller: startedText, decoration: const InputDecoration(labelText: 'Work started'))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: completedText, decoration: const InputDecoration(labelText: 'Work completed'))),
                  ]),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero, dense: true, value: traffic,
                    onChanged: (v) => setDialogState(() => traffic = v ?? false),
                    title: const Text('Traffic management arrangements confirmed'),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero, dense: true, value: clearance,
                    onChanged: (v) => setDialogState(() => clearance = v ?? false),
                    title: const Text('Utility-owner clearance confirmed'),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero, dense: true, value: safety,
                    onChanged: (v) => setDialogState(() => safety = v ?? false),
                    title: const Text('Road safety plan confirmed'),
                  ),
                  TextField(controller: notes, minLines: 2, maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Conditions, exemption reason or notes')),
                  const SizedBox(height: 8),
                   Text('The competent road authority determines permit requirements and statutory conditions.',
                    style: TextStyle(fontSize: 11, color: mutedInk)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: saving ? null : () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel')),
            FilledButton(
              onPressed: saving ? null : () async {
                if (requestId == null || departmentId == null || departmentId!.isEmpty) {
                  _message('Select a case and responsible department.'); return;
                }
                final from = _date(fromText.text);
                final until = _date(untilText.text);
                final due = _date(dueText.text);
                final started = _date(startedText.text);
                final completed = _date(completedText.text);
                final invalid = (fromText.text.trim().isNotEmpty && from == null) ||
                    (untilText.text.trim().isNotEmpty && until == null) ||
                    (dueText.text.trim().isNotEmpty && due == null) ||
                    (startedText.text.trim().isNotEmpty && started == null) ||
                    (completedText.text.trim().isNotEmpty && completed == null);
                if (invalid) { _message('Enter dates in YYYY-MM-DD format.'); return; }
                if (from != null && until != null && until.isBefore(from)) {
                  _message('Permit expiry cannot be before its start date.'); return;
                }
                if (from != null && due != null && due.isBefore(from)) {
                  _message('Restoration deadline cannot be before permit start.'); return;
                }
                if (started != null && completed != null && completed.isBefore(started)) {
                  _message('Completion date cannot be before work started.'); return;
                }
                if (['issued','suspended','expired','revoked','closed'].contains(status) &&
                    (reference.text.trim().isEmpty || authority.text.trim().isEmpty || from == null || until == null)) {
                  _message('This status requires a permit reference, authority and validity dates.'); return;
                }
                if (status == 'not_required' && notes.text.trim().isEmpty) {
                  _message('Record the reason why a permit is not required.'); return;
                }
                if (status == 'closed' && completed == null) {
                  _message('Enter the work completion date before closing the permit.'); return;
                }

                setDialogState(() => saving = true);
                final payload = <String, dynamic>{
                  'permit_status': status,
                  'permit_reference': reference.text.trim().isEmpty ? null : reference.text.trim(),
                  'issuing_authority': authority.text.trim().isEmpty ? null : authority.text.trim(),
                  'permit_valid_from': _asDate(from),
                  'permit_valid_until': _asDate(until),
                  'restoration_due_date': _asDate(due),
                  'work_started_at': _asTimestamp(started),
                  'work_completed_at': _asTimestamp(completed),
                  'traffic_management_confirmed': traffic,
                  'utility_clearance_confirmed': clearance,
                  'road_safety_plan_confirmed': safety,
                  'notes': notes.text.trim().isEmpty ? null : notes.text.trim(),
                  'updated_by': user.id,
                };
                try {
                  if (existing == null) {
                    await supabase.from('road_cut_permit_records').insert({
                      ...payload, 'request_id': requestId,
                      'responsible_department_id': departmentId, 'created_by': user.id,
                    });
                  } else {
                    await supabase.from('road_cut_permit_records')
                        .update(payload).eq('id', existing['id'].toString());
                  }
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop(true);
                } catch (_) {
                  setDialogState(() => saving = false);
                  _message('Unable to save. Check assignment, dates and restoration acceptance requirements.');
                }
              },
              child: saving ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save permit record'),
            ),
          ],
        ),
      ),
    );

    reference.dispose(); authority.dispose(); fromText.dispose(); untilText.dispose();
    dueText.dispose(); startedText.dispose(); completedText.dispose(); notes.dispose();
    if (saved == true) {
      await _loadRecords();
      _message('Road-cut permit record saved.');
    }
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
             Icon(Icons.fact_check_outlined, color: teal),
            const SizedBox(width: 9),
             Expanded(child: Text('Road-cut permits & deadline compliance',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: ink))),
            IconButton(onPressed: loading ? null : _loadRecords,
              icon: const Icon(Icons.refresh), tooltip: 'Refresh permit records'),
          ]),
           Text('Track permit references, validity windows, utility clearance, road safety and restoration deadlines.',
            style: TextStyle(fontSize: 11, color: mutedInk)),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: widget.requests.isEmpty ? null : () => _editRecord(),
            icon: const Icon(Icons.add), label: const Text('REGISTER ROAD-CUT PERMIT'))),
          const SizedBox(height: 8),
          if (loading)
            const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
          else if (errorMessage.isNotEmpty)
            Text(errorMessage, style: const TextStyle(fontSize: 12, color: Colors.red))
          else if (records.isEmpty)
             Text('No permit records have been entered yet.',
              style: TextStyle(fontSize: 12, color: mutedInk))
          else
            ...records.map((record) {
              final state = (record['compliance_state'] ?? 'review_required').toString();
              final req = record['request_id'].toString();
              final dept = record['responsible_department_id'].toString();
              final days = record['days_to_restoration_due'];
              final dueLabel = days == null ? (record['restoration_due_date']?.toString() ?? 'No deadline')
                  : days is num && days < 0 ? days.abs().toString() + ' day(s) overdue'
                  : days == 0 ? 'Due today' : 'Due in ' + days.toString() + ' day(s)';
              return Container(
                margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFF7FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE4EAF1))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(_requestLabel(req),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: _stateColor(state).withOpacity(.12),
                        borderRadius: BorderRadius.circular(20)),
                      child: Text(_pretty(state), style: TextStyle(color: _stateColor(state),
                        fontSize: 9, fontWeight: FontWeight.w800))),
                  ]),
                  const SizedBox(height: 5),
                  Text(_departmentLabel(dept) + ' · ' + _pretty((record['permit_status'] ?? '').toString()),
                    style:  TextStyle(fontSize: 10, color: mutedInk)),
                  Text('Restoration: ' + dueLabel + ' · Permit expiry: ' +
                    (record['permit_valid_until']?.toString() ?? 'Not recorded'),
                    style:  TextStyle(fontSize: 11, color: ink)),
                  Align(alignment: Alignment.centerRight, child: TextButton.icon(
                    onPressed: () => _editRecord(existing: record),
                    icon: const Icon(Icons.edit_outlined, size: 15), label: const Text('UPDATE'))),
                ]),
              );
            }),
        ]),
      ),
    );
  }
}


class RoadWorkScheduleBoard extends StatefulWidget {
  const RoadWorkScheduleBoard({super.key});

  @override
  State<RoadWorkScheduleBoard> createState() => _RoadWorkScheduleBoardState();
}

class _RoadWorkScheduleBoardState extends State<RoadWorkScheduleBoard> {
  List<Map<String, dynamic>> rows = [];
  bool loading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { loading = true; errorMessage = ''; });
    try {
      final result = await supabase.from('road_work_schedule_advisories')
          .select().order('planned_start_date', ascending: true).limit(100);
      if (!mounted) return;
      setState(() {
        rows = List<Map<String, dynamic>>.from(result);
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorMessage = 'Road-work schedule could not be loaded for this account.';
      });
    }
  }

  String _stateLabel(String state) => state.replaceAll('_', ' ').toUpperCase();

  Color _stateColor(String state) {
    if (state == 'road_window_overlap' || state == 'invalid_window' || state == 'past_due') {
      return const Color(0xFFB54747);
    }
    if (state == 'dates_missing') return const Color(0xFFB7791F);
    if (state == 'closed') return const Color(0xFF25845C);
    return const Color(0xFF3978B8);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
             Icon(Icons.calendar_month_outlined, color: teal),
            const SizedBox(width: 9),
             Expanded(child: Text('Coordinated road-work schedule',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: ink))),
            IconButton(onPressed: loading ? null : _load,
              icon: const Icon(Icons.refresh), tooltip: 'Refresh road schedule'),
          ]),
           Text('Compare planned work windows on the same road and city. Update dates in the linked case record.',
            style: TextStyle(fontSize: 11, color: mutedInk)),
          const SizedBox(height: 8),
          if (loading)
            const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
          else if (errorMessage.isNotEmpty)
            Text(errorMessage, style: const TextStyle(fontSize: 12, color: Colors.red))
          else if (rows.isEmpty)
             Text('No accessible road-work schedules are available.',
              style: TextStyle(fontSize: 12, color: mutedInk))
          else
            ...rows.map((row) {
              final state = (row['schedule_state'] ?? 'dates_missing').toString();
              final number = row['request_number']?.toString() ?? '';
              final road = (row['road_name'] ?? 'Road not specified').toString();
              final city = (row['city'] ?? '').toString();
              final start = row['planned_start_date']?.toString() ?? 'Start not set';
              final end = row['planned_end_date']?.toString() ?? 'End not set';
              final department = (row['department_name'] ?? 'Unassigned').toString();
              final rawOverlaps = row['overlapping_request_numbers'];
              final overlapText = rawOverlaps is List
                  ? rawOverlaps.map((v) => v.toString()).join(', ')
                  : '';
              final days = row['days_until_start'];
              final startLabel = days == null ? start
                  : days is num && days < 0 ? days.abs().toString() + ' day(s) since planned start'
                  : days == 0 ? 'Starts today'
                  : 'Starts in ' + days.toString() + ' day(s)';
              return Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFF7FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE4EAF1))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text('Case #' + number + ' · ' + road,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: _stateColor(state).withOpacity(.12),
                        borderRadius: BorderRadius.circular(20)),
                      child: Text(_stateLabel(state),
                        style: TextStyle(color: _stateColor(state), fontSize: 9, fontWeight: FontWeight.w800)),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text(city + ' · ' + department,
                    style:  TextStyle(fontSize: 10, color: mutedInk)),
                  Text(start + ' → ' + end + ' · ' + startLabel,
                    style:  TextStyle(fontSize: 11, color: ink)),
                  if (overlapText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Overlapping case numbers: ' + overlapText,
                        style: const TextStyle(fontSize: 11, color: Color(0xFFB54747),
                          fontWeight: FontWeight.w700)),
                    ),
                ]),
              );
            }),
        ]),
      ),
    );
  }
}

class RoadRestorationBoard extends StatefulWidget {
  final List<Map<String, dynamic>> requests;
  final List<Map<String, dynamic>> departments;
  final bool isDepartment;
  final String? departmentId;

  const RoadRestorationBoard({
    super.key,
    required this.requests,
    required this.departments,
    required this.isDepartment,
    this.departmentId,
  });

  @override
  State<RoadRestorationBoard> createState() => _RoadRestorationBoardState();
}

class _RoadRestorationBoardState extends State<RoadRestorationBoard> {
  List<Map<String, dynamic>> records = [];
  bool loading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      errorMessage = '';
    });
    try {
      final rows = await supabase
          .from('road_restoration_records')
          .select()
          .order('updated_at', ascending: false)
          .limit(100);
      if (!mounted) return;
      setState(() {
        records = List<Map<String, dynamic>>.from(rows);
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorMessage = 'Restoration records could not be loaded for this account.';
      });
    }
  }

  String _requestLabel(String requestId) {
    for (final request in widget.requests) {
      if (request['id'].toString() == requestId) {
        final number = request['request_number']?.toString();
        final title = (request['title'] ?? request['road_name'] ?? 'Infrastructure case').toString();
        return number == null ? title : 'Case #$number · $title';
      }
    }
    final shortId = requestId.length > 8 ? requestId.substring(0, 8) : requestId;
    return 'Case $shortId';
  }

  String _departmentLabel(String departmentId) {
    for (final department in widget.departments) {
      if (department['id'].toString() == departmentId) {
        return (department['name'] ?? 'Department').toString();
      }
    }
    return widget.isDepartment ? 'Your assigned department' : 'Department';
  }

  String _pretty(String value) => value.replaceAll('_', ' ').toUpperCase();

  Color _statusColor(String value) {
    switch (value) {
      case 'accepted':
        return const Color(0xFF25845C);
      case 'rework_required':
        return const Color(0xFFB54747);
      case 'awaiting_inspection':
        return const Color(0xFFB7791F);
      case 'in_progress':
        return const Color(0xFF3978B8);
      default:
        return const Color(0xFF64748B);
    }
  }

  double? _optionalNumber(String value) {
    if (value.trim().isEmpty) return null;
    return double.tryParse(value.trim());
  }

  Future<void> _editRecord({Map<String, dynamic>? existing}) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      _showMessage('Please sign in again.');
      return;
    }
    if (widget.requests.isEmpty) {
      _showMessage('No accessible cases are available to link to a restoration record.');
      return;
    }

    final requestIds = widget.requests.map((r) => r['id'].toString()).toSet();
    var selectedRequestId = existing?['request_id']?.toString();
    if (selectedRequestId == null || !requestIds.contains(selectedRequestId)) {
      selectedRequestId = widget.requests.first['id'].toString();
    }

    var selectedDepartmentId = existing?['responsible_department_id']?.toString()
        ?? widget.departmentId
        ?? (widget.departments.isNotEmpty ? widget.departments.first['id'].toString() : null);
    var surface = (existing?['road_surface_type'] ?? 'bituminous').toString();
    var status = (existing?['restoration_status'] ?? 'planned').toString();
    var inspection = (existing?['inspection_outcome'] ?? 'not_inspected').toString();
    var compaction = existing?['compaction_verified'] == true;
    var drainage = existing?['drainage_clear'] == true;
    var saving = false;

    final cutLength = TextEditingController(text: existing?['cut_length_m']?.toString() ?? '');
    final cutWidth = TextEditingController(text: existing?['cut_width_m']?.toString() ?? '');
    final restoredLength = TextEditingController(text: existing?['restored_length_m']?.toString() ?? '');
    final restoredWidth = TextEditingController(text: existing?['restored_width_m']?.toString() ?? '');
    final method = TextEditingController(text: existing?['restoration_method']?.toString() ?? '');
    final plannedDate = TextEditingController(text: existing?['planned_restore_date']?.toString() ?? '');
    final notes = TextEditingController(text: existing?['surface_quality_notes']?.toString() ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(existing == null ? 'Record road restoration' : 'Update road restoration'),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: selectedRequestId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Linked case'),
                        items: widget.requests.map((request) {
                          final number = request['request_number']?.toString() ?? '';
                          final title = (request['title'] ?? request['road_name'] ?? 'Infrastructure case').toString();
                          return DropdownMenuItem<String>(
                            value: request['id'].toString(),
                            child: Text(number.isEmpty ? title : 'Case #$number · $title',
                              overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (value) => setDialogState(() => selectedRequestId = value),
                      ),
                      const SizedBox(height: 10),
                      if (widget.isDepartment)
                        Text('Responsible department: ${widget.departmentId ?? 'Not assigned'}',
                          style:  TextStyle(fontSize: 12, color: mutedInk))
                      else
                        DropdownButtonFormField<String>(
                          initialValue: selectedDepartmentId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Responsible department'),
                          items: widget.departments.map((department) => DropdownMenuItem<String>(
                            value: department['id'].toString(),
                            child: Text((department['name'] ?? 'Department').toString()),
                          )).toList(),
                          onChanged: (value) => setDialogState(() => selectedDepartmentId = value),
                        ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: surface,
                        decoration: const InputDecoration(labelText: 'Road surface type'),
                        items: const [
                          DropdownMenuItem(value: 'bituminous', child: Text('Bituminous / asphalt')),
                          DropdownMenuItem(value: 'concrete', child: Text('Concrete')),
                          DropdownMenuItem(value: 'interlocking_pavers', child: Text('Interlocking pavers')),
                          DropdownMenuItem(value: 'gravel', child: Text('Gravel')),
                          DropdownMenuItem(value: 'earthen', child: Text('Earthen')),
                          DropdownMenuItem(value: 'other', child: Text('Other')),
                        ],
                        onChanged: (value) => setDialogState(() => surface = value ?? surface),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        decoration: const InputDecoration(labelText: 'Restoration status'),
                        items: const [
                          DropdownMenuItem(value: 'planned', child: Text('Planned')),
                          DropdownMenuItem(value: 'in_progress', child: Text('In progress')),
                          DropdownMenuItem(value: 'awaiting_inspection', child: Text('Awaiting inspection')),
                          DropdownMenuItem(value: 'accepted', child: Text('Accepted')),
                          DropdownMenuItem(value: 'rework_required', child: Text('Rework required')),
                        ],
                        onChanged: (value) => setDialogState(() => status = value ?? status),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: inspection,
                        decoration: const InputDecoration(labelText: 'Final inspection outcome'),
                        items: const [
                          DropdownMenuItem(value: 'not_inspected', child: Text('Not inspected')),
                          DropdownMenuItem(value: 'accepted', child: Text('Accepted')),
                          DropdownMenuItem(value: 'rework_required', child: Text('Rework required')),
                        ],
                        onChanged: (value) => setDialogState(() => inspection = value ?? inspection),
                      ),
                      const SizedBox(height: 8),
                      const Text('Measured dimensions (optional, metres)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      Row(children: [
                        Expanded(child: TextField(controller: cutLength, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Cut length'))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: cutWidth, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Cut width'))),
                      ]),
                      Row(children: [
                        Expanded(child: TextField(controller: restoredLength, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Restored length'))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: restoredWidth, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Restored width'))),
                      ]),
                      TextField(controller: plannedDate, decoration: const InputDecoration(labelText: 'Planned restoration date', hintText: 'YYYY-MM-DD')),
                      TextField(controller: method, decoration: const InputDecoration(labelText: 'Restoration method')),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: compaction,
                        onChanged: (value) => setDialogState(() => compaction = value ?? false),
                        title: const Text('Compaction / surface preparation verified'),
                        dense: true,
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: drainage,
                        onChanged: (value) => setDialogState(() => drainage = value ?? false),
                        title: const Text('Drainage path is clear'),
                        dense: true,
                      ),
                      TextField(
                        controller: notes,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Surface quality / inspection notes',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                       Text('Acceptance is blocked until inspection, compaction and drainage checks pass.',
                        style: TextStyle(fontSize: 11, color: mutedInk)),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving ? null : () async {
                    if (selectedRequestId == null || selectedDepartmentId == null || selectedDepartmentId!.isEmpty) {
                      _showMessage('Select a case and responsible department.');
                      return;
                    }
                    if (plannedDate.text.trim().isNotEmpty &&
                        DateTime.tryParse(plannedDate.text.trim()) == null) {
                      _showMessage('Enter the planned date as YYYY-MM-DD.');
                      return;
                    }
                    final cutLengthValue = _optionalNumber(cutLength.text);
                    final cutWidthValue = _optionalNumber(cutWidth.text);
                    final restoredLengthValue = _optionalNumber(restoredLength.text);
                    final restoredWidthValue = _optionalNumber(restoredWidth.text);
                    if ((cutLength.text.trim().isNotEmpty && cutLengthValue == null) ||
                        (cutWidth.text.trim().isNotEmpty && cutWidthValue == null) ||
                        (restoredLength.text.trim().isNotEmpty && restoredLengthValue == null) ||
                        (restoredWidth.text.trim().isNotEmpty && restoredWidthValue == null)) {
                      _showMessage('Enter valid numeric dimensions in metres.');
                      return;
                    }
                    if (status == 'accepted' &&
                        (inspection != 'accepted' || !compaction || !drainage)) {
                      _showMessage('Acceptance requires a passed inspection, compaction verification and clear drainage.');
                      return;
                    }
                    if (status == 'rework_required' && inspection != 'rework_required') {
                      _showMessage('Select “Rework required” as the inspection outcome.');
                      return;
                    }
                    if (inspection == 'accepted' && status != 'accepted') {
                      _showMessage('Set the restoration status to Accepted after a passed inspection.');
                      return;
                    }
                    if (inspection == 'rework_required' && status != 'rework_required') {
                      _showMessage('Set the restoration status to Rework required.');
                      return;
                    }
                    if (inspection != 'not_inspected' && notes.text.trim().isEmpty) {
                      _showMessage('Add inspection notes before recording an inspection outcome.');
                      return;
                    }

                    setDialogState(() => saving = true);
                    try {
                      await supabase.rpc('save_road_restoration_record', params: {
                        'p_request_id': selectedRequestId,
                        'p_responsible_department_id': selectedDepartmentId,
                        'p_road_surface_type': surface,
                        'p_restoration_status': status,
                        'p_cut_length_m': cutLengthValue,
                        'p_cut_width_m': cutWidthValue,
                        'p_restored_length_m': restoredLengthValue,
                        'p_restored_width_m': restoredWidthValue,
                        'p_restoration_method': method.text.trim().isEmpty ? null : method.text.trim(),
                        'p_planned_restore_date': plannedDate.text.trim().isEmpty ? null : plannedDate.text.trim(),
                        'p_inspection_outcome': inspection,
                        'p_compaction_verified': compaction,
                        'p_drainage_clear': drainage,
                        'p_surface_quality_notes': notes.text.trim().isEmpty ? null : notes.text.trim(),
                      });

                      if (dialogContext.mounted) Navigator.of(dialogContext).pop(true);
                    } catch (_) {
                      setDialogState(() => saving = false);
                      _showMessage('Unable to save restoration record. Confirm the case is assigned to the selected department.');
                    }
                  },
                  child: saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save record'),
                ),
              ],
            );
          },
        );
      },
    );

    cutLength.dispose();
    cutWidth.dispose();
    restoredLength.dispose();
    restoredWidth.dispose();
    method.dispose();
    plannedDate.dispose();
    notes.dispose();

    if (saved == true) {
      await _loadRecords();
      _showMessage('Road restoration record saved.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
               Icon(Icons.construction_outlined, color: teal),
              const SizedBox(width: 9),
               Expanded(child: Text('Road restoration & quality assurance',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: ink))),
              IconButton(onPressed: loading ? null : _loadRecords,
                icon: const Icon(Icons.refresh), tooltip: 'Refresh restoration records'),
            ]),
             Text('Track reinstatement after road openings, inspect the restored surface and drainage, and record accepted work or required rework.',
              style: TextStyle(fontSize: 11, color: mutedInk)),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: widget.requests.isEmpty ? null : () => _editRecord(),
                icon: const Icon(Icons.add),
                label: const Text('RECORD RESTORATION'),
              ),
            ),
            const SizedBox(height: 8),
            if (loading)
              const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
            else if (errorMessage.isNotEmpty)
              Text(errorMessage, style: const TextStyle(fontSize: 12, color: Colors.red))
            else if (records.isEmpty)
               Text('No restoration records have been entered yet.',
                style: TextStyle(fontSize: 12, color: mutedInk))
            else
              ...records.map((record) {
                final state = (record['restoration_status'] ?? 'planned').toString();
                final surfaceName = _pretty((record['road_surface_type'] ?? 'other').toString());
                final outcome = _pretty((record['inspection_outcome'] ?? 'not_inspected').toString());
                final departmentId = record['responsible_department_id'].toString();
                final dimensions = [
                  if (record['restored_length_m'] != null) '${record['restored_length_m']} m length',
                  if (record['restored_width_m'] != null) '${record['restored_width_m']} m width',
                ].join(' · ');
                return Container(
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE4EAF1)),
                  ),
                  child: ListTile(
                    dense: true,
                    onTap: () => _editRecord(existing: record),
                    leading: Icon(Icons.route_outlined, color: _statusColor(state)),
                    title: Text(_requestLabel(record['request_id'].toString()),
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style:  TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ink)),
                    subtitle: Text(
                      '${_departmentLabel(departmentId)} · $surfaceName · inspection: $outcome${dimensions.isEmpty ? '' : ' · $dimensions'}',
                      style:  TextStyle(fontSize: 10, color: mutedInk)),
                    trailing: Icon(Icons.chevron_right, color: _statusColor(state)),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}


class BuildingComplianceInspectionBoard extends StatefulWidget {
  final List<Map<String, dynamic>> requests;
  final List<Map<String, dynamic>> departments;
  final bool isDepartment;
  final String? departmentId;
  const BuildingComplianceInspectionBoard({super.key, required this.requests,
    required this.departments, required this.isDepartment, this.departmentId});
  @override
  State<BuildingComplianceInspectionBoard> createState() => _BuildingComplianceInspectionBoardState();
}

class _BuildingComplianceInspectionBoardState extends State<BuildingComplianceInspectionBoard> {
  List<Map<String, dynamic>> records = [];
  List<Map<String, dynamic>> publicApprovalRecords = [];
  bool loading = true;
  String errorMessage = '';
  List<Map<String, dynamic>> get buildingCases => widget.requests
      .where((r) => (r['case_category'] ?? '').toString() == 'building_planning').toList();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { loading = true; errorMessage = ''; });
    try {
      final rows = await supabase.from('building_compliance_inspections')
          .select().order('inspected_at', ascending: false).limit(100);
      List<Map<String, dynamic>> publishedRows = [];
      try {
        final publicRows = await supabase
            .from('building_approval_public_register_records')
            .select('source_record_id,zone_name,building_type,building_sub_type,plot_area_sqm,approval_status,release_date')
            .eq('source_dataset', 'MCD_NEXGEN_OBPS_PLAN_RELEASE_REPORT_2023')
            .order('release_date', ascending: false)
            .limit(8);
        publishedRows = List<Map<String, dynamic>>.from(publicRows);
      } catch (_) {
        publishedRows = [];
      }
      if (!mounted) return;
      setState(() {
        records = List<Map<String, dynamic>>.from(rows);
        publicApprovalRecords = publishedRows;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { loading = false; errorMessage = 'Building inspection records could not be loaded for this account.'; });
    }
  }

  String _caseLabel(String id) {
    for (final r in widget.requests) {
      if (r['id'].toString() == id) {
        final n = r['request_number']?.toString();
        final t = (r['title'] ?? r['road_name'] ?? 'Building case').toString();
        return n == null ? t : 'Case #' + n + ' · ' + t;
      }
    }
    return 'Case ' + (id.length > 8 ? id.substring(0, 8) : id);
  }

  String _departmentLabel(String id) {
    for (final d in widget.departments) {
      if (d['id'].toString() == id) return (d['name'] ?? 'Department').toString();
    }
    return widget.isDepartment ? 'Assigned department' : 'Department';
  }

  Future<void> _addInspection() async {
    final user = supabase.auth.currentUser;
    if (user == null) { _message('Please sign in again.'); return; }
    final cases = buildingCases;
    if (cases.isEmpty) { _message('No accessible building-planning cases are available.'); return; }

    var requestId = cases.first['id'].toString();
    var departmentId = widget.departmentId ?? cases.first['department_id']?.toString()
        ?? (widget.departments.isNotEmpty ? widget.departments.first['id'].toString() : null);
    var reviewState = 'awaiting_review';
    var saving = false;
    final approval = TextEditingController();
    final authority = TextEditingController();
    final approvedFloors = TextEditingController();
    final observedFloors = TextEditingController();
    final approvedHeight = TextEditingController();
    final observedHeight = TextEditingController();
    final notes = TextEditingController();

    final saved = await showDialog<bool>(context: context, builder: (dialogContext) =>
      StatefulBuilder(builder: (dialogContext, setDialogState) => AlertDialog(
        title: const Text('Record building compliance inspection'),
        content: SizedBox(width: 480, child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              initialValue: requestId, isExpanded: true,
              decoration: const InputDecoration(labelText: 'Building-planning case'),
              items: cases.map((r) {
                final id = r['id'].toString();
                return DropdownMenuItem(value: id, child: Text(_caseLabel(id), overflow: TextOverflow.ellipsis));
              }).toList(),
              onChanged: saving ? null : (v) { if (v != null) setDialogState(() => requestId = v); },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: departmentId, isExpanded: true,
              decoration: const InputDecoration(labelText: 'Responsible department'),
              items: widget.departments.map((d) => DropdownMenuItem<String>(
                value: d['id'].toString(), child: Text((d['name'] ?? 'Department').toString(),
                  overflow: TextOverflow.ellipsis))).toList(),
              onChanged: saving ? null : (v) => setDialogState(() => departmentId = v),
            ),
            TextField(controller: approval, decoration: const InputDecoration(labelText: 'Approval / permit reference')),
            TextField(controller: authority, decoration: const InputDecoration(labelText: 'Issuing authority')),
            TextField(controller: approvedFloors, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Approved floor count')),
            TextField(controller: observedFloors, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Observed floor count *')),
            TextField(controller: approvedHeight, keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Approved height (m)')),
            TextField(controller: observedHeight, keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Observed height (m)')),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: reviewState,
              decoration: const InputDecoration(labelText: 'Inspection review state'),
              items: const [
                DropdownMenuItem(value: 'awaiting_review', child: Text('Awaiting review')),
                DropdownMenuItem(value: 'reviewed_consistent', child: Text('Reviewed — consistent with recorded approval')),
                DropdownMenuItem(value: 'refer_to_authority', child: Text('Refer to competent authority')),
              ],
              onChanged: saving ? null : (v) { if (v != null) setDialogState(() => reviewState = v); },
            ),
            TextField(controller: notes, maxLines: 3,
              decoration: const InputDecoration(labelText: 'Inspection notes / verification limitations')),
            const SizedBox(height: 8),
             Text('A recorded difference is an inspection flag only. It does not establish unlawful construction or replace review by the competent planning authority.',
              style: TextStyle(fontSize: 11, color: mutedInk)),
          ],
        ))),
        actions: [
          TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel')),
          FilledButton(
            onPressed: saving ? null : () async {
              final observed = int.tryParse(observedFloors.text.trim());
              final approved = approvedFloors.text.trim().isEmpty ? null : int.tryParse(approvedFloors.text.trim());
              final aHeight = approvedHeight.text.trim().isEmpty ? null : double.tryParse(approvedHeight.text.trim());
              final oHeight = observedHeight.text.trim().isEmpty ? null : double.tryParse(observedHeight.text.trim());
              if (departmentId == null || departmentId!.isEmpty || observed == null || observed < 0) {
                _message('Select a department and enter a valid observed floor count.'); return;
              }
              if ((approvedFloors.text.trim().isNotEmpty && (approved == null || approved < 0)) ||
                  (approvedHeight.text.trim().isNotEmpty && (aHeight == null || aHeight < 0)) ||
                  (observedHeight.text.trim().isNotEmpty && (oHeight == null || oHeight < 0))) {
                _message('Floor counts and heights must be valid non-negative numbers.'); return;
              }
              if (approved == null && aHeight == null && approval.text.trim().isEmpty) {
                _message('Enter an approval reference, approved floor count, or approved height.'); return;
              }
              setDialogState(() => saving = true);
              try {
                await supabase.from('building_compliance_inspections').insert({
                  'request_id': requestId,
                  'responsible_department_id': departmentId,
                  'approval_reference': approval.text.trim().isEmpty ? null : approval.text.trim(),
                  'issuing_authority': authority.text.trim().isEmpty ? null : authority.text.trim(),
                  'approved_floor_count': approved,
                  'observed_floor_count': observed,
                  'approved_height_m': aHeight,
                  'observed_height_m': oHeight,
                  'review_state': reviewState,
                  'inspection_notes': notes.text.trim().isEmpty ? null : notes.text.trim(),
                  'created_by': user.id,
                });
                if (dialogContext.mounted) Navigator.pop(dialogContext, true);
              } catch (_) {
                setDialogState(() => saving = false);
                _message('Unable to save. Confirm that the case is assigned to the selected department.');
              }
            },
            child: saving ? const SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save inspection'),
          ),
        ],
      )),
    );

    approval.dispose(); authority.dispose(); approvedFloors.dispose(); observedFloors.dispose();
    approvedHeight.dispose(); observedHeight.dispose(); notes.dispose();
    if (saved == true) { await _load(); _message('Building compliance inspection recorded.'); }
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
           Icon(Icons.apartment_outlined, color: teal),
          const SizedBox(width: 9),
           Expanded(child: Text('Building height & floor compliance',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: ink))),
          IconButton(onPressed: loading ? null : _load, icon: const Icon(Icons.refresh)),
        ]),
         Text('Compare observed building details with recorded approval information. Discrepancies require competent-authority verification.',
          style: TextStyle(fontSize: 11, color: mutedInk)),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F7F8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD7E8E9)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
             Text('OFFICIAL PUBLIC APPROVAL REGISTER',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: teal, letterSpacing: 0.6)),
            const SizedBox(height: 4),
             Text('2,015 MCD plan-release records imported · Delhi · 2023',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ink)),
            const SizedBox(height: 3),
             Text('Partial MCD coverage only. The source does not provide approved floor count, building height or verified coordinates.',
              style: TextStyle(fontSize: 10, color: mutedInk)),
            if (publicApprovalRecords.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...publicApprovalRecords.map((record) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                   Icon(Icons.verified_outlined, size: 15, color: teal),
                  const SizedBox(width: 7),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Request #${record['source_record_id'] ?? '—'} · ${record['zone_name'] ?? 'Zone not stated'}',
                      style:  TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ink)),
                    Text('${record['building_type'] ?? 'Building'} · ${record['plot_area_sqm'] ?? '—'} m² plot · ${record['approval_status'] ?? 'Status not stated'} · ${record['release_date'] ?? 'Date not stated'}',
                      style:  TextStyle(fontSize: 10, color: mutedInk)),
                  ])),
                ]),
              )),
            ],
          ]),
        ),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(
          onPressed: buildingCases.isEmpty ? null : _addInspection,
          icon: const Icon(Icons.add), label: const Text('RECORD BUILDING INSPECTION'))),
        const SizedBox(height: 8),
        if (loading) const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
        else if (errorMessage.isNotEmpty) Text(errorMessage, style: const TextStyle(fontSize: 12, color: Colors.red))
        else if (records.isEmpty)  Text('No building inspections have been recorded yet.',
          style: TextStyle(fontSize: 12, color: mutedInk))
        else ...records.map((record) {
          final dept = record['responsible_department_id'].toString();
          final approved = record['approved_floor_count']?.toString() ?? 'Not recorded';
          final observed = record['observed_floor_count']?.toString() ?? 'Not recorded';
          final state = (record['review_state'] ?? 'awaiting_review').toString().replaceAll('_', ' ').toUpperCase();
          final heights = record['approved_height_m'] == null && record['observed_height_m'] == null ? ''
            : ' · height ' + (record['observed_height_m']?.toString() ?? '—') + ' m observed / ' +
              (record['approved_height_m']?.toString() ?? '—') + ' m approved';
          return Container(margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: panelNavy, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_caseLabel(record['request_id'].toString()),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              Text(_departmentLabel(dept) + ' · floors ' + observed + ' observed / ' + approved +
                ' approved' + heights + ' · ' + state,
                style:  TextStyle(fontSize: 10, color: mutedInk)),
              if ((record['approval_reference'] ?? '').toString().isNotEmpty)
                Text('Approval: ' + record['approval_reference'].toString(),
                  style:  TextStyle(fontSize: 10, color: ink)),
              if ((record['inspection_notes'] ?? '').toString().isNotEmpty)
                Text(record['inspection_notes'].toString(), style:  TextStyle(fontSize: 10, color: ink)),
            ]));
        }),
      ],
    )));
  }
}

class DrainageInspectionBoard extends StatefulWidget {
  final List<Map<String, dynamic>> requests;
  final List<Map<String, dynamic>> departments;
  final bool isDepartment;
  final String? departmentId;

  const DrainageInspectionBoard({super.key, required this.requests,
    required this.departments, required this.isDepartment, this.departmentId});

  @override
  State<DrainageInspectionBoard> createState() => _DrainageInspectionBoardState();
}

class _DrainageInspectionBoardState extends State<DrainageInspectionBoard> {
  List<Map<String, dynamic>> records = [];
  bool loading = true;
  String errorMessage = '';

  List<Map<String, dynamic>> get drainageCases => widget.requests.where((r) =>
      (r['case_category'] ?? '').toString() == 'stormwater_drainage').toList();

  @override
  void initState() { super.initState(); _loadRecords(); }

  Future<void> _loadRecords() async {
    if (!mounted) return;
    setState(() { loading = true; errorMessage = ''; });
    try {
      final rows = await supabase.from('drainage_inspection_records')
          .select().order('updated_at', ascending: false).limit(100);
      if (!mounted) return;
      setState(() { records = List<Map<String, dynamic>>.from(rows); loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { loading = false; errorMessage = 'Drainage records could not be loaded for this account.'; });
    }
  }

  String _caseLabel(String id) {
    for (final r in widget.requests) {
      if (r['id'].toString() == id) {
        final number = r['request_number']?.toString();
        final title = (r['title'] ?? r['road_name'] ?? 'Drainage case').toString();
        return number == null ? title : 'Case #' + number + ' · ' + title;
      }
    }
    return 'Case ' + (id.length > 8 ? id.substring(0, 8) : id);
  }

  String _departmentLabel(String id) {
    for (final d in widget.departments) {
      if (d['id'].toString() == id) return (d['name'] ?? 'Department').toString();
    }
    return widget.isDepartment ? 'Assigned department' : 'Department';
  }

  String _pretty(String value) => value.replaceAll('_', ' ');
  Color _statusColor(String status) {
    switch (status) {
      case 'cleared': return const Color(0xFF25845C);
      case 'critical': return const Color(0xFFB54747);
      case 'high': return const Color(0xFFB7791F);
      case 'in_progress': return const Color(0xFF3978B8);
      default: return const Color(0xFF64748B);
    }
  }

  Future<void> _edit({Map<String, dynamic>? existing}) async {
    if (supabase.auth.currentUser == null) { _message('Please sign in again.'); return; }
    final cases = drainageCases;
    if (cases.isEmpty) { _message('No accessible stormwater-drainage cases are available.'); return; }

    var requestId = existing?['request_id']?.toString() ?? cases.first['id'].toString();
    if (!cases.any((r) => r['id'].toString() == requestId)) requestId = cases.first['id'].toString();
    var departmentId = existing?['responsible_department_id']?.toString()
        ?? widget.departmentId
        ?? (widget.departments.isNotEmpty ? widget.departments.first['id'].toString() : null);
    var obstruction = (existing?['obstruction_type'] ?? 'blocked_inlet').toString();
    var severity = (existing?['severity'] ?? 'moderate').toString();
    var status = (existing?['action_status'] ?? 'reported').toString();
    var standingWater = existing?['standing_water'] == true;
    var inletClear = existing?['inlet_clear'] == true;
    var outfallClear = existing?['outfall_clear'] == true;
    var frontageDrain = existing?['frontage_drain_present'] != false;
    var saving = false;
    final notes = TextEditingController(text: existing?['inspection_notes']?.toString() ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Record drainage inspection' : 'Update drainage inspection'),
          content: SizedBox(width: 480, child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                initialValue: requestId, isExpanded: true,
                decoration: const InputDecoration(labelText: 'Stormwater case'),
                items: cases.map((r) {
                  final n = r['request_number']?.toString() ?? '';
                  final t = (r['title'] ?? r['road_name'] ?? 'Drainage case').toString();
                  return DropdownMenuItem(value: r['id'].toString(),
                    child: Text(n.isEmpty ? t : 'Case #' + n + ' · ' + t, overflow: TextOverflow.ellipsis));
                }).toList(),
                onChanged: (v) => setDialogState(() => requestId = v ?? requestId),
              ),
              const SizedBox(height: 8),
              if (widget.isDepartment)
                Align(alignment: Alignment.centerLeft,
                  child: Text('Responsible department: ' + (widget.departmentId ?? 'Not assigned')))
              else
                DropdownButtonFormField<String>(
                  initialValue: departmentId, isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Responsible department'),
                  items: widget.departments.map((d) => DropdownMenuItem(
                    value: d['id'].toString(), child: Text((d['name'] ?? 'Department').toString()))).toList(),
                  onChanged: (v) => setDialogState(() => departmentId = v),
                ),
              DropdownButtonFormField<String>(
                initialValue: obstruction,
                decoration: const InputDecoration(labelText: 'Observed issue'),
                items: const [
                  DropdownMenuItem(value: 'blocked_inlet', child: Text('Blocked drain inlet')),
                  DropdownMenuItem(value: 'silt_debris', child: Text('Silt / debris accumulation')),
                  DropdownMenuItem(value: 'encroachment', child: Text('Drain encroachment')),
                  DropdownMenuItem(value: 'damaged_drain', child: Text('Damaged drain')),
                  DropdownMenuItem(value: 'missing_frontage_drain', child: Text('Missing frontage drain')),
                  DropdownMenuItem(value: 'inadequate_capacity', child: Text('Inadequate drainage capacity')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (v) => setDialogState(() => obstruction = v ?? obstruction),
              ),
              DropdownButtonFormField<String>(
                initialValue: severity, decoration: const InputDecoration(labelText: 'Severity'),
                items: const [
                  DropdownMenuItem(value: 'low', child: Text('Low')),
                  DropdownMenuItem(value: 'moderate', child: Text('Moderate')),
                  DropdownMenuItem(value: 'high', child: Text('High')),
                  DropdownMenuItem(value: 'critical', child: Text('Critical')),
                ],
                onChanged: (v) => setDialogState(() => severity = v ?? severity),
              ),
              DropdownButtonFormField<String>(
                initialValue: status, decoration: const InputDecoration(labelText: 'Action status'),
                items: const [
                  DropdownMenuItem(value: 'reported', child: Text('Reported')),
                  DropdownMenuItem(value: 'inspection_required', child: Text('Inspection required')),
                  DropdownMenuItem(value: 'action_assigned', child: Text('Action assigned')),
                  DropdownMenuItem(value: 'in_progress', child: Text('In progress')),
                  DropdownMenuItem(value: 'cleared', child: Text('Cleared')),
                  DropdownMenuItem(value: 'monitoring', child: Text('Monitoring')),
                ],
                onChanged: (v) => setDialogState(() => status = v ?? status),
              ),
              CheckboxListTile(contentPadding: EdgeInsets.zero, dense: true,
                value: standingWater, onChanged: (v) => setDialogState(() => standingWater = v ?? false),
                title: const Text('Standing water observed')),
              CheckboxListTile(contentPadding: EdgeInsets.zero, dense: true,
                value: inletClear, onChanged: (v) => setDialogState(() => inletClear = v ?? false),
                title: const Text('Drain inlet verified clear')),
              CheckboxListTile(contentPadding: EdgeInsets.zero, dense: true,
                value: outfallClear, onChanged: (v) => setDialogState(() => outfallClear = v ?? false),
                title: const Text('Outfall / discharge path verified clear')),
              CheckboxListTile(contentPadding: EdgeInsets.zero, dense: true,
                value: frontageDrain, onChanged: (v) => setDialogState(() => frontageDrain = v ?? false),
                title: const Text('Frontage drain is present')),
              TextField(controller: notes, minLines: 2, maxLines: 4,
                decoration: const InputDecoration(labelText: 'Inspection / action notes')),
              const SizedBox(height: 6),
               Text('Clearance requires a clear inlet, clear outfall and no standing water.',
                style: TextStyle(fontSize: 11, color: mutedInk)),
            ]),
          )),
          actions: [
            TextButton(onPressed: saving ? null : () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel')),
            FilledButton(
              onPressed: saving ? null : () async {
                if (departmentId == null || departmentId!.isEmpty) {
                  _message('Select a responsible department.'); return;
                }
                if (status == 'cleared' && (!inletClear || !outfallClear || standingWater)) {
                  _message('Clearance requires a clear inlet, clear outfall and no standing water.'); return;
                }
                setDialogState(() => saving = true);
                try {
                  await supabase.rpc('save_drainage_inspection_record', params: {
                    'p_request_id': requestId,
                    'p_responsible_department_id': departmentId,
                    'p_obstruction_type': obstruction,
                    'p_severity': severity,
                    'p_action_status': status,
                    'p_standing_water': standingWater,
                    'p_inlet_clear': inletClear,
                    'p_outfall_clear': outfallClear,
                    'p_frontage_drain_present': frontageDrain,
                    'p_inspection_notes': notes.text.trim().isEmpty ? null : notes.text.trim(),
                  });
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop(true);
                } catch (_) {
                  setDialogState(() => saving = false);
                  _message('Unable to save. Confirm the case is assigned to the selected department.');
                }
              },
              child: saving ? const SizedBox(width: 16,height: 16,child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save inspection'),
            ),
          ],
        ),
      ),
    );

    notes.dispose();
    if (saved == true) { await _loadRecords(); _message('Drainage inspection saved.'); }
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    return Card(child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
           Icon(Icons.water_damage_outlined, color: teal),
          const SizedBox(width: 9),
           Expanded(child: Text('Stormwater & frontage drainage',
            style: TextStyle(fontSize: 14,fontWeight: FontWeight.w800,color: ink))),
          IconButton(onPressed: loading ? null : _loadRecords,
            icon: const Icon(Icons.refresh), tooltip: 'Refresh drainage records'),
        ]),
         Text('Track blocked inlets, silt, encroachment, standing water and missing frontage drains. This is case-management data, not engineering clearance.',
          style: TextStyle(fontSize: 11,color: mutedInk)),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(
          onPressed: drainageCases.isEmpty ? null : () => _edit(),
          icon: const Icon(Icons.add), label: const Text('RECORD DRAINAGE INSPECTION'))),
        if (drainageCases.isEmpty)
           Padding(padding: EdgeInsets.only(top: 8),
            child: Text('Create or assign a case under Stormwater and drainage to start an inspection.',
              style: TextStyle(fontSize: 11,color: mutedInk))),
        const SizedBox(height: 8),
        if (loading)
          const Center(child: Padding(padding: EdgeInsets.all(12),child: CircularProgressIndicator()))
        else if (errorMessage.isNotEmpty)
          Text(errorMessage,style: const TextStyle(fontSize: 12,color: Colors.red))
        else if (records.isEmpty)
           Text('No drainage inspections have been entered yet.',
            style: TextStyle(fontSize: 12,color: mutedInk))
        else
          ...records.map((r) {
            final status = (r['action_status'] ?? 'reported').toString();
            final severity = (r['severity'] ?? 'moderate').toString();
            final dept = r['responsible_department_id'].toString();
            final issue = _pretty((r['obstruction_type'] ?? 'other').toString());
            return Container(
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(color: const Color(0xFFF7FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE4EAF1))),
              child: ListTile(dense: true, onTap: () => _edit(existing: r),
                leading: Icon(Icons.water_damage_outlined,color: _statusColor(status)),
                title: Text(_caseLabel(r['request_id'].toString()),maxLines: 2,overflow: TextOverflow.ellipsis,
                  style:  TextStyle(fontSize: 12,fontWeight: FontWeight.w700,color: ink)),
                subtitle: Text(_departmentLabel(dept) + ' · ' + issue + ' · ' +
                  severity.toUpperCase() + ' · ' + _pretty(status),
                  style:  TextStyle(fontSize: 10,color: mutedInk)),
                trailing: const Icon(Icons.chevron_right)),
            );
          }),
      ]),
    ));
  }
}

class GroundwaterTelemetryDashboard extends StatefulWidget {
  const GroundwaterTelemetryDashboard({super.key});
  @override
  State<GroundwaterTelemetryDashboard> createState() => _GroundwaterTelemetryDashboardState();
}

class _GroundwaterTelemetryDashboardState extends State<GroundwaterTelemetryDashboard> {
  List<Map<String, dynamic>> jurisdictions = [];
  List<Map<String, dynamic>> stations = [];
  List<Map<String, dynamic>> districtAssessments = [];
  Map<String, dynamic>? assessment;
  String? selectedStateId;
  String selectedStateName = 'Tamil Nadu';
  bool loading = true;
  String errorMessage = '';

  @override
  void initState() { super.initState(); _loadSnapshot(); }

  Future<void> _loadSnapshot({String? requestedStateId}) async {
    if (!mounted) return;
    setState(() { loading = true; errorMessage = ''; });
    try {
      final rawJurisdictions = await supabase.from('india_state_uts')
          .select('id,name,jurisdiction_type').order('name');
      final loaded = List<Map<String, dynamic>>.from(rawJurisdictions);
      if (loaded.isEmpty) throw Exception('Empty State/UT directory');
      String? nextId = requestedStateId ?? selectedStateId;
      if (nextId == null || !loaded.any((r) => r['id'].toString() == nextId)) {
        final tn = loaded.where((r) => r['name'].toString() == 'Tamil Nadu');
        nextId = tn.isNotEmpty ? tn.first['id'].toString() : loaded.first['id'].toString();
      }
      final selected = loaded.firstWhere((r) => r['id'].toString() == nextId);
      final stateName = selected['name'].toString();
      final rawStations = await supabase.from('latest_groundwater_station_observations')
          .select('station_name,agency,state_name,district_name,tehsil,block_name,latitude,longitude,rl_msl_m,observed_at_local,reported_level_m,reported_level_text,imported_at')
          .eq('state_name', stateName).order('observed_at_local', ascending: false).limit(300);
      final rawAssessment = await supabase.from('groundwater_state_assessments')
          .select('assessment_year,agency,total_annual_recharge_bcm,annual_extractable_resource_bcm,total_annual_extraction_bcm,stage_of_extraction_pct,source_document_url,source_reference')
          .eq('state_ut_id', nextId).order('assessment_year', ascending: false).limit(1);
      final rawDistrictAssessments = await supabase
          .from('groundwater_resource_assessments')
          .select('district_name,total_annual_recharge_ham,annual_extractable_resource_ham,annual_extraction_ham,stage_of_extraction_pct,source_reference,source_document_url')
          .eq('state_name', stateName)
          .eq('assessment_year', 2025)
          .eq('geography_level', 'district')
          .ilike('source_reference', 'National Compilation on Dynamic Ground Water Resources of India, 2025, Annexure II%')
          .order('stage_of_extraction_pct', ascending: false)
          .limit(100);
      if (!mounted) return;
      setState(() {
        jurisdictions = loaded; selectedStateId = nextId; selectedStateName = stateName;
        stations = List<Map<String, dynamic>>.from(rawStations);
        districtAssessments = List<Map<String, dynamic>>.from(rawDistrictAssessments);
        assessment = rawAssessment.isEmpty ? null : Map<String, dynamic>.from(rawAssessment.first);
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { loading = false; errorMessage = 'Nationwide groundwater records could not be loaded. Check your connection and account permissions.'; });
    }
  }

  String _number(dynamic value, {int digits = 2, String suffix = ''}) {
    if (value is num) return value.toStringAsFixed(digits) + suffix;
    final parsed = num.tryParse(value?.toString() ?? '');
    return parsed == null ? 'Not reported' : parsed.toStringAsFixed(digits) + suffix;
  }

  String _reading(Map<String, dynamic> station) {
    final value = station['reported_level_m'];
    if (value is num) return value.toStringAsFixed(3) + ' m (as published)';
    final raw = (station['reported_level_text'] ?? '').toString();
    return raw.isEmpty || raw == '-' ? 'Not reported' : raw + ' (as published)';
  }

  Widget _metric(String label, String value) => Expanded(
    child: Container(padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(color: panelNavy, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style:  TextStyle(fontSize: 10, color: mutedInk)),
        const SizedBox(height: 4),
        Text(value, style:  TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: ink)),
      ])));

  Widget _districtAssessmentTile(Map<String, dynamic> district) {
    final name = (district['district_name'] ?? 'District not named').toString();
    final recharge = _number(district['total_annual_recharge_ham'], digits: 0);
    final extractable = _number(district['annual_extractable_resource_ham'], digits: 0);
    final extraction = _number(district['annual_extraction_ham'], digits: 0);
    final stage = _number(district['stage_of_extraction_pct'], suffix: '%');
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(name, style:  TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ink)),
      subtitle: Text('Recharge $recharge ha.m · Extractable $extractable ha.m · Extraction $extraction ha.m',
        style:  TextStyle(fontSize: 10, color: mutedInk)),
      trailing: Text(stage, style:  TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: ink)),
    );
  }

  Widget _stationTile(Map<String, dynamic> station) {
    final name = (station['station_name'] ?? 'Unnamed station').toString();
    final district = (station['district_name'] ?? 'District not supplied').toString();
    final tehsil = (station['tehsil'] ?? station['block_name'] ?? '').toString();
    final observed = (station['observed_at_local'] ?? 'Timestamp unavailable').toString();
    final place = [district, tehsil].where((v) => v.trim().isNotEmpty).join(' · ');
    final rl = station['rl_msl_m'] is num ? ' · RL MSL ${(station['rl_msl_m'] as num).toStringAsFixed(2)} m' : '';
    return ListTile(dense: true, contentPadding: EdgeInsets.zero,
      leading:  Icon(Icons.sensors_outlined, color: teal),
      title: Text(name, style:  TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ink)),
      subtitle: Text('$place · Observed $observed$rl', style:  TextStyle(fontSize: 10, color: mutedInk)),
      trailing: Text(_reading(station), style:  TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ink)));
  }

  @override
  Widget build(BuildContext context) {
    final latest = stations.isNotEmpty ? (stations.first['observed_at_local'] ?? 'Unavailable').toString() : 'Unavailable';
    final year = assessment?['assessment_year']?.toString() ?? 'Unavailable';
    final stage = assessment == null ? 'Not reported' : _number(assessment?['stage_of_extraction_pct'], suffix: '%');
    return Card(child: Padding(padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
           Icon(Icons.public, color: teal), const SizedBox(width: 9),
           Expanded(child: Text('India groundwater intelligence', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: ink))),
          IconButton(onPressed: loading ? null : () => _loadSnapshot(), icon: const Icon(Icons.refresh), tooltip: 'Refresh nationwide groundwater records'),
        ]),
         Text('CGWB State/UT resource assessments + published NWDP monitoring observations', style: TextStyle(fontSize: 11, color: mutedInk)),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: selectedStateId, isExpanded: true,
          decoration: const InputDecoration(labelText: 'Select State / Union Territory', border: OutlineInputBorder(), isDense: true),
          items: jurisdictions.map((r) => DropdownMenuItem<String>(value: r['id'].toString(), child: Text(r['name'].toString()))).toList(),
          onChanged: loading || jurisdictions.isEmpty ? null : (v) { if (v != null) _loadSnapshot(requestedStateId: v); },
        ),
        const SizedBox(height: 10),
        if (loading) const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
        else if (errorMessage.isNotEmpty) Text(errorMessage, style: const TextStyle(fontSize: 12, color: Colors.red))
        else ...[
          Text(selectedStateName, style:  TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 8),
          Row(children: [_metric('Assessment year', year), const SizedBox(width: 8), _metric('Extraction stage', stage)]),
          const SizedBox(height: 8),
          Row(children: [
            _metric('Annual recharge', assessment == null ? 'Not reported' : _number(assessment?['total_annual_recharge_bcm'], suffix: ' BCM')),
            const SizedBox(width: 8),
            _metric('Annual extraction', assessment == null ? 'Not reported' : _number(assessment?['total_annual_extraction_bcm'], suffix: ' BCM')),
          ]),
          const SizedBox(height: 12),
          Row(children: [
             Expanded(child: Text('CGWB 2025 district resource assessments', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: ink))),
            Text('${districtAssessments.length} districts', style:  TextStyle(fontSize: 10, color: mutedInk)),
          ]),
           Text('Official CGWB Annexure II values · hectare-metres (ha.m). These are annual resource assessments, not live readings or individual borewell permissions.',
            style: TextStyle(fontSize: 10, color: mutedInk)),
          if (districtAssessments.isEmpty)
             Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('No Annexure II district rows are currently registered for this jurisdiction. This is a coverage gap, not evidence that district assessments do not exist.', style: TextStyle(fontSize: 10, color: mutedInk)))
          else ...[
            const SizedBox(height: 5),
            ...districtAssessments.take(6).map(_districtAssessmentTile),
            if (districtAssessments.length > 6)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text('Show remaining ${districtAssessments.length - 6} districts', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                children: districtAssessments.skip(6).map(_districtAssessmentTile).toList(),
              ),
          ],
          const SizedBox(height: 12),
          Row(children: [
             Expanded(child: Text('Published monitoring stations', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: ink))),
            Text('${stations.length} shown', style:  TextStyle(fontSize: 10, color: mutedInk)),
          ]),
          if (stations.isEmpty)
             Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('No station observations are currently imported for this jurisdiction. This does not mean that monitoring stations are absent.', style: TextStyle(fontSize: 11, color: mutedInk)))
          else ...[
            Text('Latest observation in this result: $latest', style:  TextStyle(fontSize: 10, color: mutedInk)),
            const SizedBox(height: 6),
            ...stations.take(10).map(_stationTile),
            if (stations.length > 10) ExpansionTile(tilePadding: EdgeInsets.zero,
              title: Text('Show remaining ${stations.length - 10} stations', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              children: stations.skip(10).map(_stationTile).toList()),
          ],
          const SizedBox(height: 6),
           Text('Resource assessments are annual CGWB estimates, not live sensor values. Station readings are displayed as published. Missing observations are not evidence of absent groundwater or safe borewell conditions. National telemetry imports run through the controlled server-side import workflow.', style: TextStyle(fontSize: 10, color: mutedInk)),
        ],
      ])));
  }
}


class NationalDataCoverageBoard extends StatefulWidget {
  const NationalDataCoverageBoard({super.key});
  @override
  State<NationalDataCoverageBoard> createState() => _NationalDataCoverageBoardState();
}

class _NationalDataCoverageBoardState extends State<NationalDataCoverageBoard> {
  List<Map<String, dynamic>> records = [];
  bool loading = true;
  String errorMessage = '';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { loading = true; errorMessage = ''; });
    try {
      final rows = await supabase.from('india_data_coverage')
          .select('state_ut_id,data_domain,coverage_status,operational_use_allowed,telemetry_records_imported,telemetry_status')
          .limit(1000);
      if (!mounted) return;
      setState(() { records = List<Map<String, dynamic>>.from(rows); loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { loading = false; errorMessage = 'National data coverage status is unavailable.'; });
    }
  }

  Widget _domainSummary(String domain, String label) {
    final items = records.where((r) => r['data_domain']?.toString() == domain).toList();
    final jurisdictions = items.map((r) => r['state_ut_id']?.toString()).whereType<String>().toSet().length;
    final operational = items.where((r) => r['operational_use_allowed'] == true).length;
    final statuses = <String, int>{};
    for (final row in items) {
      final status = (row['coverage_status'] ?? 'unknown').toString();
      statuses[status] = (statuses[status] ?? 0) + 1;
    }
    final imported = items.fold<int>(0, (sum, row) {
      final v = row['telemetry_records_imported'];
      return sum + (v is num ? v.toInt() : 0);
    });
    return Container(width: double.infinity, margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: panelNavy, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style:  TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: ink)),
        const SizedBox(height: 5),
        Text(jurisdictions.toString() + ' of 36 jurisdictions have a coverage row · ' +
          operational.toString() + ' operationally authorised', style:  TextStyle(fontSize: 10, color: mutedInk)),
        if (domain == 'groundwater') Text('State-level telemetry records attributed in coverage matrix: ' + imported.toString(),
          style:  TextStyle(fontSize: 10, color: mutedInk)),
        const SizedBox(height: 5),
        ...statuses.entries.map((e) => Padding(padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Expanded(child: Text(e.key.replaceAll('_', ' '), style:  TextStyle(fontSize: 10, color: mutedInk))),
            Text(e.value.toString(), style:  TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: ink)),
          ]))),
      ]));
  }

  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
         Icon(Icons.account_tree_outlined, color: teal), const SizedBox(width: 9),
         Expanded(child: Text('India-wide data readiness', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: ink))),
        IconButton(onPressed: loading ? null : _load, icon: const Icon(Icons.refresh), tooltip: 'Refresh national coverage matrix'),
      ]),
       Text('36 States / UTs · 10 infrastructure domains · authority verification tracked', style: TextStyle(fontSize: 11, color: mutedInk)),
      if (loading) const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()))
      else if (errorMessage.isNotEmpty) Text(errorMessage, style: const TextStyle(fontSize: 11, color: Colors.red))
      else ...[
        _domainSummary('groundwater', 'Groundwater'),
        _domainSummary('utility_gis', 'Underground utility GIS'),
        _domainSummary('building_approvals', 'Building approvals'),
        _domainSummary('road_right_of_way', 'Roads and right-of-way'),
        _domainSummary('water_supply', 'Drinking-water supply'),
        _domainSummary('sewerage_wastewater', 'Sewerage and wastewater'),
        _domainSummary('stormwater_drainage', 'Stormwater drainage'),
        _domainSummary('electricity_distribution', 'Electricity distribution'),
        _domainSummary('telecom_fibre', 'Telecom and fibre'),
        _domainSummary('city_gas', 'City gas distribution'),
        _domainSummary('administrative_directory', 'Districts, ULBs and local bodies'),
        const SizedBox(height: 8),
         Text('A portal reference or imported public record does not establish a complete or current asset inventory. Operational use remains disabled until the responsible authority validates the relevant records.', style: TextStyle(fontSize: 10, color: mutedInk)),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const IndiaCoverageExplorerPage(),
          )),
          icon: const Icon(Icons.public),
          label: const Text('OPEN INDIA-WIDE COVERAGE EXPLORER'),
        )),
      ],
    ])));
}

class IndiaCoverageExplorerPage extends StatefulWidget {
  const IndiaCoverageExplorerPage({super.key});
  @override
  State<IndiaCoverageExplorerPage> createState() => _IndiaCoverageExplorerPageState();
}

class _IndiaCoverageExplorerPageState extends State<IndiaCoverageExplorerPage> {
  List<Map<String, dynamic>> states = [];
  List<Map<String, dynamic>> coverage = [];
  List<Map<String, dynamic>> administrativeUnits = [];
  List<Map<String, dynamic>> directoryBatches = [];
  bool canManageDirectory = false;
  bool loading = true;
  String errorMessage = '';
  String searchText = '';
  String? selectedStateId;
  String selectedDomain = 'all';
  String selectedRegion = 'All India';

  static const List<String> regionOrder = [
    'All India', 'North', 'Northeast', 'East', 'Central', 'West', 'South', 'Islands',
  ];

  static const Map<String, Set<String>> regionJurisdictions = {
    'North': {
      'Chandigarh', 'Delhi', 'Haryana', 'Himachal Pradesh',
      'Jammu and Kashmir', 'Ladakh', 'Punjab', 'Rajasthan',
      'Uttar Pradesh', 'Uttarakhand',
    },
    'Northeast': {
      'Arunachal Pradesh', 'Assam', 'Manipur', 'Meghalaya',
      'Mizoram', 'Nagaland', 'Sikkim', 'Tripura',
    },
    'East': {'Bihar', 'Jharkhand', 'Odisha', 'West Bengal'},
    'Central': {'Chhattisgarh', 'Madhya Pradesh'},
    'West': {
      'Dadra and Nagar Haveli and Daman and Diu', 'Goa', 'Gujarat', 'Maharashtra',
    },
    'South': {
      'Andhra Pradesh', 'Karnataka', 'Kerala', 'Puducherry',
      'Tamil Nadu', 'Telangana',
    },
    'Islands': {'Andaman and Nicobar Islands', 'Lakshadweep'},
  };

  static const Map<String, String> domainLabels = {
    'all': 'All infrastructure domains',
    'groundwater': 'Groundwater',
    'utility_gis': 'Underground utility GIS',
    'building_approvals': 'Building approvals',
    'road_right_of_way': 'Roads and right-of-way',
    'water_supply': 'Drinking-water supply',
    'sewerage_wastewater': 'Sewerage and wastewater',
    'stormwater_drainage': 'Stormwater drainage',
    'electricity_distribution': 'Electricity distribution',
    'telecom_fibre': 'Telecom and fibre',
    'city_gas': 'City gas distribution',
    'administrative_directory': 'Districts, ULBs and local bodies',
  };

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { loading = true; errorMessage = ''; });
    try {
      final rawStates = await supabase.from('india_state_uts')
          .select('id,name,jurisdiction_type').order('name').limit(100);
      final rawCoverage = await supabase.from('india_data_coverage')
          .select('state_ut_id,data_domain,responsible_authority,official_portal_url,national_source_url,coverage_status,data_granularity,operational_use_allowed,last_checked_at,notes,telemetry_resource_count,telemetry_records_imported,telemetry_source_records,telemetry_status')
          .limit(1000);
      final rawAdministrativeUnits = await supabase.from('india_administrative_units')
          .select('unit_type,verification_status,state_ut_id')
          .limit(1000);
      final userId = supabase.auth.currentUser?.id;
      final profile = userId == null ? null : await supabase.from('profiles')
          .select('role').eq('id', userId).maybeSingle();
      final role = (profile?['role'] ?? '').toString();
      final manager = role == 'admin' || role == 'coordinator';
      final rawDirectoryBatches = manager
          ? await supabase.from('india_directory_import_batches')
              .select('unit_type,import_status,rows_received,rows_inserted,rows_rejected,jurisdiction_state_ut_id')
              .limit(1000)
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        states = List<Map<String, dynamic>>.from(rawStates);
        coverage = List<Map<String, dynamic>>.from(rawCoverage);
        administrativeUnits = List<Map<String, dynamic>>.from(rawAdministrativeUnits);
        directoryBatches = List<Map<String, dynamic>>.from(rawDirectoryBatches);
        canManageDirectory = manager;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorMessage = 'Coverage records could not be loaded for this account. Refresh or check the account permissions.';
      });
    }
  }

  String _domainLabel(String domain) => domainLabels[domain] ?? domain.replaceAll('_', ' ');

  List<Map<String, dynamic>> _rowsFor(String stateId) {
    final rows = coverage.where((row) {
      final sameState = row['state_ut_id']?.toString() == stateId;
      final sameDomain = selectedDomain == 'all' || row['data_domain']?.toString() == selectedDomain;
      return sameState && sameDomain;
    }).toList();
    rows.sort((a, b) => _domainLabel(a['data_domain'].toString())
        .compareTo(_domainLabel(b['data_domain'].toString())));
    return rows;
  }

  String _statusLabel(Map<String, dynamic> row) {
    if (row['operational_use_allowed'] == true) return 'OPERATIONAL AUTHORISED';
    final status = (row['coverage_status'] ?? '').toString().toLowerCase();
    if (status.contains('partial')) return 'PARTIAL REGISTER';
    if (status.contains('imported')) return 'IMPORTED · REVIEW REQUIRED';
    if (status.contains('national_authority_identified_state_level_register_pending')) {
      return 'NATIONAL SOURCE · LOCAL DATA PENDING';
    }
    if (status.contains('captcha_required_for_bulk_export')) {
      return 'OFFICIAL DIRECTORY · EXPORT PENDING';
    }
    if (status.contains('portal_identified')) return 'PORTAL IDENTIFIED';
    return 'AUTHORITY DATA PENDING';
  }

  Color _statusBackground(Map<String, dynamic> row) {
    if (row['operational_use_allowed'] == true) return const Color(0xFFE4F4E9);
    final status = (row['coverage_status'] ?? '').toString().toLowerCase();
    if (status.contains('partial')) return const Color(0xFFFFF0D7);
    if (status.contains('imported')) return const Color(0xFFE6F0FB);
    if (status.contains('national_authority_identified_state_level_register_pending') ||
        status.contains('captcha_required_for_bulk_export')) {
      return const Color(0xFFFFF0D7);
    }
    if (status.contains('portal_identified')) return const Color(0xFFEAF4F4);
    return const Color(0xFFF0F2F5);
  }

  Color _statusForeground(Map<String, dynamic> row) {
    if (row['operational_use_allowed'] == true) return const Color(0xFF216B3B);
    final status = (row['coverage_status'] ?? '').toString().toLowerCase();
    if (status.contains('partial')) return const Color(0xFF8A5A00);
    if (status.contains('imported')) return const Color(0xFF285B8F);
    if (status.contains('national_authority_identified_state_level_register_pending') ||
        status.contains('captcha_required_for_bulk_export')) {
      return const Color(0xFF8A5A00);
    }
    if (status.contains('portal_identified')) return const Color(0xFF176B6D);
    return const Color(0xFF526071);
  }

  Future<void> _openSource(String? value) async {
    final raw = value?.trim() ?? '';
    final uri = Uri.tryParse(raw);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      _message('No verified source link is recorded for this item.');
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) _message('The source portal could not be opened.');
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _metric(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: panelNavy,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: teal),
        const SizedBox(width: 7),
        Text(value, style:  TextStyle(fontWeight: FontWeight.w800, color: ink)),
        const SizedBox(width: 5),
        Text(label, style:  TextStyle(fontSize: 10, color: mutedInk)),
      ]),
    );
  }

  Widget _coverageRow(Map<String, dynamic> row) {
    final domain = (row['data_domain'] ?? '').toString();
    final status = _statusLabel(row);
    final authority = (row['responsible_authority'] ?? 'Authority not yet confirmed').toString();
    final granularity = (row['data_granularity'] ?? '').toString();
    final notes = (row['notes'] ?? '').toString();
    final nationalUrl = row['national_source_url']?.toString();
    final portalUrl = row['official_portal_url']?.toString();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7EDF2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(_domainLabel(domain),
            style:  TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: ink))),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(color: _statusBackground(row), borderRadius: BorderRadius.circular(8)),
            child: Text(status, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: _statusForeground(row))),
          ),
        ]),
        const SizedBox(height: 8),
         Text('RESPONSIBLE AUTHORITY / CUSTODIAN',
          style: TextStyle(fontSize: 8, letterSpacing: .6, fontWeight: FontWeight.w900, color: mutedInk)),
        const SizedBox(height: 3),
        Text(authority, style:  TextStyle(fontSize: 11, color: ink, height: 1.35)),
        if (granularity.isNotEmpty) ...[
          const SizedBox(height: 8),
           Text('DATA EXPECTED',
            style: TextStyle(fontSize: 8, letterSpacing: .6, fontWeight: FontWeight.w900, color: mutedInk)),
          const SizedBox(height: 3),
          Text(granularity, style:  TextStyle(fontSize: 10, color: mutedInk, height: 1.35)),
        ],
        if (notes.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(notes, style:  TextStyle(fontSize: 10, color: mutedInk, height: 1.35)),
        ],
        if ((nationalUrl != null && nationalUrl.isNotEmpty) || (portalUrl != null && portalUrl.isNotEmpty)) ...[
          const SizedBox(height: 5),
          Wrap(spacing: 4, children: [
            if (nationalUrl != null && nationalUrl.isNotEmpty)
              TextButton.icon(
                onPressed: () => _openSource(nationalUrl),
                icon: const Icon(Icons.public, size: 14),
                label: const Text('National source', style: TextStyle(fontSize: 10)),
              ),
            if (portalUrl != null && portalUrl.isNotEmpty)
              TextButton.icon(
                onPressed: () => _openSource(portalUrl),
                icon: const Icon(Icons.open_in_new, size: 14),
                label: const Text('State / local portal', style: TextStyle(fontSize: 10)),
              ),
          ]),
        ],
      ]),
    );
  }

  Widget _administrativeDirectoryCard() {
    final counts = <String, int>{};
    final verified = administrativeUnits.where(
      (row) => row['verification_status'] == 'authority_verified',
    ).length;
    final pendingDistrictExports = directoryBatches.where((row) =>
      row['unit_type'] == 'district' && row['import_status'] == 'awaiting_authorised_export').length;
    final pendingUlbExports = directoryBatches.where((row) =>
      row['unit_type'] == 'urban_local_body' && row['import_status'] == 'awaiting_authorised_export').length;
    final completedBatches = directoryBatches.where((row) =>
      row['import_status'] == 'imported').length;
    for (final row in administrativeUnits) {
      final type = (row['unit_type'] ?? 'other').toString();
      counts[type] = (counts[type] ?? 0) + 1;
    }
    const labels = {
      'district': 'Districts',
      'sub_district': 'Sub-districts',
      'block': 'Blocks',
      'urban_local_body': 'Urban local bodies',
      'gram_panchayat': 'Gram panchayats',
      'village': 'Villages',
      'ward': 'Wards',
      'traditional_local_body': 'Traditional local bodies',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
             Icon(Icons.account_balance_outlined, color: teal),
            const SizedBox(width: 8),
             Expanded(child: Text('District and local-government directory',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: ink))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0D7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('IMPORT PENDING',
                style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Color(0xFF8A5A00))),
            ),
          ]),
          const SizedBox(height: 7),
          Text(administrativeUnits.length.toString() + ' directory records currently loaded · ' +
            verified.toString() + ' authority-verified',
            style:  TextStyle(fontSize: 10, color: mutedInk)),
          if (canManageDirectory) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 7, runSpacing: 7, children: [
              _metric('DISTRICT EXPORTS PENDING', pendingDistrictExports.toString(), Icons.map_outlined),
              _metric('ULB EXPORTS PENDING', pendingUlbExports.toString(), Icons.location_city_outlined),
              _metric('BATCHES IMPORTED', completedBatches.toString(), Icons.fact_check_outlined),
            ]),
          ],
          const SizedBox(height: 8),
          if (administrativeUnits.isEmpty)
            Text(
              canManageDirectory
                ? 'No district or ULB rows have been imported yet. ' + pendingDistrictExports.toString() + ' district and ' + pendingUlbExports.toString() + ' urban-local-body state export tasks are queued. Each official report must be generated through the LGD portal with its normal CAPTCHA check.'
                : 'No district or ULB rows have been imported yet. The national LGD source is registered; the responsible authority export and validation process is pending.',
              style:  TextStyle(fontSize: 11, color: mutedInk, height: 1.4),
            )
          else
            Wrap(spacing: 7, runSpacing: 7, children: labels.entries
              .where((entry) => counts.containsKey(entry.key))
              .map((entry) => _metric(entry.value, counts[entry.key].toString(), Icons.location_city_outlined))
              .toList()),
          const SizedBox(height: 8),
           Text(
            'Required source: Ministry of Panchayati Raj Local Government Directory (LGD). Its bulk report generator requires a CAPTCHA. Upload an authority-generated report with its LGD codes and report date; do not treat manually typed names as verified records.',
            style: TextStyle(fontSize: 10, color: mutedInk, height: 1.4),
          ),
          const SizedBox(height: 7),
          Wrap(spacing: 8, runSpacing: 6, children: [
            TextButton.icon(
              onPressed: () => _openSource('https://lgdirectory.gov.in/downloadDirectory.do'),
              icon: const Icon(Icons.open_in_new, size: 15),
              label: const Text('Open official LGD report generator'),
            ),
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const IndiaNationalAuthorityDirectoryPage(),
              )),
              icon: const Icon(Icons.account_balance, size: 15),
              label: const Text('National authority directory'),
            ),
            if (canManageDirectory) ...[
              FilledButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const IndiaLgdCsvImportPage(),
                  ));
                  if (mounted) _load();
                },
                icon: const Icon(Icons.upload_file, size: 15),
                label: const Text('Import official CSV'),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const UtilityAssetVerificationPage(),
                )),
                icon: const Icon(Icons.fact_check_outlined, size: 15),
                label: const Text('Asset verification centre'),
              ),
            ],
          ]),
        ]),
      ),
    );
  }

  Widget _jurisdictionCard(Map<String, dynamic> state) {
    final stateId = state['id'].toString();
    final rows = _rowsFor(stateId);
    final authorised = rows.where((row) => row['operational_use_allowed'] == true).length;
    final kind = (state['jurisdiction_type'] ?? 'jurisdiction').toString() == 'state'
        ? 'STATE' : 'UNION TERRITORY';

    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: ExpansionTile(
        initiallyExpanded: selectedStateId == stateId,
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE7F8F6),
          child: Icon(kind == 'STATE' ? Icons.map_outlined : Icons.location_city_outlined,
            color: teal, size: 19),
        ),
        title: Text(state['name'].toString(),
          style:  TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: ink)),
        subtitle: Text(kind + ' · ' + rows.length.toString() + ' domain record(s) · ' +
          authorised.toString() + ' operationally authorised',
          style:  TextStyle(fontSize: 10, color: mutedInk)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(children: rows.map(_coverageRow).toList()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredStates = states.where((state) {
      final rawName = state['name'].toString();
      final name = rawName.toLowerCase();
      final matchesSearch = searchText.isEmpty || name.contains(searchText.toLowerCase());
      final matchesSelected = selectedStateId == null || state['id'].toString() == selectedStateId;
      final regionStates = regionJurisdictions[selectedRegion];
      final matchesRegion = regionStates == null || regionStates.contains(rawName);
      return matchesSearch && matchesSelected && matchesRegion;
    }).toList();

    final uniqueDomains = coverage.map((row) => row['data_domain']?.toString())
        .whereType<String>().toSet().length;
    final authorisedRows = coverage.where((row) => row['operational_use_allowed'] == true).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('India-wide coverage'),
        actions: [
          IconButton(onPressed: loading ? null : _load, icon: const Icon(Icons.refresh), tooltip: 'Refresh coverage'),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                     Icon(Icons.cloud_off_outlined, size: 42, color: mutedInk),
                    const SizedBox(height: 12),
                    Text(errorMessage, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Retry')),
                  ]),
                ))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(15),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [navy, Color(0xFF14515E)],
                            begin: Alignment.topLeft, end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Icon(Icons.public, color: Colors.white, size: 28),
                          SizedBox(height: 9),
                          Text('NATIONAL INFRASTRUCTURE COVERAGE',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
                          SizedBox(height: 6),
                          Text('Explore official source coverage and data-readiness across every Indian State and Union Territory.',
                            style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.4)),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      Wrap(spacing: 7, runSpacing: 7, children: [
                        _metric('JURISDICTIONS', states.length.toString(), Icons.location_on_outlined),
                        _metric('DATA DOMAINS', uniqueDomains.toString(), Icons.layers_outlined),
                        _metric('OPERATIONAL', authorisedRows.toString(), Icons.verified_outlined),
                        _metric('COVERAGE ROWS', coverage.length.toString(), Icons.storage_outlined),
                      ]),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(13),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                               Text('BROWSE BY INDIA REGION',
                                style: TextStyle(fontSize: 10, letterSpacing: .8,
                                  fontWeight: FontWeight.w900, color: cyanAccent)),
                              const SizedBox(height: 4),
                               Text(
                                'Regional filters expose northern and other State/UT records directly. These are browse groupings, not separate data-authority boundaries.',
                                style: TextStyle(fontSize: 10, color: mutedInk, height: 1.35),
                              ),
                              const SizedBox(height: 10),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    for (final region in regionOrder)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 7),
                                        child: ChoiceChip(
                                          selected: selectedRegion == region,
                                          label: Text(
                                            region + ' · ' +
                                            (region == 'All India'
                                              ? states.length
                                              : regionJurisdictions[region]!.length).toString(),
                                          ),
                                          labelStyle: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: selectedRegion == region
                                              ? Colors.white
                                              : ink,
                                          ),
                                          selectedColor: teal,
                                          backgroundColor: panelNavy,
                                          side: BorderSide(
                                            color: selectedRegion == region
                                              ? const Color(0xFF35D7C2)
                                              : borderColor,
                                          ),
                                          onSelected: (_) => setState(() {
                                            selectedRegion = region;
                                            selectedStateId = null;
                                          }),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _administrativeDirectoryCard(),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(13),
                          child: Column(children: [
                            TextField(
                              onChanged: (value) => setState(() => searchText = value),
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.search),
                                hintText: 'Search a State or Union Territory',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String?>(
                              initialValue: selectedStateId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Jurisdiction',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: [
                                const DropdownMenuItem<String?>(value: null, child: Text('All India')),
                                ...states.map((state) => DropdownMenuItem<String?>(
                                  value: state['id'].toString(),
                                  child: Text(state['name'].toString(), overflow: TextOverflow.ellipsis),
                                )),
                              ],
                              onChanged: (value) => setState(() {
                                selectedStateId = value;
                                if (value != null) selectedRegion = 'All India';
                              }),
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              initialValue: selectedDomain,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Infrastructure domain',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: domainLabels.entries.map((entry) => DropdownMenuItem<String>(
                                value: entry.key, child: Text(entry.value, overflow: TextOverflow.ellipsis),
                              )).toList(),
                              onChanged: (value) {
                                if (value != null) setState(() => selectedDomain = value);
                              },
                            ),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Showing ' + filteredStates.length.toString() + ' of ' + states.length.toString() + ' jurisdictions',
                        style:  TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: mutedInk)),
                      const SizedBox(height: 8),
                      if (filteredStates.isEmpty)
                        const Card(child: Padding(
                          padding: EdgeInsets.all(18),
                          child: Text('No State or Union Territory matches this search.'),
                        ))
                      else
                        ...filteredStates.map(_jurisdictionCard),
                      const SizedBox(height: 10),
                       Card(
                        child: Padding(
                          padding: EdgeInsets.all(13),
                          child: Text(
                            'DATA GOVERNANCE: This explorer records source discovery, coverage and verification status. It does not publish exact underground utility routes, depths or asset-point locations. Public-source presence is not an excavation permit or safety clearance; the responsible authority must confirm current records before field work.',
                            style: TextStyle(fontSize: 10, height: 1.45, color: mutedInk),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}




class IndiaNationalAuthorityDirectoryPage extends StatefulWidget {
  const IndiaNationalAuthorityDirectoryPage({super.key});
  @override
  State<IndiaNationalAuthorityDirectoryPage> createState() => _IndiaNationalAuthorityDirectoryPageState();
}

class _IndiaNationalAuthorityDirectoryPageState extends State<IndiaNationalAuthorityDirectoryPage> {
  List<Map<String, dynamic>> authorities = [];
  bool loading = true;
  String errorMessage = '';
  String searchText = '';
  String selectedDomain = 'all';

  static const Map<String, String> domainLabels = {
    'all': 'All domains',
    'administrative_directory': 'Administrative directory',
    'building_approvals': 'Building approvals',
    'groundwater': 'Groundwater',
    'road_right_of_way': 'Roads / right-of-way',
    'water_supply': 'Water supply',
    'sewerage_wastewater': 'Sewerage / wastewater',
    'stormwater_drainage': 'Stormwater drainage',
    'electricity_distribution': 'Electricity',
    'telecom_fibre': 'Telecom / fibre',
    'city_gas': 'City gas',
  };

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { loading = true; errorMessage = ''; });
    try {
      final rows = await supabase.from('india_national_authority_directory')
        .select('authority_name,authority_level,responsibility,domain_tags,official_portal_url,source_reference_url,local_custodian_required,verification_status,notes,last_checked_at')
        .order('authority_name').limit(100);
      if (!mounted) return;
      setState(() {
        authorities = List<Map<String, dynamic>>.from(rows);
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorMessage = 'National authority references could not be loaded. Check the account permissions and refresh.';
      });
    }
  }

  Future<void> _open(String? value) async {
    final uri = Uri.tryParse((value ?? '').trim());
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      _message('No valid official source link is recorded.');
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) _message('The official portal could not be opened.');
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Widget _authorityCard(Map<String, dynamic> row) {
    final name = (row['authority_name'] ?? '').toString();
    final level = (row['authority_level'] ?? '').toString().replaceAll('_', ' ').toUpperCase();
    final responsibility = (row['responsibility'] ?? '').toString();
    final notes = (row['notes'] ?? '').toString();
    final tags = (row['domain_tags'] is List)
      ? List<String>.from((row['domain_tags'] as List).map((v) => v.toString()))
      : <String>[];
    final localRequired = row['local_custodian_required'] == true;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style:  TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 4),
          Text(level, style:  TextStyle(fontSize: 8, letterSpacing: .7, fontWeight: FontWeight.w900, color: teal)),
          const SizedBox(height: 8),
          Text(responsibility, style:  TextStyle(fontSize: 11, height: 1.4, color: ink)),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 9),
            Wrap(spacing: 6, runSpacing: 6, children: tags.map((tag) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(color: const Color(0xFFEAF4F4), borderRadius: BorderRadius.circular(7)),
              child: Text(domainLabels[tag] ?? tag.replaceAll('_', ' '),
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF176B6D))),
            )).toList()),
          ],
          if (localRequired) ...[
            const SizedBox(height: 9),
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: const Color(0xFFFFF0D7), borderRadius: BorderRadius.circular(8)),
              child: const Text(
                'LOCAL CUSTODIAN REQUIRED: Confirm the relevant State/UT department, municipal body, utility operator or asset owner before treating this authority as responsible for a specific site.',
                style: TextStyle(fontSize: 9, height: 1.4, color: Color(0xFF805600), fontWeight: FontWeight.w600),
              ),
            ),
          ],
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(notes, style:  TextStyle(fontSize: 10, height: 1.4, color: mutedInk)),
          ],
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: () => _open(row['official_portal_url']?.toString()),
            icon: const Icon(Icons.open_in_new, size: 15),
            label: const Text('Open official authority portal'),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = authorities.where((row) {
      final name = (row['authority_name'] ?? '').toString().toLowerCase();
      final responsibility = (row['responsibility'] ?? '').toString().toLowerCase();
      final matchesText = searchText.isEmpty || name.contains(searchText.toLowerCase()) ||
        responsibility.contains(searchText.toLowerCase());
      final tags = (row['domain_tags'] is List)
        ? (row['domain_tags'] as List).map((v) => v.toString()).toList()
        : <String>[];
      final matchesDomain = selectedDomain == 'all' || tags.contains(selectedDomain);
      return matchesText && matchesDomain;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('National authority directory'),
        actions: [
          IconButton(onPressed: loading ? null : _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: loading
        ? const Center(child: CircularProgressIndicator())
        : errorMessage.isNotEmpty
          ? Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(errorMessage, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Retry')),
              ]),
            ))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(15),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                         Text('NATIONAL GOVERNMENT SOURCES',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: ink)),
                        const SizedBox(height: 6),
                        Text(authorities.length.toString() + ' national authority and directory references registered.',
                          style:  TextStyle(fontSize: 10, color: mutedInk)),
                        const SizedBox(height: 8),
                         Text(
                          'These records identify national policy, programme, regulatory and technical bodies. They do not establish which State/UT or local operator owns an asset. Confirm the local custodian for each site.',
                          style: TextStyle(fontSize: 10, height: 1.45, color: mutedInk),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    onChanged: (value) => setState(() => searchText = value),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search authority or responsibility',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 9),
                  DropdownButtonFormField<String>(
                    initialValue: selectedDomain,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Infrastructure domain', border: OutlineInputBorder(), isDense: true),
                    items: domainLabels.entries.map((entry) => DropdownMenuItem<String>(
                      value: entry.key, child: Text(entry.value, overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (value) { if (value != null) setState(() => selectedDomain = value); },
                  ),
                  const SizedBox(height: 10),
                  Text('Showing ' + filtered.length.toString() + ' of ' + authorities.length.toString() + ' authorities',
                    style:  TextStyle(fontSize: 10, color: mutedInk, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  if (filtered.isEmpty)
                    const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No authority references match this filter.')))
                  else
                    ...filtered.map(_authorityCard),
                ],
              ),
            ),
    );
  }
}


class UtilityAssetVerificationPage extends StatefulWidget {
  const UtilityAssetVerificationPage({super.key});
  @override
  State<UtilityAssetVerificationPage> createState() => _UtilityAssetVerificationPageState();
}

class _UtilityAssetVerificationPageState extends State<UtilityAssetVerificationPage> {
  List<Map<String, dynamic>> records = [];
  bool loading = true;
  bool authorised = false;
  String errorMessage = '';
  String selectedStatus = 'all';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { loading = true; errorMessage = ''; });
    try {
      final userId = supabase.auth.currentUser?.id;
      final profile = userId == null ? null : await supabase.from('profiles')
          .select('role').eq('id', userId).maybeSingle();
      final role = (profile?['role'] ?? '').toString();
      if (role != 'admin' && role != 'coordinator') {
        if (!mounted) return;
        setState(() { authorised = false; loading = false; });
        return;
      }
      final rows = await supabase.from('utility_asset_verification_queue')
          .select('asset_id,asset_type,owner_department,operational_status,source_type,verification_status,surveyed_at,surveyed_by_org,verified_at,verification_notes,evidence_count,created_at,import_run_id,source_title,source_organisation,authorization_reference,source_url,import_status,evidence_reference_items')
          .order('created_at', ascending: false).limit(300);
      if (!mounted) return;
      setState(() {
        authorised = true;
        records = List<Map<String, dynamic>>.from(rows);
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorMessage = 'The restricted verification queue could not be loaded. Check administrator permissions.';
      });
    }
  }

  Future<void> _review(Map<String, dynamic> row, String decision) async {
    final rationaleController = TextEditingController();
    final rationale = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(decision == 'approve' ? 'Approve verified submission' : 'Reject / dispute submission'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Approval marks the submitted asset record as verified after recorded survey evidence is present. Approve only after independently checking the evidence and authority record. This does not provide excavation clearance.'),
          const SizedBox(height: 12),
          TextField(
            controller: rationaleController,
            minLines: 3,
            maxLines: 5,
            maxLength: 2000,
            decoration: const InputDecoration(
              labelText: 'Review rationale (minimum 10 characters)',
              border: OutlineInputBorder(),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final value = rationaleController.text.trim();
              if (value.length >= 10) Navigator.pop(dialogContext, value);
            },
            child: Text(decision == 'approve' ? 'Confirm approval' : 'Record dispute'),
          ),
        ],
      ),
    );
    rationaleController.dispose();
    if (rationale == null || !mounted) return;
    try {
      final response = await supabase.functions.invoke(
        'samanvay-asset-review',
        body: {
          'asset_id': row['asset_id'].toString(),
          'decision': decision,
          'rationale': rationale,
        },
      );
      if (response.status < 200 || response.status >= 300) {
        throw Exception('Review endpoint returned an error.');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(decision == 'approve'
          ? 'Asset marked verified and review audit recorded.'
          : 'Submission marked disputed; review audit recorded.')),
      );
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review could not be completed. Confirm reviewer permissions and evidence requirements.')),
      );
    }
  }

  String _date(dynamic value) {
    if (value == null) return 'Not recorded';
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return 'Not recorded';
    return parsed.toLocal().toString().split('.').first;
  }

  Color _statusColor(String status) {
    if (status == 'verified' || status == 'owner_confirmed') return const Color(0xFFE4F4E9);
    if (status == 'field_surveyed') return const Color(0xFFE6F0FB);
    if (status == 'disputed') return const Color(0xFFFFE8E8);
    return const Color(0xFFFFF0D7);
  }

  Widget _metric(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: panelNavy,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: teal),
        const SizedBox(width: 7),
        Text(value, style:  TextStyle(fontWeight: FontWeight.w800, color: ink)),
        const SizedBox(width: 5),
        Text(label, style:  TextStyle(fontSize: 10, color: mutedInk)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = records.where((row) {
      return selectedStatus == 'all' || row['verification_status'] == selectedStatus;
    }).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asset verification centre'),
        actions: [IconButton(onPressed: loading ? null : _load, icon: const Icon(Icons.refresh))],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : !authorised
              ? const Center(child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Restricted area. Only authorised SAMANVAY administrators and coordinators can access this review queue.',
                    textAlign: TextAlign.center),
                ))
              : errorMessage.isNotEmpty
                  ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(errorMessage)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(padding: const EdgeInsets.all(15), children: [
                         Card(child: Padding(
                          padding: EdgeInsets.all(14),
                          child: Text(
                            'AUTHORITY REVIEW QUEUE — metadata only. This screen deliberately excludes underground asset coordinates, routes, depths, dimensions and precise geometry. A verification label is not excavation clearance.',
                            style: TextStyle(fontSize: 10, height: 1.45, color: mutedInk),
                          ),
                        )),
                        const SizedBox(height: 10),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          _metric('RECORDS LOADED', records.length.toString(), Icons.inventory_2_outlined),
                          _metric('WITH EVIDENCE', records.where((r) => (r['evidence_count'] as num? ?? 0) > 0).length.toString(), Icons.attach_file),
                          _metric('VERIFIED', records.where((r) => r['verification_status'] == 'verified').length.toString(), Icons.verified_outlined),
                        ]),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: selectedStatus,
                          decoration: const InputDecoration(labelText: 'Verification status', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('All statuses')),
                            DropdownMenuItem(value: 'unverified', child: Text('Unverified')),
                            DropdownMenuItem(value: 'field_surveyed', child: Text('Field surveyed')),
                            DropdownMenuItem(value: 'owner_confirmed', child: Text('Owner confirmed')),
                            DropdownMenuItem(value: 'verified', child: Text('Verified')),
                            DropdownMenuItem(value: 'disputed', child: Text('Disputed')),
                            DropdownMenuItem(value: 'retired', child: Text('Retired')),
                          ],
                          onChanged: (value) { if (value != null) setState(() => selectedStatus = value); },
                        ),
                        const SizedBox(height: 12),
                        if (filtered.isEmpty)
                          const Card(child: Padding(
                            padding: EdgeInsets.all(18),
                            child: Text('No asset metadata records are available for this queue yet. Authorised owner or survey submissions are required before review can begin.'),
                          ))
                        else
                          ...filtered.map((row) {
                            final status = (row['verification_status'] ?? 'unverified').toString();
                            final evidenceItems = (row['evidence_reference_items'] is List
                              ? row['evidence_reference_items'] as List : const [])
                              .whereType<Map>()
                              .map((item) => Map<String, dynamic>.from(item))
                              .toList();
                            return Card(
                              margin: const EdgeInsets.only(bottom: 9),
                              child: Padding(
                                padding: const EdgeInsets.all(13),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Row(children: [
                                    Expanded(child: Text((row['asset_type'] ?? 'unknown').toString().toUpperCase(),
                                      style:  TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: ink))),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                      decoration: BoxDecoration(color: _statusColor(status), borderRadius: BorderRadius.circular(8)),
                                      child: Text(status.replaceAll('_', ' ').toUpperCase(),
                                        style:  TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: ink)),
                                    ),
                                  ]),
                                  const SizedBox(height: 7),
                                  Text('Owner department: ' + (row['owner_department'] ?? 'Not assigned').toString(),
                                    style:  TextStyle(fontSize: 10, color: mutedInk)),
                                  Text('Source: ' + (row['source_type'] ?? 'Not recorded').toString() +
                                    ' · Operational status: ' + (row['operational_status'] ?? 'unknown').toString(),
                                    style:  TextStyle(fontSize: 10, color: mutedInk)),
                                  Text('Survey date: ' + _date(row['surveyed_at']) +
                                    ' · Evidence items: ' + (row['evidence_count'] ?? 0).toString(),
                                    style:  TextStyle(fontSize: 10, color: mutedInk)),
                                  if ((row['surveyed_by_org'] ?? '').toString().isNotEmpty)
                                    Text('Survey organisation: ' + row['surveyed_by_org'].toString(),
                                      style:  TextStyle(fontSize: 10, color: mutedInk)),
                                  if ((row['source_title'] ?? '').toString().isNotEmpty)
                                    Text('Submitted source: ' + row['source_title'].toString(),
                                      style:  TextStyle(fontSize: 10, color: mutedInk)),
                                  if ((row['source_organisation'] ?? '').toString().isNotEmpty)
                                    Text('Source organisation: ' + row['source_organisation'].toString(),
                                      style:  TextStyle(fontSize: 10, color: mutedInk)),
                                  if ((row['authorization_reference'] ?? '').toString().isNotEmpty)
                                    Text('Authority reference: ' + row['authorization_reference'].toString(),
                                      style:  TextStyle(fontSize: 10, color: mutedInk)),
                                  if ((row['import_status'] ?? '').toString().isNotEmpty)
                                    Text('Import audit: ' + row['import_status'].toString().replaceAll('_', ' ').toUpperCase(),
                                      style: const TextStyle(fontSize: 10, color: Color(0xFF9A6700), fontWeight: FontWeight.w700)),
                                  if ((row['import_run_id'] ?? '').toString().isNotEmpty)
                                    Text('Audit run: ' + row['import_run_id'].toString(),
                                      style:  TextStyle(fontSize: 9, color: mutedInk)),
                                  if (evidenceItems.isNotEmpty) ...[
                                    const Divider(height: 16),
                                     Text('REFERENCE-ONLY SURVEY EVIDENCE',
                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: ink)),
                                    ...evidenceItems.map((item) => Padding(
                                      padding: const EdgeInsets.only(top: 7),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            (item['evidence_reference_code'] ?? 'Reference').toString(),
                                            style:  TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: ink),
                                          ),
                                          Text(
                                            '${item['survey_method']} · ${_date(item['survey_date'])} · ${item['surveyor_organisation']}',
                                            style:  TextStyle(fontSize: 9, color: mutedInk),
                                          ),
                                          Text(
                                            'SHA-256: ${item['evidence_sha256']}',
                                            style:  TextStyle(fontSize: 8, color: mutedInk),
                                          ),
                                        ],
                                      ),
                                    )),
                                    const Text(
                                      'Original source material is not stored or viewable in this queue. Confirm the reference with the owner department through authorised channels.',
                                      style: TextStyle(fontSize: 9, color: Color(0xFF9A6700), height: 1.35),
                                    ),
                                  ],
                                  if ((row['verification_notes'] ?? '').toString().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(row['verification_notes'].toString(),
                                        style:  TextStyle(fontSize: 10, color: mutedInk)),
                                    ),
                                  if (status != 'verified' && status != 'retired') ...[
                                    const Divider(height: 18),
                                    Wrap(spacing: 8, runSpacing: 8, children: [
                                      FilledButton.icon(
                                        onPressed: (row['evidence_count'] as num? ?? 0) > 0
                                          ? () => _review(row, 'approve') : null,
                                        icon: const Icon(Icons.verified_outlined, size: 16),
                                        label: const Text('Approve after evidence review'),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: () => _review(row, 'reject'),
                                        icon: const Icon(Icons.flag_outlined, size: 16),
                                        label: const Text('Reject / dispute'),
                                      ),
                                    ]),
                                    if ((row['evidence_count'] as num? ?? 0) == 0)
                                      const Padding(
                                        padding: EdgeInsets.only(top: 6),
                                        child: Text('Approval requires recorded evidence. Verify the source and authority independently before approval.',
                                          style: TextStyle(fontSize: 10, color: Color(0xFF9A6700))),
                                      ),
                                  ],
                                ]),
                              ),
                            );
                          }),
                      ]),
                    ),
    );
  }
}

class IndiaLgdCsvImportPage extends StatefulWidget {
  const IndiaLgdCsvImportPage({super.key});
  @override
  State<IndiaLgdCsvImportPage> createState() => _IndiaLgdCsvImportPageState();
}

class _IndiaLgdCsvImportPageState extends State<IndiaLgdCsvImportPage> {
  final TextEditingController reportDateController = TextEditingController();
  String unitType = 'district';
  bool busy = false;
  String statusMessage = '';

  static const Map<String, String> unitTypes = {
    'district': 'Districts',
    'sub_district': 'Sub-districts',
    'block': 'Blocks',
    'urban_local_body': 'Urban Local Bodies',
    'gram_panchayat': 'Gram Panchayats',
    'village': 'Villages',
    'ward': 'Wards',
    'traditional_local_body': 'Traditional Local Bodies',
  };

  String _key(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  int _column(List<String> headers, List<String> aliases) {
    for (var i = 0; i < headers.length; i++) {
      if (aliases.contains(headers[i])) return i;
    }
    return -1;
  }

  String _cell(List<dynamic> row, int index) {
    if (index < 0 || index >= row.length) return '';
    return (row[index] ?? '').toString().trim();
  }

  Future<void> _pickAndImport() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      setState(() => statusMessage = 'Sign in before importing an official directory report.');
      return;
    }
    final profile = await supabase.from('profiles').select('role').eq('id', userId).maybeSingle();
    final role = (profile?['role'] ?? '').toString();
    if (role != 'admin' && role != 'coordinator') {
      setState(() => statusMessage = 'This import is restricted to SAMANVAY administrators and coordinators.');
      return;
    }
    final reportDate = DateTime.tryParse(reportDateController.text.trim());
    if (reportDate == null) {
      setState(() => statusMessage = 'Enter the report date in YYYY-MM-DD format before importing.');
      return;
    }

    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (picked == null) return;
    final selectedFile = picked;
    const maxCsvBytes = 25 * 1024 * 1024;
    final bytes = await selectedFile.readAsBytes();
    if (bytes.isEmpty) {
      setState(() => statusMessage = 'The selected CSV could not be read completely.');
      return;
    }
    if (bytes.length > maxCsvBytes) {
      setState(() => statusMessage =
          'The selected CSV exceeds the 25 MB import limit. Split a larger official export into jurisdiction-sized files.');
      return;
    }
    // Fingerprint the exact uploaded bytes for the import audit record.
    final fileSha256 = sha256.convert(bytes).toString();

    setState(() { busy = true; statusMessage = 'Validating the official LGD CSV...'; });
    try {
      var csvText = utf8.decode(bytes, allowMalformed: true);
      if (csvText.startsWith('\uFEFF')) csvText = csvText.substring(1);
      final parsed = csv.decode(csvText);
      if (parsed.length < 2) throw Exception('The CSV contains no data rows.');
      final headers = parsed.first.map((v) => _key(v.toString())).toList();
      final codeAliases = switch (unitType) {
        'district' => ['lgdcode', 'districtlgdcode', 'districtcode', 'code'],
        'sub_district' => ['lgdcode', 'subdistrictlgdcode', 'subdistrictcode', 'code'],
        'block' => ['lgdcode', 'blocklgdcode', 'blockcode', 'code'],
        'urban_local_body' => [
          'lgdcode', 'localbodylgdcode', 'urbanlocalbodylgdcode',
          'localbodycode', 'urbanlocalbodycode', 'code',
        ],
        'gram_panchayat' => [
          'lgdcode', 'grampanchayatlgdcode', 'grampanchayatcode',
          'panchayatcode', 'code',
        ],
        'village' => ['lgdcode', 'villagelgdcode', 'villagecode', 'code'],
        'ward' => ['lgdcode', 'wardlgdcode', 'wardcode', 'code'],
        _ => ['lgdcode', 'traditionalbodylgdcode', 'traditionalbodycode', 'code'],
      };
      final nameAliases = switch (unitType) {
        'district' => ['name', 'districtname', 'districtnameenglish', 'nameenglish'],
        'sub_district' => ['name', 'subdistrictname', 'subdistrictnameenglish', 'nameenglish'],
        'block' => ['name', 'blockname', 'blocknameenglish', 'nameenglish'],
        'urban_local_body' => [
          'name', 'localbodyname', 'localbodynameenglish',
          'urbanlocalbodyname', 'municipalbodyname', 'nameenglish',
        ],
        'gram_panchayat' => [
          'name', 'grampanchayatname', 'panchayatname', 'nameenglish',
        ],
        'village' => ['name', 'villagename', 'villagenameenglish', 'nameenglish'],
        'ward' => ['name', 'wardname', 'wardnameenglish', 'nameenglish'],
        _ => ['name', 'traditionalbodyname', 'nameenglish'],
      };
      final parentAliases = switch (unitType) {
        'district' => <String>[],
        'sub_district' => [
          'parentlgdcode', 'parentcode', 'parentunitcode',
          'districtlgdcode', 'districtcode',
        ],
        'block' => [
          'parentlgdcode', 'parentcode', 'parentunitcode',
          'subdistrictlgdcode', 'subdistrictcode',
          'districtlgdcode', 'districtcode',
        ],
        'urban_local_body' => [
          'parentlgdcode', 'parentcode', 'parentunitcode',
          'districtlgdcode', 'districtcode',
        ],
        'gram_panchayat' => [
          'parentlgdcode', 'parentcode', 'parentunitcode',
          'blocklgdcode', 'blockcode', 'subdistrictlgdcode',
          'subdistrictcode', 'districtlgdcode', 'districtcode',
        ],
        'village' => [
          'parentlgdcode', 'parentcode', 'parentunitcode',
          'grampanchayatlgdcode', 'grampanchayatcode',
          'blocklgdcode', 'blockcode', 'subdistrictlgdcode',
          'subdistrictcode',
        ],
        'ward' => [
          'parentlgdcode', 'parentcode', 'parentunitcode',
          'urbanlocalbodylgdcode', 'urbanlocalbodycode',
          'localbodylgdcode', 'localbodycode',
        ],
        _ => [
          'parentlgdcode', 'parentcode', 'parentunitcode',
          'districtlgdcode', 'districtcode',
        ],
      };
      final codeCol = _column(headers, codeAliases);
      final nameCol = _column(headers, nameAliases);
      final stateCol = _column(headers, [
        'statename', 'statenameenglish', 'stateutname',
        'stateutnameenglish', 'state',
      ]);
      final localNameCol = _column(headers, [
        'namelocal', 'localname', 'localbodynamelocal', 'nameinlocal',
      ]);
      final parentCol = _column(headers, parentAliases);
      if (codeCol < 0 || nameCol < 0 || stateCol < 0) {
        throw Exception(
          'Required columns not found for ' + unitTypes[unitType]! +
          '. Include the entity LGD code, entity name and State Name. '
          'Recognised code headers: ' + codeAliases.join(', ') + '.',
        );
      }
      if (unitType != 'district' && parentCol < 0) {
        throw Exception(
          'The ' + unitTypes[unitType]! +
          ' CSV has no recognised direct-parent LGD code column. '
          'Include Parent LGD Code or the appropriate parent code column so imported records can be linked into the national hierarchy. '
          'No rows were imported.',
        );
      }

      final rawStates = await supabase.from('india_state_uts').select('id,name').limit(100);
      final stateIds = <String, String>{};
      for (final state in rawStates) {
        stateIds[_key(state['name'].toString())] = state['id'].toString();
      }
      // Resolve only the parent LGD codes referenced by this CSV. A fixed
      // first-page lookup (for example, LIMIT 5000) silently misses valid
      // parents once the national directory grows beyond that page.
      final parentCodes = parsed.skip(1)
          .map((row) => _cell(row, parentCol))
          .where((code) => code.isNotEmpty)
          .toSet()
          .toList();
      final parentIds = <String, Map<String, dynamic>>{};
      const parentLookupBatchSize = 200;
      for (var offset = 0; offset < parentCodes.length; offset += parentLookupBatchSize) {
        final end = (offset + parentLookupBatchSize < parentCodes.length)
            ? offset + parentLookupBatchSize
            : parentCodes.length;
        final codeBatch = parentCodes.sublist(offset, end);
        final parentRows = await supabase
            .from('india_administrative_units')
            .select('id,lgd_code,state_ut_id,unit_type')
            .eq('source_system', 'Local Government Directory (LGD)')
            .eq('is_active', true)
            .inFilter('verification_status', ['imported_unverified', 'authority_verified'])
            .inFilter('lgd_code', codeBatch)
            .limit(parentLookupBatchSize);
        for (final row in parentRows) {
          final code = (row['lgd_code'] ?? '').toString();
          if (code.isNotEmpty) {
            parentIds[code] = {
              'id': row['id'].toString(),
              'state_ut_id': row['state_ut_id'].toString(),
              'unit_type': row['unit_type'].toString(),
            };
          }
        }
      }

      final payload = <Map<String, dynamic>>[];
      final seenCodes = <String>{};
      final rejectionReasons = <String, int>{};
      var rejected = 0;
      void rejectRow(String reason) {
        rejected++;
        rejectionReasons[reason] = (rejectionReasons[reason] ?? 0) + 1;
      }
      final expectedParentTypes = switch (unitType) {
        'district' => <String>{},
        'sub_district' => <String>{'district'},
        'block' => <String>{'district', 'sub_district'},
        'urban_local_body' => <String>{'district'},
        'gram_panchayat' => <String>{'district', 'sub_district', 'block'},
        'village' => <String>{'sub_district', 'block', 'gram_panchayat'},
        'ward' => <String>{'urban_local_body'},
        _ => <String>{'district', 'sub_district'},
      };
      for (final row in parsed.skip(1)) {
        final code = _cell(row, codeCol);
        final name = _cell(row, nameCol);
        final stateName = _cell(row, stateCol);
        final stateId = stateIds[_key(stateName)];
        if (code.isEmpty) {
          rejectRow('Missing entity LGD code');
          continue;
        }
        if (name.isEmpty) {
          rejectRow('Missing entity name');
          continue;
        }
        if (stateId == null) {
          rejectRow('State name does not match the 36 State/UT directory');
          continue;
        }
        if (!seenCodes.add(code)) {
          rejectRow('Duplicate LGD code within this CSV');
          continue;
        }

        final parentCode = _cell(row, parentCol);
        Map<String, dynamic>? parent;
        if (unitType != 'district' && parentCode.isEmpty) {
          rejectRow('Missing direct-parent LGD code');
          continue;
        }
        if (parentCode.isNotEmpty) {
          parent = parentIds[parentCode];
          if (parent == null) {
            rejectRow('Parent LGD code is not already imported');
            continue;
          }
          if (parent['state_ut_id'] != stateId) {
            rejectRow('Parent LGD code belongs to a different State/UT');
            continue;
          }
          if (!expectedParentTypes.contains(parent['unit_type'])) {
            rejectRow('Parent LGD code has an incompatible hierarchy type');
            continue;
          }
        }
        final parentId = parent?['id'];
        payload.add({
          'state_ut_id': stateId,
          'parent_unit_id': parentId,
          'unit_type': unitType,
          'lgd_code': code,
          'name': name,
          'local_name': _cell(row, localNameCol).isEmpty ? null : _cell(row, localNameCol),
          'source_system': 'Local Government Directory (LGD)',
          'source_url': 'https://lgdirectory.gov.in/',
          'source_updated_at': reportDate.toIso8601String().split('T').first,
          'verification_status': 'imported_unverified',
          'is_active': true,
        });
      }
      if (payload.isEmpty) {
        final reasonSummary = rejectionReasons.entries
            .map((entry) => entry.key + ': ' + entry.value.toString())
            .join('; ');
        throw Exception(
          'No valid rows remain after LGD hierarchy validation. ' +
          (reasonSummary.isEmpty ? 'Check the CSV headers and source records.' : reasonSummary),
        );
      }

      final touchedStates = payload.map((row) => row['state_ut_id'].toString()).toSet();
      final batchStateId = touchedStates.length == 1 ? touchedStates.first : null;
      Map<String, dynamic>? queuedBatch;
      if (batchStateId != null) {
        queuedBatch = await supabase.from('india_directory_import_batches')
          .select('id')
          .eq('jurisdiction_state_ut_id', batchStateId)
          .eq('unit_type', unitType)
          .eq('import_status', 'awaiting_authorised_export')
          .maybeSingle();
      }

      late final String batchId;
      final batchMetadata = {
        'jurisdiction_state_ut_id': batchStateId,
        'source_url': 'https://lgdirectory.gov.in/downloadDirectory.do',
        'unit_type': unitType,
        'source_updated_at': reportDate.toIso8601String().split('T').first,
        'original_file_name': selectedFile.name,
        'file_sha256': fileSha256,
        'import_status': 'uploaded',
        'rows_received': parsed.length - 1,
        'rows_rejected': rejected,
        'imported_by': userId,
        'notes': 'Imported from an administrator-supplied LGD report converted to CSV. Records remain unverified until authority review.',
      };
      if (queuedBatch != null) {
        batchId = queuedBatch['id'].toString();
        await supabase.from('india_directory_import_batches')
          .update(batchMetadata).eq('id', batchId);
      } else {
        final batch = await supabase.from('india_directory_import_batches')
          .insert(batchMetadata).select('id').single();
        batchId = batch['id'].toString();
      }

      for (var i = 0; i < payload.length; i += 100) {
        final end = (i + 100 < payload.length) ? i + 100 : payload.length;
        final chunk = payload.sublist(i, end)
            .map((row) => {...row, 'import_batch_id': batchId})
            .toList();
        await supabase.from('india_administrative_units')
            .upsert(chunk, onConflict: 'source_system,lgd_code');
      }
      await supabase.from('india_directory_import_batches').update({
        'import_status': 'imported',
        'rows_inserted': payload.length,
        'completed_at': DateTime.now().toIso8601String(),
      }).eq('id', batchId);

      for (final stateId in touchedStates) {
        await supabase.from('india_data_coverage').update({
          'coverage_status': 'directory_records_imported_pending_authority_validation',
          'operational_use_allowed': false,
          'last_checked_at': DateTime.now().toIso8601String(),
          'notes': 'LGD directory rows imported from ' + selectedFile.name +
            ' dated ' + reportDate.toIso8601String().split('T').first +
            '. Imported records remain unverified pending authority review.',
        }).eq('state_ut_id', stateId).eq('data_domain', 'administrative_directory');
      }

      if (!mounted) return;
      setState(() {
        busy = false;
        final reasonSummary = rejectionReasons.entries
            .map((entry) => entry.key + ': ' + entry.value.toString())
            .join('; ');
        statusMessage = 'Import complete: ' + payload.length.toString() +
          ' rows inserted/updated; ' + rejected.toString() +
          ' rows rejected. ' +
          (reasonSummary.isEmpty ? '' : 'Rejection reasons: ' + reasonSummary + '. ') +
          'Records remain unverified until authority review.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        busy = false;
        statusMessage = 'Import stopped: ' + error.toString();
      });
    }
  }

  @override
  void dispose() {
    reportDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Import official LGD directory')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
       Card(child: Padding(
        padding: EdgeInsets.all(14),
        child: Text(
          'ADMINISTRATOR / COORDINATOR ONLY. Generate the report on the official LGD portal yourself, complete its CAPTCHA normally, and convert the XLS/HTML report to CSV using the standard column headings. This importer does not automate or bypass the CAPTCHA.',
          style: TextStyle(fontSize: 11, height: 1.45, color: mutedInk),
        ),
      )),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: unitType,
        decoration: const InputDecoration(labelText: 'Directory entity type', border: OutlineInputBorder()),
        items: unitTypes.entries.map((entry) => DropdownMenuItem(
          value: entry.key, child: Text(entry.value),
        )).toList(),
        onChanged: busy ? null : (value) { if (value != null) setState(() => unitType = value); },
      ),
      const SizedBox(height: 12),
      TextField(
        controller: reportDateController,
        enabled: !busy,
        decoration: const InputDecoration(
          labelText: 'Official report date',
          hintText: 'YYYY-MM-DD',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      Text(
        unitType == 'district'
            ? 'Required: District LGD Code, District Name and State Name. Maximum CSV size: 25 MB.'
            : 'Required: entity LGD code, entity name, State Name and direct-parent LGD code. Ward files should include Local Body Code; village files should include their direct revenue / local-government parent code. Maximum CSV size: 25 MB.',
        style:  TextStyle(fontSize: 11, color: mutedInk, height: 1.4),
      ),
      const SizedBox(height: 14),
      FilledButton.icon(
        onPressed: busy ? null : _pickAndImport,
        icon: busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.upload_file),
        label: Text(busy ? 'IMPORTING...' : 'SELECT CSV AND IMPORT'),
      ),
      if (statusMessage.isNotEmpty) ...[
        const SizedBox(height: 12),
        Card(child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(statusMessage, style: const TextStyle(fontSize: 11, height: 1.4)),
        )),
      ],
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: () => launchUrl(Uri.parse('https://lgdirectory.gov.in/downloadDirectory.do'),
          mode: LaunchMode.externalApplication),
        icon: const Icon(Icons.open_in_new),
        label: const Text('Open official LGD report generator'),
      ),
    ]),
  );
}


class BuildingApprovalRegisterBoard extends StatefulWidget {
  const BuildingApprovalRegisterBoard({super.key});

  @override
  State<BuildingApprovalRegisterBoard> createState() => _BuildingApprovalRegisterBoardState();
}

class _BuildingApprovalRegisterBoardState extends State<BuildingApprovalRegisterBoard> {
  List<Map<String, dynamic>> records = [];
  bool loading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { loading = true; errorMessage = ''; });
    try {
      final rows = await supabase
          .from('building_approval_public_register_records')
          .select('authority,jurisdiction,source_document_title,source_url,approval_status,approved_floor_count,approved_height_m')
          .limit(3000);
      if (!mounted) return;
      setState(() {
        records = List<Map<String, dynamic>>.from(rows);
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorMessage = 'Public building approval register summary is unavailable for this account.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusCounts = <String, int>{};
    for (final row in records) {
      final status = (row['approval_status'] ?? 'Status not supplied').toString();
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }
    final floorValues = records.where((r) => r['approved_floor_count'] != null).length;
    final heightValues = records.where((r) => r['approved_height_m'] != null).length;
    final sourceUrl = records.isNotEmpty ? (records.first['source_url'] ?? '').toString() : '';
    final authority = records.isNotEmpty ? (records.first['authority'] ?? 'Authority not supplied').toString() : 'Municipal Corporation of Delhi';
    final jurisdiction = records.isNotEmpty ? (records.first['jurisdiction'] ?? 'Jurisdiction not supplied').toString() : 'Delhi, India';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
             Icon(Icons.apartment_outlined, color: teal),
            const SizedBox(width: 9),
             Expanded(child: Text('Public building-approval register', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: ink))),
            IconButton(onPressed: loading ? null : _load, icon: const Icon(Icons.refresh), tooltip: 'Refresh public approval register'),
          ]),
           Text('Official published plan-release records imported into SAMANVAY. This is not a nationwide permit registry.', style: TextStyle(fontSize: 10, color: mutedInk)),
          if (loading)
            const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()))
          else if (errorMessage.isNotEmpty)
            Text(errorMessage, style: const TextStyle(fontSize: 11, color: Colors.red))
          else ...[
            const SizedBox(height: 9),
            Row(children: [
              Expanded(child: _approvalMetric('Records', records.length.toString())),
              const SizedBox(width: 8),
              Expanded(child: _approvalMetric('Jurisdiction', jurisdiction)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _approvalMetric('Official floor values', floorValues.toString())),
              const SizedBox(width: 8),
              Expanded(child: _approvalMetric('Official height values', heightValues.toString())),
            ]),
            const SizedBox(height: 8),
            Text('$authority · $jurisdiction', style:  TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ink)),
            const SizedBox(height: 4),
            ...statusCounts.entries.map((entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                Expanded(child: Text(entry.key, style:  TextStyle(fontSize: 10, color: mutedInk))),
                Text(entry.value.toString(), style:  TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: ink)),
              ]),
            )),
            const SizedBox(height: 6),
             Text('Source status is preserved as published. No sanctioned floors, building heights, parcel locations or legal compliance conclusions are inferred from missing fields.', style: TextStyle(fontSize: 10, color: mutedInk)),
            if (sourceUrl.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () async {
                    final uri = Uri.tryParse(sourceUrl);
                    if (uri != null && await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.open_in_new, size: 15),
                  label: const Text('Open original authority register'),
                ),
              ),
          ],
        ]),
      ),
    );
  }

  Widget _approvalMetric(String label, String value) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: panelNavy, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style:  TextStyle(fontSize: 9, color: mutedInk)),
      const SizedBox(height: 3),
      Text(value, maxLines: 2, overflow: TextOverflow.ellipsis,
        style:  TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: ink)),
    ]),
  );
}

class GroundwaterObservationBoard extends StatefulWidget {
  final List<Map<String, dynamic>> requests;
  final List<Map<String, dynamic>> departments;
  final bool isDepartment;
  final String? departmentId;
  const GroundwaterObservationBoard({super.key, required this.requests,
    required this.departments, required this.isDepartment, this.departmentId});
  @override
  State<GroundwaterObservationBoard> createState() => _GroundwaterObservationBoardState();
}

class _GroundwaterObservationBoardState extends State<GroundwaterObservationBoard> {
  List<Map<String, dynamic>> records = [];
  bool loading = true;
  String errorMessage = '';
  List<Map<String, dynamic>> get groundwaterCases => widget.requests
      .where((r) => (r['case_category'] ?? '').toString() == 'borewell_groundwater').toList();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { loading = true; errorMessage = ''; });
    try {
      final rows = await supabase.from('groundwater_observation_records')
          .select().order('observed_at', ascending: false).limit(100);
      if (!mounted) return;
      setState(() { records = List<Map<String, dynamic>>.from(rows); loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { loading = false; errorMessage = 'Groundwater observations could not be loaded for this account.'; });
    }
  }

  String _caseLabel(String id) {
    for (final r in widget.requests) {
      if (r['id'].toString() == id) {
        final n = r['request_number']?.toString();
        final t = (r['title'] ?? r['road_name'] ?? 'Groundwater case').toString();
        return n == null ? t : 'Case #' + n + ' · ' + t;
      }
    }
    return 'Case ' + (id.length > 8 ? id.substring(0, 8) : id);
  }

  Future<void> _add() async {
    final user = supabase.auth.currentUser;
    if (user == null) { _message('Please sign in again.'); return; }
    final cases = groundwaterCases;
    if (cases.isEmpty) { _message('No accessible borewell/groundwater cases are available.'); return; }
    var requestId = cases.first['id'].toString();
    var departmentId = widget.departmentId ?? cases.first['department_id']?.toString()
      ?? (widget.departments.isNotEmpty ? widget.departments.first['id'].toString() : null);
    var wellType = 'borewell';
    var method = 'manual_measurement';
    var pumping = 'unknown';
    var sourceType = 'field_observed';
    var saving = false;
    final site = TextEditingController();
    final level = TextEditingController();
    final sourceRef = TextEditingController();
    final notes = TextEditingController();

    final saved = await showDialog<bool>(context: context, builder: (dialogContext) =>
      StatefulBuilder(builder: (dialogContext, setDialogState) => AlertDialog(
        title: const Text('Record groundwater observation'),
        content: SizedBox(width: 460, child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              initialValue: requestId, isExpanded: true,
              decoration: const InputDecoration(labelText: 'Groundwater case'),
              items: cases.map((r) {
                final id = r['id'].toString();
                return DropdownMenuItem(value: id, child: Text(_caseLabel(id), overflow: TextOverflow.ellipsis));
              }).toList(),
              onChanged: saving ? null : (v) { if (v != null) setDialogState(() => requestId = v); },
            ),
            DropdownButtonFormField<String>(
              initialValue: departmentId, isExpanded: true,
              decoration: const InputDecoration(labelText: 'Responsible department'),
              items: widget.departments.map((d) => DropdownMenuItem<String>(
                value: d['id'].toString(), child: Text((d['name'] ?? 'Department').toString(),
                  overflow: TextOverflow.ellipsis))).toList(),
              onChanged: saving ? null : (v) => setDialogState(() => departmentId = v),
            ),
            TextField(controller: site, decoration: const InputDecoration(labelText: 'Site / well reference *')),
            DropdownButtonFormField<String>(
              initialValue: wellType, decoration: const InputDecoration(labelText: 'Well type'),
              items: const [
                DropdownMenuItem(value: 'borewell', child: Text('Borewell')),
                DropdownMenuItem(value: 'open_well', child: Text('Open well')),
                DropdownMenuItem(value: 'observation_well', child: Text('Observation well')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: saving ? null : (v) { if (v != null) setDialogState(() => wellType = v); },
            ),
            DropdownButtonFormField<String>(
              initialValue: method, decoration: const InputDecoration(labelText: 'Observation method'),
              items: const [
                DropdownMenuItem(value: 'manual_measurement', child: Text('Manual measurement')),
                DropdownMenuItem(value: 'sensor_reading', child: Text('Sensor reading')),
                DropdownMenuItem(value: 'authority_record', child: Text('Authority record')),
                DropdownMenuItem(value: 'field_inspection', child: Text('Field inspection')),
              ],
              onChanged: saving ? null : (v) { if (v != null) setDialogState(() => method = v); },
            ),
            TextField(controller: level, keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Water level below ground (m) *')),
            DropdownButtonFormField<String>(
              initialValue: pumping, decoration: const InputDecoration(labelText: 'Pumping state at observation'),
              items: const [
                DropdownMenuItem(value: 'unknown', child: Text('Unknown')),
                DropdownMenuItem(value: 'not_pumping', child: Text('Not pumping')),
                DropdownMenuItem(value: 'pumping', child: Text('Pumping')),
                DropdownMenuItem(value: 'recovery', child: Text('Recovery')),
              ],
              onChanged: saving ? null : (v) { if (v != null) setDialogState(() => pumping = v); },
            ),
            DropdownButtonFormField<String>(
              initialValue: sourceType, decoration: const InputDecoration(labelText: 'Source type'),
              items: const [
                DropdownMenuItem(value: 'field_observed', child: Text('Field observed')),
                DropdownMenuItem(value: 'authority_document', child: Text('Authority document')),
                DropdownMenuItem(value: 'sensor_snapshot', child: Text('Sensor snapshot')),
              ],
              onChanged: saving ? null : (v) { if (v != null) setDialogState(() => sourceType = v); },
            ),
            TextField(controller: sourceRef, decoration: const InputDecoration(labelText: 'Source / document reference')),
            TextField(controller: notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Measurement notes')),
            const SizedBox(height: 8),
             Text('A water-level reading is not a legal or sustainability classification. Record the measurement time, method and pumping state accurately. This form does not connect to live sensors.',
              style: TextStyle(fontSize: 11, color: mutedInk)),
          ],
        ))),
        actions: [
          TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel')),
          FilledButton(
            onPressed: saving ? null : () async {
              final value = double.tryParse(level.text.trim());
              if (departmentId == null || departmentId!.isEmpty || site.text.trim().isEmpty ||
                  value == null || value < 0) {
                _message('Enter a site reference and a valid non-negative water-level measurement.');
                return;
              }
              setDialogState(() => saving = true);
              try {
                await supabase.from('groundwater_observation_records').insert({
                  'request_id': requestId,
                  'responsible_department_id': departmentId,
                  'site_reference': site.text.trim(),
                  'well_type': wellType,
                  'observation_method': method,
                  'water_level_below_ground_m': value,
                  'pumping_state': pumping,
                  'source_type': sourceType,
                  'source_reference': sourceRef.text.trim().isEmpty ? null : sourceRef.text.trim(),
                  'measurement_notes': notes.text.trim().isEmpty ? null : notes.text.trim(),
                  'created_by': user.id,
                });
                if (dialogContext.mounted) Navigator.pop(dialogContext, true);
              } catch (_) {
                setDialogState(() => saving = false);
                _message('Unable to save. Confirm that the case is assigned to the selected department.');
              }
            },
            child: saving ? const SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save observation'),
          ),
        ],
      )),
    );
    site.dispose(); level.dispose(); sourceRef.dispose(); notes.dispose();
    if (saved == true) { await _load(); _message('Groundwater observation recorded.'); }
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
           Icon(Icons.water_drop_outlined, color: teal),
          const SizedBox(width: 9),
           Expanded(child: Text('Borewell & groundwater field observations',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: ink))),
          IconButton(onPressed: loading ? null : _load, icon: const Icon(Icons.refresh)),
        ]),
         Text('Append dated site measurements to a borewell/groundwater case. The public station snapshot above remains separate.',
          style: TextStyle(fontSize: 11, color: mutedInk)),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(
          onPressed: groundwaterCases.isEmpty ? null : _add,
          icon: const Icon(Icons.add), label: const Text('RECORD GROUNDWATER OBSERVATION'))),
        const SizedBox(height: 8),
        if (loading) const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
        else if (errorMessage.isNotEmpty) Text(errorMessage, style: const TextStyle(fontSize: 12, color: Colors.red))
        else if (records.isEmpty)  Text('No field observations have been recorded yet.',
          style: TextStyle(fontSize: 12, color: mutedInk))
        else ...records.map((r) {
          final dept = (r['responsible_department_id'] ?? '').toString();
          return Container(margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: panelNavy, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_caseLabel(r['request_id'].toString()),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              Text((r['site_reference'] ?? 'Site not specified').toString() + ' · ' +
                (r['well_type'] ?? '').toString().replaceAll('_', ' ') + ' · ' +
                (r['water_level_below_ground_m']?.toString() ?? '—') + ' m below ground',
                style:  TextStyle(fontSize: 11, color: ink)),
              Text(_departmentName(dept) + ' · ' +
                (r['pumping_state'] ?? 'unknown').toString().replaceAll('_', ' ') + ' · ' +
                (r['source_type'] ?? '').toString().replaceAll('_', ' '),
                style:  TextStyle(fontSize: 10, color: mutedInk)),
              Text('Observed: ' + (r['observed_at'] ?? '').toString(),
                style:  TextStyle(fontSize: 10, color: mutedInk)),
            ]));
        }),
      ],
    )));
  }

  String _departmentName(String id) {
    for (final d in widget.departments) {
      if (d['id'].toString() == id) return (d['name'] ?? 'Department').toString();
    }
    return 'Department';
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
        color: panelNavy,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: teal, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style:  TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: ink,
            ),
          ),
          Text(
            title,
            style:  TextStyle(color: mutedInk),
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
      backgroundColor: background,
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
        backgroundColor: electricBlue,
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

             Text(
              'Filter by status',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: ink,
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
      color: panelNavy,
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
                    style:  TextStyle(
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
              style:  TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: ink,
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
                style:  TextStyle(
                  color: mutedInk,
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
        Icon(icon, size: 17, color: mutedInk),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style:  TextStyle(
              fontSize: 13,
              color: mutedInk,
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
           Icon(
            Icons.assignment_outlined,
            size: 65,
            color: teal,
          ),
          const SizedBox(height: 15),
           Text(
            'No requests found',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: ink,
            ),
          ),
          const SizedBox(height: 8),
           Text(
            'Create your first excavation request '
            'using the button below.',
            textAlign: TextAlign.center,
            style: TextStyle(color: mutedInk),
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
            style:  TextStyle(color: mutedInk),
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
             Text(
              'Request details',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: ink,
              ),
            ),

            const SizedBox(height: 8),

             Text(
              'Register a work proposal or infrastructure issue for coordinated review by the responsible departments.',
              style: TextStyle(color: mutedInk),
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
                labelText: 'Reported issue / work activity',
                prefixIcon: Icon(Icons.build_outlined),
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'new_installation', child: Text('New installation / development')),
                DropdownMenuItem(value: 'repair', child: Text('Repair')),
                DropdownMenuItem(value: 'maintenance', child: Text('Repair / maintenance of existing infrastructure')),
                DropdownMenuItem(value: 'relocation', child: Text('Relocation')),
                DropdownMenuItem(value: 'survey', child: Text('Survey')),
                DropdownMenuItem(value: 'inspection', child: Text('Inspection')),
                DropdownMenuItem(value: 'violation_report', child: Text('Possible violation / complaint')),
                DropdownMenuItem(value: 'emergency_response', child: Text('Emergency response')),
                DropdownMenuItem(value: 'repeat_excavation_coordination', child: Text('Repeated digging / joint-work coordination')),
                DropdownMenuItem(value: 'utility_route_conflict', child: Text('Underground utility route conflict / clash')),
                DropdownMenuItem(value: 'unplanned_road_cutting', child: Text('Unplanned road cutting / restoration issue')),
                DropdownMenuItem(value: 'frontage_drainage_gap', child: Text('Missing or obstructed house-front drainage')),
                DropdownMenuItem(value: 'unauthorised_borewell', child: Text('Possible unauthorised / excessive borewell')),
                DropdownMenuItem(value: 'groundwater_overextraction', child: Text('Groundwater stress / over-extraction concern')),
                DropdownMenuItem(value: 'building_height_violation', child: Text('Possible building height / planning violation')),
                DropdownMenuItem(value: 'water_pipeline_leakage', child: Text('Drinking-water pipeline leakage / failure')),
                DropdownMenuItem(value: 'water_pipeline_mapping', child: Text('Water pipeline mapping / asset-record gap')),
                DropdownMenuItem(value: 'stormwater_encroachment', child: Text('Stormwater drain obstruction / encroachment')),
                DropdownMenuItem(value: 'other', child: Text('Other infrastructure issue')),
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

             Text(
              'Planned schedule',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: ink,
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
              child:  Text(
                'A case number will be generated automatically. Department assignment and official decisions are completed by authorised officers.',
                style: TextStyle(
                  color: ink,
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
           Icon(Icons.calendar_month, color: teal),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style:  TextStyle(color: mutedInk),
                ),
                const SizedBox(height: 4),
                Text(
                  formatDate(date),
                  style:  TextStyle(
                    color: ink,
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
      backgroundColor: panelNavy,
      appBar: AppBar(
        title: const Text('Select Work Location'),
        backgroundColor: navy,
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
// ==========================================
// ==========================================
// LPU CAMPUS — LIVE BASEMAP VIEW
// ==========================================
// Uses the same live national GIS map as every other region. No synthetic
// routes or invented campus asset locations are rendered. LPU-owned utility
// geometry will appear only after authorised, verified survey records exist.
class LpuCampusModelPage extends StatelessWidget {
  const LpuCampusModelPage({super.key});

  static const LatLng _campusCentre = LatLng(31.2559, 75.7050);

  @override
  Widget build(BuildContext context) => const MapPage(
    initialCenter: _campusCentre,
    initialZoom: 16.1,
    initialTilt: 54,
    contextLabel: 'LPU CAMPUS · PHAGWARA',
  );
}

class ClashVisualizerPage extends StatefulWidget {
  const ClashVisualizerPage({super.key, required this.candidates});
  final List<Map<String, dynamic>> candidates;

  @override
  State<ClashVisualizerPage> createState() => _ClashVisualizerPageState();
}

class _ClashVisualizerPageState extends State<ClashVisualizerPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flow;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _flow = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat();
  }

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  String _caseTitle(dynamic value) {
    if (value is! Map) return 'Infrastructure case';
    final row = Map<String, dynamic>.from(value);
    return (row['title'] ?? row['case_category'] ?? row['request_number'] ?? 'Infrastructure case')
        .toString().replaceAll('_', ' ');
  }

  Widget _alertCard(Map<String, dynamic> match, int index) {
    final first = Map<String, dynamic>.from(match['first'] as Map);
    final second = Map<String, dynamic>.from(match['second'] as Map);
    final distance = ((match['distance'] as num?) ?? 0).toDouble();
    final start = match['start'] is DateTime ? match['start'] as DateTime : null;
    final end = match['end'] is DateTime ? match['end'] as DateTime : null;
    final selected = index == _selectedIndex;
    final title = _caseTitle(first) + '  ↔  ' + _caseTitle(second);
    final window = start == null || end == null
        ? 'Overlapping planned works · date window unavailable'
        : 'Overlapping window · ' + start.toString().substring(0, 10) + ' – ' + end.toString().substring(0, 10);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        borderRadius: BorderRadius.circular(13),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF3A222B) : const Color(0xFF14253A),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected ? const Color(0xFFFF646E) : const Color(0xFF30465B),
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected
                ? const [BoxShadow(color: Color(0x33FF454F), blurRadius: 18)]
                : const [],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.warning_amber_rounded,
                color: selected ? const Color(0xFFFF767F) : const Color(0xFFFFB45F), size: 17),
              const SizedBox(width: 6),
              Expanded(child: Text(
                'POTENTIAL SPATIAL OVERLAP',
                style: TextStyle(
                  color: selected ? const Color(0xFFFFA1A6) : const Color(0xFFFFD18D),
                  fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: .7,
                ),
              )),
              Text(distance.round().toString() + ' m',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
            ]),
            const SizedBox(height: 8),
            Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(window, style: const TextStyle(color: Color(0xFFB8C9D8), fontSize: 9)),
            const SizedBox(height: 7),
            Text(
              'Coordinator review required · verify owner records and field conditions',
              style: TextStyle(color: selected ? const Color(0xFFFFA6AB) : const Color(0xFF91D7D0),
                fontSize: 9, fontWeight: FontWeight.w700),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _sceneBadge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xE90B1A2B),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: .6)),
    ),
    child: Text(text, style: TextStyle(color: color, fontSize: 8,
      fontWeight: FontWeight.w900, letterSpacing: .6)),
  );

  Widget _legendDot(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 8, height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: color.withValues(alpha: .45), blurRadius: 7)])),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(color: Color(0xFFB8C9D8), fontSize: 8, fontWeight: FontWeight.w700)),
    ],
  );

  Widget _scenePanel() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(fit: StackFit.expand, children: [
            AnimatedBuilder(
              animation: _flow,
              builder: (context, _) => CustomPaint(
                painter: _Clash3DScenePainter(
                  phase: _flow.value,
                  hasCandidate: widget.candidates.isNotEmpty,
                  selectedIndex: _selectedIndex,
                ),
              ),
            ),
            Positioned(left: 13, top: 13,
              child: _sceneBadge(
                widget.candidates.isEmpty ? 'NO CURRENT CANDIDATES' : 'POTENTIAL OVERLAP DETECTED',
                widget.candidates.isEmpty ? const Color(0xFF39C6B5) : const Color(0xFFFF666F),
              ),
            ),
            Positioned(right: 12, top: 12,
              child: _sceneBadge('3D CUTAWAY · ADVISORY', const Color(0xFF8BDCD3))),
            Positioned(right: 12, bottom: 12,
              child: _sceneBadge('SCHEMATIC · NOT SURVEYED', const Color(0xFFFFD18D))),
          ]),
        ),
      ),
      const SizedBox(height: 11),
      Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _legendDot(const Color(0xFF31BFF2), 'Water'),
          _legendDot(const Color(0xFFFFA34B), 'Sewer'),
          _legendDot(const Color(0xFFB88CFF), 'Power / fibre'),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MapPage()),
            ),
            icon: const Icon(Icons.map_outlined, size: 16),
            label: const Text('Open live GIS'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF167D87),
              foregroundColor: Colors.white,
              textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF071426),
    appBar: AppBar(
      backgroundColor: const Color(0xFF0B1D31),
      foregroundColor: Colors.white,
      title: Row(children: [
        const Icon(Icons.hub_rounded, color: Color(0xFF5ED8D0), size: 22),
        const SizedBox(width: 9),
        const Expanded(child: Text('CLASH DETECTION & CONFLICT ALERT',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: .55))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(color: const Color(0xFF4B2029), borderRadius: BorderRadius.circular(9)),
          child: Text(widget.candidates.length.toString() + ' CANDIDATE(S)',
            style: const TextStyle(color: Color(0xFFFF8990), fontSize: 8, fontWeight: FontWeight.w900)),
        ),
      ]),
    ),
    body: LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 900;
      final alertList = Container(
        width: wide ? 350 : double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xFF0E2035),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: const Color(0xFF283D55)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: Text('CONFLICT CANDIDATES',
              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .8))),
            Text(widget.candidates.length.toString(),
              style: const TextStyle(color: Color(0xFFFF7C84), fontSize: 17, fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 7),
          const Text('Different work domains within 100 m with overlapping planned dates.',
            style: TextStyle(color: Color(0xFF9EB3C6), fontSize: 9, height: 1.4)),
          const SizedBox(height: 12),
          Expanded(
            child: widget.candidates.isEmpty
                ? const Center(child: Text(
                    'No qualifying candidates in the current record window.\nCases without coordinates or planned dates are not assessed.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF9EB3C6), fontSize: 11, height: 1.5),
                  ))
                : ListView.builder(
                    itemCount: widget.candidates.length,
                    itemBuilder: (context, index) => _alertCard(widget.candidates[index], index),
                  ),
          ),
        ]),
      );

      final scene = Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1C2D),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: const Color(0xFF28445D)),
        ),
        child: Column(children: [
          Expanded(child: _scenePanel()),
          const SizedBox(height: 10),
          const Text(
            'This view is a coordination aid, not an underground utility survey. Candidate generation is rule-based. The 3D crossing graphic is illustrative; live pipe routes appear only when verified owner-authorised geometry is available.',
            style: TextStyle(color: Color(0xFFFFD18D), fontSize: 8.5, height: 1.45),
          ),
        ]),
      );

      if (wide) {
        return Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(width: 350, child: alertList),
            const SizedBox(width: 13),
            Expanded(child: scene),
          ]),
        );
      }
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          SizedBox(height: 250, child: alertList),
          const SizedBox(height: 10),
          Expanded(child: scene),
        ]),
      );
    }),
  );
}

class _Clash3DScenePainter extends CustomPainter {
  const _Clash3DScenePainter({
    required this.phase,
    required this.hasCandidate,
    required this.selectedIndex,
  });
  final double phase;
  final bool hasCandidate;
  final int selectedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xFF0C2439), Color(0xFF091829), Color(0xFF050F1C)],
      ).createShader(rect));

    final roadTop = Path()
      ..moveTo(w * .03, h * .18)
      ..lineTo(w * .94, h * .08)
      ..lineTo(w * .98, h * .48)
      ..lineTo(w * .07, h * .62)
      ..close();
    canvas.drawPath(roadTop, Paint()..color = const Color(0xFF384B5E));
    canvas.drawPath(roadTop, Paint()
      ..color = const Color(0xFF9FB4C4).withValues(alpha: .65)
      ..style = PaintingStyle.stroke..strokeWidth = 1.2);

    final soil = Path()
      ..moveTo(w * .07, h * .62)
      ..lineTo(w * .98, h * .48)
      ..lineTo(w * .98, h)
      ..lineTo(w * .07, h)
      ..close();
    canvas.drawPath(soil, Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xFF354854), Color(0xFF1E3443), Color(0xFF102538)],
      ).createShader(Rect.fromLTWH(0, h * .48, w, h * .52)));

    for (var i = 0; i < 4; i++) {
      final y = h * (.68 + i * .075);
      final band = Path()
        ..moveTo(w * .07, y)
        ..cubicTo(w * .34, y - h * .035, w * .64, y + h * .02, w * .98, y - h * .04);
      canvas.drawPath(band, Paint()
        ..color = const Color(0xFFB0C3BF).withValues(alpha: .16)
        ..style = PaintingStyle.stroke..strokeWidth = 1.1);
    }

    final centre = Path()
      ..moveTo(w * .06, h * .39)
      ..cubicTo(w * .35, h * .34, w * .62, h * .28, w * .96, h * .23);
    canvas.drawPath(centre, Paint()
      ..color = const Color(0xFFD3E0E8).withValues(alpha: .70)
      ..style = PaintingStyle.stroke..strokeWidth = 1.2);

    Path pipe(double y, bool reverse) {
      final p = Path();
      if (!reverse) {
        p.moveTo(-w * .03, y);
        p.cubicTo(w * .23, y - h * .16, w * .36, y + h * .12, w * .54, h * .77);
        p.cubicTo(w * .72, h * .86, w * .83, y - h * .09, w * 1.04, y + h * .05);
      } else {
        p.moveTo(w * .04, h * .91);
        p.cubicTo(w * .24, h * .76, w * .42, h * .71, w * .54, h * .77);
        p.cubicTo(w * .69, h * .80, w * .81, h * .59, w * .98, h * .68);
      }
      return p;
    }

    void drawTube(Path path, Color color, double width, double offset) {
      canvas.drawPath(path, Paint()
        ..color = const Color(0xFF050C16)
        ..style = PaintingStyle.stroke..strokeWidth = width + 11
        ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
      canvas.drawPath(path, Paint()
        ..color = Color.lerp(color, Colors.black, .42)!
        ..style = PaintingStyle.stroke..strokeWidth = width + 4
        ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
      canvas.drawPath(path, Paint()
        ..color = color
        ..style = PaintingStyle.stroke..strokeWidth = width
        ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
      canvas.drawPath(path, Paint()
        ..color = Colors.white.withValues(alpha: .42)
        ..style = PaintingStyle.stroke..strokeWidth = math.max(1.1, width * .18).toDouble()
        ..strokeCap = StrokeCap.round);
      final m = path.computeMetrics().first;
      for (var i = 0; i < 4; i++) {
        final d = ((phase + offset + i / 4) % 1.0) * m.length;
        final t = m.getTangentForOffset(d);
        if (t == null) continue;
        canvas.drawCircle(t.position, width * .66,
          Paint()..color = color.withValues(alpha: .4)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
        canvas.drawCircle(t.position, width * .22,
          Paint()..color = Colors.white.withValues(alpha: .95));
      }
    }

    drawTube(pipe(h * .72, false), const Color(0xFF27BDF5), 9, 0);
    drawTube(pipe(h * .84, true), const Color(0xFFFF9848), 8, .28);
    drawTube(pipe(h * .64, true), const Color(0xFF22C9A6), 5, .55);

    final c = Offset(w * .54, h * .77);
    if (hasCandidate) {
      final pulse = .5 + .5 * math.sin(phase * math.pi * 2);
      canvas.drawCircle(c, 17 + pulse * 16,
        Paint()..color = const Color(0xFFFF334B).withValues(alpha: .19)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
      canvas.drawCircle(c, 10 + pulse * 4,
        Paint()..color = const Color(0xFFFF334B).withValues(alpha: .18)
          ..style = PaintingStyle.stroke..strokeWidth = 2);
      canvas.drawCircle(c, 5, Paint()..color = const Color(0xFFFF6A73));
    } else {
      canvas.drawCircle(c, 5, Paint()..color = const Color(0xFF44C9B6));
    }

    final grid = Paint()..color = Colors.white.withValues(alpha: .07)..strokeWidth = .7;
    for (var i = 0; i < 6; i++) {
      final yy = h * (.66 + i * .06);
      canvas.drawLine(Offset(w * .07, yy), Offset(w * .98, yy - h * .13), grid);
    }
    final tp = TextPainter(
      text: TextSpan(
        text: hasCandidate ? 'POTENTIAL CONFLICT · REVIEW REQUIRED' : 'NO CURRENT COORDINATION CANDIDATE',
        style: const TextStyle(color: Color(0xFFFFA3A8), fontSize: 9,
          fontWeight: FontWeight.w900, letterSpacing: .7),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: w * .75);
    tp.paint(canvas, Offset(w * .08, h * .06));
  }

  @override
  bool shouldRepaint(covariant _Clash3DScenePainter old) =>
      old.phase != phase || old.hasCandidate != hasCandidate || old.selectedIndex != selectedIndex;
}

class MapPage extends StatefulWidget {
  const MapPage({
    super.key,
    this.initialCenter,
    this.initialZoom = 3.5,
    this.initialTilt = 0,
    this.contextLabel,
  });

  final LatLng? initialCenter;
  final double initialZoom;
  final double initialTilt;
  final String? contextLabel;

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  static const String _mapTilerKey =
      String.fromEnvironment('MAPTILER_API_KEY');
  // Dark OpenFreeMap OSM vector style; satellite uses the MapTiler source key.
  static const String _vectorStyle =
      'https://tiles.openfreemap.org/styles/dark';

  static const String _esriImageryStyle = '''
  {
    "version": 8,
    "sources": {
      "esri-world-imagery": {
        "type": "raster",
        "tiles": ["https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}"],
        "tileSize": 256,
        "attribution": "Sources: Esri, Maxar, Earthstar Geographics, USDA FSA, USGS, and the GIS User Community"
      },
      "esri-world-imagery-labels": {
        "type": "raster",
        "tiles": ["https://services.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}"],
        "tileSize": 256,
        "attribution": "Esri"
      }
    },
    "layers": [
      {"id": "esri-imagery", "type": "raster", "source": "esri-world-imagery"},
      {"id": "esri-imagery-labels", "type": "raster", "source": "esri-world-imagery-labels"}
    ]
  }
  ''';

  MapLibreMapController? _controller;
  CameraPosition? _pendingBasemapCamera;
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _openingMapCases = <String>{};
  Timer? _viewportRefreshTimer;
  List<Map<String, dynamic>> _placeResults = [];
  bool _searching = false;
  bool _utilityQueryInFlight = false;
  bool _requestLayerInFlight = false;
  bool _requestLayerRefreshPending = false;
  String _scaleLabel = '';
  double _scaleWidth = 80;
  bool _is3D = true;
  bool _undergroundMode = true;
  bool _styleReady = false;
  bool _buildingReadinessLoaded = false;
  bool _utilityReadinessLoaded = false;
  bool _groundwaterReadinessLoaded = false;
  int _approvalRecordCount = 0;
  int _approvalMappedCount = 0;
  int _approvalFloorCount = 0;
  int _utilityLayerCatalogueCount = 0;
  int _utilityLayersPending = 0;
  int _utilityLayersOperational = 0;
  int _groundwaterCoverageJurisdictions = 0;
  int _groundwaterTelemetryGaps = 0;
  bool _satellite = false;
  bool _showRequests = true;
  bool _showUtilityZones = true;
  bool _canViewUtilityOverview = false;
  bool _canViewConflictScreening = false;
  bool _loadingLayers = false;
  bool _locating = false;
  bool _hasLocationPermission = false;
  int _requestMarkerCount = 0;
  int _utilityCellCount = 0;
  int _verifiedAssetCount = 0;
  int _unverifiedAssetCount = 0;
  int _utilityConflictCount = 0;
  String _utilityConflictStatus = 'Conflict screening has not run.';
  List<Map<String, dynamic>> _visibleRequests = [];
  final Map<String, Map<String, dynamic>> _utilityConflictDetails = {};
  String _lastConflictAlertSignature = '';
  bool _canViewDepartmentAssets = false;
  bool _showVerifiedAssets = true;
  bool _showCoimbatoreWardBoundaries = true;
  int _coimbatoreWardCount = 0;
  bool _showGroundwaterTelemetry = true;
  int _groundwaterStationCount = 0;
  String _groundwaterFreshnessLabel = 'Not loaded';
  String _groundwaterLatestAgency = 'Not reported';
  final Map<String, Map<String, dynamic>> _groundwaterStationDetails = {};
  String _deviceCoordinateLabel = '';
  String _layerStatus =
      'Underground visibility requires authorised, verified GIS records.';
  bool _routing = false;
  String _routeSummary = '';
  List<String> _routeInstructions = [];
  Map<String, dynamic>? _activeRouteGeoJson;

  String get _mapStyle {
    if (_satellite) {
      if (_mapTilerKey.isNotEmpty) {
        return 'https://api.maptiler.com/maps/hybrid/style.json?key=$_mapTilerKey';
      }
      return _esriImageryStyle;
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
    if (layerId == 'samanvay-groundwater-telemetry-points') {
      final details = _groundwaterStationDetails[id];
      if (details != null) {
        final station = (details['station_name'] ?? 'Groundwater station').toString();
        final district = (details['district_name'] ?? '').toString();
        final state = (details['state_name'] ?? '').toString();
        final reading = details['reported_level_m'];
        final readingText = (details['reported_level_text'] ?? '').toString();
        final observed = (details['observed_at_local'] ?? 'Timestamp unavailable').toString();
        final place = [district, state].where((part) => part.isNotEmpty).join(', ');
        final level = readingText.isNotEmpty
            ? readingText
            : reading == null ? 'not reported' : '$reading m';
        _showMessage('$station${place.isEmpty ? '' : ' · $place'} · level: $level · observed: $observed');
      }
      return;
    }
    if (layerId == 'samanvay-utility-conflict-markers') {
      final details = _utilityConflictDetails[id];
      if (details != null) {
        final conflicts = (details['conflicts'] as List?) ?? const [];
        final summary = conflicts.take(3).map((raw) {
          final item = Map<String, dynamic>.from(raw as Map);
          return '${item['owner_department']} · ${item['asset_type']} · ${item['distance_m']} m · depth ${item['depth_m'] ?? 'n/a'} m · accuracy ${item['horizontal_accuracy_m'] ?? 'unknown'} m';
        }).join(' | ');
        _showMessage(
          'POTENTIAL UTILITY PROXIMITY · Request ${details['request_number']} · '
          '${details['candidate_count']} verified asset match(es). $summary. '
          'Recorded depths/accuracy are advisory metadata only. Obtain owner-department clearance and field verification; this is not a safety clearance.',
        );
      }
      return;
    }
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

  // Reload request markers and cross-department advisories for the current
  // map viewport. A pending flag coalesces camera movement during pagination.
  Future<void> _loadVisibleWorkRequests() async {
    if (_requestLayerInFlight) {
      _requestLayerRefreshPending = true;
      return;
    }
    _requestLayerInFlight = true;
    try {
      do {
        _requestLayerRefreshPending = false;
        final controller = _controller;
        if (controller == null || !_styleReady) break;

        final visibleBounds = await controller.getVisibleRegion();
        final centerLatitude =
            (visibleBounds.southwest.latitude + visibleBounds.northeast.latitude) / 2;
        final latitudeBuffer = 1000 / 110540;
        final longitudeScale =
            (math.cos(centerLatitude * math.pi / 180).abs()).clamp(0.01, 1.0);
        final longitudeBuffer = 1000 / (111320 * longitudeScale);
        final minRequestLat =
            (visibleBounds.southwest.latitude - latitudeBuffer).clamp(-90.0, 90.0);
        final maxRequestLat =
            (visibleBounds.northeast.latitude + latitudeBuffer).clamp(-90.0, 90.0);
        final minRequestLon =
            (visibleBounds.southwest.longitude - longitudeBuffer).clamp(-180.0, 180.0);
        final maxRequestLon =
            (visibleBounds.northeast.longitude + longitudeBuffer).clamp(-180.0, 180.0);

        final loadedRequestRows = <Map<String, dynamic>>[];
        const requestPageSize = 500;
        var requestOffset = 0;
        while (true) {
          final requestPage = await supabase
              .from('excavation_requests')
              .select('id,request_number,title,status,latitude,longitude,work_radius_m')
              .gte('latitude', minRequestLat)
              .lte('latitude', maxRequestLat)
              .gte('longitude', minRequestLon)
              .lte('longitude', maxRequestLon)
              .order('created_at', ascending: false)
              .order('id')
              .range(requestOffset, requestOffset + requestPageSize - 1);
          final pageRows = List<Map<String, dynamic>>.from(requestPage);
          loadedRequestRows.addAll(pageRows);
          if (pageRows.length < requestPageSize) break;
          requestOffset += requestPageSize;
        }

        if (!mounted) break;
        _visibleRequests = loadedRequestRows;
        final features = <Map<String, dynamic>>[];
        for (final row in loadedRequestRows) {
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
        final requestCollection = {
          'type': 'FeatureCollection',
          'features': features,
        };
        if (sourceIds.contains('samanvay-work-requests')) {
          await controller.setGeoJsonSource(
            'samanvay-work-requests',
            requestCollection,
          );
        } else {
          await controller.addGeoJsonSource(
            'samanvay-work-requests',
            requestCollection,
          );
        }

        var layerIds = await controller.getLayerIds();
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
          layerIds = await controller.getLayerIds();
        }
        if (layerIds.contains('samanvay-work-request-points')) {
          await controller.setLayerVisibility(
            'samanvay-work-request-points',
            _showRequests,
          );
        }

        if (mounted) {
          setState(() => _requestMarkerCount = features.length);
        }
        if (_canViewConflictScreening) {
          await _refreshUtilityConflictOverlay();
        }
      } while (_requestLayerRefreshPending && mounted);
    } catch (_) {
      if (mounted) {
        setState(() {
          _utilityConflictCount = 0;
          _utilityConflictStatus = 'Request locations or conflict advisories could not be refreshed. Check connectivity and staff access; do not treat this as a clear site.';
          _utilityConflictDetails.clear();
        });
      }
    } finally {
      _requestLayerInFlight = false;
    }
  }

  void _handleCameraIdle() {
    if (!_styleReady) return;
    _viewportRefreshTimer?.cancel();
    _viewportRefreshTimer = Timer(const Duration(milliseconds: 420), () async {
      if (!mounted) return;
      await _refreshMapScale();
      if (!mounted) return;
      await _loadVisibleWorkRequests();
      if (_showGroundwaterTelemetry) {
        await _loadGroundwaterTelemetryStations();
      }
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
              [
                'max',
                6,
                [
                  'coalesce',
                  ['to-number', ['get', 'render_height']],
                  ['to-number', ['get', 'height']],
                  ['*', ['to-number', ['get', 'building:levels']], 3],
                  6,
                ],
              ],
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

      // Fine footprint edges improve the legibility of real OSM building
      // massing at neighbourhood zoom without inventing facade geometry.
      final refreshedLayers = await controller.getLayerIds();
      if (!refreshedLayers.contains('samanvay-3d-building-outlines')) {
        await controller.addLineLayer(
          'openmaptiles',
          'samanvay-3d-building-outlines',
          const LineLayerProperties(
            lineColor: '#B8D0E0',
            lineWidth: 0.65,
            lineOpacity: 0.48,
          ),
          sourceLayer: 'building',
          minzoom: 14,
          enableInteraction: false,
        );
      }

      await controller.setLayerVisibility(
        'samanvay-3d-buildings',
        _is3D,
      );
      await controller.setLayerVisibility(
        'samanvay-3d-building-outlines',
        _is3D,
      );
    } catch (_) {
      // If a provider style lacks the expected source/attributes, the
      // basemap remains usable. No illustrative buildings are substituted.
    }
  }

  Future<void> _openJurisdictionNavigator() async {
    List<Map<String, dynamic>> stateRows;
    try {
      final rows = await supabase
          .from('india_state_uts')
          .select('id,name,jurisdiction_type')
          .order('name')
          .limit(100);
      stateRows = List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      _showMessage('The State/UT directory could not be loaded for this account.');
      return;
    }
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: panelNavy,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        String? stateId;
        String? districtId;
        String? localBodyId;
        String? wardId;
        List<Map<String, dynamic>> districts = [];
        List<Map<String, dynamic>> localBodies = [];
        List<Map<String, dynamic>> wards = [];
        bool loadingDistricts = false;
        bool loadingLocalBodies = false;
        bool loadingWards = false;
        String directoryMessage = '';

        return StatefulBuilder(
          builder: (context, setSheetState) {
            Map<String, dynamic>? findById(
              List<Map<String, dynamic>> rows,
              String? id,
            ) {
              if (id == null) return null;
              for (final row in rows) {
                if (row['id']?.toString() == id) return row;
              }
              return null;
            }

            String unitLabel(Map<String, dynamic> row) {
              final name = (row['name'] ?? 'Unnamed unit').toString();
              final code = (row['lgd_code'] ?? '').toString();
              final verified = row['verification_status'] == 'authority_verified';
              final suffix = verified
                  ? ' · authority verified'
                  : ' · imported, verification pending';
              final sourceDate = (row['source_updated_at'] ?? '').toString().trim();
              final datedSuffix = sourceDate.isEmpty ? '' : ' · report ' + sourceDate;
              return name + (code.isEmpty ? '' : ' · LGD ' + code) +
                  suffix + datedSuffix;
            }

            Future<void> loadDistricts(String selectedId) async {
              setSheetState(() {
                loadingDistricts = true;
                loadingLocalBodies = false;
                loadingWards = false;
                districts = [];
                localBodies = [];
                wards = [];
                districtId = null;
                localBodyId = null;
                wardId = null;
                directoryMessage = '';
              });
              try {
                final rows = await supabase
                    .from('india_administrative_units')
                    .select('id,name,lgd_code,verification_status,parent_unit_id,source_system,source_updated_at')
                    .eq('state_ut_id', selectedId)
                    .eq('unit_type', 'district')
                    .eq('source_system', 'Local Government Directory (LGD)')
                    .eq('is_active', true)
                    .inFilter('verification_status', ['imported_unverified', 'authority_verified'])
                    .order('name')
                    .limit(1000);
                if (!sheetContext.mounted) return;
                setSheetState(() {
                  districts = List<Map<String, dynamic>>.from(rows);
                  loadingDistricts = false;
                  if (districts.isEmpty) {
                    directoryMessage =
                        'No official district rows are imported for this State/UT yet. State-level map search is still available.';
                  }
                });
              } catch (_) {
                if (!sheetContext.mounted) return;
                setSheetState(() {
                  loadingDistricts = false;
                  directoryMessage =
                      'District directory is unavailable under the current account permissions.';
                });
              }
            }

            Future<void> loadLocalBodies(String parentId) async {
              setSheetState(() {
                loadingLocalBodies = true;
                loadingWards = false;
                localBodies = [];
                wards = [];
                localBodyId = null;
                wardId = null;
                directoryMessage = '';
              });
              try {
                final rows = await supabase
                    .from('india_administrative_units')
                    .select('id,name,lgd_code,verification_status,parent_unit_id,source_system,source_updated_at')
                    .eq('state_ut_id', stateId!)
                    .eq('parent_unit_id', parentId)
                    .eq('unit_type', 'urban_local_body')
                    .eq('source_system', 'Local Government Directory (LGD)')
                    .eq('is_active', true)
                    .inFilter('verification_status', ['imported_unverified', 'authority_verified'])
                    .order('name')
                    .limit(1000);
                if (!sheetContext.mounted) return;
                setSheetState(() {
                  localBodies = List<Map<String, dynamic>>.from(rows);
                  loadingLocalBodies = false;
                  if (localBodies.isEmpty) {
                    directoryMessage =
                        'No urban local bodies are linked to this district in the imported LGD directory.';
                  }
                });
              } catch (_) {
                if (!sheetContext.mounted) return;
                setSheetState(() {
                  loadingLocalBodies = false;
                  directoryMessage = 'Urban-local-body records could not be loaded.';
                });
              }
            }

            Future<void> loadWards(String parentId) async {
              setSheetState(() {
                loadingWards = true;
                wards = [];
                wardId = null;
                directoryMessage = '';
              });
              try {
                final rows = await supabase
                    .from('india_administrative_units')
                    .select('id,name,lgd_code,verification_status,parent_unit_id,source_system,source_updated_at')
                    .eq('state_ut_id', stateId!)
                    .eq('parent_unit_id', parentId)
                    .eq('unit_type', 'ward')
                    .eq('source_system', 'Local Government Directory (LGD)')
                    .eq('is_active', true)
                    .inFilter('verification_status', ['imported_unverified', 'authority_verified'])
                    .order('name')
                    .limit(2000);
                if (!sheetContext.mounted) return;
                setSheetState(() {
                  wards = List<Map<String, dynamic>>.from(rows);
                  loadingWards = false;
                  if (wards.isEmpty) {
                    directoryMessage =
                        'No ward records are linked to this urban local body in the imported LGD directory.';
                  }
                });
              } catch (_) {
                if (!sheetContext.mounted) return;
                setSheetState(() {
                  loadingWards = false;
                  directoryMessage = 'Ward records could not be loaded.';
                });
              }
            }

            final selectedState = findById(stateRows, stateId);
            final selectedDistrict = findById(districts, districtId);
            final selectedLocalBody = findById(localBodies, localBodyId);
            final selectedWard = findById(wards, wardId);

            Widget unavailable(String message) => Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: panelNavy,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x665F7C93)),
              ),
              child: Text(
                message,
                style:  TextStyle(
                  color: mutedInk,
                  fontSize: 10,
                  height: 1.4,
                ),
              ),
            );

            final queryParts = [
              selectedWard?['name'],
              selectedLocalBody?['name'],
              selectedDistrict?['name'],
              selectedState?['name'],
              'India',
            ].where((part) => part != null && part.toString().trim().isNotEmpty)
             .map((part) => part.toString().trim()).toList();
            final canSearch = selectedState != null;

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16, 16, 16, MediaQuery.of(sheetContext).viewInsets.bottom + 18,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.account_tree_outlined,
                              color: Color(0xFF55D9CE)),
                          const SizedBox(width: 9),
                          const Expanded(
                            child: Text(
                              'INDIA JURISDICTION NAVIGATOR',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: .7,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(Icons.close, color: Colors.white70),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                       Text(
                        'Choose a level from the imported directory. Missing district, city or ward records are not filled with estimates.',
                        style: TextStyle(
                          color: mutedInk,
                          fontSize: 10,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 13),
                      DropdownButtonFormField<String>(
                        key: ValueKey('jurisdiction-state-' + (stateId ?? '')),
                        initialValue: stateId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'State / Union Territory',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: stateRows.map((row) => DropdownMenuItem<String>(
                          value: row['id'].toString(),
                          child: Text(
                            row['name'].toString(),
                            overflow: TextOverflow.ellipsis,
                          ),
                        )).toList(),
                        onChanged: (value) async {
                          if (value == null) return;
                          setSheetState(() {
                            stateId = value;
                            districtId = null;
                            localBodyId = null;
                            wardId = null;
                          });
                          await loadDistricts(value);
                        },
                      ),
                      if (stateId != null) ...[
                        const SizedBox(height: 10),
                        if (loadingDistricts)
                          const LinearProgressIndicator(minHeight: 2),
                        if (districts.isNotEmpty)
                          DropdownButtonFormField<String>(
                            key: ValueKey('jurisdiction-district-' + (districtId ?? '') + '-' + districts.length.toString()),
                            initialValue: districtId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'District (official LGD directory)',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: districts.map((row) => DropdownMenuItem<String>(
                              value: row['id'].toString(),
                              child: Text(
                                unitLabel(row),
                                overflow: TextOverflow.ellipsis,
                              ),
                            )).toList(),
                            onChanged: (value) async {
                              if (value == null) return;
                              setSheetState(() {
                                districtId = value;
                                localBodyId = null;
                                wardId = null;
                              });
                              await loadLocalBodies(value);
                            },
                          )
                        else if (!loadingDistricts)
                          unavailable(
                            'District directory not imported for this State/UT. You can still search the selected State/UT.',
                          ),
                      ],
                      if (districtId != null) ...[
                        const SizedBox(height: 10),
                        if (loadingLocalBodies)
                          const LinearProgressIndicator(minHeight: 2),
                        if (localBodies.isNotEmpty)
                          DropdownButtonFormField<String>(
                            key: ValueKey('jurisdiction-ulb-' + (localBodyId ?? '') + '-' + localBodies.length.toString()),
                            initialValue: localBodyId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'City / Urban Local Body',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: localBodies.map((row) => DropdownMenuItem<String>(
                              value: row['id'].toString(),
                              child: Text(
                                unitLabel(row),
                                overflow: TextOverflow.ellipsis,
                              ),
                            )).toList(),
                            onChanged: (value) async {
                              if (value == null) return;
                              setSheetState(() {
                                localBodyId = value;
                                wardId = null;
                              });
                              await loadWards(value);
                            },
                          )
                        else if (!loadingLocalBodies)
                          unavailable(
                            'No city / urban-local-body records are currently linked to the selected district.',
                          ),
                      ],
                      if (localBodyId != null) ...[
                        const SizedBox(height: 10),
                        if (loadingWards)
                          const LinearProgressIndicator(minHeight: 2),
                        if (wards.isNotEmpty)
                          DropdownButtonFormField<String>(
                            key: ValueKey('jurisdiction-ward-' + (wardId ?? '') + '-' + wards.length.toString()),
                            initialValue: wardId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Ward',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: wards.map((row) => DropdownMenuItem<String>(
                              value: row['id'].toString(),
                              child: Text(
                                unitLabel(row),
                                overflow: TextOverflow.ellipsis,
                              ),
                            )).toList(),
                            onChanged: (value) {
                              if (value != null) setSheetState(() => wardId = value);
                            },
                          )
                        else if (!loadingWards)
                          unavailable(
                            'No ward rows are currently linked to the selected urban local body.',
                          ),
                      ],
                      if (directoryMessage.isNotEmpty)
                        unavailable(directoryMessage),
                      const SizedBox(height: 13),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: !canSearch
                              ? null
                              : () {
                                  final query = queryParts.join(', ');
                                  Navigator.of(sheetContext).pop();
                                  _searchController.text = query;
                                  _searchPlaces(query);
                                },
                          icon: const Icon(Icons.location_searching_rounded),
                          label: Text(
                            selectedWard != null
                                ? 'SEARCH SELECTED WARD'
                                : selectedLocalBody != null
                                    ? 'SEARCH SELECTED CITY'
                                    : selectedDistrict != null
                                        ? 'SEARCH SELECTED DISTRICT'
                                        : 'SEARCH SELECTED STATE / UT',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF13A89E),
                            foregroundColor: background,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 9),
                      const Text(
                        'MAP NAVIGATION ONLY: The selected LGD name is sent to the map search provider. Search-result coordinates are geocoding results, not official boundary polygons or legal jurisdiction geometry. Imported LGD rows remain unverified until authority review.',
                        style: TextStyle(
                          color: Color(0xFFF6C66B),
                          fontSize: 9,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
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

  Future<LatLng> _geocodeRoutePlace(String query) async {
    final uri = Uri.https('photon.komoot.io', '/api/', {
      'q': query,
      'limit': '1',
      'lang': 'en',
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw StateError('Place lookup returned HTTP ${response.statusCode}.');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['features'] is! List ||
        (decoded['features'] as List).isEmpty) {
      throw StateError('Could not find: $query');
    }
    final first = (decoded['features'] as List).first;
    if (first is! Map || first['geometry'] is! Map) {
      throw const FormatException('Place lookup returned invalid geometry.');
    }
    final coordinates = (first['geometry'] as Map)['coordinates'];
    if (coordinates is! List || coordinates.length < 2 ||
        coordinates[0] is! num || coordinates[1] is! num) {
      throw const FormatException('Place lookup returned invalid coordinates.');
    }
    return LatLng(
      (coordinates[1] as num).toDouble(),
      (coordinates[0] as num).toDouble(),
    );
  }

  Future<void> _renderActiveRoute() async {
    final controller = _controller;
    final route = _activeRouteGeoJson;
    if (controller == null || !_styleReady || route == null) return;

    final sources = await controller.getSourceIds();
    if (sources.contains('samanvay-navigation-route')) {
      await controller.setGeoJsonSource('samanvay-navigation-route', route);
    } else {
      await controller.addGeoJsonSource('samanvay-navigation-route', route);
    }

    final layers = await controller.getLayerIds();
    if (!layers.contains('samanvay-navigation-route-line')) {
      await controller.addLineLayer(
        'samanvay-navigation-route',
        'samanvay-navigation-route-line',
        const LineLayerProperties(
          lineColor: '#20D6C2',
          lineWidth: 5,
          lineOpacity: 0.96,
        ),
        enableInteraction: false,
      );
    }
    await controller.setLayerVisibility('samanvay-navigation-route-line', true);
  }

  Future<void> _calculateRoute(String originText, String destinationText) async {
    if (_routing) return;
    if (originText.trim().isEmpty || destinationText.trim().isEmpty) {
      _showMessage('Enter both a starting point and a destination.');
      return;
    }

    setState(() {
      _routing = true;
      _routeSummary = '';
      _routeInstructions = [];
    });

    try {
      final origin = await _geocodeRoutePlace(originText.trim());
      final destination = await _geocodeRoutePlace(destinationText.trim());
      final uri = Uri.https(
        'router.project-osrm.org',
        '/route/v1/driving/${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}',
        {
          'overview': 'full',
          'geometries': 'geojson',
          'steps': 'true',
          'alternatives': 'true',
        },
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 25));
      if (response.statusCode != 200) {
        throw StateError('Routing service returned HTTP ${response.statusCode}.');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['code'] != 'Ok' ||
          decoded['routes'] is! List || (decoded['routes'] as List).isEmpty) {
        throw StateError('No drivable route was returned for these places.');
      }

      final route = (decoded['routes'] as List).first;
      if (route is! Map || route['geometry'] is! Map ||
          (route['geometry'] as Map)['coordinates'] is! List) {
        throw const FormatException('Routing service returned invalid route geometry.');
      }
      final coordinates = (route['geometry'] as Map)['coordinates'] as List;
      if (coordinates.length < 2) {
        throw const FormatException('The route contains too few coordinates.');
      }

      final featureCollection = <String, dynamic>{
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'properties': {'source': 'OSRM public demonstration routing service'},
            'geometry': Map<String, dynamic>.from(route['geometry'] as Map),
          },
        ],
      };

      final distanceMeters = (route['distance'] as num?)?.toDouble() ?? 0;
      final durationSeconds = (route['duration'] as num?)?.toDouble() ?? 0;
      final distanceLabel = distanceMeters >= 1000
          ? '${(distanceMeters / 1000).toStringAsFixed(1)} km'
          : '${distanceMeters.round()} m';
      final durationMinutes = (durationSeconds / 60).round();
      final summary = '$distanceLabel · about $durationMinutes min · driving preview';

      final instructions = <String>[];
      final legs = route['legs'];
      if (legs is List) {
        for (final leg in legs) {
          if (leg is! Map || leg['steps'] is! List) continue;
          for (final step in leg['steps'] as List) {
            if (step is! Map) continue;
            final maneuver = step['maneuver'];
            final name = (step['name'] ?? '').toString().trim();
            if (maneuver is! Map) continue;
            final type = (maneuver['type'] ?? 'continue').toString();
            final modifier = (maneuver['modifier'] ?? '').toString();
            final distance = (step['distance'] as num?)?.toDouble() ?? 0;
            final action = [type, modifier].where((v) => v.isNotEmpty).join(' ');
            final road = name.isEmpty ? 'unnamed road' : name;
            instructions.add('${action.isEmpty ? 'Continue' : action} on $road · ${distance.round()} m');
            if (instructions.length >= 12) break;
          }
          if (instructions.length >= 12) break;
        }
      }

      if (!mounted) return;
      setState(() {
        _activeRouteGeoJson = featureCollection;
        _routeSummary = summary;
        _routeInstructions = instructions;
      });
      await _renderActiveRoute();

      final middle = coordinates[coordinates.length ~/ 2];
      if (middle is List && middle.length >= 2 &&
          middle[0] is num && middle[1] is num) {
        await _controller?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(
                (middle[1] as num).toDouble(),
                (middle[0] as num).toDouble(),
              ),
              zoom: 11.5,
              tilt: _is3D && !_undergroundMode ? 42 : 0,
              bearing: 0,
            ),
          ),
          duration: const Duration(milliseconds: 900),
        );
      }

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Route preview'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(summary, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  const Text(
                    'Preview route only. This public routing service does not provide live traffic, guaranteed turn-by-turn guidance or excavation clearance.',
                    style: TextStyle(fontSize: 12, color: Colors.deepOrange),
                  ),
                  const SizedBox(height: 12),
                  ...instructions.map((instruction) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('• $instruction', style: const TextStyle(fontSize: 12)),
                  )),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (error) {
      _showMessage('Route preview failed: ${error.toString()}');
    } finally {
      if (mounted) setState(() => _routing = false);
    }
  }

  Future<void> _showDirectionsDialog() async {
    final originController = TextEditingController();
    final destinationController = TextEditingController();

    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Plan a route'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: originController,
              decoration: const InputDecoration(
                labelText: 'Starting point',
                hintText: 'e.g. Coimbatore Railway Station',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: destinationController,
              decoration: const InputDecoration(
                labelText: 'Destination',
                hintText: 'e.g. Gandhipuram Bus Stand',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.directions),
            label: const Text('Find route'),
          ),
        ],
      ),
    );

    if (accepted == true) {
      await _calculateRoute(originController.text, destinationController.text);
    }
    originController.dispose();
    destinationController.dispose();
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
      await _renderActiveRoute();
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
          _showCoimbatoreWardBoundaries && !_undergroundMode,
        );
      }
      if (layers.contains('samanvay-coimbatore-ward-lines')) {
        await controller.setLayerVisibility(
          'samanvay-coimbatore-ward-lines',
          _showCoimbatoreWardBoundaries && !_undergroundMode,
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
      final bounds = await controller.getVisibleRegion();
      final rows = await supabase
          .from('latest_groundwater_station_observations')
          .select('id,station_name,agency,state_name,district_name,tehsil,latitude,longitude,rl_msl_m,observed_at_local,reported_level_m,reported_level_text')
          .gte('latitude', bounds.southwest.latitude)
          .lte('latitude', bounds.northeast.latitude)
          .gte('longitude', bounds.southwest.longitude)
          .lte('longitude', bounds.northeast.longitude)
          .order('state_name')
          .order('district_name')
          .limit(1000);

      final features = <Map<String, dynamic>>[];
      final stationDetails = <Map<String, dynamic>>[];
      DateTime? latestObservationTime;
      String latestObservationSourceText = '';
      String latestObservationAgency = '';
      for (final item in rows) {
        final properties = Map<String, dynamic>.from(item);
        final latitude = properties['latitude'];
        final longitude = properties['longitude'];
        if (latitude is! num || longitude is! num) continue;

        final sourceTimestamp = (properties['observed_at_local'] ?? '').toString().trim();
        final parsedTimestamp = DateTime.tryParse(sourceTimestamp);
        if (parsedTimestamp != null &&
            (latestObservationTime == null || parsedTimestamp.isAfter(latestObservationTime))) {
          latestObservationTime = parsedTimestamp;
          latestObservationSourceText = sourceTimestamp;
          latestObservationAgency = (properties['agency'] ?? '').toString().trim();
        }

        final featureId = (properties['id'] ?? '').toString();
        if (featureId.isEmpty) continue;
        features.add({
          'type': 'Feature',
          'id': featureId,
          'geometry': {
            'type': 'Point',
            'coordinates': [longitude.toDouble(), latitude.toDouble()],
          },
          'properties': properties,
        });
        stationDetails.add(Map<String, dynamic>.from(properties));
      }

      final collection = <String, dynamic>{
        'type': 'FeatureCollection',
        'features': features,
      };
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
          enableInteraction: true,
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
        setState(() {
          _groundwaterStationCount = features.length;
          _groundwaterFreshnessLabel = latestObservationSourceText.isEmpty
              ? 'No valid source timestamp in the current map extent'
              : latestObservationSourceText;
          _groundwaterLatestAgency = latestObservationAgency.isEmpty
              ? 'Publisher not stated'
              : latestObservationAgency;
          _groundwaterStationDetails
            ..clear()
            ..addEntries(stationDetails.map((properties) => MapEntry(
              (properties['id'] ?? '').toString(),
              properties,
            )));
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _groundwaterStationCount = 0;
          _groundwaterFreshnessLabel = 'Observation layer unavailable';
          _groundwaterLatestAgency = 'Publisher unavailable';
          _groundwaterStationDetails.clear();
        });
      }
    }
  }

  Future<void> _loadMapLayers() async {
    final controller = _controller;
    if (controller == null || !_styleReady) return;

    if (mounted) setState(() => _loadingLayers = true);

    try {
      // Public administrative reference data is independent of account role.
      // This 2024 ward reference layer is not a current statutory jurisdiction source.
      await Future.wait<void>([
        _loadCoimbatoreWardBoundaries(),
        _loadGroundwaterTelemetryStations(),
        _loadMapReadiness(),
      ]);

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

      if (mounted) {
        setState(() {
          // Public map access is limited to generalised 250 m aggregate cells.
          // The server RPC returns verified aggregates (minimum 3 assets/cell),
          // never exact routes, depths, or owner-specific geometry.
          // Public endpoint returns verified 250 m aggregate cells only.
          // Every signed-in role (Citizen included) can view this overview.
          _canViewUtilityOverview = true;
          _canViewConflictScreening = authorised;
          _canViewDepartmentAssets = departmentAssigned;
          _layerStatus = departmentAssigned
              ? 'Department GIS view: public aggregate coverage plus verified assets owned by your department. Other owners’ exact geometry remains withheld.'
              : authorised
                  ? 'Staff GIS view: public aggregate coverage; exact asset geometry remains restricted.'
                  : 'Citizen GIS view: generalised coverage only. Exact utility routes and depths are never disclosed.';
        });
      }

      await _loadVisibleWorkRequests();

      if (_showUtilityZones) {
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

      var layerIds = await controller.getLayerIds();
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
      }

      // Generalised 250 m density cells can be extruded in underground 3D mode.
      // Extrusion height is a relative density index, never physical depth or a pipe route.
      layerIds = await controller.getLayerIds();
      if (!layerIds.contains('samanvay-utility-overview-3d')) {
        await controller.addFillExtrusionLayer(
          'samanvay-utility-overview',
          'samanvay-utility-overview-3d',
          FillExtrusionLayerProperties(
            fillExtrusionColor: '#38BDF8',
            fillExtrusionHeight: [
              'interpolate',
              ['linear'],
              ['get', 'asset_count'],
              3, 6,
              10, 14,
              25, 24,
            ],
            fillExtrusionBase: 0,
            fillExtrusionOpacity: 0.62,
          ),
        );
      }

      layerIds = await controller.getLayerIds();
      final showDensityExtrusion =
          _showUtilityZones && _undergroundMode && _is3D;
      if (layerIds.contains('samanvay-utility-overview-cells')) {
        await controller.setLayerVisibility(
          'samanvay-utility-overview-cells',
          _showUtilityZones && !showDensityExtrusion,
        );
      }
      if (layerIds.contains('samanvay-utility-overview-3d')) {
        await controller.setLayerVisibility(
          'samanvay-utility-overview-3d',
          showDensityExtrusion,
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

  Future<void> _refreshUtilityConflictOverlay() async {
    final controller = _controller;
    if (controller == null || !_styleReady || !_canViewUtilityOverview) return;

    final activeRequests = _visibleRequests.where((request) {
      final status = (request['status'] ?? '').toString().toLowerCase();
      return !['completed', 'resolved', 'rejected', 'cancelled'].contains(status);
    }).toList();

    final features = <Map<String, dynamic>>[];
    final detailsById = <String, Map<String, dynamic>>{};
    var eligibleRequestCount = 0;
    var verifiedAssetsAvailable = false;

    try {
      const batchSize = 500;
      for (var offset = 0; offset < activeRequests.length; offset += batchSize) {
        final batch = activeRequests.skip(offset).take(batchSize).toList();
        final requestIds = batch
            .map((request) => (request['id'] ?? '').toString())
            .where((id) => id.isNotEmpty)
            .toList();
        if (requestIds.isEmpty) continue;

        // The server performs PostGIS screening against verified assets across
        // departments and returns advisory metadata only, never asset geometry.
        final raw = await supabase.rpc(
          'get_map_utility_conflict_advisories',
          params: {'p_request_ids': requestIds},
        );
        final response = Map<String, dynamic>.from(raw as Map);
        verifiedAssetsAvailable =
            response['verified_assets_available'] == true || verifiedAssetsAvailable;
        final rawResults = response['results'];
        if (rawResults is! List) continue;

        for (final rawResult in rawResults) {
          if (rawResult is! Map) continue;
          final result = Map<String, dynamic>.from(rawResult);
          final screeningStatus = (result['screening_status'] ?? '').toString();
          if (screeningStatus == 'potential_conflict' ||
              screeningStatus == 'screened_no_proximity_match') {
            eligibleRequestCount++;
          }
          final rawConflicts = result['conflicts'];
          if (screeningStatus != 'potential_conflict' ||
              rawConflicts is! List || rawConflicts.isEmpty) {
            continue;
          }

          final requestId = (result['request_id'] ?? '').toString();
          final request = batch.firstWhere(
            (item) => item['id']?.toString() == requestId,
            orElse: () => <String, dynamic>{},
          );
          if (request.isEmpty) continue;
          final lat = (request['latitude'] as num?)?.toDouble();
          final lon = (request['longitude'] as num?)?.toDouble();
          if (lat == null || lon == null) continue;

          final conflicts = rawConflicts
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
          if (conflicts.isEmpty) continue;

          final requestNumber =
              (result['request_number'] ?? requestId).toString();
          final markerId = requestId.replaceAll(
            RegExp(r'[^A-Za-z0-9_-]'),
            '_',
          );
          detailsById[markerId] = {
            'request_number': requestNumber,
            'candidate_count': conflicts.length,
            'conflicts': conflicts,
          };
          features.add({
            'type': 'Feature',
            'id': markerId,
            'geometry': {
              'type': 'Point',
              'coordinates': [lon, lat],
            },
            'properties': {
              'request_number': requestNumber,
              'candidate_count': conflicts.length,
            },
          });
        }
      }

      final collection = {
        'type': 'FeatureCollection',
        'features': features,
      };
      final sources = await controller.getSourceIds();
      if (sources.contains('samanvay-utility-conflict-candidates')) {
        await controller.setGeoJsonSource(
          'samanvay-utility-conflict-candidates',
          collection,
        );
      } else {
        await controller.addGeoJsonSource(
          'samanvay-utility-conflict-candidates',
          collection,
        );
      }

      final layers = await controller.getLayerIds();
      if (!layers.contains('samanvay-utility-conflict-markers')) {
        await controller.addCircleLayer(
          'samanvay-utility-conflict-candidates',
          'samanvay-utility-conflict-markers',
          const CircleLayerProperties(
            circleRadius: 9,
            circleColor: '#EF4444',
            circleOpacity: 0.98,
            circleStrokeColor: '#FFFFFF',
            circleStrokeWidth: 2.2,
          ),
          enableInteraction: true,
        );
      } else {
        await controller.setLayerVisibility(
          'samanvay-utility-conflict-markers',
          true,
        );
      }

      if (!mounted) return;
      final status = activeRequests.isEmpty
          ? 'No active work requests are available in this map area to screen.'
          : !verifiedAssetsAvailable
              ? 'No verified underground utility assets are registered. Cross-department screening is unavailable; this does not mean sites are clear.'
              : eligibleRequestCount == 0
                  ? 'No active request in the loaded map area has a valid location and an entered 1–500 m work-site radius.'
                  : features.isEmpty
                      ? 'No proximity warnings found among verified assets for the screened requests. This is not an excavation clearance.'
                      : '${features.length} request(s) have potential proximity to verified underground assets across departments. Obtain owner-department clearance and field verification.';
      final alertSignature = detailsById.keys.toList()..sort();
      final signature = alertSignature.join('|');
      final shouldNotify = signature.isNotEmpty &&
          signature != _lastConflictAlertSignature;
      _lastConflictAlertSignature = signature;
      setState(() {
        _utilityConflictCount = features.length;
        _utilityConflictStatus = status;
        _utilityConflictDetails
          ..clear()
          ..addAll(detailsById);
      });
      if (shouldNotify) {
        _showMessage(
          '${features.length} work request(s) have potential proximity to verified underground assets across departments. Tap a red marker for advisory details.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _utilityConflictCount = 0;
          _utilityConflictStatus = 'Cross-department screening could not be completed. Check staff access and GIS connectivity; do not treat this as a clear site.';
          _utilityConflictDetails.clear();
        });
      }
    }
  }

  Future<void> _loadDepartmentAssets() async {
    final controller = _controller;
    if (controller == null || !_styleReady || !_canViewDepartmentAssets) return;

    try {
      final bounds = await controller.getVisibleRegion();
      final centerLatitude =
          (bounds.southwest.latitude + bounds.northeast.latitude) / 2;
      final latitudeBuffer = 1000 / 110540;
      final longitudeScale =
          (math.cos(centerLatitude * math.pi / 180).abs()).clamp(0.01, 1.0);
      final longitudeBuffer = 1000 / (111320 * longitudeScale);
      final minLon =
          (bounds.southwest.longitude - longitudeBuffer).clamp(-180.0, 180.0);
      final minLat =
          (bounds.southwest.latitude - latitudeBuffer).clamp(-90.0, 90.0);
      final maxLon =
          (bounds.northeast.longitude + longitudeBuffer).clamp(-180.0, 180.0);
      final maxLat =
          (bounds.northeast.latitude + latitudeBuffer).clamp(-90.0, 90.0);
      if (minLon >= maxLon || minLat >= maxLat) return;

      // The 1 km query buffer covers maximum work radius plus survey uncertainty.
      // This RPC remains scoped by auth.uid() to the signed-in department's own assets.
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
      _showMessage('The public aggregate coverage layer is not ready. Refresh the map and retry.');
      return;
    }

    setState(() => _showUtilityZones = enabled);
    final controller = _controller;
    if (controller == null || !_styleReady) return;

    if (!enabled) {
      try {
        final layers = await controller.getLayerIds();
        for (final layerId in [
          'samanvay-utility-overview-cells',
          'samanvay-utility-overview-3d',
        ]) {
          if (layers.contains(layerId)) {
            await controller.setLayerVisibility(layerId, false);
          }
        }
      } catch (_) {}
      return;
    }

    await _loadUtilityOverview();
  }


  Future<void> _setUndergroundMode(bool enabled) async {
    if (_undergroundMode == enabled) return;

    final controller = _controller;
    setState(() {
      _undergroundMode = enabled;
      if (enabled) {
        _showUtilityZones = _canViewUtilityOverview;
        _showVerifiedAssets = _canViewDepartmentAssets;
      } else {
        _showUtilityZones = false;
        _showVerifiedAssets = false;
      }
    });

    if (controller == null || !_styleReady) return;

    Future<void> setVisibility(String layerId, bool visible) async {
      final layerIds = await controller.getLayerIds();
      if (layerIds.contains(layerId)) {
        await controller.setLayerVisibility(layerId, visible);
      }
    }

    try {
      if (enabled) {
        // Hide the surface extrusions and ward outlines to make the
        // underground operational layer visually distinct.
        await setVisibility('samanvay-3d-buildings', _is3D);
        await setVisibility('samanvay-3d-building-outlines', _is3D);
        await setVisibility('samanvay-coimbatore-ward-fill', false);
        await setVisibility('samanvay-coimbatore-ward-lines', false);

        if (_canViewUtilityOverview) {
          await _loadUtilityOverview();
        }
        if (_canViewDepartmentAssets) {
          await _loadDepartmentAssets();
        }

        if (!_canViewUtilityOverview) {
          if (mounted) {
            setState(() {
              _layerStatus =
                  'Public underground coverage is temporarily unavailable. No data shown is not proof that utilities are absent.';
            });
          }
        } else if (mounted) {
          setState(() {
            _layerStatus = _canViewDepartmentAssets
                ? 'Underground mode: generalised national/municipal coverage plus verified geometry owned by your department. Other departments’ exact routes remain withheld.'
                : 'Underground mode: public generalised coverage cells only. Exact utility routes and depths remain withheld.';
          });
        }
      } else {
        await setVisibility('samanvay-utility-overview-cells', false);
        await setVisibility('samanvay-utility-overview-3d', false);
        await setVisibility('samanvay-verified-asset-lines', false);
        await setVisibility('samanvay-verified-asset-points', false);
        await setVisibility('samanvay-3d-buildings', _is3D);
        await setVisibility('samanvay-coimbatore-ward-fill', _showCoimbatoreWardBoundaries);
        await setVisibility('samanvay-coimbatore-ward-lines', _showCoimbatoreWardBoundaries);
        if (mounted) {
          setState(() {
            _layerStatus = 'Surface mode: 2D/3D basemap, work requests and available public reference layers.';
          });
        }
      }
    } catch (_) {
      _showMessage('Unable to switch map mode. Refresh the map layers and retry.');
    }
  }

  Future<void> _changeBasemap(bool useSatellite) async {
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
        await controller.setLayerVisibility('samanvay-3d-buildings', use3D && !_undergroundMode);
      }
      if (layers.contains('samanvay-utility-overview-cells')) {
        await controller.setLayerVisibility(
          'samanvay-utility-overview-cells',
          _showUtilityZones,
        );
      }
      if (layers.contains('samanvay-utility-overview-3d')) {
        await controller.setLayerVisibility(
          'samanvay-utility-overview-3d',
          _showUtilityZones && _undergroundMode && use3D,
        );
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
          ? (_mapTilerKey.isNotEmpty
              ? 'https://www.maptiler.com/copyright/'
              : 'https://www.esri.com/')
          : 'https://openfreemap.org/',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      _showMessage('Unable to open the map provider attribution page.');
    }
  }


  Future<void> _loadMapReadiness() async {
    var buildingLoaded = false;
    var utilityLoaded = false;
    var groundwaterLoaded = false;

    var approvalCount = 0;
    var approvalMapped = 0;
    var approvalFloors = 0;
    var utilityCount = 0;
    var utilityPending = 0;
    var utilityUnverified = 0;
    var utilityOperational = 0;
    var groundwaterJurisdictions = 0;
    var groundwaterGaps = 0;

    try {
      final rawRows = await supabase
          .from('building_approval_public_register_records')
          .select('id,geometry_status,approved_floor_count')
          .limit(2500);
      final rows = rawRows.map((raw) => Map<String, dynamic>.from(raw as Map)).toList();
      approvalCount = rows.length;
      approvalMapped = rows.where((row) => row['geometry_status'] == 'verified_geocoded').length;
      approvalFloors = rows.where((row) => row['approved_floor_count'] != null).length;
      buildingLoaded = true;
    } catch (_) {
      // A missing permission or unavailable register must not block the map.
    }

    try {
      final rawRows = await supabase
          .from('india_data_coverage')
          .select('id,coverage_status,operational_use_allowed')
          .eq('data_domain', 'utility_gis')
          .limit(50);
      final rows = rawRows.map((raw) => Map<String, dynamic>.from(raw as Map)).toList();
      utilityCount = rows.length;
      utilityPending = rows.where((row) => row['coverage_status'] == 'authority_asset_gis_required').length;
      utilityOperational = rows.where((row) => row['operational_use_allowed'] == true).length;
      utilityLoaded = true;
    } catch (_) {
      // Metadata-only utility status is optional for requester accounts.
    }

    try {
      final rawRows = await supabase
          .from('india_data_coverage')
          .select('telemetry_status')
          .eq('data_domain', 'groundwater')
          .limit(50);
      final rows = rawRows.map((raw) => Map<String, dynamic>.from(raw as Map)).toList();
      groundwaterJurisdictions = rows.length;
      groundwaterGaps = rows.where((row) {
        final status = (row['telemetry_status'] ?? '').toString();
        return status.contains('no_2021_2025_feed') ||
            status.contains('unverified') ||
            status.contains('historical');
      }).length;
      groundwaterLoaded = true;
    } catch (_) {
      // Station rendering continues even if the national coverage summary is unavailable.
    }

    if (!mounted) return;
    setState(() {
      _buildingReadinessLoaded = buildingLoaded;
      _utilityReadinessLoaded = utilityLoaded;
      _groundwaterReadinessLoaded = groundwaterLoaded;
      _approvalRecordCount = approvalCount;
      _approvalMappedCount = approvalMapped;
      _approvalFloorCount = approvalFloors;
      _utilityLayerCatalogueCount = utilityCount;
      _utilityLayersPending = utilityPending;
      _utilityLayersOperational = utilityOperational;
      _groundwaterCoverageJurisdictions = groundwaterJurisdictions;
      _groundwaterTelemetryGaps = groundwaterGaps;
    });
  }

  Widget _readinessRow({
    required IconData icon,
    required String title,
    required String detail,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style:  TextStyle(
                    color: mutedInk,
                    fontSize: 10,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openLayerPanel() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: panelNavy,
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
                     Text(
                      'Layers are drawn only from records your account is authorised to access.',
                      style: TextStyle(color: mutedInk, fontSize: 11),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(13, 12, 13, 10),
                      decoration: BoxDecoration(
                        color: panelNavy,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0x5541BFB4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'NATIONAL DATA READINESS',
                            style: TextStyle(
                              color: Color(0xFF55D9CE),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 7),
                          _readinessRow(
                            icon: Icons.water_drop_outlined,
                            title: 'GROUNDWATER',
                            color: const Color(0xFFA78BFA),
                            detail: _groundwaterReadinessLoaded
                                ? '$_groundwaterStationCount station point(s) in this map extent · up to 1,000 displayed · latest timestamp among loaded records (max 1,000): $_groundwaterFreshnessLabel · publisher: $_groundwaterLatestAgency · $_groundwaterTelemetryGaps of $_groundwaterCoverageJurisdictions State/UT coverage entries still lack a verified 2021–2025 telemetry feed'
                                : 'Coverage summary unavailable; station layer remains independently controlled.',
                          ),
                          _readinessRow(
                            icon: Icons.account_balance_outlined,
                            title: 'BUILDING APPROVALS',
                            color: const Color(0xFFFBBF24),
                            detail: _buildingReadinessLoaded
                                ? '$_approvalRecordCount public-register record(s) · $_approvalMappedCount geocoded · $_approvalFloorCount with approved floor count. Address-only records are not plotted at guessed locations.'
                                : 'Public approval register summary unavailable.',
                          ),
                          _readinessRow(
                            icon: Icons.hub_outlined,
                            title: 'UNDERGROUND UTILITY GIS',
                            color: const Color(0xFF38BDF8),
                            detail: _utilityReadinessLoaded
                                ? '$_utilityLayerCatalogueCount State/UT coverage entry(ies) · $_utilityLayersPending awaiting authority asset GIS · $_utilityLayersOperational operationally enabled'
                                : 'Utility catalogue summary unavailable or access restricted.',
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            '3D buildings use live OpenStreetMap footprints with mapped heights/levels where available; missing heights receive a 6 m visual estimate and must not be used for compliance decisions. Underground 3D cells show relative density in generalised 250 m cells—not physical depth, elevation, dimensions or routes. Exact assets remain access-controlled; an empty layer is not excavation clearance.',
                            style: TextStyle(
                              color: Color(0xFFF6C66B),
                              fontSize: 9,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: _showRequests,
                      activeThumbColor: const Color(0xFF20D6C2),
                      title: const Text('Work request locations',
                          style: TextStyle(color: Colors.white)),
                      subtitle: Text(
                        '$_requestMarkerCount request marker(s) visible to your account',
                        style:  TextStyle(color: mutedInk, fontSize: 11),
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
                        style:  TextStyle(
                          color: mutedInk,
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
                        'National groundwater monitoring stations (2021–2025)',
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        '$_groundwaterStationCount station point(s) in the current map extent · up to 1,000 displayed · tap for the published reading and timestamp · not a borewell register or complete station inventory',
                        style:  TextStyle(
                          color: mutedInk,
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
                          style:  TextStyle(color: mutedInk, fontSize: 11),
                        ),
                        onChanged: (value) {
                          setSheetState(() {});
                          _toggleVerifiedAssets(value);
                        },
                      ),
                    if (_canViewConflictScreening) ...[
                       const Divider(color: Color(0x334B647C)),
                       Row(
                         children: [
                           const Icon(Icons.warning_amber_rounded, color: Color(0xFFF87171), size: 18),
                           const SizedBox(width: 8),
                           const Expanded(child: Text('UTILITY PROXIMITY SCREENING', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 0.7, fontSize: 11))),
                           Text('$_utilityConflictCount request(s)', style: const TextStyle(color: Color(0xFFFCA5A5), fontWeight: FontWeight.w700, fontSize: 11)),
                         ],
                       ),
                       const SizedBox(height: 6),
                       Text(_utilityConflictStatus, style:  TextStyle(color: mutedInk, fontSize: 11, height: 1.4)),
                       ..._utilityConflictDetails.values.take(5).map((detail) {
                         final conflicts = (detail['conflicts'] as List?) ?? const [];
                         final summary = conflicts.take(2).map((raw) {
                           final item = Map<String, dynamic>.from(raw as Map);
                           return '${item['owner_department']} · ${item['asset_type']} · ${item['distance_m']} m';
                         }).join(' | ');
                         return ListTile(
                           dense: true,
                           contentPadding: EdgeInsets.zero,
                           leading: const Icon(Icons.location_searching, color: Color(0xFFF87171), size: 17),
                           title: Text('${detail['request_number']} · ${detail['candidate_count']} potential match(es)', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                           subtitle: Text(summary, style:  TextStyle(color: mutedInk, fontSize: 10)),
                         );
                       }),
                       if (_utilityConflictDetails.length > 5)
                         Text('And ${_utilityConflictDetails.length - 5} more. Tap red map markers for details.', style:  TextStyle(color: mutedInk, fontSize: 10)),
                       const SizedBox(height: 8),
                       const Text('Cross-department screening runs on the server against verified assets. The phone receives advisory metadata only, never another department’s exact route geometry. No warning is not a safety clearance.', style: TextStyle(color: Color(0xFFF6C66B), fontSize: 10, height: 1.4)),
                     ],
                     if (_canViewUtilityOverview)
                       SwitchListTile(
                        value: _showUtilityZones,
                        activeThumbColor: const Color(0xFFF59E0B),
                        title: const Text('Generalised utility coverage',
                            style: TextStyle(color: Colors.white)),
                        subtitle: Text(
                          '$_utilityCellCount aggregate cell(s); not individual utility routes',
                          style:  TextStyle(color: mutedInk, fontSize: 11),
                        ),
                        onChanged: (value) {
                          setSheetState(() {});
                          _toggleUtilityZones(value);
                        },
                      )
                    else
                       ListTile(
                        leading: Icon(Icons.lock_outline, color: Color(0xFFF6C66B)),
                        title: Text('Utility coverage restricted',
                            style: TextStyle(color: Colors.white)),
                        subtitle: Text(
                          'Only generalised public coverage is shown. Exact infrastructure records remain restricted.',
                          style: TextStyle(color: mutedInk, fontSize: 11),
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
                      style:  TextStyle(color: mutedInk, fontSize: 11, height: 1.4),
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

  Widget _undergroundModelPanel() {
    final layers = <({Color color, IconData icon, String title})>[
      (color: const Color(0xFF38BDF8), icon: Icons.water_drop_outlined, title: 'Water & wastewater'),
      (color: const Color(0xFF22C55E), icon: Icons.waves_outlined, title: 'Stormwater & drainage'),
      (color: const Color(0xFFFBBF24), icon: Icons.bolt_outlined, title: 'Power & telecom'),
      (color: const Color(0xFFFB7185), icon: Icons.hub_outlined, title: 'Gas & other networks'),
    ];

    return Container(
      width: 258,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xF2182638),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x6645D9CE)),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.layers_outlined, color: Color(0xFF55D9CE), size: 17),
              const SizedBox(width: 7),
              const Expanded(
                child: Text('BELOW-GROUND MODEL',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(color: const Color(0x3320D6C2), borderRadius: BorderRadius.circular(6)),
                child: const Text('3D VIEW', style: TextStyle(color: Color(0xFF7DE9DE), fontSize: 8, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text('GENERALIZED 250 M COVERAGE · NOT TO SCALE',
            style: TextStyle(color: mutedInk, fontSize: 7.5, letterSpacing: 0.7, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...layers.map((layer) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Container(
                  width: 24, height: 20,
                  decoration: BoxDecoration(color: layer.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                  child: Icon(layer.icon, color: layer.color, size: 14),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(layer.title,
                  style: const TextStyle(color: Color(0xFFE5EEF5), fontSize: 9, fontWeight: FontWeight.w700))),
                Text('REFERENCE', style: TextStyle(color: layer.color, fontSize: 7, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
              ],
            ),
          )),
          const Divider(height: 9, color: Color(0x334B647C)),
          const Text('DATA TRUST CLASSES',
            style: TextStyle(color: Color(0xFF55D9CE), fontSize: 8, letterSpacing: .8, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          _trustClassRow(
            color: const Color(0xFF55D9CE),
            label: 'VERIFIED OWNER GEOMETRY',
            value: _canViewDepartmentAssets ? 'OWNER-DEPT VIEW · $_verifiedAssetCount' : 'OWNER-DEPT ACCESS ONLY',
          ),
          _trustClassRow(
            color: const Color(0xFF38BDF8),
            label: 'GENERALISED COVERAGE',
            value: 'AGGREGATE · NOT CLEARANCE',
          ),
          _trustClassRow(
            color: const Color(0xFFF6C66B),
            label: 'CONTEXT / ESTIMATED',
            value: 'REFERENCE ONLY · EXCLUDED FROM CLEARANCE',
          ),
          const Divider(height: 9, color: Color(0x334B647C)),
          const Text('GROUNDWATER SOURCE FRESHNESS',
            style: TextStyle(color: Color(0xFF55D9CE), fontSize: 8, letterSpacing: .8, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('Latest timestamp among loaded records (up to 1,000 in this map extent): $_groundwaterFreshnessLabel',
            style: const TextStyle(color: Color(0xFFE5EEF5), fontSize: 8, height: 1.35)),
          Text('Publisher: $_groundwaterLatestAgency · source-reported values; coordinate accuracy is not independently validated here.',
            style: TextStyle(color: mutedInk, fontSize: 7.5, height: 1.35)),
          const Divider(height: 9, color: Color(0x334B647C)),
          Row(
            children: [
              Expanded(child: _undergroundStat('UTILITY CATALOGUE', '$_utilityLayerCatalogueCount')),
              Expanded(child: _undergroundStat('LIVE MAP CELLS', '$_utilityCellCount')),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(child: _undergroundStat('GROUNDWATER POINTS', '$_groundwaterStationCount')),
              Expanded(child: _undergroundStat('APPROVALS MAPPED', '$_approvalMappedCount / $_approvalRecordCount')),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '3D blocks show relative aggregate density inside generalized coverage cells. They are not pipes, surveyed alignments, asset depths or excavation-clearance data. Owner-authorised geometry is a separate restricted layer.',
            style: TextStyle(color: Color(0xFFF6C66B), fontSize: 8, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _desktopGisMetric(String label, String value, IconData icon, Color accent) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: panelNavy,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: borderColor),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: accent, size: 17),
        const SizedBox(height: 7),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
        Text(label, maxLines: 2, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: mutedInk, fontSize: 8, fontWeight: FontWeight.w700, height: 1.25)),
      ]),
    ));
  }

  Widget _desktopGisLayerToggle({
    required String title,
    required String detail,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) => SwitchListTile.adaptive(
    dense: true,
    contentPadding: EdgeInsets.zero,
    activeThumbColor: const Color(0xFF55D9CE),
    title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
    subtitle: Text(detail, style: TextStyle(color: mutedInk, fontSize: 8, height: 1.3)),
    value: value,
    onChanged: onChanged,
  );

  Widget _desktopGISCommandPanel() => Container(
    width: 292,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xF20B1B2D),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0x6645D9CE)),
      boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 7))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 31, height: 31,
          decoration: BoxDecoration(color: const Color(0x2220D6C2), borderRadius: BorderRadius.circular(9)),
          child: const Icon(Icons.hub_rounded, color: Color(0xFF55D9CE), size: 18)),
        const SizedBox(width: 9),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('NATIONAL GIS COMMAND', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .7)),
          SizedBox(height: 2),
          Text('INDIA · AUTHORISED MAP VIEW', style: TextStyle(color: Color(0xFF55D9CE), fontSize: 7, fontWeight: FontWeight.w800, letterSpacing: .55)),
        ])),
        IconButton(tooltip: 'Open layer catalogue', visualDensity: VisualDensity.compact,
          onPressed: _openLayerPanel, icon:  Icon(Icons.tune_rounded, color: mutedInk, size: 18)),
      ]),
      const SizedBox(height: 9),
      Text('LIVE COUNTS · CURRENT MAP EXTENT',
        style: TextStyle(color: mutedInk, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: .7)),
      const SizedBox(height: 7),
      Row(children: [
        _desktopGisMetric('VISIBLE CASES', '$_requestMarkerCount', Icons.assignment_outlined, const Color(0xFF55D9CE)),
        const SizedBox(width: 7),
        _desktopGisMetric('GROUNDWATER POINTS', '$_groundwaterStationCount', Icons.water_drop_outlined, const Color(0xFFA78BFA)),
      ]),
      const SizedBox(height: 7),
      Row(children: [
        _desktopGisMetric('VERIFIED OWNER ASSETS', _canViewDepartmentAssets ? '$_verifiedAssetCount' : 'Restricted',
          Icons.verified_user_outlined, const Color(0xFF38BDF8)),
        const SizedBox(width: 7),
        _desktopGisMetric('GENERAL COVERAGE CELLS', _canViewUtilityOverview ? '$_utilityCellCount' : 'Restricted',
          Icons.grid_view_rounded, const Color(0xFFFBBF24)),
      ]),
      if (_canViewConflictScreening) ...[
        const SizedBox(height: 8),
        Text('$_utilityConflictCount advisory conflict candidate(s)',
          style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 9, fontWeight: FontWeight.w800)),
      ],
      const Divider(color: Color(0x334B647C), height: 18),
      const Text('MAP LAYERS',
        style: TextStyle(color: Color(0xFF55D9CE), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .9)),
      Expanded(child: SingleChildScrollView(child: Column(children: [
        _desktopGisLayerToggle(title: 'Work request locations',
          detail: 'Visible cases permitted for this account', value: _showRequests,
          onChanged: (value) => _toggleRequests(value)),
        _desktopGisLayerToggle(title: 'Groundwater monitoring',
          detail: 'Published observations in the current extent', value: _showGroundwaterTelemetry,
          onChanged: (value) => _toggleGroundwaterTelemetry(value)),
        _desktopGisLayerToggle(title: 'Coimbatore ward reference',
          detail: '2024 public-domain reference; not legal certification', value: _showCoimbatoreWardBoundaries,
          onChanged: (value) => _toggleCoimbatoreWardBoundaries(value)),
        if (_canViewDepartmentAssets)
          _desktopGisLayerToggle(title: 'Verified department-owned assets',
            detail: 'Authorised owner-department geometry only', value: _showVerifiedAssets,
            onChanged: (value) => _toggleVerifiedAssets(value)),
        if (_canViewUtilityOverview)
          _desktopGisLayerToggle(title: 'Generalised utility coverage',
            detail: 'Aggregate cells only; no individual routes or depths', value: _showUtilityZones,
            onChanged: (value) => _toggleUtilityZones(value)),
        if (_canViewConflictScreening)
          Padding(padding: const EdgeInsets.symmetric(vertical: 7),
            child: Text(_utilityConflictStatus,
              style: const TextStyle(color: Color(0xFFF6C66B), fontSize: 8, height: 1.35))),
        const Divider(color: Color(0x334B647C), height: 14),
        Wrap(spacing: 7, runSpacing: 7, children: [
          OutlinedButton.icon(onPressed: _openJurisdictionNavigator,
            icon: const Icon(Icons.account_tree_outlined, size: 15), label: const Text('Jurisdiction'),
            style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF8DECE2),
              side: const BorderSide(color: Color(0x6655D9CE)),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
              textStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800))),
          OutlinedButton.icon(onPressed: _openLayerPanel,
            icon: const Icon(Icons.layers_outlined, size: 15), label: const Text('All layers'),
            style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF8DECE2),
              side: const BorderSide(color: Color(0x6655D9CE)),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
              textStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800))),
        ]),
        const SizedBox(height: 7),
        const Text('Coverage counts are not underground asset counts. Exact utility geometry remains restricted. Missing or unverified data is never excavation clearance.',
          style: TextStyle(color: Color(0xFFF6C66B), fontSize: 8, height: 1.35)),
      ]))),
    ]),
  );

  Widget _trustClassRow({
    required Color color,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Container(width: 7, height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 7),
        Expanded(child: Text(label, style: const TextStyle(
          color: Color(0xFFE5EEF5), fontSize: 7, fontWeight: FontWeight.w800))),
        const SizedBox(width: 5),
        Flexible(child: Text(value, textAlign: TextAlign.right,
          style: TextStyle(color: color, fontSize: 6.5, fontWeight: FontWeight.w900))),
      ]),
    );
  }

  Widget _undergroundStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: mutedInk, fontSize: 6.5, fontWeight: FontWeight.w700, letterSpacing: 0.35)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
      ],
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

  Future<void> _jumpToIndiaRegion(String region) async {
    final controller = _controller;
    if (controller == null) {
      _showMessage('The GIS map is still initialising. Try again in a moment.');
      return;
    }

    final positions = <String, CameraPosition>{
      'All India': const CameraPosition(target: LatLng(22.5, 79.0), zoom: 3.5),
      'North': const CameraPosition(target: LatLng(30.2, 78.2), zoom: 4.4),
      'Northeast': const CameraPosition(target: LatLng(25.8, 93.1), zoom: 4.8),
      'East': const CameraPosition(target: LatLng(23.7, 86.7), zoom: 4.7),
      'Central': const CameraPosition(target: LatLng(23.4, 79.0), zoom: 4.7),
      'West': const CameraPosition(target: LatLng(22.4, 73.0), zoom: 4.7),
      'South': const CameraPosition(target: LatLng(12.8, 78.3), zoom: 4.5),
      'Andaman and Nicobar': const CameraPosition(target: LatLng(11.9, 92.7), zoom: 5.1),
      'Lakshadweep': const CameraPosition(target: LatLng(10.5, 72.6), zoom: 5.3),
    };
    final destination = positions[region];
    if (destination == null) return;

    try {
      await controller.animateCamera(CameraUpdate.newCameraPosition(destination));
      if (mounted) _showMessage('GIS view moved to ' + region + '. Available layers remain governed by verified source coverage and your account permissions.');
    } catch (_) {
      if (mounted) _showMessage('Unable to move the GIS map to ' + region + '.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final desktopLayout = MediaQuery.sizeOf(context).width >= 1180;
    return Scaffold(
      backgroundColor: panelNavy,
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.contextLabel == null ? 'SAMANVAY GIS' : 'SAMANVAY GIS · ${widget.contextLabel}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: 2),
            Text(
              widget.contextLabel == null
                  ? 'GEOSPATIAL INFRASTRUCTURE WORKSPACE'
                  : 'LIVE BASEMAP · VERIFIED UTILITY ASSETS ONLY',
              style: TextStyle(
                fontSize: 9,
                letterSpacing: 1.35,
                color: mutedInk,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Open LPU campus in the live GIS map',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LpuCampusModelPage()),
            ),
            icon: const Icon(Icons.school_outlined),
          ),
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
            tooltip: 'Plan a driving route',
            onPressed: _routing ? null : _showDirectionsDialog,
            icon: const Icon(Icons.directions_outlined),
          ),
          IconButton(
            tooltip: 'Layer controls',
            onPressed: _openLayerPanel,
            icon: const Icon(Icons.layers_outlined),
          ),
          PopupMenuButton<String>(
            tooltip: 'Jump to an Indian region',
            icon: const Icon(Icons.explore_outlined),
            onSelected: _jumpToIndiaRegion,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'All India', child: Text('All India')),
              PopupMenuItem(value: 'North', child: Text('North India')),
              PopupMenuItem(value: 'Northeast', child: Text('Northeast India')),
              PopupMenuItem(value: 'East', child: Text('East India')),
              PopupMenuItem(value: 'Central', child: Text('Central India')),
              PopupMenuItem(value: 'West', child: Text('West India')),
              PopupMenuItem(value: 'South', child: Text('South India')),
              PopupMenuItem(value: 'Andaman and Nicobar', child: Text('Andaman & Nicobar Islands')),
              PopupMenuItem(value: 'Lakshadweep', child: Text('Lakshadweep')),
            ],
          ),
          IconButton(
            tooltip: 'India-wide data coverage',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const IndiaCoverageExplorerPage()),
            ),
            icon: const Icon(Icons.public_outlined),
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
                target: widget.initialCenter ?? const LatLng(22.5, 79.0),
                zoom: widget.initialZoom,
                tilt: widget.initialTilt,
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
                    style: TextStyle(
                      color: mutedInk,
                      fontSize: 9,
                      letterSpacing: 1.3,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _undergroundMode
                        ? 'UNDERGROUND DATA VIEW'
                        : _is3D ? '3D SURFACE MAP' : '2D SURFACE MAP',
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
                    _undergroundMode
                        ? (_canViewDepartmentAssets
                            ? 'Own-department verified geometry plus generalised coverage. Other owners’ exact routes are withheld.'
                            : _canViewUtilityOverview
                                ? 'Generalised coverage only. Exact utility routes and depths are withheld.'
                                : 'Operational underground geometry is restricted for this account.')
                        : _satellite
                            ? 'Imagery date and resolution vary by location.'
                            : 'Real OpenStreetMap building footprints are extruded in 3D. Mapped height or floor tags are used where available; otherwise a clearly labelled 6 m visual estimate is used. This is not a statutory building-approval record.',
                    style:  TextStyle(
                      color: mutedInk,
                      fontSize: 9,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (desktopLayout)
            Positioned(left: 12, top: 150, bottom: 88, child: _desktopGISCommandPanel()),

          Positioned(
            left: desktopLayout ? 320 : 12,
            right: 62,
            top: desktopLayout ? 12 : 116,
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
                      decoration: InputDecoration(
                        hintText: 'Search India: state, district, city, ward or road',
                        hintStyle: TextStyle(color: mutedInk, fontSize: 11),
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
              left: desktopLayout ? 320 : 12,
              right: 62,
              top: desktopLayout ? 68 : 172,
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
                        style:  TextStyle(color: mutedInk, fontSize: 9),
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
                  icon: Icons.account_tree_outlined,
                  tooltip: 'India jurisdiction navigator',
                  onPressed: _openJurisdictionNavigator,
                ),
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
              bottom: 226,
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
            left: desktopLayout ? 320 : 12,
            right: 12,
            bottom: 118,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xF2182638),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: const Color(0x5539BDB0)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      _pill(
                        label: 'SURFACE',
                        selected: !_undergroundMode,
                        onTap: () => _setUndergroundMode(false),
                      ),
                      const SizedBox(width: 5),
                      _pill(
                        label: 'UNDERGROUND',
                        selected: _undergroundMode,
                        onTap: () => _setUndergroundMode(true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Divider(height: 1, color: Color(0x334B647C)),
                  const SizedBox(height: 4),
                  Row(
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
                ],
              ),
            ),
          ),

          if (_undergroundMode)
            Positioned(
              left: desktopLayout ? 320 : 12,
              bottom: 118,
              child: _undergroundModelPanel(),
            ),

          Positioned(
            left: desktopLayout ? 320 : 12,
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
            left: desktopLayout ? 320 : 12,
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
  static const Map<String, String> _sourceTypeLabels = {
    'utility_owner': 'Utility-owner supplied',
    'field_survey': 'Field survey',
    'as_built_drawing': 'Authority as-built drawing',
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
  String _sourceType = 'utility_owner';
  final TextEditingController _sourceTitleController = TextEditingController();
  final TextEditingController _sourceOrganisationController = TextEditingController();
  final TextEditingController _authorizationReferenceController = TextEditingController();
  final TextEditingController _dataSharingBasisController = TextEditingController();
  final TextEditingController _sourceUrlController = TextEditingController();
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

  @override
  void dispose() {
    _sourceTitleController.dispose();
    _sourceOrganisationController.dispose();
    _authorizationReferenceController.dispose();
    _dataSharingBasisController.dispose();
    _sourceUrlController.dispose();
    super.dispose();
  }

  String? _validateSourceMetadata() {
    if (_sourceTitleController.text.trim().length < 3 ||
        _sourceTitleController.text.trim().length > 200) {
      return 'Enter the official dataset or survey title (3–200 characters).';
    }
    if (_sourceOrganisationController.text.trim().length < 3 ||
        _sourceOrganisationController.text.trim().length > 200) {
      return 'Enter the responsible utility owner or survey organisation.';
    }
    if (_authorizationReferenceController.text.trim().length < 6 ||
        _authorizationReferenceController.text.trim().length > 200) {
      return 'Enter the authority permission, MOU or sharing-reference number.';
    }
    if (_dataSharingBasisController.text.trim().length < 10 ||
        _dataSharingBasisController.text.trim().length > 1000) {
      return 'Describe the data-sharing authority or permission basis (10–1000 characters).';
    }
    final sourceUrl = _sourceUrlController.text.trim();
    if (sourceUrl.isNotEmpty) {
      final uri = Uri.tryParse(sourceUrl);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        return 'The source URL must be a valid HTTPS address.';
      }
    }
    return null;
  }

  Widget _metadataField(
    TextEditingController controller,
    String label, {
    String? hint,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
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
    if (value is! List || value.isEmpty) return false;
    if (value[0] is num || (value.length > 1 && value[1] is num)) {
      if (value.length != 2 || value[0] is! num || value[1] is! num) return false;
      final lon = (value[0] as num).toDouble();
      final lat = (value[1] as num).toDouble();
      return lon.isFinite && lat.isFinite &&
          lon >= -180 && lon <= 180 && lat >= -90 && lat <= 90;
    }
    return value.every(_validCoordinates);
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
    if (code.length < 2 || code.length > 100) return 'asset_code is required (2–100 characters).';
    if (name.length < 2 || name.length > 200) return 'asset_name is required (2–200 characters).';
    if (!_assetTypes.contains(assetType)) return 'Unsupported asset_type.';
    if (_sourceType == 'field_survey' &&
        (p['surveyed_at'] ?? '').toString().trim().isEmpty) {
      return 'surveyed_at is required for a field-survey batch.';
    }

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
    final sourceError = _validateSourceMetadata();
    if (sourceError != null) {
      setState(() => _status = sourceError);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Register as unverified?'),
        content: Text(
          '${valid.length} records from "$_fileName" will be registered under $_departmentName. '
          'Your source and permission details will be recorded in an audit log. '
          'This declaration is not independently verified; the records remain UNVERIFIED and hidden from the map pending owner review.',
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
        body: {
          'action': 'import',
          'source': {
            'source_title': _sourceTitleController.text.trim(),
            'source_organisation': _sourceOrganisationController.text.trim(),
            'source_type': _sourceType,
            'authorization_reference': _authorizationReferenceController.text.trim(),
            'data_sharing_basis': _dataSharingBasisController.text.trim(),
            'source_url': _sourceUrlController.text.trim().isEmpty
                ? null : _sourceUrlController.text.trim(),
            'declared_srid': 4326,
          },
          'features': features,
        },
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      final imported = (data['imported'] as num?)?.toInt() ?? 0;
      final failed = (data['rejected'] as num?)?.toInt() ?? (valid.length - imported);
      final runId = (data['run_id'] ?? '').toString();
      final errorText = (data['error'] ?? '').toString();
      final errors = <String>[];
      if (errorText.isNotEmpty) errors.add(errorText);

      if (!mounted) return;
      setState(() {
        _imported = imported;
        _failed = failed;
        _progress = valid.length;
        _errors = errors;
        _status = 'Import run ' + (runId.isEmpty ? '(ID unavailable)' : runId) +
            ': $_imported registered; $_failed rejected. All accepted geometry remains UNVERIFIED and hidden from the map pending independent owner review.';
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
      backgroundColor: background,
      appBar: AppBar(title: const Text('GIS Data Ingestion'), backgroundColor: navy),
      body: _checkingAccess
          ? const Center(child: CircularProgressIndicator())
          : !_authorised
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                     Icon(Icons.lock_outline, size: 52, color: mutedInk),
                    const SizedBox(height: 14),
                     Text('Department authorisation required',
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: ink)),
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
                         Text('SOURCE AUTHORITY & PROVENANCE',
                            style: TextStyle(fontWeight: FontWeight.w800, color: ink, letterSpacing: 0.7)),
                        const SizedBox(height: 6),
                         Text('These fields create an audit declaration. They do not independently prove that the submitter has permission. The receiving authority must review the source before the records are verified.',
                            style: TextStyle(color: mutedInk, fontSize: 11, height: 1.4)),
                        const SizedBox(height: 12),
                        _metadataField(_sourceTitleController, 'Official source / dataset title'),
                        _metadataField(_sourceOrganisationController, 'Utility owner / survey organisation'),
                        DropdownButtonFormField<String>(
                          value: _sourceType,
                          decoration: const InputDecoration(
                            labelText: 'Source category',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: _sourceTypeLabels.entries.map((entry) =>
                            DropdownMenuItem<String>(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          ).toList(),
                          onChanged: _importing ? null : (value) {
                            if (value != null) setState(() => _sourceType = value);
                          },
                        ),
                        const SizedBox(height: 10),
                        _metadataField(
                          _authorizationReferenceController,
                          'Authority permission / MOU reference',
                          hint: 'Reference number only; do not enter credentials',
                        ),
                        _metadataField(
                          _dataSharingBasisController,
                          'Data-sharing authority / permission basis',
                          hint: 'Identify the written approval, agreement or owner authorisation',
                          maxLines: 3,
                        ),
                        _metadataField(
                          _sourceUrlController,
                          'Official source URL (optional)',
                          hint: 'https://…',
                        ),
                         Text('Coordinate reference system: EPSG:4326 only. Reproject the source file before upload; the server does not guess or transform CRSs.',
                            style: TextStyle(color: ink, fontSize: 11, height: 1.4, fontWeight: FontWeight.w600)),
                      ]),
                    )),
                    const SizedBox(height: 12),
                    Card(child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                         Text('SUPPORTED FILE',
                            style: TextStyle(fontWeight: FontWeight.w800, color: ink, letterSpacing: 0.7)),
                        const SizedBox(height: 8),
                         Text('GeoJSON FeatureCollection (.geojson / .json), WGS84 EPSG:4326. Point, MultiPoint, LineString and MultiLineString. Maximum 10 MB / 500 features.',
                            style: TextStyle(color: mutedInk, height: 1.45, fontSize: 12)),
                        const SizedBox(height: 8),
                         Text('Required properties: asset_code, asset_name and asset_type. Source type and permission details are entered in the audit form below.',
                            style: TextStyle(color: ink, fontSize: 12, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                         Text('Optional: depth_m, horizontal_accuracy_m, vertical_accuracy_m, material, diameter_mm and surveyed_at. Field-survey batches must include surveyed_at.',
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
                           Text('PRE-IMPORT VALIDATION',
                              style: TextStyle(fontWeight: FontWeight.w800, color: ink)),
                          const SizedBox(height: 6),
                          Text(_fileName, style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(child: _countTile('VALID', validCount, teal)),
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
                                  color: error == null ? teal : Colors.red),
                              title: Text((p['asset_code'] ?? 'Feature ${entry.key + 1}').toString(), 
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                              subtitle: Text(error ?? '${p['asset_name'] ?? ''} · ${p['asset_type'] ?? ''} · ${(f['geometry'] as Map?)?['type'] ?? ''}',
                                  style: const TextStyle(fontSize: 10)),
                            );
                          }),
                          if (_records.length > 20)
                            Text('Showing first 20 of ${_records.length} features.',
                                style:  TextStyle(color: mutedInk, fontSize: 11)),
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
                            style: FilledButton.styleFrom(backgroundColor: teal, padding: const EdgeInsets.symmetric(vertical: 14)),
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
                     Text('Only import records your department is authorised to submit. This tool does not independently verify geometry and does not issue excavation clearance or safety certification.',
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

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() { super.initState(); _future = _loadProfile(); }

  Future<Map<String, dynamic>> _loadProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) throw StateError('Your session has expired. Sign in again.');
    final row = await supabase.from('profiles')
        .select('role,department_id,display_name').eq('id', user.id).maybeSingle();
    if (row == null) throw StateError('Your SAMANVAY profile could not be found.');

    var department = 'Not assigned';
    final id = row['department_id']?.toString();
    if (id != null && id.isNotEmpty) {
      try {
        final d = await supabase.from('departments').select('name').eq('id', id).maybeSingle();
        department = (d?['name'] ?? 'Assigned department').toString();
      } catch (_) { department = 'Assigned department'; }
    }

    final role = (row['role'] ?? 'unknown').toString();
    var requestRows = <Map<String, dynamic>>[];
    var requestsAvailable = true;
    var evidenceCount = 0, unreadCount = 0;
    var evidenceAvailable = true, notificationsAvailable = true;
    try {
      // Requesters see their own submissions. Staff counts are based on the
      // cases already visible under their database-enforced RLS policies.
      final rawRequests = role == 'requester'
          ? await supabase.from('excavation_requests')
              .select('id,status').eq('requester_id', user.id).limit(1000)
          : await supabase.from('excavation_requests')
              .select('id,status').limit(1000);
      requestRows = List<Map<String, dynamic>>.from(rawRequests);
    } catch (_) {
      requestsAvailable = false;
    }
    try {
      evidenceCount = List.from(await supabase.from('case_attachments')
          .select('id').eq('uploaded_by', user.id).limit(1000)).length;
    } catch (_) {
      evidenceAvailable = false;
    }
    try {
      unreadCount = List.from(await supabase.from('user_notifications')
          .select('id').eq('recipient_id', user.id)
          .filter('read_at', 'is', null).limit(1000)).length;
    } catch (_) {
      notificationsAvailable = false;
    }

    final completedCount = requestRows.where((item) {
      final status = (item['status'] ?? '').toString().toLowerCase();
      return status == 'completed' || status == 'resolved';
    }).length;
    final inactiveStatuses = {'completed', 'resolved', 'rejected', 'cancelled'};
    final activeCount = requestRows.where((item) {
      final status = (item['status'] ?? '').toString().toLowerCase();
      return status.isNotEmpty && !inactiveStatuses.contains(status);
    }).length;

    return {
      'name': (row['display_name'] ?? user.userMetadata?['display_name'] ?? 'SAMANVAY user').toString(),
      'email': user.email ?? '', 'role': role,
      'department': department, 'department_id': id,
      'requests_label': role == 'requester' ? 'My requests' : 'Visible cases',
      'requests': requestsAvailable ? requestRows.length : null,
      'active': requestsAvailable ? activeCount : null,
      'completed': requestsAvailable ? completedCount : null,
      'evidence': evidenceAvailable ? evidenceCount : null,
      'unread': notificationsAvailable ? unreadCount : null,
    };
  }

  Future<void> _switchProfiles() async {
    final selected = await _showProfileSwitcher(
      context,
      currentRole: 'requester',
    );
    if (!mounted || selected == null || selected == 'requester') return;
    final navigator = Navigator.of(context);
    navigator.push(MaterialPageRoute<void>(
      builder: (previewContext) => _StaffDemoPreview(
        role: selected,
        staffId: _publicDemoStaffIds[selected]!,
        onExit: () => Navigator.of(previewContext).pop(),
      ),
    ));
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  Future<void> _passwordReset() async {
    final email = supabase.auth.currentUser?.email;
    if (email == null || email.isEmpty) { _toast('No account email is available.'); return; }
    try {
      await supabase.auth.resetPasswordForEmail(email);
      _toast('Password reset instructions requested. Check your email.');
    } on AuthException catch (e) { _toast(e.message); }
    catch (_) { _toast('Unable to request a password reset right now.'); }
  }

  Future<void> _showEvidence() async {
    final user = supabase.auth.currentUser;
    if (user == null) { _toast('Sign in to view your evidence submissions.'); return; }
    try {
      final rows = await supabase.from('case_attachments')
        .select('request_id,storage_path,file_name,content_type,file_size_bytes,created_at')
        .eq('uploaded_by', user.id)
        .order('created_at', ascending: false)
        .limit(100);
      if (!mounted) return;
      final files = List<Map<String, dynamic>>.from(rows);
      await showModalBottomSheet<void>(
        context: context, isScrollControlled: true, backgroundColor: panelNavy,
        builder: (sheet) => SafeArea(child: SizedBox(
          height: MediaQuery.of(sheet).size.height * .62,
          child: files.isEmpty
            ? const Center(child: Text('No evidence submissions are linked to this account.'))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                   Text('MY PRIVATE EVIDENCE',
                    style: TextStyle(fontWeight: FontWeight.w800, color: ink)),
                  const SizedBox(height: 10),
                  ...files.map((item) {
                    final bytes = (item['file_size_bytes'] as num?)?.toInt() ?? 0;
                    final sizeLabel = bytes >= 1024 * 1024
                      ? (bytes / (1024 * 1024)).toStringAsFixed(1) + ' MB'
                      : (bytes / 1024).toStringAsFixed(0) + ' KB';
                    return ListTile(
                      leading:  Icon(Icons.attach_file_rounded, color: electricBlue),
                      title: Text((item['file_name'] ?? 'Evidence file').toString(),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(sizeLabel + ' · Private file · Case ' +
                        item['request_id'].toString().substring(0, 8)),
                      trailing: IconButton(
                        tooltip: 'Open secure evidence link',
                        icon: const Icon(Icons.open_in_new_rounded),
                        onPressed: () async {
                          try {
                            final signed = await supabase.storage
                              .from('samanvay-case-evidence')
                              .createSignedUrl(item['storage_path'].toString(), 600);
                            await launchUrl(Uri.parse(signed), mode: LaunchMode.externalApplication);
                          } catch (_) {
                            _toast('Unable to open this private evidence file. Check your case access.');
                          }
                        },
                      ),
                    );
                  }),
                ],
              ),
        )),
      );
    } catch (_) {
      _toast('Unable to load private evidence submitted by this account.');
    }
  }

  Future<void> _logout() async {
    try { await supabase.auth.signOut(); }
    on AuthException catch (e) { _toast(e.message); }
  }

  void _help() {
    showDialog<void>(context: context, builder: (dialog) => AlertDialog(
      title: const Text('SAMANVAY help'),
      content: const Text(
        'Use Cases to submit and follow requests, GIS to inspect available map layers, and Public works for authority-published notices or obstruction reports. '
        'Exact underground utility geometry is restricted to authorised owner departments. An empty or unverified layer is never excavation clearance.'),
      actions: [TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Close'))],
    ));
  }

  Future<void> _requestNotificationPermission() async {
    if (kIsWeb) {
      _toast('Browser notifications are controlled by your browser site permissions.');
      return;
    }
    final status = await Permission.notification.request();
    if (!mounted) return;
    if (status.isGranted || status.isProvisional) {
      _toast('Notifications are enabled for SAMANVAY on this device.');
    } else {
      _toast('Notification permission was not granted. You can change it in Android app settings.');
      if (status.isPermanentlyDenied) await openAppSettings();
    }
  }

  Future<void> _openSettings() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<ThemeMode>(
              valueListenable: samanvayThemeMode,
              builder: (context, mode, _) => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Light mode'),
                subtitle: Text(mode == ThemeMode.light ? 'Light appearance enabled' : 'Dark appearance enabled'),
                value: mode == ThemeMode.light,
                onChanged: (enabled) async {
                  samanvayThemeMode.value = enabled ? ThemeMode.light : ThemeMode.dark;
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('samanvay_light_mode', enabled);
                },
              ),
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('Device notifications'),
              subtitle: const Text('Request permission to show SAMANVAY alerts'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.of(dialogContext).pop();
                _requestNotificationPermission();
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Close')),
        ],
      ),
    );
  }

  void _aboutSamanvay() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('About SAMANVAY'),
        content: const SingleChildScrollView(
          child: Text(
            'SAMANVAY — Towards Our Development.\n\n'
            'Brief: SAMANVAY is a citizen-facing, nationwide platform for transparent public infrastructure planning and coordination across government departments. It helps people understand published works, public underground-infrastructure coverage, service requests and government outcomes.\n\n'
            'Detailed overview: The platform connects urban development, municipal bodies, water supply, sewerage, stormwater drainage, electricity, telecommunications, gas, groundwater and borewell regulation, building planning and approvals, public health engineering, roads, transport and other public services. It is designed to provide public GIS layers, 2D/3D map views, published excavation and no-dig notices, request tracking, obstruction reporting, department workflows, joint-work coordination, AI-assisted risk insights, public progress dashboards, notifications and accountable audit trails.\n\nPublic accountability: avoided excavations, public funds saved and coordination percentages are displayed only after competent authorities publish verifiable baselines and outcome evidence. Demonstration figures are not shown as live government results.\n\n'
            'Data integrity: Official records are distinguished from public reference datasets, owner-authorised verified utility geometry, aggregate coverage and illustrative estimates. Missing data is shown as a gap. An empty map or absence of a warning is never excavation clearance. Final approvals remain with the competent public authority.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _tile(IconData icon, String title, String subtitle, VoidCallback action,
      {Color? color}) {
    final tileColor = color ?? electricBlue;
    return Card(
      color: panelNavy,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: tileColor.withValues(alpha: .12),
          child: Icon(icon, color: tileColor),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: ink)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 11, color: mutedInk)),
        trailing: Icon(Icons.chevron_right_rounded, color: mutedInk),
        onTap: action,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: background,
    appBar: AppBar(title: const Text('My profile'), actions: [
      IconButton(
        tooltip: 'Switch profiles',
        onPressed: _switchProfiles,
        icon: const Icon(Icons.switch_account_rounded),
      ),
      IconButton(
        tooltip: 'Settings',
        onPressed: _openSettings,
        icon: const Icon(Icons.settings_outlined),
      ),
      IconButton(tooltip: 'Refresh profile',
        onPressed: () => setState(() => _future = _loadProfile()),
        icon: const Icon(Icons.refresh_rounded)),
    ]),
    body: FutureBuilder<Map<String, dynamic>>(future: _future, builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData)
        return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
           Icon(Icons.account_circle_outlined, size: 44, color: electricBlue),
          const Text('Profile details unavailable', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(snapshot.error.toString(), textAlign: TextAlign.center,
            style:  TextStyle(color: mutedInk, fontSize: 12)),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => setState(() => _future = _loadProfile()),
            child: const Text('Retry')),
        ]),
      ));

      final data = snapshot.data!;
      final accountRole = data['role'].toString();
      final departmentId = data['department_id']?.toString();
      final workspaceTitle = switch (accountRole) {
        'requester' => 'My requests',
        'department' => 'Department cases',
        'coordinator' => 'Coordination workspace',
        'admin' => 'Administration workspace',
        _ => 'Assigned workspace',
      };
      final workspaceSubtitle = switch (accountRole) {
        'requester' => 'Review your submitted requests and their status',
        'department' => 'Review requests and evidence assigned to your department',
        'coordinator' => 'Coordinate cases across departments',
        'admin' => 'Open platform operations and administration',
        _ => 'Open the workspace available to your account',
      };
      final Widget workspacePage = switch (accountRole) {
        'requester' => const RequestsPage(),
        'department' => departmentId == null || departmentId.isEmpty
            ? const _PortalError(message: 'No department is assigned to this account.')
            : DepartmentPortal(departmentId: departmentId),
        'coordinator' => const CoordinatorPortal(),
        'admin' => const AdminPortal(),
        _ => const RequestsPage(),
      };
      return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 28), children: [
        Container(
          padding: const EdgeInsets.all(21),
          decoration: BoxDecoration(
            gradient:  LinearGradient(colors: [navy, Color(0xFF123B65), Color(0xFF075E72)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: cyanAccent.withValues(alpha: .25))),
          child: Column(children: [
             CircleAvatar(
              radius: 38,
              backgroundColor: cyanAccent,
              child: const CircleAvatar(
                radius: 35,
                backgroundImage: AssetImage('assets/brand/profile_avatar.jpg'),
                backgroundColor: Color(0xFF244D70),
              ),
            ),
            const SizedBox(height: 12),
            Text(data['name'].toString(), textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(data['email'].toString(), textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFD6E6F2), fontSize: 12)),
            const SizedBox(height: 12),
            Wrap(alignment: WrapAlignment.center, spacing: 7, runSpacing: 7, children: [
              _badge(_displayRoleName(data['role'].toString()), cyanAccent),
              _badge(data['department'].toString(), const Color(0xFFB9D4FF)),
            ]),
          ]),
        ),
        const SizedBox(height: 14),
        Card(
          color: Theme.of(context).colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: teal.withValues(alpha: .12),
                  child: Icon(Icons.switch_account_rounded, color: teal),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Switch profiles',
                        style: TextStyle(
                          color: ink,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Open Citizen, Officer, Coordinator or Administrator demo workspaces.',
                        style: TextStyle(color: mutedInk, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _switchProfiles,
                  child: const Text('Switch'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
         Text('Account activity', style: TextStyle(color: ink, fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (context, constraints) {
          const spacing = 8.0;
          final columns = constraints.maxWidth >= 640 ? 5 : 3;
          final tileWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;
          return Wrap(spacing: spacing, runSpacing: spacing, children: [
            SizedBox(width: tileWidth, child: _metric(
              data['requests_label'].toString(),
              data['requests']?.toString() ?? '—',
              Icons.assignment_outlined)),
            SizedBox(width: tileWidth, child: _metric(
              'Active', data['active']?.toString() ?? '—',
              Icons.pending_actions_outlined)),
            SizedBox(width: tileWidth, child: _metric(
              'Completed', data['completed']?.toString() ?? '—',
              Icons.task_alt_rounded)),
            SizedBox(width: tileWidth, child: _metric(
              'Evidence', data['evidence']?.toString() ?? '—',
              Icons.attach_file_rounded)),
            SizedBox(width: tileWidth, child: _metric(
              'Unread', data['unread']?.toString() ?? '—',
              Icons.notifications_active_outlined)),
          ]);
        }),
        const SizedBox(height: 20),
         Text('Workspace and support', style: TextStyle(color: ink, fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        _tile(Icons.assignment_outlined, workspaceTitle, workspaceSubtitle,
          () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => workspacePage))),
        _tile(Icons.attach_file_rounded, 'Evidence submissions', 'View files you uploaded to private case records',
          _showEvidence),
        _tile(Icons.campaign_outlined, 'Public works tracker', 'Published excavation and no-dig notices',
          () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PublicExcavationTrackerPage()))),
        _tile(Icons.calendar_month_outlined, 'Coordinated works calendar', 'Compare planned works across departments and identify possible schedule overlaps',
          () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CoordinatedWorkCalendarPage())),
          color: const Color(0xFF35C6B5)),
        _tile(Icons.notifications_none_rounded, 'Notifications', 'Read assignment, review and case updates',
          () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsPage()))),
        _tile(Icons.public_rounded, 'India data coverage', 'Explore imported coverage and data gaps',
          () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const IndiaCoverageExplorerPage()))),
        _tile(Icons.lock_outline_rounded, 'Security settings', 'Request a password reset through Supabase Auth',
          _passwordReset, color: const Color(0xFF0E8A78)),
        _tile(Icons.info_outline_rounded, 'About SAMANVAY', 'Platform purpose, departments, data integrity and governance',
          _aboutSamanvay, color: const Color(0xFF35B6C8)),
        _tile(Icons.help_outline_rounded, 'Help and guidance', 'Understand modules and data-safety limits',
          _help, color: const Color(0xFF8A62C7)),
        const SizedBox(height: 10),
        OutlinedButton.icon(onPressed: _logout, icon: const Icon(Icons.logout_rounded),
          label: const Text('Sign out'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFB33B45),
            side: const BorderSide(color: Color(0xFFE7B9BD)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)))),
        const SizedBox(height: 10),
         Text('Account identity and activity are loaded from authenticated records. Evidence remains in private storage.',
          textAlign: TextAlign.center, style: TextStyle(color: mutedInk, fontSize: 10, height: 1.4)),
        const SizedBox(height: 18),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.asset(
            'assets/brand/profile_footer.jpg',
            width: double.infinity,
            height: 59,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
        ),
      ]);
    }),
  );

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: color.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: color.withValues(alpha: .45))),
    child: Text(text, style: TextStyle(color: color, fontSize: 9,
      letterSpacing: .5, fontWeight: FontWeight.w800)),
  );

  Widget _metric(String label, String value, IconData icon) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
    decoration: BoxDecoration(color: panelNavy, borderRadius: BorderRadius.circular(15),
      border: Border.all(color: borderColor)),
    child: Column(children: [
      Icon(icon, color: electricBlue, size: 19), const SizedBox(height: 8),
      Text(value, style: GoogleFonts.robotoMono(color: ink, fontSize: 19, fontWeight: FontWeight.w800)),
      Text(label, textAlign: TextAlign.center,
        maxLines: 2, overflow: TextOverflow.ellipsis,
        style: TextStyle(color: mutedInk, fontSize: 9, fontWeight: FontWeight.w700)),
    ]),
  );
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
        context: context, isScrollControlled: true, backgroundColor: panelNavy,
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
               Text('Advisory only. Authorised officers must verify information and make official decisions.',
                style: TextStyle(fontSize: 11, color: mutedInk)),
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
            color: possibleOverlap ? Colors.deepOrange : teal,
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
                 Text(
                  'This check uses only the records currently available to SAMANVAY. It is not a utility-location certificate, permit, site clearance or guarantee of safety. Obtain clearance from utility owners and complete required field verification before work.',
                  style: TextStyle(fontSize: 11, color: mutedInk),
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
        backgroundColor: panelNavy,
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
                              color: overlap ? Colors.deepOrange : teal,
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
        backgroundColor: panelNavy,
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
                            leading:  Icon(Icons.fact_check_outlined, color: teal),
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
        backgroundColor: panelNavy,
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
                        leading:  Icon(Icons.timeline, color: teal),
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
          color: mine ? const Color(0xFF123C4A) : panelNavy,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: mine ? const Color(0xFF286B72) : borderColor),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(mine ? 'You' : 'Case participant',
            style:  TextStyle(fontSize: 9, color: mutedInk, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(item['body']?.toString() ?? '', style:  TextStyle(color: ink)),
          if (time.isNotEmpty) Align(alignment: Alignment.bottomRight,
            child: Text(time, style:  TextStyle(fontSize: 9, color: mutedInk))),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = supabase.auth.currentUser?.id;
    return Scaffold(
      backgroundColor: background,
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
          color: panelNavy,
          child: Row(children: [
             Icon(Icons.shield_outlined, color: teal, size: 18),
            const SizedBox(width: 8),
             Expanded(child: Text(
              'Case messages and evidence are restricted to authenticated participants.',
              style: TextStyle(fontSize: 10, color: mutedInk))),
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
            color: panelNavy,
            child: Row(children: [
              IconButton(tooltip: 'Upload evidence', onPressed: _uploading ? null : _upload,
                icon:  Icon(Icons.attach_file, color: teal)),
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
      backgroundColor: background,
      appBar: AppBar(title: const Text('Notifications')),
      body: StreamBuilder<List<Map<String,dynamic>>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Notifications could not be loaded.',
                style: TextStyle(color: Colors.white)),
            );
          }
          if (!snapshot.hasData) {
            return  Center(
              child: CircularProgressIndicator(color: cyanAccent),
            );
          }
          final rows = snapshot.data!;
          final unread = rows.where((x) => x['read_at'] == null).length;
          if (rows.isEmpty) {
            return const Center(
              child: Text('You are all caught up.',
                style: TextStyle(color: Colors.white)),
            );
          }
          final total = rows.length;
          return ListView(padding: const EdgeInsets.all(14), children: [
            Text('$unread unread · $total total',
              style:  TextStyle(color: mutedInk, fontSize: 12, fontWeight: FontWeight.w700)),
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
                color: fresh ? const Color(0xFF123C4A) : panelNavy,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0x3320D6C2),
                    child: Icon(icon, color: cyanAccent)),
                  title: Text(item['title']?.toString() ?? 'SAMANVAY update',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                  subtitle: Text('$notificationBody\n$dateText', style:  TextStyle(color: mutedInk)),
                  isThreeLine: true,
                  trailing: fresh
                    ? const Icon(Icons.circle, color: Color(0xFF13A89E), size: 10)
                    :  Icon(Icons.check, color: mutedInk, size: 18),
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
                  style:  TextStyle(fontSize: 10, color: mutedInk),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Platform role', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'requester', child: Text('Citizen')),
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
                 Text(
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
               Text(
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
                 Text(
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
          Text(title, style:  TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 3),
          Text(subtitle, style:  TextStyle(fontSize: 11, color: mutedInk)),
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
                gradient: LinearGradient(
                  colors: [navy, Color(0xFF14515E)],
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
                final subtitle = '${_displayRoleName(role).toUpperCase()}'
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
                      child: Icon(icon, color: teal),
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
                  leading:  Icon(Icons.account_tree_outlined, color: teal),
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
                    leading:  Icon(Icons.route_outlined, color: teal),
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
                      leading:  Icon(Icons.history, color: mutedInk),
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

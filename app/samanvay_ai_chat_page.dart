import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ai_assistant_page.dart';

/// Authenticated SAMANVAY chatbot. Conversation text remains in screen memory only.
class SamanvayAiChatPage extends StatefulWidget {
  const SamanvayAiChatPage({super.key});
  @override
  State<SamanvayAiChatPage> createState() => _SamanvayAiChatPageState();
}

class _SamanvayAiChatPageState extends State<SamanvayAiChatPage> {
  final SupabaseClient _db = Supabase.instance.client;
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<Map<String, dynamic>> _messages = [
    {
      'role': 'assistant',
      'content': 'Hello! I’m the SAMANVAY Smart Assistant. I use built-in guidance and SAMANVAY’s existing public data metadata, with no paid AI API. I can help with app navigation, requests, department routing, GIS and groundwater-data interpretation. What would you like to know?',
    },
  ];
  bool _busy = false;
  bool _roleChecked = false;
  bool _canOpenCaseIntelligence = false;
  String? _error;

  Color get _surface => Theme.of(context).colorScheme.surface;
  Color get _ink => Theme.of(context).colorScheme.onSurface;
  Color get _muted => Theme.of(context).colorScheme.onSurfaceVariant;
  Color get _primary => Theme.of(context).colorScheme.primary;
  Color get _outline => Theme.of(context).colorScheme.outlineVariant;
  bool get _light => Theme.of(context).brightness == Brightness.light;

  @override
  void initState() {
    super.initState();
    _loadRoleAccess();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadRoleAccess() async {
    final user = _db.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _roleChecked = true);
      return;
    }
    try {
      final row = await _db.from('profiles').select('role').eq('id', user.id).maybeSingle();
      final role = row?['role']?.toString();
      if (!mounted) return;
      setState(() {
        _canOpenCaseIntelligence = ['department', 'coordinator', 'admin'].contains(role);
        _roleChecked = true;
      });
    } catch (_) {
      if (mounted) setState(() => _roleChecked = true);
    }
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    });
  }

  String _friendlyError(Object error) {
    final value = error.toString();
    if (value.contains('SUPABASE_FUNCTION_CONFIG_MISSING') || value.contains('INTERNAL_SERVER_ERROR') || value.contains('BUILTIN_ASSISTANT_ERROR')) {
      return 'The built-in assistant is temporarily unavailable. Check your connection and try again.';
    }
    if (value.contains('DAILY_AI_LIMIT_REACHED') || value.contains('429')) {
      return 'You have reached the daily assistant message allowance. Please try again after the 24-hour usage window.';
    }
    if (value.contains('AUTHENTICATION_REQUIRED') || value.contains('INVALID_SESSION') || value.contains('401')) {
      return 'Your sign-in session is not valid. Sign in again and reopen SAMANVAY ASSISTANT.';
    }
    if (value.contains('PROFILE_NOT_FOUND')) {
      return 'Your SAMANVAY profile is not ready. Please contact the platform administrator.';
    }
    if (value.contains('FUNCTION_NOT_FOUND') || value.contains('404')) {
      return 'The SAMANVAY assistant service is not available in this app build yet.';
    }
    return 'SAMANVAY could not process that message. Check your connection and try again.';
  }

  Future<void> _send([String? suggestion]) async {
    if (_busy) return;
    final text = (suggestion ?? _input.text).trim();
    if (text.isEmpty) return;
    if (text.length > 1200) {
      setState(() => _error = 'Please keep each message within 1,200 characters.');
      return;
    }
    if (_db.auth.currentSession == null) {
      setState(() => _error = 'Please sign in to use the SAMANVAY assistant.');
      return;
    }
    final next = <Map<String, dynamic>>[
      ..._messages,
      {'role': 'user', 'content': text},
    ];
    setState(() {
      _messages..clear()..addAll(next);
      _input.clear();
      _busy = true;
      _error = null;
    });
    _scrollToLatest();

    try {
      final history = _messages.length > 12
          ? _messages.sublist(_messages.length - 12)
          : List<Map<String, dynamic>>.from(_messages);
      final response = await _db.functions.invoke(
        'samanvay-ai-chat',
        body: {'messages': history},
      );
      final data = response.data;
      if (response.status < 200 || response.status >= 300) {
        final code = data is Map ? (data['error'] ?? 'BUILTIN_ASSISTANT_ERROR').toString() : 'BUILTIN_ASSISTANT_ERROR';
        throw StateError(code);
      }
      if (data is! Map || data['reply'] is! String || (data['reply'] as String).trim().isEmpty) {
        throw StateError('EMPTY_AI_RESPONSE');
      }
      if (!mounted) return;
      setState(() => _messages.add({
        'role': 'assistant',
        'content': (data['reply'] as String).trim(),
        'sources': data['sources'] is List ? List<dynamic>.from(data['sources'] as List) : <dynamic>[],
      }));
      _scrollToLatest();
    } catch (error) {
      if (mounted) {
        final fallback = _builtInReply(text);
        setState(() {
          _messages.add({
            'role': 'assistant',
            'content': '$fallback\n\n[Built-in offline guidance; live assistant service unavailable.]',
          });
          _error = null;
        });
        _scrollToLatest();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _builtInReply(String question) {
    final q = question.toLowerCase();
    if (q.contains('what can') || q.contains('about samanvay') || q.contains('explore the app')) {
      return 'SAMANVAY is a civic infrastructure coordination prototype. Citizens can submit and track infrastructure requests; authorised department officers review assigned work; coordinators monitor cross-department dependencies; administrators manage access and routing. The GIS combines public reference layers with clearly labelled simulated underground visuals. It is a prototype, not an official utility-clearance system.';
    }
    if (q.contains('sign up') || q.contains('signup') || q.contains('register') || q.contains('create account') || q.contains('official access')) {
      return 'To register: choose Create Account, enter your name, enter an email address or mobile number, create a password, and select the requested account type: Citizen, Department Officer, Coordinator or Administrator. Verify the contact using the code sent by the configured provider. Official access remains pending until an administrator verifies the request and assigns the department. The account role opens the matching workspace only after approval.';
    }
    if (q.contains('otp') || q.contains('verification code') || q.contains('sms code') || q.contains('verify mobile')) {
      return "For mobile verification, enter the number with its country code, request the six-digit code, enter it on the verification screen, and use Resend after the countdown. SMS delivery requires the project's Supabase phone-auth SMS hook and provider configuration. The app cannot create a real SMS delivery without that external configuration. Never share your OTP in chat.";
    }
    if (q.contains('change password') || q.contains('reset password') || q.contains('forgot password') || q.contains('password recovery')) {
      return "To change a password while signed in, open Profile and select Change password. To recover access from the login screen, select Forgot password? and follow the reset email. Email delivery depends on the project's Supabase email provider and redirect setup. Do not share your password or reset link in chat.";
    }
    if (q.contains('submit') || q.contains('raise a request') || q.contains('complaint')) {
      return 'To submit a request: open the Citizen workspace, choose New Request, select the infrastructure category, describe the issue, add the location and supporting evidence if available, then submit. Keep personal information out of public descriptions. The request should appear under My Requests after successful submission.';
    }
    if (q.contains('status')) {
      return 'Request statuses describe workflow progress: Submitted means received; Under Review means a department is assessing it; More Information Required means the requester must add details; Coordinating means multiple departments are being consulted; Approved or Scheduled means work is planned; In Progress means work has started; Completed means the responsible team has reported completion. Status labels are prototype workflow indicators, not statutory approvals.';
    }
    if (q.contains('department') || q.contains('coordinat')) {
      return 'SAMANVAY routes requests to relevant infrastructure departments and helps identify work that may overlap in time or location. Department officers should act only on assigned cases. Coordinators review cross-department dependencies. Administrator access is for account governance. Privileged roles must be approved; choosing a role during registration does not grant it.';
    }
    if (q.contains('underground') || q.contains('utility') || q.contains('pipe') || q.contains('cable')) {
      return 'Open GIS and select Underground. The cutaway now provides separate Water, Sewer, Drainage, Electricity, Telecom, Gas and Borewell switches. The 2D / 3D map control changes the cutaway presentation. Moving line markers make the schematic easier to read, but the paths are synthetic, are not attached to road coordinates or measured depths, and are not excavation clearance. Confirm actual infrastructure with the relevant utility owners and authorised surveys.';
    }
    if (q.contains('gis') || q.contains('map') || q.contains('satellite') || q.contains('ward') || q.contains('district')) {
      return 'Open GIS from the main navigation. Switch between vector and satellite basemaps, use search to navigate administrative areas, and enable available public reference layers. Groundwater observations show their source dates. Any simulated underground layer must remain visibly labelled DEMO / NOT SURVEYED.';
    }
    if (q.contains('groundwater') || q.contains('borewell')) {
      return 'The groundwater layer is a reference view of retained observations, not a live sensor feed. Check the displayed publisher and observation date before interpreting a reading. It cannot certify borewell permission, water quality or current groundwater conditions.';
    }
    if (q.contains('password') || q.contains('otp') || q.contains('login') || q.contains('sign in')) {
      return 'Use your registered email or verified mobile number on the sign-in screen. SMS OTP delivery depends on the Supabase phone-auth provider and its SMS configuration. Use Forgot password for email-based recovery. If a code is not delivered, do not repeatedly request it; check the registered number and provider configuration.';
    }
    return 'I can guide you through SAMANVAY navigation, Citizen requests, workflow statuses, department coordination, GIS layers and groundwater references. Ask one of those questions for a specific walkthrough. This built-in fallback is rule-based guidance; live AI responses require the configured assistant service.';
  }

  void _newChat() {
    if (_busy) return;
    setState(() {
      _messages..clear()..add({
        'role': 'assistant',
        'content': 'New chat started. Ask about SAMANVAY, infrastructure requests, department coordination, GIS or how to use the app.',
      });
      _error = null;
    });
    _scrollToLatest();
  }


  Widget _sourceReferences(dynamic rawSources) {
    if (rawSources is! List || rawSources.isEmpty) return const SizedBox.shrink();
    final sources = rawSources
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .take(6)
        .toList();
    if (sources.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _light ? const Color(0xFFE8F0F5) : const Color(0xFF0B2033),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('RETRIEVED SOURCE REFERENCES',
              style: TextStyle(color: _primary, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .7)),
          const SizedBox(height: 5),
          ...sources.map((source) {
            final id = (source['id'] ?? '').toString();
            final title = (source['title'] ?? 'Reference source').toString();
            final agency = (source['agency'] ?? '').toString();
            final status = (source['status'] ?? '').toString();
            final note = (source['note'] ?? '').toString();
            final checkedAt = (source['checked_at'] ?? '').toString();
            final url = (source['url'] ?? '').toString();
            final uri = Uri.tryParse(url);
            final canOpen = uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
            return Padding(
              padding: const EdgeInsets.only(top: 5),
              child: InkWell(
                onTap: canOpen ? () async {
                  try {
                    await launchUrl(uri!, mode: LaunchMode.externalApplication);
                  } catch (_) {
                    if (mounted) setState(() => _error = 'Unable to open the source reference.');
                  }
                } : null,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('[$id] ', style: TextStyle(color: _primary, fontSize: 10, fontWeight: FontWeight.w900)),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: TextStyle(color: _ink, fontSize: 10, fontWeight: FontWeight.w800)),
                        if (agency.isNotEmpty)
                          Text(agency, style: TextStyle(color: _muted, fontSize: 9)),
                        if (status.isNotEmpty)
                          Text('Catalogue status: $status', style: TextStyle(color: _muted, fontSize: 8)),
                        if (checkedAt.isNotEmpty)
                          Text('Checked: $checkedAt', style: TextStyle(color: _muted, fontSize: 8)),
                        if (note.isNotEmpty)
                          Text(note, maxLines: 3, overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: _muted, fontSize: 8, height: 1.3)),
                      ],
                    )),
                    if (canOpen) const Icon(Icons.open_in_new_rounded, size: 14, color: Color(0xFF31BFD0)),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 5),
          Text('Catalogue references support provenance and discovery; they do not prove complete live coverage or a verified underground asset at a location.',
              style: TextStyle(color: _muted, fontSize: 8, height: 1.35)),
        ],
      ),
    );
  }

  Widget _bubble(Map<String, dynamic> message) {
    final fromUser = message['role'] == 'user';
    final color = fromUser ? _primary : (_light ? const Color(0xFFF0F5F8) : const Color(0xFF142B42));
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(17),
              topRight: const Radius.circular(17),
              bottomLeft: Radius.circular(fromUser ? 17 : 5),
              bottomRight: Radius.circular(fromUser ? 5 : 17),
            ),
            border: fromUser ? null : Border.all(color: _outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText(
                (message['content'] ?? '').toString(),
                style: TextStyle(color: fromUser ? Colors.white : _ink, fontSize: 13, height: 1.48),
              ),
              if (!fromUser) _sourceReferences(message['sources']),
            ],
          ),
        ),
      ),
    );
  }

  Widget _suggestion(String label, IconData icon, String query) => ActionChip(
    avatar: Icon(icon, size: 16, color: _primary),
    label: Text(label, style: TextStyle(color: _ink, fontSize: 10)),
    backgroundColor: _surface,
    side: BorderSide(color: _outline),
    onPressed: _busy ? null : () => _send(query),
  );

  Widget _composer() {
    final signedIn = _db.auth.currentSession != null;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(color: _surface, border: Border(top: BorderSide(color: _outline))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 4,
                maxLength: 1200,
                enabled: signedIn && !_busy,
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: signedIn ? 'Ask SAMANVAY…' : 'Sign in to chat',
                  hintStyle: TextStyle(color: _muted, fontSize: 12),
                  filled: true,
                  fillColor: _light ? const Color(0xFFF4F7FA) : const Color(0xFF0A1C2E),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: _outline)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: _outline)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 48,
              width: 48,
              child: FilledButton(
                onPressed: !signedIn || _busy ? null : () => _send(),
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: _primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: _busy
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.arrow_upward_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = _db.auth.currentSession != null;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF31BFD0).withValues(alpha: .16),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.smart_toy_rounded, color: Color(0xFF31BFD0), size: 21),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Text('SAMANVAY ASSISTANT')),
        ]),
        actions: [
          if (_roleChecked && _canOpenCaseIntelligence)
            IconButton(
              tooltip: 'Open case intelligence',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SamanvayAiAssistantPage()),
              ),
              icon: const Icon(Icons.analytics_outlined),
            ),
          IconButton(
            tooltip: 'New chat',
            onPressed: _busy ? null : _newChat,
            icon: const Icon(Icons.add_comment_outlined),
          ),
        ],
      ),
      body: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 11),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _light
                  ? const [Color(0xFFE4F5F3), Color(0xFFE7F0FA)]
                  : const [Color(0xFF102C45), Color(0xFF123D60)],
            ),
            border: Border(bottom: BorderSide(color: _outline)),
          ),
          child: Row(children: [
            Icon(Icons.public_rounded, color: _primary, size: 19),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                'Your guide to infrastructure coordination and the SAMANVAY app',
                style: TextStyle(color: _ink, fontSize: 11, height: 1.35, fontWeight: FontWeight.w600),
              ),
            ),
            if (signedIn)
              const Icon(Icons.verified_user_outlined, size: 16, color: Color(0xFF42B98D)),
          ]),
        ),
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            children: [
              if (_messages.length == 1) ...[
                Text('SUGGESTED QUESTIONS', style: TextStyle(color: _muted, fontSize: 9, letterSpacing: 1, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  runSpacing: 1,
                  children: [
                    _suggestion('Explore the app', Icons.explore_outlined, 'What can I do with SAMANVAY?'),
                    _suggestion('Raise a request', Icons.add_task_outlined, 'How do I submit an infrastructure request?'),
                    _suggestion('Track a request', Icons.track_changes_outlined, 'How do I track a submitted request?'),
                    _suggestion('Request official access', Icons.badge_outlined, 'How do I request a Department Officer, Coordinator or Administrator account?'),
                    _suggestion('Mobile OTP', Icons.sms_outlined, 'How do I sign up with my mobile number and verify the OTP?'),
                    _suggestion('Underground GIS', Icons.layers_outlined, 'How do I use the underground map service layers?'),
                    _suggestion('Password recovery', Icons.lock_reset_rounded, 'How do I change or reset my password?'),
                    _suggestion('Department coordination', Icons.account_tree_outlined, 'How does SAMANVAY coordinate work across departments?'),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              ..._messages.map(_bubble),
              if (_busy)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                    decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _outline)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2, color: _primary)),
                      const SizedBox(width: 9),
                      Text('Checking built-in guidance…', style: TextStyle(color: _muted, fontSize: 10)),
                    ]),
                  ),
                ),
            ],
          ),
        ),
        if (_error != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: _light ? const Color(0xFFFFF0E4) : const Color(0xFF422F25),
              border: Border.all(color: const Color(0xFFCF8B49)),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(_error!, style: TextStyle(color: _ink, fontSize: 10, height: 1.35)),
          ),
        _composer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            'Zero-cost rule-based guidance using existing SAMANVAY data metadata. It is advisory, cannot verify site conditions or approve work, and cannot provide underground utility clearance. Chat text is not saved.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 9, height: 1.35),
          ),
        ),
      ]),
    );
  }
}

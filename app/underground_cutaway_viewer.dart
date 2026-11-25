import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Interactive, locally hosted Three.js cutaway used only for the SAMANVAY demo.
/// The geometry is synthetic and must never be used for excavation decisions.
class SamanvayCutawayViewer extends StatefulWidget {
  const SamanvayCutawayViewer({
    super.key,
    required this.viewMode,
    required this.visibleLayers,
    required this.isLight,
    this.onViewModeChanged,
  });

  final String viewMode;
  final Set<String> visibleLayers;
  final bool isLight;
  final ValueChanged<String>? onViewModeChanged;

  @override
  State<SamanvayCutawayViewer> createState() => _SamanvayCutawayViewerState();
}

class _SamanvayCutawayViewerState extends State<SamanvayCutawayViewer> {
  late final WebViewController _controller;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(widget.isLight ? const Color(0xFFE8F0F2) : const Color(0xFF102332))
      ..addJavaScriptChannel(
        'Samanvay',
        onMessageReceived: (message) {
          try {
            final payload = jsonDecode(message.message);
            if (payload is Map && payload['type'] == 'mode' && mounted) {
              final mode = payload['mode']?.toString();
              if (mode == '2D plan' || mode == '3D cutaway') {
                widget.onViewModeChanged?.call(mode!);
              }
            }
            if (payload is Map && payload['type'] == 'record_selected' && mounted) {
              final name = payload['name']?.toString() ?? 'Infrastructure asset';
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Selected demo feature: $name'),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          } catch (_) {
            // Ignore malformed messages from the local visualisation.
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) {
              setState(() => _ready = true);
              _pushState();
            }
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true && mounted) {
              setState(() => _failed = true);
            }
          },
        ),
      )
      ..loadFlutterAsset('assets/cutaway/index.html');
  }

  @override
  void didUpdateWidget(covariant SamanvayCutawayViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewMode != widget.viewMode ||
        oldWidget.visibleLayers != widget.visibleLayers ||
        oldWidget.isLight != widget.isLight) {
      _pushState();
    }
  }

  void _pushState() {
    if (!_ready) return;
    final payload = jsonEncode({
      'mode': widget.viewMode,
      'layers': widget.visibleLayers.toList(),
      'light': widget.isLight,
    });
    _controller.runJavaScript('window.samanvayUpdate($payload);');
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            '3D viewer could not initialise on this device. Check Android System WebView, then reopen this panel.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        WebViewWidget(controller: _controller),
        if (!_ready)
          const ColoredBox(
            color: Color(0xFF102332),
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
            ),
          ),
      ],
    );
  }
}

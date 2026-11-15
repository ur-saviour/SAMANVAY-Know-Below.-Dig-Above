import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A compact, interactive subsurface digital-twin panel for the GIS map.
///
/// All drawn routes are explicitly illustrative. This widget does not create
/// or imply georeferenced utility records.
class SamanvayUndergroundTwinPanel extends StatefulWidget {
  const SamanvayUndergroundTwinPanel({
    super.key,
    required this.is3D,
    required this.visibleLayers,
    required this.onLayerChanged,
  });

  final bool is3D;
  final Set<String> visibleLayers;
  final void Function(String name, bool enabled) onLayerChanged;

  @override
  State<SamanvayUndergroundTwinPanel> createState() =>
      _SamanvayUndergroundTwinPanelState();
}

class _SamanvayUndergroundTwinPanelState
    extends State<SamanvayUndergroundTwinPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flow = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  String _view = 'CITY TWIN';

  static const _layers = <({String name, String label, Color color, IconData icon})>[
    (name: 'Water', label: 'WATER', color: Color(0xFF35BDF2), icon: Icons.water_drop_rounded),
    (name: 'Sewer', label: 'SEWER', color: Color(0xFFAA8BFF), icon: Icons.water_rounded),
    (name: 'Stormwater', label: 'DRAIN', color: Color(0xFF35D6B1), icon: Icons.grain_rounded),
    (name: 'Electricity', label: 'POWER', color: Color(0xFFFFC857), icon: Icons.bolt_rounded),
    (name: 'Telecom', label: 'FIBRE', color: Color(0xFFFF83C8), icon: Icons.cable_rounded),
    (name: 'Gas', label: 'GAS', color: Color(0xFFFF925C), icon: Icons.local_fire_department_rounded),
    (name: 'Borewell', label: 'BOREWELL', color: Color(0xFF51D8D0), icon: Icons.sensors_rounded),
  ];

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = math.min(430.0, MediaQuery.sizeOf(context).width - 24).toDouble();
    final maxHeight = math.min(430.0, MediaQuery.sizeOf(context).height * .52).toDouble();

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width, maxHeight: maxHeight),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xF20A192A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x9955D9CE), width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 22,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_tree_rounded,
                      color: Color(0xFF5CE2D2), size: 18),
                  const SizedBox(width: 7),
                  const Expanded(
                    child: Text(
                      'SUBSURFACE DIGITAL TWIN',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .85,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0x33F6C66B),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0x77F6C66B)),
                    ),
                    child: const Text(
                      'ILLUSTRATIVE',
                      style: TextStyle(
                        color: Color(0xFFFFD98B),
                        fontSize: 7,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _modeButton('CITY TWIN', Icons.location_city_rounded),
                  const SizedBox(width: 6),
                  _modeButton('ROAD SECTION', Icons.view_agenda_rounded),
                  const Spacer(),
                  Text(
                    widget.is3D ? '3D' : '2D',
                    style: const TextStyle(
                      color: Color(0xFF8FE9DF),
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  height: 196,
                  width: double.infinity,
                  child: AnimatedBuilder(
                    animation: _flow,
                    builder: (context, _) => CustomPaint(
                      painter: _SamanvayTwinPainter(
                        view: _view,
                        visibleLayers: widget.visibleLayers,
                        flow: _flow.value,
                        is3D: widget.is3D,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 7),
              Wrap(
                spacing: 5,
                runSpacing: 3,
                children: _layers.map((layer) {
                  final selected = widget.visibleLayers.contains(layer.name);
                  return InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => widget.onLayerChanged(layer.name, !selected),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                      decoration: BoxDecoration(
                        color: selected
                            ? layer.color.withValues(alpha: .18)
                            : const Color(0xFF14283B),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? layer.color.withValues(alpha: .85)
                              : const Color(0x554B647C),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(layer.icon, color: layer.color, size: 11),
                          const SizedBox(width: 4),
                          Text(
                            layer.label,
                            style: TextStyle(
                              color: selected ? Colors.white : const Color(0xFF9FB2C4),
                              fontSize: 7.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 6),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: Color(0xFFFFD98B), size: 12),
                  SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Concept visualization only — not survey geometry, measured depth or excavation clearance. Verified owner-authorised assets appear separately when available.',
                      style: TextStyle(
                        color: Color(0xFFFFD98B),
                        fontSize: 7.5,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeButton(String label, IconData icon) {
    final selected = _view == label;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => _view = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF174A55) : const Color(0xFF14283B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? const Color(0xFF55D9CE) : const Color(0x554B647C),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12,
                color: selected ? const Color(0xFF75EBDD) : const Color(0xFF9FB2C4)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF9FB2C4),
                fontSize: 7.5,
                fontWeight: FontWeight.w900,
                letterSpacing: .2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SamanvayTwinPainter extends CustomPainter {
  const _SamanvayTwinPainter({
    required this.view,
    required this.visibleLayers,
    required this.flow,
    required this.is3D,
  });

  final String view;
  final Set<String> visibleLayers;
  final double flow;
  final bool is3D;

  static const _water = Color(0xFF35BDF2);
  static const _sewer = Color(0xFFAA8BFF);
  static const _drain = Color(0xFF35D6B1);
  static const _power = Color(0xFFFFC857);
  static const _telecom = Color(0xFFFF83C8);
  static const _gas = Color(0xFFFF925C);
  static const _bore = Color(0xFF51D8D0);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF132B40), Color(0xFF091725)],
        ).createShader(rect),
    );

    if (view == 'ROAD SECTION') {
      _paintRoadSection(canvas, size);
    } else {
      _paintCityTwin(canvas, size);
    }

    _paintDepthScale(canvas, size);
    _paintFlowParticles(canvas, size);
  }

  void _paintCityTwin(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;
    final groundY = h * .39;

    // Distant skyline.
    final skyline = Paint()..color = const Color(0xFF27465C);
    for (var i = 0; i < 9; i++) {
      final x = i * w / 8.2;
      final bw = w * (.075 + (i % 3) * .012);
      final bh = h * (.12 + (i % 4) * .035);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, groundY - bh - 5, bw, bh),
          const Radius.circular(2),
        ),
        skyline,
      );
      _windows(canvas, Rect.fromLTWH(x, groundY - bh - 5, bw, bh));
    }

    // Ground plane and road surface.
    final ground = Path()
      ..moveTo(0, groundY)
      ..lineTo(w, groundY)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      ground,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF8B694D), Color(0xFF493B35)],
        ).createShader(Rect.fromLTWH(0, groundY, w, h - groundY)),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, groundY - 5, w, 10),
      Paint()..color = const Color(0xFF687D85),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, groundY - 2, w, 3),
      Paint()..color = const Color(0xFFCAD4D4),
    );
    canvas.drawLine(
      Offset(0, groundY - 5),
      Offset(w, groundY - 5),
      Paint()
        ..color = const Color(0xFFECF3F4)
        ..strokeWidth = 1.3,
    );

    // Road lane markings and curb.
    for (var i = 0; i < 7; i++) {
      final x = w * (.16 + i * .115);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, groundY - 1, w * .055, 2),
          const Radius.circular(2),
        ),
        Paint()..color = const Color(0xFFDFE6E5).withValues(alpha: .75),
      );
    }

    // Foreground building masses.
    _building(canvas, Rect.fromLTWH(w * .045, groundY - h * .23, w * .17, h * .225), const Color(0xFF466B7C), extruded: is3D);
    _building(canvas, Rect.fromLTWH(w * .79, groundY - h * .27, w * .16, h * .265), const Color(0xFF3B6075), extruded: is3D);
    _building(canvas, Rect.fromLTWH(w * .29, groundY - h * .15, w * .11, h * .145), const Color(0xFF36586A), extruded: is3D);

    // Subsurface strata.
    final bands = [
      (groundY + 5, h * .19, const Color(0xFF72533F)),
      (groundY + h * .19, h * .17, const Color(0xFF5C483D)),
      (groundY + h * .36, h * .25, const Color(0xFF3D3D3B)),
    ];
    for (final band in bands) {
      canvas.drawRect(
        Rect.fromLTWH(0, band.$1, w, band.$2),
        Paint()..color = band.$3.withValues(alpha: .86),
      );
      final top = band.$1;
      for (var i = 0; i < 13; i++) {
        final x = (i * 47.0 + (i % 3) * 13) % w;
        canvas.drawCircle(
          Offset(x, top + 8 + (i % 4) * 9),
          1.1 + (i % 2),
          Paint()..color = const Color(0xFFD8B18A).withValues(alpha: .28),
        );
      }
    }

    // Utility conduits at distinct illustrative depths.
    _utilityLine(canvas, w, groundY + h * .15, _water, 8, 'Water');
    _utilityLine(canvas, w, groundY + h * .24, _sewer, 10, 'Sewer');
    _utilityLine(canvas, w, groundY + h * .31, _drain, 7, 'Stormwater');
    _utilityLine(canvas, w, groundY + h * .39, _gas, 5, 'Gas');
    _utilityLine(canvas, w, groundY + h * .46, _power, 3, 'Electricity');
    _utilityLine(canvas, w, groundY + h * .50, _telecom, 2, 'Telecom');

    // Service shaft and borewell.
    if (visibleLayers.contains('Borewell')) {
      final x = w * .66;
      final borePaint = Paint()
        ..color = _bore
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(x, groundY + 1), Offset(x, h * .94), borePaint);
      canvas.drawCircle(Offset(x, h * .94), 4, Paint()..color = _bore);
      _tag(canvas, 'BOREWELL', Offset(x + 5, h * .88), _bore);
    }

    // A subtle cutaway edge gives the city block depth.
    final edge = Path()
      ..moveTo(w * .015, groundY)
      ..lineTo(w * .015, h * .96)
      ..lineTo(w * .985, h * .96);
    canvas.drawPath(
      edge,
      Paint()
        ..color = const Color(0xFFB78D68)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    _tag(canvas, 'SURFACE', Offset(7, groundY - 15), const Color(0xFFDCE8EC));
    _tag(canvas, 'SUBSURFACE', Offset(7, h * .91), const Color(0xFFD9B18A));
  }

  void _paintRoadSection(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;
    final roadBottom = h * .30;

    // Surface background and adjacent buildings.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, roadBottom),
      Paint()..color = const Color(0xFF18364A),
    );
    _building(canvas, Rect.fromLTWH(w * .04, h * .015, w * .18, h * .25), const Color(0xFF466B7C), extruded: is3D);
    _building(canvas, Rect.fromLTWH(w * .78, h * .035, w * .17, h * .23), const Color(0xFF3B6075), extruded: is3D);

    // Road slab, asphalt and footpaths.
    canvas.drawRect(
      Rect.fromLTWH(w * .20, h * .15, w * .60, h * .15),
      Paint()..color = const Color(0xFF29343C),
    );
    canvas.drawRect(
      Rect.fromLTWH(w * .20, h * .145, w * .60, 4),
      Paint()..color = const Color(0xFF8C9BA0),
    );
    canvas.drawRect(
      Rect.fromLTWH(w * .20, h * .275, w * .60, 4),
      Paint()..color = const Color(0xFFB7C2C0),
    );
    for (var i = 0; i < 5; i++) {
      canvas.drawRect(
        Rect.fromLTWH(w * (.29 + i * .105), h * .215, w * .06, 2),
        Paint()..color = const Color(0xFFDCE5E5).withValues(alpha: .85),
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(0, roadBottom, w, h - roadBottom),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF846047), Color(0xFF3F3B38)],
        ).createShader(Rect.fromLTWH(0, roadBottom, w, h - roadBottom)),
    );

    // Trench profile and bedding.
    final trench = Path()
      ..moveTo(w * .34, roadBottom)
      ..lineTo(w * .34, h * .88)
      ..lineTo(w * .72, h * .88)
      ..lineTo(w * .72, roadBottom);
    canvas.drawPath(
      trench,
      Paint()
        ..color = const Color(0xFFB28B64).withValues(alpha: .28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * .355, h * .78, w * .35, h * .105),
        const Radius.circular(5),
      ),
      Paint()..color = const Color(0xFFB69A78).withValues(alpha: .55),
    );

    // Utilities crossing the trench at different elevations.
    _utilityLine(canvas, w, h * .43, _water, 9, 'Water');
    _utilityLine(canvas, w, h * .55, _sewer, 11, 'Sewer');
    _utilityLine(canvas, w, h * .65, _drain, 7, 'Stormwater');
    _utilityLine(canvas, w, h * .72, _gas, 5, 'Gas');
    _utilityLine(canvas, w, h * .84, _power, 3, 'Electricity');
    if (visibleLayers.contains('Telecom')) {
      final cable = Paint()
        ..color = _telecom
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;
      final p = Path()
        ..moveTo(w * .09, h * .91)
        ..cubicTo(w * .28, h * .84, w * .48, h * .95, w * .91, h * .90);
      canvas.drawPath(p, cable);
      _tag(canvas, 'FIBRE DUCT', Offset(w * .73, h * .91), _telecom);
    }
    if (visibleLayers.contains('Borewell')) {
      final x = w * .86;
      canvas.drawLine(
        Offset(x, roadBottom),
        Offset(x, h * .94),
        Paint()
          ..color = _bore
          ..strokeWidth = 3,
      );
      _tag(canvas, 'BORE', Offset(x - 34, h * .88), _bore);
    }

    // Manhole and service access chamber.
    final chamber = Rect.fromLTWH(w * .50, roadBottom - 2, w * .075, h * .20);
    canvas.drawRect(chamber, Paint()..color = const Color(0xFF43515A));
    canvas.drawRect(
      Rect.fromLTWH(chamber.left - 4, roadBottom - 5, chamber.width + 8, 4),
      Paint()..color = const Color(0xFFB6C2C5),
    );
    _tag(canvas, 'ROAD CUTAWAY', Offset(7, h * .035), const Color(0xFFE0EAF0));
    _tag(canvas, 'SOIL / UTILITY CORRIDOR', Offset(7, h * .94), const Color(0xFFE0C29E));
  }

  void _utilityLine(Canvas canvas, double w, double y, Color color, double width, String layer) {
    if (!visibleLayers.contains(layer)) return;
    final path = Path()
      ..moveTo(-8, y + 2)
      ..cubicTo(w * .22, y - 7, w * .34, y + 8, w * .52, y)
      ..cubicTo(w * .70, y - 7, w * .82, y + 7, w + 8, y - 1);
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: .22)
        ..strokeWidth = width + 5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = width
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    if (width >= 6) {
      for (var i = 0; i < 3; i++) {
        final x = w * (.24 + i * .27);
        canvas.drawCircle(Offset(x, y), width * .48,
            Paint()..color = color.withValues(alpha: .9));
      }
    }
    _tag(canvas, layer.toUpperCase(), Offset(w * .77, y - 8), color);
  }

  void _building(Canvas canvas, Rect r, Color color, {bool extruded = false}) {
    final shadow = Rect.fromLTWH(r.left + 4, r.top + 5, r.width, r.height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(shadow, const Radius.circular(2)),
      Paint()..color = const Color(0xFF07111B).withValues(alpha: .45),
    );
    if (extruded) {
      final side = Path()
        ..moveTo(r.right, r.top)
        ..lineTo(r.right + 8, r.top - 5)
        ..lineTo(r.right + 8, r.bottom - 5)
        ..lineTo(r.right, r.bottom)
        ..close();
      canvas.drawPath(side, Paint()..color = color.withValues(alpha: .48));
      final roof = Path()
        ..moveTo(r.left, r.top)
        ..lineTo(r.left + 8, r.top - 5)
        ..lineTo(r.right + 8, r.top - 5)
        ..lineTo(r.right, r.top)
        ..close();
      canvas.drawPath(roof, Paint()..color = color.withValues(alpha: .82));
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, const Radius.circular(2)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [color, color.withValues(alpha: .62)],
        ).createShader(r),
    );
    _windows(canvas, r);
    canvas.drawLine(
      Offset(r.left, r.top),
      Offset(r.right, r.top),
      Paint()
        ..color = const Color(0xFF9BC3D0).withValues(alpha: .65)
        ..strokeWidth = 1,
    );
  }

  void _windows(Canvas canvas, Rect r) {
    final p = Paint()..color = const Color(0xFFBCE8EA).withValues(alpha: .45);
    final columns = math.max(1, (r.width / 9).floor());
    final rows = math.max(1, (r.height / 9).floor());
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < columns; col++) {
        canvas.drawRect(
          Rect.fromLTWH(
            r.left + 4 + col * 9,
            r.top + 5 + row * 9,
            3.2,
            4.2,
          ),
          p,
        );
      }
    }
  }

  void _paintDepthScale(Canvas canvas, Size s) {
    final p = Paint()
      ..color = const Color(0xFFDFE8ED).withValues(alpha: .45)
      ..strokeWidth = 1;
    final x = s.width - 12;
    canvas.drawLine(Offset(x, s.height * .42), Offset(x, s.height * .94), p);
    for (var i = 0; i < 4; i++) {
      final y = s.height * (.45 + i * .15);
      canvas.drawLine(Offset(x - 4, y), Offset(x + 1, y), p);
    }
  }

  void _paintFlowParticles(Canvas canvas, Size s) {
    final colors = <String, Color>{
      'Water': _water,
      'Sewer': _sewer,
      'Stormwater': _drain,
      'Gas': _gas,
      'Electricity': _power,
      'Telecom': _telecom,
    };
    final baseY = view == 'ROAD SECTION' ? s.height * .54 : s.height * .63;
    var index = 0;
    for (final entry in colors.entries) {
      if (!visibleLayers.contains(entry.key)) continue;
      final x = ((flow + index * .17) % 1) * s.width;
      canvas.drawCircle(
        Offset(x, baseY + index * 3.2),
        1.7,
        Paint()..color = entry.value.withValues(alpha: .95),
      );
      index++;
    }
  }

  void _tag(Canvas canvas, String label, Offset at, Color color) {
    final text = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontSize: 6.5,
          fontWeight: FontWeight.w900,
          letterSpacing: .35,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: 100);
    final bounds = canvas.getLocalClipBounds();
    final left = at.dx.clamp(2.0, math.max(2.0, bounds.width - text.width - 4).toDouble()).toDouble();
    final top = at.dy.clamp(1.0, math.max(1.0, bounds.height - 10).toDouble()).toDouble();
    text.paint(canvas, Offset(left, top));
  }

  @override
  bool shouldRepaint(covariant _SamanvayTwinPainter oldDelegate) =>
      oldDelegate.view != view ||
      oldDelegate.visibleLayers != visibleLayers ||
      oldDelegate.flow != flow ||
      oldDelegate.is3D != is3D;
}

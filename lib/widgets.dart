import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'engine.dart';
import 'theme.dart';

/// Maglia disegnata con il colore della divisa e il numero.
class Jersey extends StatelessWidget {
  final Color color;
  final int number;
  final double width;

  const Jersey({super.key, required this.color, required this.number, this.width = 80});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: width * 0.9,
      child: CustomPaint(painter: _JerseyPainter(color, number)),
    );
  }
}

class _JerseyPainter extends CustomPainter {
  final Color color;
  final int number;
  _JerseyPainter(this.color, this.number);

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 100;
    final sy = size.height / 90;
    Offset p(double x, double y) => Offset(x * sx, y * sy);
    final path = Path()
      ..moveTo(p(32, 6).dx, p(32, 6).dy)
      ..lineTo(p(42, 2).dx, p(42, 2).dy)
      ..quadraticBezierTo(p(50, 11).dx, p(50, 11).dy, p(58, 2).dx, p(58, 2).dy)
      ..lineTo(p(68, 6).dx, p(68, 6).dy)
      ..lineTo(p(94, 20).dx, p(94, 20).dy)
      ..lineTo(p(84, 40).dx, p(84, 40).dy)
      ..lineTo(p(74, 35).dx, p(74, 35).dy)
      ..lineTo(p(74, 86).dx, p(74, 86).dy)
      ..lineTo(p(26, 86).dx, p(26, 86).dy)
      ..lineTo(p(26, 35).dx, p(26, 35).dy)
      ..lineTo(p(16, 40).dx, p(16, 40).dy)
      ..lineTo(p(6, 20).dx, p(6, 20).dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF0B0E12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, size.width / 50)
        ..strokeJoin = StrokeJoin.round,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: '$number',
        style: TextStyle(
          fontSize: size.height * 0.4,
          fontWeight: FontWeight.w800,
          color: isLight(color) ? C.bg : Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height * 0.62 - tp.height / 2));
  }

  @override
  bool shouldRepaint(_JerseyPainter old) => old.color != color || old.number != number;
}

/// Pulsante grande stile "tile".
class Tile extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color bg;
  final Color? border;
  final double borderWidth;
  final double radius;

  const Tile({
    super.key,
    required this.child,
    this.onTap,
    this.bg = C.surface2,
    this.border,
    this.borderWidth = 1,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: border ?? C.border, width: borderWidth),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Center(child: child)),
    );
  }
}

class ColorPickerRow extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const ColorPickerRow({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final c in jerseyPalette)
          Semantics(
            button: true,
            selected: c == value,
            child: InkWell(
              onTap: () => onChanged(c),
              customBorder: const CircleBorder(),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Color(c),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: c == value ? C.accent : C.border,
                    width: c == value ? 4 : 1,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Grafico dell'andamento del punteggio nel tempo, con timeout e cambi.
class ScoreChart extends StatelessWidget {
  final SetState st;
  final int durationSec;
  final Color usColor;
  const ScoreChart({super.key, required this.st, required this.durationSec, this.usColor = C.accent});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ChartPainter(st, durationSec, usColor),
      child: const SizedBox.expand(),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final SetState st;
  final int duration;
  final Color usColor;
  _ChartPainter(this.st, this.duration, this.usColor);

  void _text(Canvas c, String s, Offset o, {Color color = C.muted, double size = 10, bool right = false, bool bold = false, Color? bg}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontSize: size, color: color, fontWeight: bold ? FontWeight.w700 : FontWeight.w400),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    var dx = right ? o.dx - tp.width : o.dx;
    if (bg != null) {
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(dx - 3, o.dy - 1, tp.width + 6, tp.height + 2),
        const Radius.circular(3),
      );
      c.drawRRect(r, Paint()..color = bg);
    }
    tp.paint(c, Offset(dx, o.dy));
  }

  @override
  void paint(Canvas canvas, Size size) {
    const left = 26.0, right = 8.0, top = 18.0, bottom = 16.0;
    final w = size.width - left - right;
    final h = size.height - top - bottom;
    if (w <= 0 || h <= 0) return;

    final last = st.timeline.isEmpty ? 0 : st.timeline.last.t;
    final maxT = math.max(math.max(duration, last), 60).toDouble();
    final maxY = math.max(st.target, math.max(st.us, st.them)).toDouble();
    double x(int t) => left + w * (t / maxT);
    double y(int v) => top + h * (1 - v / maxY);

    final grid = Paint()
      ..color = C.line
      ..strokeWidth = 1;
    for (var v = 0; v <= maxY; v += 5) {
      canvas.drawLine(Offset(left, y(v)), Offset(left + w, y(v)), grid);
      _text(canvas, '$v', Offset(left - 4, y(v) - 6), right: true);
    }
    final stepMin = maxT > 40 * 60 ? 10 : 5;
    for (var mnt = 0; mnt * 60 <= maxT; mnt += stepMin) {
      _text(canvas, "$mnt'", Offset(x(mnt * 60) - 6, top + h + 3));
    }

    // marcatori timeout / cambi
    var row = 0;
    for (final mk in st.markers) {
      final color = mk.kind == 'T' ? C.timeout : C.sub;
      final mx = x(mk.t);
      final dash = Paint()
        ..color = color
        ..strokeWidth = 1.2;
      for (var yy = top; yy < top + h; yy += 7) {
        canvas.drawLine(Offset(mx, yy), Offset(mx, math.min(yy + 4, top + h)), dash);
      }
      _text(canvas, mk.label, Offset(mx + 3, row.isEven ? 0 : top + 2),
          color: C.bg, size: 9, bold: true, bg: color);
      row++;
    }

    Path line(int Function(ScorePoint) pick) {
      final path = Path();
      var first = true;
      var prev = 0;
      for (final pt in st.timeline) {
        final px = x(pt.t);
        if (first) {
          path.moveTo(px, y(pick(pt)));
          first = false;
        } else {
          path.lineTo(px, y(prev));
          path.lineTo(px, y(pick(pt)));
        }
        prev = pick(pt);
      }
      path.lineTo(x(math.max(duration, last)), y(prev));
      return path;
    }

    canvas.drawPath(
      line((p) => p.them),
      Paint()
        ..color = C.muted
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke,
    );
    canvas.drawPath(
      line((p) => p.us),
      Paint()
        ..color = usColor
        ..strokeWidth = 2.8
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_ChartPainter old) => true;
}

class Legend extends StatelessWidget {
  final Color color;
  final String text;
  final bool box;
  final String? letter;
  const Legend({super.key, required this.color, required this.text, this.box = false, this.letter});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      box
          ? Container(
              width: 14,
              height: 14,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
              child: Text(letter ?? '', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: C.bg)),
            )
          : Container(width: 16, height: 3, color: color),
      const SizedBox(width: 6),
      Text(text, style: const TextStyle(fontSize: 12, color: C.muted)),
    ]);
  }
}

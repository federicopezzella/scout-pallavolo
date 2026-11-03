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

/// Card con grafico a barre delle ultime partite (una barra per partita).
class TrendCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<double?> values;
  final List<String> labels;
  final bool percent;
  final bool signed;
  final Color color;

  const TrendCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.values,
    required this.labels,
    this.percent = true,
    this.signed = false,
    this.color = C.accent,
  });

  String fmt(double? v) {
    if (v == null) return '–';
    if (!percent) return v.round().toString();
    final p = (v * 100).round();
    return signed && p > 0 ? '+$p%' : '$p%';
  }

  @override
  Widget build(BuildContext context) {
    final valid = values.whereType<double>().toList();
    final last = values.isEmpty ? null : values.last;
    final avg = valid.isEmpty ? null : valid.reduce((a, b) => a + b) / valid.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: C.muted)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(fmt(last), style: cond(26, color: color)),
            Text('media ${fmt(avg)}', style: const TextStyle(fontSize: 11, color: C.muted)),
          ]),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          height: 130,
          child: CustomPaint(
            painter: _TrendPainter(values, labels, percent, signed, color, avg, fmt),
            child: const SizedBox.expand(),
          ),
        ),
      ]),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<double?> values;
  final List<String> labels;
  final bool percent;
  final bool signed;
  final Color color;
  final double? avg;
  final String Function(double?) fmt;
  _TrendPainter(this.values, this.labels, this.percent, this.signed, this.color, this.avg, this.fmt);

  TextPainter _tp(String s, {double size = 10, Color c = C.muted, bool bold = false}) => TextPainter(
        text: TextSpan(text: s, style: TextStyle(fontSize: size, color: c, fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      );

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const top = 16.0, bottom = 18.0;
    final h = size.height - top - bottom;
    final valid = values.whereType<double>();
    double maxV, minV;
    if (percent && !signed) {
      maxV = 1;
      minV = 0;
    } else if (signed) {
      final m = valid.isEmpty ? 0.25 : valid.map((v) => v.abs()).reduce(math.max);
      maxV = math.max(0.25, (m * 4).ceil() / 4);
      minV = valid.any((v) => v < 0) ? -maxV : 0;
    } else {
      final m = valid.isEmpty ? 1.0 : valid.reduce(math.max);
      maxV = math.max(4, m + 1).toDouble();
      minV = 0;
    }
    double y(double v) => top + h * (maxV - v) / (maxV - minV);

    final grid = Paint()
      ..color = C.line
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, y(maxV)), Offset(size.width, y(maxV)), grid);
    canvas.drawLine(Offset(0, y((maxV + minV) / 2)), Offset(size.width, y((maxV + minV) / 2)), grid);
    final zero = Paint()
      ..color = C.border
      ..strokeWidth = 1.4;
    canvas.drawLine(Offset(0, y(0)), Offset(size.width, y(0)), zero);

    // media tratteggiata
    final a = avg;
    if (a != null && values.length > 1) {
      final ay = y(a);
      final dash = Paint()
        ..color = C.muted.withValues(alpha: 0.7)
        ..strokeWidth = 1;
      for (var x = 0.0; x < size.width; x += 8) {
        canvas.drawLine(Offset(x, ay), Offset(math.min(x + 4, size.width), ay), dash);
      }
    }

    final slot = size.width / values.length;
    final barW = math.min(38.0, slot * 0.5);
    for (var i = 0; i < values.length; i++) {
      final cx = slot * i + slot / 2;
      final v = values[i];
      final isLast = i == values.length - 1;
      if (v != null) {
        final y0 = y(0), y1 = y(v);
        final rect = Rect.fromLTRB(cx - barW / 2, math.min(y0, y1), cx + barW / 2, math.max(y0, y1) + (v == 0 ? 2 : 0));
        final base = v < 0 ? const Color(0xFFE5695A) : color;
        final paint = Paint()..color = isLast ? base : base.withValues(alpha: 0.55);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), paint);
        final vt = _tp(fmt(v), size: 11, c: isLast ? C.text : C.muted, bold: isLast)..layout();
        final ly = v >= 0 ? rect.top - vt.height - 2 : rect.bottom + 2;
        vt.paint(canvas, Offset(cx - vt.width / 2, ly));
      } else {
        final nt = _tp('n.d.', size: 10)..layout();
        nt.paint(canvas, Offset(cx - nt.width / 2, y(0) - nt.height - 2));
      }
      final lt = _tp(labels[i], size: 10, c: isLast ? C.text : C.muted)..layout(maxWidth: slot - 4);
      lt.paint(canvas, Offset(cx - lt.width / 2, size.height - lt.height));
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) => true;
}

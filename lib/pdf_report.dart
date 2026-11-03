import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'analytics.dart';
import 'models.dart';

// ------------------------------------------------------------------ palette

PdfColor _c(int argb) => PdfColor.fromInt(argb);

final _ink = _c(0xFF141A22);
final _muted = _c(0xFF5A6675);
final _faint = _c(0xFFA7B1BD);
final _line = _c(0xFFE1E5EA);
final _zebra = _c(0xFFF5F7F9);
final _track = _c(0xFFECEFF3);
final _accent = _c(0xFFE07B1F);
final _good = _c(0xFF1E7A57);
final _bad = _c(0xFFC0392B);
final _band = _c(0xFF141A22);

final _gradeColors = <String, PdfColor>{
  '#': _c(0xFF2F8F6B),
  '+': _c(0xFF5BAE8C),
  '!': _c(0xFF6B7889),
  '-': _c(0xFFB88A3E),
  '/': _c(0xFFC9692B),
  '=': _c(0xFFB23A2E),
};

String _date(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year}';
}

String reportFileName(MatchData m) {
  final d = DateTime.fromMillisecondsSinceEpoch(m.date);
  String two(int v) => v.toString().padLeft(2, '0');
  String clean(String s) => s.trim().replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
  return 'Report_${clean(m.teamName)}_vs_${clean(m.opponent)}_${d.year}-${two(d.month)}-${two(d.day)}.pdf';
}

// ------------------------------------------------------------------ report

Future<Uint8List> buildMatchPdf(MatchData m) async {
  final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Regular.ttf'));
  final semi = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-SemiBold.ttf'));
  final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Bold.ttf'));
  final r = MatchReport.of(m);
  final b = _Builder(r, semi);

  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
    title: '${m.teamName} vs ${m.opponent}',
    author: 'Scout Volley',
  );

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(30, 28, 30, 34),
    footer: b.footer,
    build: (ctx) => [
      b.header(),
      pw.SizedBox(height: 14),
      b.leaders(),
      pw.SizedBox(height: 14),
      b.pointsLine(),
      pw.SizedBox(height: 18),
      b.sectionTitle('Valutazioni per fondamentale', 'Squadra'),
      pw.SizedBox(height: 6),
      b.gradeTable(r.team),
      pw.SizedBox(height: 18),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(child: b.chartBox('Positività per fondamentale', b.positivityChart(r.team))),
        pw.SizedBox(width: 14),
        pw.Expanded(child: b.chartBox('Efficienza per fondamentale', b.efficiencyChart(r.team))),
      ]),
      pw.SizedBox(height: 10),
      b.legend(),
      if (r.players.isNotEmpty) ...[
        pw.NewPage(),
        b.sectionTitle('Giocatori', 'ordinati per punti'),
        pw.SizedBox(height: 8),
        for (final p in r.players) ...[
          b.playerBlock(p),
          pw.SizedBox(height: 16),
        ],
      ],
    ],
  ));
  return doc.save();
}

class _Builder {
  final MatchReport r;
  final pw.Font semi;
  _Builder(this.r, this.semi);

  MatchData get m => r.match;

  pw.TextStyle _t(double size, {PdfColor? color, bool bold = false, bool medium = false}) => pw.TextStyle(
        fontSize: size,
        color: color ?? _ink,
        font: medium && !bold ? semi : null,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      );

  // ---------------------------------------------------------------- header

  pw.Widget header() {
    final won = r.summary.setsUs > r.summary.setsThem;
    final place = m.home ? 'in casa' : 'in trasferta';
    final sub = [
      _date(m.date),
      if (m.competition.isNotEmpty) m.competition,
      place,
    ].join('  ·  ');
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      pw.Container(
        padding: const pw.EdgeInsets.fromLTRB(18, 14, 18, 14),
        decoration: pw.BoxDecoration(color: _band, borderRadius: pw.BorderRadius.circular(8)),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('REPORT PARTITA', style: _t(7.5, color: _accent, bold: true).copyWith(letterSpacing: 1.4)),
              pw.SizedBox(height: 4),
              pw.Text('${m.teamName}  vs  ${m.opponent}', style: _t(17, color: PdfColors.white, bold: true)),
              pw.SizedBox(height: 3),
              pw.Text(sub, style: _t(8.5, color: _faint)),
            ]),
          ),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('${r.summary.setsUs} – ${r.summary.setsThem}', style: _t(28, color: PdfColors.white, bold: true)),
            pw.SizedBox(height: 4),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: pw.BoxDecoration(color: won ? _good : _bad, borderRadius: pw.BorderRadius.circular(4)),
              child: pw.Text(won ? 'VINTA' : 'PERSA', style: _t(7.5, color: PdfColors.white, bold: true)),
            ),
          ]),
        ]),
      ),
      pw.SizedBox(height: 8),
      pw.Wrap(spacing: 6, runSpacing: 6, children: [
        for (var i = 0; i < r.summary.sets.length; i++) _setChip(i),
      ]),
    ]);
  }

  pw.Widget _setChip(int i) {
    final st = r.summary.sets[i];
    final s = m.sets[i];
    final won = st.us > st.them;
    final dur = s.elapsedSec();
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: won ? _good : _line, width: won ? 1 : 0.8),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
        pw.Text('Set ${i + 1}  ', style: _t(8, color: _muted)),
        pw.Text('${st.us}–${st.them}', style: _t(9, bold: true)),
        if (dur > 0) pw.Text('  ${dur ~/ 60}\'', style: _t(8, color: _muted)),
        pw.Text('   TO ${st.timeoutsUs}/${st.timeoutsThem} · C ${st.subsUsed}', style: _t(7, color: _faint)),
      ]),
    );
  }

  // --------------------------------------------------------------- leaders

  pw.Widget leaders() {
    pw.Widget card(String label, Leader? l, String unit) {
      return pw.Expanded(
        child: pw.Container(
          height: 74,
          decoration: pw.BoxDecoration(color: _zebra, borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
            pw.Container(width: 3, color: _accent),
            pw.Expanded(
              child: pw.Padding(
                padding: const pw.EdgeInsets.fromLTRB(9, 8, 8, 8),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(label, style: _t(7, color: _muted, bold: true).copyWith(letterSpacing: 1)),
            pw.SizedBox(height: 4),
            if (l == null)
              pw.Text('–', style: _t(16, color: _faint, bold: true))
            else ...[
              pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text('${l.value}', style: _t(18, bold: true)),
                pw.SizedBox(width: 4),
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 2.5),
                  child: pw.Text(l.value == 1 ? unit.split('|').first : unit.split('|').last, style: _t(8, color: _muted)),
                ),
              ]),
              pw.SizedBox(height: 2),
              pw.Text('#${l.player.number} ${l.player.name}', style: _t(9, medium: true), maxLines: 1),
              pw.Text(l.detail, style: _t(6.8, color: _muted), maxLines: 1),
            ],
                ]),
              ),
            ),
          ]),
        ),
      );
    }

    return pw.Row(children: [
      card('TOP SCORER', r.topScorer, 'punto|punti'),
      pw.SizedBox(width: 8),
      card('BATTUTA', r.topServer, 'ace|ace'),
      pw.SizedBox(width: 8),
      card('MURO', r.topBlocker, 'muro punto|muri punto'),
      pw.SizedBox(width: 8),
      card('ATTACCO', r.topAttacker, 'punto|punti'),
    ]);
  }

  pw.Widget pointsLine() {
    final t = r.team;
    final att = t['Attacco']!.n('#'), mur = t['Muro']!.n('#'), ace = t['Battuta']!.n('#');
    final total = att + mur + ace + r.opponentErrors;
    pw.Widget item(String label, int v, PdfColor color) => pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
          pw.Container(width: 7, height: 7, decoration: pw.BoxDecoration(color: color, borderRadius: pw.BorderRadius.circular(2))),
          pw.SizedBox(width: 4),
          pw.Text('$label ', style: _t(8, color: _muted)),
          pw.Text('$v', style: _t(8.5, bold: true)),
        ]);
    // barra di composizione dei punti
    final parts = <(int, PdfColor)>[
      (att, _c(0xFFE07B1F)),
      (mur, _c(0xFF2F6FB8)),
      (ace, _c(0xFF2F8F6B)),
      (r.opponentErrors, _c(0xFFA7B1BD)),
    ];
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      pw.Row(children: [
        pw.Text('Punti fatti: ', style: _t(9, color: _muted)),
        pw.Text('$total', style: _t(10, bold: true)),
        pw.Spacer(),
        item('Attacco', att, parts[0].$2),
        pw.SizedBox(width: 10),
        item('Muro', mur, parts[1].$2),
        pw.SizedBox(width: 10),
        item('Ace', ace, parts[2].$2),
        pw.SizedBox(width: 10),
        item('Errori avversari', r.opponentErrors, parts[3].$2),
      ]),
      pw.SizedBox(height: 5),
      pw.Container(
        height: 8,
        decoration: pw.BoxDecoration(color: _track, borderRadius: pw.BorderRadius.circular(2)),
        child: total == 0
            ? pw.SizedBox()
            : pw.Row(children: [
                for (final p in parts)
                  if (p.$1 > 0) pw.Expanded(flex: p.$1, child: pw.Container(color: p.$2)),
              ]),
      ),
    ]);
  }

  // ----------------------------------------------------------------- table

  pw.Widget sectionTitle(String title, String note) => pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        pw.Text(title, style: _t(13, bold: true)),
        pw.SizedBox(width: 8),
        pw.Padding(padding: const pw.EdgeInsets.only(bottom: 1.5), child: pw.Text(note, style: _t(8.5, color: _muted))),
      ]);

  pw.Widget _cell(String text, {pw.TextStyle? style, PdfColor? bg, pw.Alignment align = pw.Alignment.center, double h = 17}) =>
      pw.Container(
        height: h,
        color: bg,
        alignment: align,
        padding: const pw.EdgeInsets.symmetric(horizontal: 5),
        child: pw.Text(text, style: style ?? _t(8.5)),
      );

  pw.Widget gradeTable(SkillTable t, {bool compact = false}) {
    final h = compact ? 15.0 : 17.0;
    final header = pw.TableRow(children: [
      pw.Container(
        height: 26,
        alignment: pw.Alignment.centerLeft,
        padding: const pw.EdgeInsets.symmetric(horizontal: 6),
        color: _band,
        child: pw.Text('Fondamentale', style: _t(7.5, color: PdfColors.white, bold: true)),
      ),
      for (final g in grades)
        pw.Container(
          height: 26,
          color: _gradeColors[g],
          alignment: pw.Alignment.center,
          child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
            pw.Text(g == '#' ? '# (++)' : g, style: _t(9, color: PdfColors.white, bold: true)),
            pw.Text(gradeShortLabels[g]!, style: _t(5.5, color: PdfColors.white)),
          ]),
        ),
      for (final label in ['Tot', 'Pos %', 'Eff %'])
        pw.Container(
          height: 26,
          color: _band,
          alignment: pw.Alignment.center,
          child: pw.Text(label, style: _t(7.5, color: PdfColors.white, bold: true)),
        ),
    ]);

    final rows = <pw.TableRow>[header];
    var i = 0;
    for (final s in reportSkills) {
      final l = t[s]!;
      final bg = i.isOdd ? _zebra : null;
      final eff = l.efficiency;
      rows.add(pw.TableRow(children: [
        pw.Container(
          height: h,
          color: bg,
          alignment: pw.Alignment.centerLeft,
          padding: const pw.EdgeInsets.symmetric(horizontal: 6),
          child: pw.Row(children: [
            pw.SizedBox(width: 24, child: pw.Text(skillShort[s]!, style: _t(8.5, bold: true))),
            pw.Text(s, style: _t(7.5, color: _muted)),
          ]),
        ),
        for (final g in grades)
          _cell(l.n(g) == 0 ? '0' : '${l.n(g)}', bg: bg, h: h, style: _t(8.5, color: l.n(g) == 0 ? _faint : _ink, medium: l.n(g) > 0)),
        _cell('${l.total}', bg: bg, h: h, style: _t(8.5, bold: true, color: l.total == 0 ? _faint : _ink)),
        _cell(fmtPct(l.positivity), bg: bg, h: h, style: _t(8.5, medium: true, color: l.hasData ? _ink : _faint)),
        _cell(fmtPct(eff, sign: true), bg: bg, h: h,
            style: _t(8.5, bold: true, color: eff == null ? _faint : (eff >= 0 ? _good : _bad))),
      ]));
      i++;
    }
    return pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(2.4),
        for (var c = 1; c <= 6; c++) c: const pw.FlexColumnWidth(1),
        7: const pw.FlexColumnWidth(0.9),
        8: const pw.FlexColumnWidth(1.1),
        9: const pw.FlexColumnWidth(1.1),
      },
      border: pw.TableBorder(
        bottom: pw.BorderSide(color: _line, width: 0.8),
        horizontalInside: pw.BorderSide(color: _line, width: 0.5),
      ),
      children: rows,
    );
  }

  // ---------------------------------------------------------------- charts

  pw.Widget chartBox(String title, pw.Widget chart) => pw.Container(
        padding: const pw.EdgeInsets.fromLTRB(10, 9, 10, 8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _line, width: 0.8),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          pw.Text(title, style: _t(8.5, bold: true)),
          pw.SizedBox(height: 7),
          chart,
        ]),
      );

  pw.Widget _scale(List<String> labels) => pw.Row(children: [
        pw.SizedBox(width: 26),
        pw.Expanded(
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [for (final l in labels) pw.Text(l, style: _t(5.8, color: _faint))],
          ),
        ),
        pw.SizedBox(width: 30),
      ]);

  pw.Widget positivityChart(SkillTable t, {double barH = 9}) {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      for (final s in reportSkills)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Row(children: [
            pw.SizedBox(width: 26, child: pw.Text(skillShort[s]!, style: _t(7.5, medium: true))),
            pw.Expanded(child: _posBar(t[s]!.positivity, barH)),
            pw.SizedBox(
              width: 30,
              child: pw.Text(fmtPct(t[s]!.positivity),
                  textAlign: pw.TextAlign.right, style: _t(7.5, bold: true, color: t[s]!.hasData ? _ink : _faint)),
            ),
          ]),
        ),
      _scale(['0', '25', '50', '75', '100%']),
    ]);
  }

  pw.Widget _posBar(double? v, double h) {
    final p = v == null ? 0 : (v * 100).round().clamp(0, 100);
    return pw.Container(
      height: h,
      decoration: pw.BoxDecoration(color: _track, borderRadius: pw.BorderRadius.circular(2)),
      child: pw.Row(children: [
        if (p > 0)
          pw.Expanded(
            flex: p,
            child: pw.Container(decoration: pw.BoxDecoration(color: _accent, borderRadius: pw.BorderRadius.circular(2))),
          ),
        if (p < 100) pw.Expanded(flex: 100 - p, child: pw.SizedBox()),
      ]),
    );
  }

  pw.Widget efficiencyChart(SkillTable t, {double barH = 9}) {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      for (final s in reportSkills)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Row(children: [
            pw.SizedBox(width: 26, child: pw.Text(skillShort[s]!, style: _t(7.5, medium: true))),
            pw.Expanded(child: _effBar(t[s]!.efficiency, barH)),
            pw.SizedBox(
              width: 30,
              child: pw.Text(fmtPct(t[s]!.efficiency, sign: true),
                  textAlign: pw.TextAlign.right,
                  style: _t(7.5, bold: true, color: t[s]!.efficiency == null ? _faint : (t[s]!.efficiency! >= 0 ? _good : _bad))),
            ),
          ]),
        ),
      _scale(['-100', '-50', '0', '+50', '+100%']),
    ]);
  }

  pw.Widget _effBar(double? v, double h) {
    final p = v == null ? 0 : (v * 100).round().clamp(-100, 100);
    final neg = p < 0 ? -p : 0;
    final pos = p > 0 ? p : 0;
    return pw.Container(
      height: h,
      decoration: pw.BoxDecoration(color: _track, borderRadius: pw.BorderRadius.circular(2)),
      child: pw.Row(children: [
        pw.Expanded(
          child: pw.Row(children: [
            if (neg < 100) pw.Expanded(flex: 100 - neg, child: pw.SizedBox()),
            if (neg > 0) pw.Expanded(flex: neg, child: pw.Container(color: _bad)),
          ]),
        ),
        pw.Container(width: 0.8, color: _muted),
        pw.Expanded(
          child: pw.Row(children: [
            if (pos > 0) pw.Expanded(flex: pos, child: pw.Container(color: _good)),
            if (pos < 100) pw.Expanded(flex: 100 - pos, child: pw.SizedBox()),
          ]),
        ),
      ]),
    );
  }

  pw.Widget legend() {
    pw.Widget item(String k, String v) => pw.SizedBox(
          width: 170,
          child: pw.Row(children: [
            pw.SizedBox(width: 62, child: pw.Text(k, style: _t(6.8, bold: true, color: _muted))),
            pw.Text(v, style: _t(6.8, color: _muted)),
          ]),
        );
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(10, 7, 10, 7),
      decoration: pw.BoxDecoration(color: _zebra, borderRadius: pw.BorderRadius.circular(6)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('Come si calcola', style: _t(7.5, bold: true)),
        pw.SizedBox(height: 4),
        pw.Wrap(spacing: 8, runSpacing: 3, children: [
          item('Positività', '(# + +) / totale'),
          for (final s in reportSkills) item('Eff. ${s.toLowerCase()}', efficiencyNotes[s]!),
        ]),
      ]),
    );
  }

  // --------------------------------------------------------------- players

  pw.Widget playerBlock(PlayerReport p) {
    final jersey = _c(m.jerseyColor);
    final light = jersey.luminance > 0.5;
    // Container: il blocco non si spezza tra due pagine
    return pw.Container(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 6),
        decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _ink, width: 1.2))),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
          pw.Container(
            width: 24,
            height: 24,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              color: jersey,
              borderRadius: pw.BorderRadius.circular(5),
              border: light ? pw.Border.all(color: _line) : null,
            ),
            child: pw.Text('${p.player.number}', style: _t(10, bold: true, color: light ? _ink : PdfColors.white)),
          ),
          pw.SizedBox(width: 8),
          pw.Text(p.player.name, style: _t(12, bold: true)),
          pw.SizedBox(width: 8),
          pw.Text(p.player.rolesLabel, style: _t(8, color: _muted)),
          pw.Spacer(),
          _stat('Punti', p.points, bold: true),
          _stat('Attacco', p.attackPoints),
          _stat('Muro', p.blockPoints),
          _stat('Ace', p.aces),
          _stat('Errori', p.errors, color: p.errors > 0 ? _bad : null),
        ]),
      ),
      pw.SizedBox(height: 6),
      gradeTable(p.table, compact: true),
      pw.SizedBox(height: 8),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(child: chartBox('Positività', positivityChart(p.table, barH: 7))),
        pw.SizedBox(width: 12),
        pw.Expanded(child: chartBox('Efficienza', efficiencyChart(p.table, barH: 7))),
      ]),
    ]));
  }

  pw.Widget _stat(String label, int v, {bool bold = false, PdfColor? color}) => pw.Padding(
        padding: const pw.EdgeInsets.only(left: 12),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text('$v', style: _t(bold ? 13 : 11, bold: true, color: color)),
          pw.Text(label, style: _t(6.5, color: _muted)),
        ]),
      );

  // ---------------------------------------------------------------- footer

  pw.Widget footer(pw.Context ctx) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 8),
        child: pw.Row(children: [
          pw.Text('Scout Volley  ·  ${m.teamName} vs ${m.opponent}  ·  ${_date(m.date)}', style: _t(7, color: _faint)),
          pw.Spacer(),
          pw.Text('Pagina ${ctx.pageNumber} di ${ctx.pagesCount}', style: _t(7, color: _faint)),
        ]),
      );
}

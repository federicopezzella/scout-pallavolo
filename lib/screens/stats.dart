import 'package:flutter/material.dart';

import 'package:printing/printing.dart';

import '../engine.dart';
import '../models.dart';
import '../pdf_report.dart';
import '../theme.dart';
import '../widgets.dart';

class StatsScreen extends StatefulWidget {
  final MatchData match;
  const StatsScreen({super.key, required this.match});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  int? _set; // null = tutta la partita
  bool _making = false;

  Future<void> _pdf(BuildContext btnContext) async {
    setState(() => _making = true);
    try {
      final bytes = await buildMatchPdf(m);
      final box = btnContext.findRenderObject() as RenderBox?;
      final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
      await Printing.sharePdf(bytes: bytes, filename: reportFileName(m), bounds: origin);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF non creato: $e')));
      }
    } finally {
      if (mounted) setState(() => _making = false);
    }
  }

  MatchData get m => widget.match;

  String _pct(int a, int tot) => tot == 0 ? '–' : '${(a * 100 / tot).round()}%';

  @override
  Widget build(BuildContext context) {
    final sum = summarize(m);
    final stats = computeStats(m, setIndex: _set);
    final players = m.players.where((p) => stats.containsKey(p.id)).toList();

    int g(Map<String, int>? x, String k) => x?[k] ?? 0;
    int tot(Map<String, int>? x) => x == null ? 0 : x.values.fold(0, (a, b) => a + b);

    Widget cell(String text, {bool bold = false, Color? color, TextAlign align = TextAlign.center}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Text(text,
              textAlign: align,
              style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w400, color: color ?? C.text, fontSize: 14)),
        );

    String skillCell(Map<String, int>? x) {
      final t = tot(x);
      if (t == 0) return '–';
      return '$t  ·  #${g(x, '#')}  =${g(x, '=')}';
    }

    final rows = <TableRow>[
      TableRow(
        decoration: const BoxDecoration(color: C.surface2),
        children: [
          cell('Giocatore', bold: true, align: TextAlign.left),
          for (final sk in skills) cell(sk, bold: true),
          cell('Pos. ricez.', bold: true),
          cell('Eff. attacco', bold: true),
        ],
      ),
    ];
    for (final p in players) {
      final ps = stats[p.id]!;
      final rec = ps['Ricezione'];
      final att = ps['Attacco'];
      final attTot = tot(att);
      final eff = attTot == 0
          ? '–'
          : '${((g(att, '#') - g(att, '=') - g(att, '/')) * 100 / attTot).round()}%';
      rows.add(TableRow(
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.line))),
        children: [
          cell('#${p.number} ${p.name}', bold: true, align: TextAlign.left),
          for (final sk in skills) cell(skillCell(ps[sk])),
          cell(_pct(g(rec, '#') + g(rec, '+'), tot(rec))),
          cell(eff, color: C.accent, bold: true),
        ],
      ));
    }

    final selected = _set;
    return Scaffold(
      appBar: AppBar(
        title: Text('Statistiche · vs ${m.opponent} · ${sum.setsUs}-${sum.setsThem}', overflow: TextOverflow.ellipsis),
        actions: [
          Builder(
            builder: (btnContext) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                onPressed: _making ? null : () => _pdf(btnContext),
                icon: _making
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.picture_as_pdf),
                label: const Text('Report PDF'),
              ),
            ),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          ChoiceChip(label: const Text('Partita'), selected: _set == null, onSelected: (_) => setState(() => _set = null)),
          for (var i = 0; i < m.sets.length; i++)
            ChoiceChip(
              label: Text('Set ${i + 1}  ${sum.sets[i].us}-${sum.sets[i].them}  (${fmtMin(m.sets[i].elapsedSec())})'),
              selected: _set == i,
              onSelected: (_) => setState(() => _set = i),
            ),
        ]),
        const SizedBox(height: 16),
        if (selected != null) ...[
          SizedBox(
            height: 200,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.line)),
              child: ScoreChart(st: sum.sets[selected], durationSec: m.sets[selected].elapsedSec()),
            ),
          ),
          const SizedBox(height: 12),
          if (sum.sets[selected].eventsLog.isNotEmpty)
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final ev in sum.sets[selected].eventsLog)
                Chip(label: Text('${fmtMin(ev.t)} ${ev.text}')),
            ]),
          const SizedBox(height: 16),
        ],
        const Text('Celle: totale · punti (#) · errori (=)', style: TextStyle(color: C.muted, fontSize: 12)),
        const SizedBox(height: 8),
        players.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Nessuna azione registrata', style: TextStyle(color: C.muted)),
              )
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Container(
                width: MediaQuery.sizeOf(context).width - 40 < 1000 ? 1000.0 : MediaQuery.sizeOf(context).width - 40,
                decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.line)),
                clipBehavior: Clip.antiAlias,
                child: Table(
                  columnWidths: const {0: FlexColumnWidth(1.6)},
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: rows,
                ),
              ),
              ),
      ]),
    );
  }
}

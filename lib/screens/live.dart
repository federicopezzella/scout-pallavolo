import 'dart:async';

import 'package:flutter/material.dart';

import '../engine.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'lineup.dart';
import 'stats.dart';

/// Schermata di inserimento live durante il set.
class LiveScreen extends StatefulWidget {
  final MatchData match;
  const LiveScreen({super.key, required this.match});

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  String? _player;
  String? _skill;
  Timer? _ticker;

  MatchData get m => widget.match;
  SetData get s => m.sets.last;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && s.running) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _add(String type, {String? playerId, String? skill, String? grade, String? team, String? outId, String? inId}) {
    final before = replaySet(m, s);
    final scoring = type == 'action' || type == 'pointUs' || type == 'pointThem';
    if (before.finished && scoring) return;
    s.start();
    s.events.add(GameEvent(
      type: type,
      t: s.elapsedSec(),
      playerId: playerId,
      skill: skill,
      grade: grade,
      team: team,
      outId: outId,
      inId: inId,
    ));
    final after = replaySet(m, s);
    if (after.finished) s.pause();
    store.save();
    setState(() {
      _player = null;
      _skill = null;
    });
  }

  void _undo() {
    if (s.events.isEmpty) return;
    s.events.removeLast();
    store.save();
    setState(() {});
  }

  void _toggleClock() {
    if (s.running) {
      s.pause();
    } else {
      s.start();
    }
    store.save();
    setState(() {});
  }

  Color _jerseyColor(String id) => Color(id == s.liberoId ? m.liberoColor : m.jerseyColor);

  // ---------------------------------------------------------------- dialoghi

  Future<void> _subsDialog(SetState st) async {
    String? out;
    String? inn;
    final onCourt = st.court.where((id) => id != s.liberoId).toList();
    final bench = benchPlayers(m, s, st);
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) {
        final err = (out != null && inn != null) ? canSub(m, s, st, out!, inn!) : null;
        Widget row(Player p, bool selected, String note, VoidCallback onTap, {bool dim = false}) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              height: 52,
              child: Tile(
                onTap: onTap,
                border: selected ? C.accent : C.border,
                borderWidth: selected ? 3 : 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(children: [
                    Jersey(color: _jerseyColor(p.id), number: p.number, width: 40),
                    const SizedBox(width: 10),
                    Text(p.name, style: TextStyle(fontWeight: FontWeight.w600, color: dim ? C.muted : C.text)),
                    const Spacer(),
                    Text(note, style: const TextStyle(fontSize: 12, color: C.muted)),
                  ]),
                ),
              ),
            ),
          );
        }

        String courtNote(String id) {
          final starter = st.subOf[id];
          if (starter != null) return 'esce solo per ${m.nr(starter)}';
          if (st.reEnteredStarters.contains(id)) return 'non può più uscire';
          return 'pos ${st.court.indexOf(id) + 1}';
        }

        String benchNote(String id) {
          if (st.exitedSubs.contains(id)) return 'non può rientrare';
          final sub = st.starterReplacedBy[id];
          if (sub != null) return 'solo per ${m.nr(sub)}';
          return 'disponibile';
        }

        return AlertDialog(
          title: Text('Cambio · Set ${s.number} · ${fmtClock(s.elapsedSec())} · ${st.us}-${st.them} · usati ${st.subsUsed}/6'),
          content: SizedBox(
            width: 680,
            height: 400,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text('ESCE (IN CAMPO)', style: labelStyle),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(children: [
                      for (final id in onCourt)
                        if (m.player(id) != null)
                          row(m.player(id)!, out == id, courtNote(id), () => setD(() => out = id),
                              dim: st.reEnteredStarters.contains(id)),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text('ENTRA (PANCHINA)', style: labelStyle),
                  const SizedBox(height: 8),
                  Expanded(
                    child: bench.isEmpty
                        ? const Text('Nessun giocatore in panchina', style: TextStyle(color: C.muted))
                        : ListView(children: [
                            for (final p in bench)
                              row(p, inn == p.id, benchNote(p.id), () => setD(() => inn = p.id),
                                  dim: st.exitedSubs.contains(p.id)),
                          ]),
                  ),
                ]),
              ),
            ]),
          ),
          actions: [
            if (err != null)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(err, style: const TextStyle(color: Color(0xFFFF8A80))),
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
            FilledButton(
              onPressed: (out != null && inn != null && err == null)
                  ? () {
                      Navigator.pop(ctx);
                      _add('sub', outId: out, inId: inn);
                    }
                  : null,
              child: Text(out != null && inn != null ? 'Conferma: ${m.nr(inn)} per ${m.nr(out)}' : 'Conferma'),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _liberoDialog(SetState st) async {
    if (s.liberoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nessun libero in formazione per questo set')));
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        if (st.liberoOnCourt) {
          return AlertDialog(
            title: Text('Libero in campo per ${m.nr(st.liberoReplaced)}'),
            content: const Text('Gli ingressi del libero non contano come cambi.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Chiudi')),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _add('liberoOut');
                },
                child: Text('Fai uscire il libero (rientra ${m.nr(st.liberoReplaced)})'),
              ),
            ],
          );
        }
        final options = st.court.where((id) => canLiberoIn(s, st, id) == null).toList();
        return AlertDialog(
          title: const Text('Il libero entra al posto di…'),
          content: SizedBox(
            width: 420,
            child: options.isEmpty
                ? const Text('Nessun giocatore di seconda linea sostituibile ora.')
                : Wrap(spacing: 10, runSpacing: 10, children: [
                    for (final id in options)
                      ActionChip(
                        label: Text('${m.nr(id)} ${m.player(id)?.name ?? ''} · pos ${st.court.indexOf(id) + 1}'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _add('liberoIn', outId: id);
                        },
                      ),
                  ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla'))],
        );
      },
    );
  }

  Future<void> _endMatch() async {
    s.pause();
    m.finished = true;
    await store.save();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => StatsScreen(match: m)));
  }

  void _nextSet() {
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => LineupScreen(match: m)));
  }

  Future<void> _confirmEndEarly() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chiudere la partita adesso?'),
        content: const Text('Utile per amichevoli o partite interrotte. I dati restano salvati.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Chiudi partita')),
        ],
      ),
    );
    if (ok == true) await _endMatch();
  }

  // ------------------------------------------------------------------ layout

  @override
  Widget build(BuildContext context) {
    final st = replaySet(m, s);
    final sum = summarize(m);
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          _header(st, sum),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(flex: 36, child: _courtPanel(st)),
                const SizedBox(width: 12),
                Expanded(flex: 40, child: _actionPanel(st)),
                const SizedBox(width: 12),
                Expanded(flex: 24, child: _sidePanel(st)),
              ]),
            ),
          ),
          if (st.finished) _setEndBar(st, sum),
          SizedBox(
            height: 150,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: _chartPanel(st),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _header(SetState st, MatchSummary sum) {
    Widget btn(String text, VoidCallback? onTap, {IconData? icon}) => Padding(
          padding: const EdgeInsets.only(left: 8),
          child: SizedBox(
            height: 46,
            child: OutlinedButton.icon(
              onPressed: onTap,
              icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 20),
              label: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: C.text,
                side: const BorderSide(color: C.border),
                backgroundColor: C.surface2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        );
    final setsUsBefore = sum.setsUs - (st.finished && st.weWon ? 1 : 0);
    final setsThemBefore = sum.setsThem - (st.finished && !st.weWon ? 1 : 0);
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(color: C.surface, border: Border(bottom: BorderSide(color: C.line))),
      child: Row(children: [
        IconButton(
          tooltip: 'Partite',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        Expanded(
          child: Text('${m.teamName}  vs  ${m.opponent}',
              overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ),
        Row(children: [
          if (st.weServe) Container(width: 10, height: 10, decoration: const BoxDecoration(color: C.accent, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text('${st.us}', style: cond(44)),
          const SizedBox(width: 16),
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('SET ${s.number}', style: labelStyle),
            const SizedBox(height: 2),
            Text('$setsUsBefore – $setsThemBefore', style: cond(17, weight: FontWeight.w600)),
          ]),
          const SizedBox(width: 16),
          Text('${st.them}', style: cond(44, color: const Color(0xFFC4CFDA))),
          const SizedBox(width: 8),
          if (!st.weServe) Container(width: 10, height: 10, decoration: const BoxDecoration(color: C.muted, shape: BoxShape.circle)),
        ]),
        Expanded(
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Container(
              height: 46,
              padding: const EdgeInsets.only(left: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0B0E12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: C.border),
              ),
              child: Row(children: [
                const Icon(Icons.timer_outlined, size: 18, color: C.muted),
                const SizedBox(width: 6),
                Text(fmtClock(s.elapsedSec()), style: cond(24)),
                IconButton(
                  tooltip: s.running ? 'Pausa cronometro' : 'Avvia cronometro',
                  icon: Icon(s.running ? Icons.pause : Icons.play_arrow),
                  onPressed: st.finished ? null : _toggleClock,
                ),
              ]),
            ),
            btn('TO noi ${st.timeoutsUs}/2', st.timeoutsUs < 2 && !st.finished ? () => _add('timeout', team: 'us') : null),
            btn('TO avv ${st.timeoutsThem}/2', st.timeoutsThem < 2 && !st.finished ? () => _add('timeout', team: 'them') : null),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: IconButton.outlined(
                tooltip: 'Annulla ultima azione',
                onPressed: s.events.isEmpty ? null : _undo,
                icon: const Icon(Icons.undo),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Altro',
              onSelected: (v) {
                if (v == 'stats') {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => StatsScreen(match: m)));
                } else if (v == 'end') {
                  _confirmEndEarly();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'stats', child: Text('Statistiche')),
                PopupMenuItem(value: 'end', child: Text('Chiudi partita')),
              ],
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _courtPanel(SetState st) {
    final setterIdx = st.court.indexWhere((id) => m.player(id)?.role == 'P');
    const order = [3, 2, 1, 4, 5, 0]; // 4 3 2 / 5 6 1
    Widget tile(int idx) {
      final id = st.court[idx];
      final p = m.player(id);
      final sel = _player == id;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Tile(
            bg: sel ? const Color(0xFF2C4A40) : C.courtTile,
            border: sel ? C.accent : Colors.transparent,
            borderWidth: sel ? 3 : 1,
            radius: 14,
            onTap: st.finished ? null : () => setState(() => _player = sel ? null : id),
            child: Stack(children: [
              Center(
                child: LayoutBuilder(builder: (ctx, c) {
                  final byW = c.maxWidth * 0.62;
                  final byH = c.maxHeight.isFinite ? (c.maxHeight - 40) / 0.9 : byW;
                  final w = (byW < byH ? byW : byH).clamp(28.0, 96.0);
                  return Column(mainAxisSize: MainAxisSize.min, children: [
                    Jersey(color: _jerseyColor(id), number: p?.number ?? 0, width: w),
                    const SizedBox(height: 2),
                    Text(p?.name ?? '?', overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('${p?.role ?? ''} · pos ${idx + 1}', style: const TextStyle(fontSize: 11, color: C.muted)),
                  ]);
                }),
              ),
              if (idx == 0 && st.weServe)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: C.accent, borderRadius: BorderRadius.circular(6)),
                    child: const Text('BATT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: C.bg)),
                  ),
                ),
            ]),
          ),
        ),
      );
    }

    Widget smallBtn(String text, VoidCallback? onTap, {IconData? icon}) => Expanded(
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: SizedBox(
              height: 46,
              child: Tile(
                onTap: onTap,
                radius: 10,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 6)],
                  Flexible(child: Text(text, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
                ]),
              ),
            ),
          ),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Text('1 · GIOCATORE', style: labelStyle),
        const Spacer(),
        Text(setterIdx >= 0 ? 'Rotazione P${setterIdx + 1}' : '', style: const TextStyle(color: C.muted)),
      ]),
      const SizedBox(height: 6),
      Expanded(
        child: Container(
          decoration: BoxDecoration(
            color: C.court,
            border: Border.all(color: const Color(0xFF3A4757), width: 2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(children: [
            Container(height: 6, color: C.text.withValues(alpha: 0.7)),
            Expanded(child: Row(children: [for (final i in order.take(3)) tile(i)])),
            Expanded(child: Row(children: [for (final i in order.skip(3)) tile(i)])),
          ]),
        ),
      ),
      const SizedBox(height: 6),
      Row(children: [
        smallBtn('Cambi ${st.subsUsed}/6', st.finished ? null : () => _subsDialog(st), icon: Icons.swap_horiz),
        smallBtn(st.liberoOnCourt ? 'Libero: esce' : 'Libero', st.finished ? null : () => _liberoDialog(st), icon: Icons.shield_outlined),
      ]),
      Row(children: [
        smallBtn('Punto avv.', st.finished ? null : () => _add('pointThem')),
        smallBtn('Errore avv.', st.finished ? null : () => _add('pointUs')),
      ]),
    ]);
  }

  Widget _actionPanel(SetState st) {
    final ready = _player != null && _skill != null && !st.finished;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('2 · FONDAMENTALE', style: labelStyle),
      const SizedBox(height: 6),
      for (final rowSkills in [skills.sublist(0, 3), skills.sublist(3)])
        Row(children: [
          for (final sk in rowSkills)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: SizedBox(
                  height: 54,
                  child: Tile(
                    bg: _skill == sk ? const Color(0xFF2A2320) : C.surface2,
                    border: _skill == sk ? C.accent : C.border,
                    borderWidth: _skill == sk ? 3 : 1,
                    onTap: st.finished ? null : () => setState(() => _skill = _skill == sk ? null : sk),
                    child: Text(sk, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ),
        ]),
      const SizedBox(height: 8),
      Row(children: [
        const Text('3 · VALUTAZIONE', style: labelStyle),
        const Spacer(),
        Text(
          ready
              ? '${m.nr(_player)} · $_skill'
              : st.finished
                  ? 'Set concluso'
                  : 'Scegli giocatore e fondamentale',
          style: TextStyle(color: ready ? C.accent : C.muted, fontWeight: FontWeight.w600),
        ),
      ]),
      const SizedBox(height: 6),
      Expanded(
        child: Column(children: [
          for (final rowGrades in [grades.sublist(0, 3), grades.sublist(3)])
            Expanded(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final g in rowGrades)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Opacity(
                        opacity: ready ? 1 : 0.35,
                        child: Tile(
                          bg: gradeColors[g]!,
                          border: Colors.transparent,
                          radius: 14,
                          onTap: ready ? () => _add('action', playerId: _player, skill: _skill, grade: g) : null,
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(g, style: cond(46, color: Colors.white)),
                            const SizedBox(height: 4),
                            Text(gradeLabels[g]!, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                          ]),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
        ]),
      ),
    ]);
  }

  Widget _sidePanel(SetState st) {
    final recent = s.events
        .where((e) => e.type == 'action' || e.type == 'pointUs' || e.type == 'pointThem')
        .toList()
        .reversed
        .take(8)
        .toList();
    String actionText(GameEvent e) {
      if (e.type == 'pointUs') return 'Errore avversario';
      if (e.type == 'pointThem') return 'Punto avversario';
      return '${m.nr(e.playerId)} ${e.skill}';
    }

    Color kindColor(String k) => k == 'T' ? C.timeout : (k == 'C' ? C.sub : C.libero);

    BoxDecoration box() => BoxDecoration(
          color: C.surface,
          border: Border.all(color: C.line),
          borderRadius: BorderRadius.circular(12),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('ULTIME AZIONI', style: labelStyle),
      const SizedBox(height: 6),
      Expanded(
        flex: 5,
        child: Container(
          decoration: box(),
          child: recent.isEmpty
              ? const Center(child: Text('Nessuna azione', style: TextStyle(color: C.muted)))
              : ListView(padding: EdgeInsets.zero, children: [
                  for (final e in recent)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.line))),
                      child: Row(children: [
                        SizedBox(width: 34, child: Text(fmtMin(e.t), style: const TextStyle(fontSize: 12, color: C.muted))),
                        Expanded(child: Text(actionText(e), overflow: TextOverflow.ellipsis)),
                        Text(e.grade ?? (e.type == 'pointUs' ? '+1' : '-1'), style: cond(17)),
                      ]),
                    ),
                ]),
        ),
      ),
      const SizedBox(height: 8),
      const Text('EVENTI DEL SET', style: labelStyle),
      const SizedBox(height: 6),
      Expanded(
        flex: 4,
        child: Container(
          decoration: box(),
          child: st.eventsLog.isEmpty
              ? const Center(child: Text('Timeout e cambi\ncompariranno qui', textAlign: TextAlign.center, style: TextStyle(color: C.muted)))
              : ListView(padding: EdgeInsets.zero, children: [
                  for (final ev in st.eventsLog.reversed)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.line))),
                      child: Row(children: [
                        SizedBox(width: 34, child: Text(fmtMin(ev.t), style: const TextStyle(fontSize: 12, color: C.muted))),
                        Container(
                          width: 20,
                          height: 20,
                          alignment: Alignment.center,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(color: kindColor(ev.kind), borderRadius: BorderRadius.circular(5)),
                          child: Text(ev.kind, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: C.bg)),
                        ),
                        Expanded(child: Text(ev.text, style: const TextStyle(fontSize: 13))),
                      ]),
                    ),
                ]),
        ),
      ),
    ]);
  }

  Widget _setEndBar(SetState st, MatchSummary sum) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: st.weWon ? C.win : C.loss,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Text(
          'Set ${s.number} ${st.weWon ? 'vinto' : 'perso'} ${st.us}-${st.them} · durata ${fmtClock(s.elapsedSec())}',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 12),
        const Text('(Annulla per correggere l\'ultimo punto)', style: TextStyle(color: C.muted)),
        const Spacer(),
        if (sum.over)
          FilledButton(onPressed: _endMatch, child: Text('Fine partita ${sum.setsUs}-${sum.setsThem}'))
        else ...[
          TextButton(onPressed: _confirmEndEarly, child: const Text('Chiudi partita')),
          const SizedBox(width: 8),
          FilledButton(onPressed: _nextSet, child: const Text('Prossimo set')),
        ],
      ]),
    );
  }

  Widget _chartPanel(SetState st) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      decoration: BoxDecoration(
        color: C.surface,
        border: Border.all(color: C.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text('ANDAMENTO PUNTEGGIO · SET ${s.number}', style: labelStyle),
          const Spacer(),
          const Legend(color: C.accent, text: 'Noi'),
          const SizedBox(width: 14),
          const Legend(color: C.muted, text: 'Avversari'),
          const SizedBox(width: 14),
          const Legend(color: C.timeout, text: 'Timeout', box: true, letter: 'T'),
          const SizedBox(width: 14),
          const Legend(color: C.sub, text: 'Cambio', box: true, letter: 'C'),
        ]),
        const SizedBox(height: 4),
        Expanded(child: ScoreChart(st: st, durationSec: s.elapsedSec())),
      ]),
    );
  }
}

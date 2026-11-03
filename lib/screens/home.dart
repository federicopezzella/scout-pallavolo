import 'package:flutter/material.dart';

import '../engine.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'lineup.dart';
import 'live.dart';
import 'new_match.dart';
import 'roster.dart';
import 'stats.dart';

String fmtDate(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year}';
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _open(BuildContext context, MatchData m) {
    final Widget page;
    if (m.finished) {
      page = StatsScreen(match: m);
    } else if (m.sets.isEmpty) {
      page = LineupScreen(match: m);
    } else {
      page = LiveScreen(match: m);
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _delete(BuildContext context, MatchData m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminare la partita?'),
        content: Text('vs ${m.opponent} del ${fmtDate(m.date)}. L\'operazione non si può annullare.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Elimina')),
        ],
      ),
    );
    if (ok == true) {
      store.data.matches.remove(m);
      await store.save();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final matches = List.of(store.data.matches)..sort((a, b) => b.date.compareTo(a.date));
        final running = matches.where((m) => !m.finished).toList();
        final done = matches.where((m) => m.finished).toList();
        return Scaffold(
          appBar: AppBar(
            title: const Text('Scout Volley', style: TextStyle(fontWeight: FontWeight.w800)),
            actions: [
              TextButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RosterScreen())),
                icon: const Icon(Icons.groups),
                label: const Text('Rosa'),
              ),
              const SizedBox(width: 12),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NewMatchScreen())),
            icon: const Icon(Icons.add),
            label: const Text('Nuova partita', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          body: matches.isEmpty
              ? const Center(
                  child: Text(
                    'Nessuna partita.\nPrima inserisci la rosa, poi crea una nuova partita.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: C.muted, fontSize: 16),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  children: [
                    if (running.isNotEmpty) ...[
                      const Text('IN CORSO', style: labelStyle),
                      const SizedBox(height: 8),
                      for (final m in running) _MatchCard(m: m, onTap: () => _open(context, m), onLong: () => _delete(context, m), live: true),
                      const SizedBox(height: 20),
                    ],
                    if (done.isNotEmpty) ...[
                      const Text('PARTITE PRECEDENTI', style: labelStyle),
                      const SizedBox(height: 8),
                      for (final m in done) _MatchCard(m: m, onTap: () => _open(context, m), onLong: () => _delete(context, m)),
                    ],
                    const SizedBox(height: 8),
                    const Text('Tieni premuto su una partita per eliminarla.', style: TextStyle(color: C.muted, fontSize: 12)),
                  ],
                ),
        );
      },
    );
  }
}

class _MatchCard extends StatelessWidget {
  final MatchData m;
  final VoidCallback onTap;
  final VoidCallback onLong;
  final bool live;
  const _MatchCard({required this.m, required this.onTap, required this.onLong, this.live = false});

  @override
  Widget build(BuildContext context) {
    final sum = summarize(m);
    String sub = m.competition.isEmpty ? '' : '${m.competition} · ';
    sub += m.home ? 'casa' : 'trasferta';
    String? current;
    if (live && sum.sets.isNotEmpty) {
      final st = sum.sets.last;
      current = 'Set ${m.sets.length} · ${st.us}-${st.them}';
    }
    final won = sum.setsUs > sum.setsThem;
    final narrow = MediaQuery.sizeOf(context).width < 600;
    if (narrow) {
      sub = '${fmtDate(m.date)} · $sub';
      if (current != null) sub = '$current · $sub';
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: live ? const Color(0xFF2A2320) : C.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: live ? C.accent : C.line, width: live ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLong,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(children: [
              if (!narrow) SizedBox(width: 110, child: Text(fmtDate(m.date), style: const TextStyle(color: C.muted, fontSize: 15))),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('vs ${m.opponent}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
                  Text(sub, style: const TextStyle(color: C.muted, fontSize: 14)),
                ]),
              ),
              if (current != null && !narrow)
                Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: Text(current, style: const TextStyle(color: C.accent, fontWeight: FontWeight.w700)),
                ),
              Text('${sum.setsUs} – ${sum.setsThem}', style: cond(28)),
              const SizedBox(width: 16),
              if (!live && !narrow)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: won ? C.win : C.loss, borderRadius: BorderRadius.circular(8)),
                  child: Text(won ? 'Vinta' : 'Persa',
                      style: TextStyle(fontWeight: FontWeight.w700, color: won ? const Color(0xFFB9F0D9) : const Color(0xFFFFC9BE))),
                )
              else if (live && !narrow)
                FilledButton(onPressed: onTap, child: const Text('Riprendi')),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: C.muted),
            ]),
          ),
        ),
      ),
    );
  }
}

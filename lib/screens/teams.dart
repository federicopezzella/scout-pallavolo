import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'roster.dart';

/// Elenco delle squadre (rose): crea, apri, duplica, elimina, scegli quella attiva.
class TeamsScreen extends StatelessWidget {
  const TeamsScreen({super.key});

  void _openRoster(BuildContext context, Team t) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => RosterScreen(team: t)));

  Future<void> _add(BuildContext context) async {
    final t = Team.empty(name: 'Squadra ${store.data.teams.length + 1}');
    store.data.teams.add(t);
    store.data.currentTeamId = t.id;
    await store.save();
    if (context.mounted) _openRoster(context, t);
  }

  Future<void> _duplicate(Team src) async {
    final copy = Team(
      id: newId(),
      name: '${src.name} (copia)',
      jerseyColor: src.jerseyColor,
      liberoColor: src.liberoColor,
      players: [for (final p in src.players) Player(id: newId(), number: p.number, name: p.name, roles: p.roles)],
    );
    store.data.teams.add(copy);
    await store.save();
  }

  Future<void> _delete(BuildContext context, Team t) async {
    if (store.data.teams.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Serve almeno una squadra')));
      return;
    }
    final n = store.data.matches.where((m) => m.teamId == t.id).length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Eliminare "${t.name}"?'),
        content: Text(n == 0
            ? 'La rosa verrà eliminata.'
            : 'Verranno eliminate la rosa e le sue $n partite. Se vuoi tenerle, fai prima un backup.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Elimina')),
        ],
      ),
    );
    if (ok != true) return;
    store.data.teams.remove(t);
    store.data.matches.removeWhere((m) => m.teamId == t.id);
    store.data.normalize();
    await store.save();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final current = store.data.team.id;
        return Scaffold(
          appBar: AppBar(title: const Text('Squadre')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _add(context),
            icon: const Icon(Icons.add),
            label: const Text('Nuova squadra', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              const Text(
                'Ogni squadra ha la sua rosa, le sue divise e le sue partite. Quella attiva è quella che vedi in home.',
                style: TextStyle(color: C.muted),
              ),
              const SizedBox(height: 16),
              for (final t in store.data.teams)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: t.id == current ? const Color(0xFF2A2320) : C.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: t.id == current ? C.accent : C.line, width: t.id == current ? 2 : 1),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _openRoster(context, t),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                        child: Row(children: [
                          Jersey(color: Color(t.jerseyColor), number: t.players.isEmpty ? 0 : t.players.first.number, width: 52),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(t.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                              Text(
                                '${t.players.length} giocatori · ${store.data.matches.where((m) => m.teamId == t.id).length} partite',
                                style: const TextStyle(color: C.muted),
                              ),
                            ]),
                          ),
                          if (t.id == current)
                            const Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: Text('ATTIVA', style: TextStyle(fontWeight: FontWeight.w800, color: C.accent)),
                            )
                          else
                            TextButton(
                              onPressed: () {
                                store.data.currentTeamId = t.id;
                                store.save();
                              },
                              child: const Text('Usa questa'),
                            ),
                          PopupMenuButton<String>(
                            tooltip: 'Altro',
                            onSelected: (v) {
                              if (v == 'edit') _openRoster(context, t);
                              if (v == 'dup') _duplicate(t);
                              if (v == 'del') _delete(context, t);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('Modifica rosa')),
                              PopupMenuItem(value: 'dup', child: Text('Duplica')),
                              PopupMenuItem(value: 'del', child: Text('Elimina')),
                            ],
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

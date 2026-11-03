import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

class RosterScreen extends StatefulWidget {
  const RosterScreen({super.key});

  @override
  State<RosterScreen> createState() => _RosterScreenState();
}

class _RosterScreenState extends State<RosterScreen> {
  late final TextEditingController _name;

  Team get team => store.data.team;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: team.name);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _edit([Player? p]) async {
    final numCtrl = TextEditingController(text: p == null ? '' : '${p.number}');
    final name = TextEditingController(text: p?.name ?? '');
    var role = p?.role ?? 'S';
    String? error;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(p == null ? 'Nuovo giocatore' : 'Modifica giocatore'),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                SizedBox(
                  width: 110,
                  child: TextField(
                    controller: numCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Numero'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Nome'),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              Wrap(spacing: 8, children: [
                for (final r in roles)
                  ChoiceChip(
                    label: Text(roleNames[r]!),
                    selected: role == r,
                    onSelected: (_) => setD(() => role = r),
                  ),
              ]),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!, style: const TextStyle(color: Color(0xFFFF8A80))),
              ],
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
            FilledButton(
              onPressed: () {
                final n = int.tryParse(numCtrl.text.trim());
                if (n == null || n < 0 || n > 99) {
                  setD(() => error = 'Numero di maglia non valido');
                  return;
                }
                if (name.text.trim().isEmpty) {
                  setD(() => error = 'Inserisci il nome');
                  return;
                }
                final dup = team.players.any((o) => o.number == n && o.id != p?.id);
                if (dup) {
                  setD(() => error = 'Numero $n già usato');
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      final n = int.parse(numCtrl.text.trim());
      if (p == null) {
        team.players.add(Player(id: newId(), number: n, name: name.text.trim(), role: role));
      } else {
        p.number = n;
        p.name = name.text.trim();
        p.role = role;
      }
      team.players.sort((a, b) => a.number.compareTo(b.number));
      await store.save();
      setState(() {});
    }
  }

  Future<void> _remove(Player p) async {
    team.players.remove(p);
    await store.save();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rosa e divise')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.person_add),
        label: const Text('Aggiungi giocatore'),
      ),
      body: LayoutBuilder(builder: (context, c) {
        final settings = <Widget>[
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nome squadra'),
            onChanged: (v) {
              team.name = v.trim().isEmpty ? 'La mia squadra' : v.trim();
              store.save();
            },
          ),
          const SizedBox(height: 24),
          const Text('COLORE DIVISA', style: labelStyle),
          const SizedBox(height: 10),
          ColorPickerRow(
            value: team.jerseyColor,
            onChanged: (col) {
              setState(() => team.jerseyColor = col);
              store.save();
            },
          ),
          const SizedBox(height: 24),
          const Text('COLORE DIVISA LIBERO', style: labelStyle),
          const SizedBox(height: 10),
          ColorPickerRow(
            value: team.liberoColor,
            onChanged: (col) {
              setState(() => team.liberoColor = col);
              store.save();
            },
          ),
          const SizedBox(height: 24),
          Row(children: [
            Jersey(color: Color(team.jerseyColor), number: 7, width: 90),
            const SizedBox(width: 16),
            Jersey(color: Color(team.liberoColor), number: 1, width: 90),
          ]),
        ];
        final players = <Widget>[
          if (team.players.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('Aggiungi i giocatori della squadra', style: TextStyle(color: C.muted))),
            ),
          for (final p in team.players)
            ListTile(
              leading: Jersey(
                color: Color(p.role == 'L' ? team.liberoColor : team.jerseyColor),
                number: p.number,
                width: 48,
              ),
              title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(roleNames[p.role] ?? p.role),
              onTap: () => _edit(p),
              trailing: IconButton(
                tooltip: 'Rimuovi',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _remove(p),
              ),
            ),
        ];
        if (c.maxWidth < 800) {
          return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), children: [
            ...settings,
            const SizedBox(height: 24),
            const Text('GIOCATORI', style: labelStyle),
            const SizedBox(height: 8),
            ...players,
          ]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 420,
            child: ListView(padding: const EdgeInsets.all(24), children: settings),
          ),
          const VerticalDivider(width: 1, color: C.line),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), children: players),
          ),
        ]);
      }),
    );
  }
}

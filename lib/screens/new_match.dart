import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'lineup.dart';

class NewMatchScreen extends StatefulWidget {
  const NewMatchScreen({super.key});

  @override
  State<NewMatchScreen> createState() => _NewMatchScreenState();
}

class _NewMatchScreenState extends State<NewMatchScreen> {
  final _opp = TextEditingController();
  final _comp = TextEditingController();
  bool _home = true;
  String? _error;

  @override
  void dispose() {
    _opp.dispose();
    _comp.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final team = store.data.team;
    final field = team.players.where((p) => p.fieldRoles.isNotEmpty).length;
    if (field < 6) {
      setState(() => _error = 'Servono almeno 6 giocatori (non liberi) nella rosa. Ora ne hai $field.');
      return;
    }
    if (_opp.text.trim().isEmpty) {
      setState(() => _error = 'Inserisci il nome dell\'avversario');
      return;
    }
    final m = MatchData(
      id: newId(),
      opponent: _opp.text.trim(),
      competition: _comp.text.trim(),
      home: _home,
      date: DateTime.now().millisecondsSinceEpoch,
      teamName: team.name,
      jerseyColor: team.jerseyColor,
      liberoColor: team.liberoColor,
      players: team.players.map((p) => p.copy()).toList(),
    );
    store.data.matches.add(m);
    await store.save();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => LineupScreen(match: m)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuova partita')),
      body: Center(
        child: SingleChildScrollView(
          child: SizedBox(
            width: 520,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextField(
                controller: _opp,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Avversario'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _comp,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Competizione (facoltativo)'),
              ),
              const SizedBox(height: 16),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('In casa'), icon: Icon(Icons.home)),
                  ButtonSegment(value: false, label: Text('In trasferta'), icon: Icon(Icons.directions_bus)),
                ],
                selected: {_home},
                onSelectionChanged: (s) => setState(() => _home = s.first),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Color(0xFFFF8A80))),
              ],
              const SizedBox(height: 24),
              SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: _create,
                  child: const Text('Crea e scegli la formazione', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'La partita usa una copia della rosa attuale: modifiche future alla rosa non cambiano le partite già giocate.',
                style: const TextStyle(color: C.muted, fontSize: 13),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

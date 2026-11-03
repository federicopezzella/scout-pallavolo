import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'live.dart';

/// Formazione iniziale del set: 6 posizioni, libero, chi batte.
class LineupScreen extends StatefulWidget {
  final MatchData match;
  const LineupScreen({super.key, required this.match});

  @override
  State<LineupScreen> createState() => _LineupScreenState();
}

class _LineupScreenState extends State<LineupScreen> {
  late List<String?> _slots; // indice 0 = posizione 1
  String? _libero;
  bool _weServe = true;

  MatchData get m => widget.match;
  int get setNumber => m.sets.length + 1;

  @override
  void initState() {
    super.initState();
    if (m.sets.isNotEmpty) {
      final prev = m.sets.last;
      _slots = List<String?>.from(prev.lineup);
      _libero = prev.liberoId;
      _weServe = !prev.weServeFirst; // di solito si alterna
    } else {
      _slots = List<String?>.filled(6, null);
      final libs = m.players.where((p) => p.role == 'L').toList();
      _libero = libs.isEmpty ? null : libs.first.id;
    }
  }

  Future<void> _pick(int idx) async {
    final used = {..._slots.whereType<String>(), if (_libero != null) _libero!};
    final current = _slots[idx];
    final options = m.players.where((p) => p.id == current || !used.contains(p.id)).toList();
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: C.surface,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Posizione ${idx + 1}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (final p in options)
                ActionChip(
                  avatar: CircleAvatar(
                    backgroundColor: Color(m.jerseyColor),
                    child: Text('${p.number}',
                        style: TextStyle(fontSize: 12, color: isLight(Color(m.jerseyColor)) ? C.bg : Colors.white)),
                  ),
                  label: Text('${p.name} (${p.role})'),
                  onPressed: () => Navigator.pop(ctx, p.id),
                ),
            ]),
          ]),
        ),
      ),
    );
    if (chosen != null) setState(() => _slots[idx] = chosen);
  }

  Future<void> _start() async {
    final s = SetData(
      number: setNumber,
      lineup: _slots.map((e) => e!).toList(),
      liberoId: _libero,
      weServeFirst: _weServe,
    );
    m.sets.add(s);
    await store.save();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => LiveScreen(match: m)));
  }

  Widget _slot(int idx) {
    final p = m.player(_slots[idx]);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Tile(
          bg: C.courtTile,
          border: idx == 0 && _weServe ? C.accent : const Color(0xFF4A6A5E),
          borderWidth: idx == 0 && _weServe ? 2 : 1,
          onTap: () => _pick(idx),
          child: p == null
              ? Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.add_circle_outline, size: 36, color: C.muted),
                  Text('Pos ${idx + 1}', style: const TextStyle(color: C.muted)),
                ])
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Jersey(color: Color(m.jerseyColor), number: p.number, width: 70),
                  Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('${p.role} · pos ${idx + 1}${idx == 0 ? ' · batte' : ''}',
                      style: const TextStyle(color: C.muted, fontSize: 12)),
                ]),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ready = _slots.every((e) => e != null);
    final libCandidates = m.players.where((p) => !_slots.contains(p.id)).toList();
    return Scaffold(
      appBar: AppBar(title: Text('Formazione · Set $setNumber · vs ${m.opponent}')),
      body: LayoutBuilder(builder: (context, c) {
        final portrait = c.maxHeight > c.maxWidth;
        return Padding(
        padding: EdgeInsets.all(portrait ? 12 : 20),
        child: Flex(direction: portrait ? Axis.vertical : Axis.horizontal, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                color: C.court,
                border: Border.all(color: const Color(0xFF3A4757), width: 2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(children: [
                Container(height: 8, color: C.text.withValues(alpha: 0.7)),
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('RETE', style: labelStyle),
                ),
                Expanded(child: Row(children: [_slot(3), _slot(2), _slot(1)])),
                Expanded(child: Row(children: [_slot(4), _slot(5), _slot(0)])),
              ]),
            ),
          ),
          const SizedBox(width: 24, height: 16),
          Expanded(
            flex: 2,
            child: ListView(children: [
              const Text('LIBERO', style: labelStyle),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                ChoiceChip(
                  label: const Text('Nessuno'),
                  selected: _libero == null,
                  onSelected: (_) => setState(() => _libero = null),
                ),
                for (final p in libCandidates)
                  ChoiceChip(
                    label: Text('#${p.number} ${p.name}'),
                    selected: _libero == p.id,
                    onSelected: (_) => setState(() => _libero = p.id),
                  ),
              ]),
              const SizedBox(height: 24),
              const Text('PRIMO SERVIZIO', style: labelStyle),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Battiamo noi')),
                  ButtonSegment(value: false, label: Text('Battono loro')),
                ],
                selected: {_weServe},
                onSelectionChanged: (s) => setState(() => _weServe = s.first),
              ),
              const SizedBox(height: 24),
              const Text(
                'Tocca una posizione per scegliere il giocatore. In basso a destra c\'è la posizione 1 (battitore).',
                style: TextStyle(color: C.muted),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: ready ? _start : null,
                  child: Text('Inizia il set $setNumber', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),
        ]),
      );
      }),
    );
  }
}

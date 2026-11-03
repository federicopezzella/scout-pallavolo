import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:scout_pallavolo/analytics.dart';
import 'package:scout_pallavolo/engine.dart';
import 'package:scout_pallavolo/models.dart';
import 'package:scout_pallavolo/pdf_report.dart';

/// Partita di esempio generata a caso (seme fisso) per controllare il report PDF.
MatchData sampleMatch() {
  final players = [
    Player(id: 'a', number: 1, name: 'Conti', roles: ['P']),
    Player(id: 'b', number: 7, name: 'Rossi', roles: ['S']),
    Player(id: 'c', number: 11, name: 'Bianchi', roles: ['C']),
    Player(id: 'd', number: 4, name: 'Verdi', roles: ['O', 'S']),
    Player(id: 'e', number: 14, name: 'Neri', roles: ['S']),
    Player(id: 'f', number: 9, name: 'Russo', roles: ['C']),
    Player(id: 'g', number: 12, name: 'Gallo', roles: ['L', 'S']),
    Player(id: 'h', number: 6, name: 'Ferri', roles: ['S', 'O']),
  ];
  final m = MatchData(
    id: 'sample',
    opponent: 'Volley Esempio',
    competition: 'Serie D',
    home: true,
    date: DateTime(2026, 11, 3).millisecondsSinceEpoch,
    teamName: 'Scout Volley',
    jerseyColor: 0xFF1F6FD1,
    liberoColor: 0xFFE9C46A,
    players: players,
  );
  final rnd = Random(42);
  String pick(Map<String, int> w) {
    final total = w.values.reduce((a, b) => a + b);
    var x = rnd.nextInt(total);
    for (final e in w.entries) {
      x -= e.value;
      if (x < 0) return e.key;
    }
    return w.keys.first;
  }

  const weights = {
    'Battuta': {'#': 8, '+': 18, '!': 30, '-': 22, '/': 8, '=': 14},
    'Ricezione': {'#': 25, '+': 25, '!': 20, '-': 15, '/': 7, '=': 8},
    'Attacco': {'#': 42, '+': 14, '!': 18, '-': 10, '/': 8, '=': 8},
    'Muro': {'#': 18, '+': 28, '!': 20, '-': 18, '/': 6, '=': 10},
    'Difesa': {'#': 12, '+': 30, '!': 25, '-': 18, '/': 5, '=': 10},
    'Alzata': {'#': 30, '+': 40, '!': 18, '-': 8, '/': 2, '=': 2},
  };
  final attackers = ['b', 'd', 'e', 'c', 'f'];

  for (var setN = 1; setN <= 4; setN++) {
    final s = SetData(
      number: setN,
      lineup: ['a', 'b', 'c', 'd', 'e', 'f'],
      liberoIds: ['g', 'h'],
      weServeFirst: setN.isOdd,
      clockMs: 0,
    );
    m.sets.add(s);
    var t = 0;
    var guard = 0;
    while (!replaySet(m, s).finished && guard++ < 400) {
      t += 20 + rnd.nextInt(25);
      final st = replaySet(m, s);
      void act(String pid, String skill) =>
          s.events.add(GameEvent(type: 'action', t: t, playerId: pid, skill: skill, grade: pick(weights[skill]!)));
      if (st.weServe) {
        act(st.court[0], 'Battuta');
      } else {
        act(rnd.nextBool() ? 'g' : 'b', 'Ricezione');
      }
      if (replaySet(m, s).us != st.us || replaySet(m, s).them != st.them) continue;
      if (rnd.nextInt(3) == 0) act(attackers[rnd.nextInt(attackers.length)], 'Muro');
      if (replaySet(m, s).us != st.us || replaySet(m, s).them != st.them) continue;
      if (rnd.nextInt(3) == 0) act(rnd.nextBool() ? 'g' : 'e', 'Difesa');
      act('a', 'Alzata');
      if (replaySet(m, s).us != st.us || replaySet(m, s).them != st.them) continue;
      act(attackers[rnd.nextInt(attackers.length)], 'Attacco');
      final after = replaySet(m, s);
      if (after.us == st.us && after.them == st.them) {
        s.events.add(GameEvent(type: rnd.nextInt(10) < 5 ? 'pointUs' : 'pointThem', t: t));
      }
      if (t > 300 && t < 340) s.events.add(GameEvent(type: 'timeout', t: t, team: 'them'));
    }
    s.clockMs = t * 1000;
  }
  m.finished = true;
  return m;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('report PDF di esempio', () async {
    final m = sampleMatch();
    final r = MatchReport.of(m);
    expect(r.players, isNotEmpty);
    expect(r.topScorer, isNotNull);
    final bytes = await buildMatchPdf(m);
    expect(bytes.length, greaterThan(10000));
    Directory('build').createSync(recursive: true);
    File('build/report_sample.pdf').writeAsBytesSync(bytes);
  });

  test('andamento ultime partite', () {
    final ms = [for (var i = 0; i < 7; i++) sampleMatch()..date = i];
    final trend = lastMatchesTrend(ms);
    expect(trend.length, 5);
    expect(trend.first.match.date, 2);
  });
}

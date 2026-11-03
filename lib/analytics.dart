import 'engine.dart';
import 'models.dart';

/// Ordine dei fondamentali nei report.
const reportSkills = ['Battuta', 'Ricezione', 'Difesa', 'Muro', 'Attacco', 'Alzata'];

const skillShort = {
  'Battuta': 'Bat',
  'Ricezione': 'Ric',
  'Difesa': 'Dif',
  'Muro': 'Mur',
  'Attacco': 'Att',
  'Alzata': 'Alz',
};

const gradeShortLabels = {
  '#': 'perfetto',
  '+': 'positivo',
  '!': 'rigiocab.',
  '-': 'negativo',
  '/': 'scarso',
  '=': 'errore',
};

/// Come si calcola l'efficienza, per la legenda del report.
const efficiencyNotes = {
  'Battuta': '(# − =) / totale',
  'Attacco': '(# − = − /) / totale',
  'Muro': '(# − =) / totale',
  'Ricezione': '(# + + − / − =) / totale',
  'Difesa': '(# + + − / − =) / totale',
  'Alzata': '(# + + − / − =) / totale',
};

/// Conteggi di un fondamentale (per un giocatore o per la squadra).
class SkillLine {
  final String skill;
  final Map<String, int> counts;
  SkillLine(this.skill, [Map<String, int>? counts]) : counts = counts ?? {};

  int n(String grade) => counts[grade] ?? 0;
  int get total => counts.values.fold(0, (a, b) => a + b);
  bool get hasData => total > 0;

  /// (# + +) / totale, tra 0 e 1
  double? get positivity => total == 0 ? null : (n('#') + n('+')) / total;

  /// tra -1 e 1, formula diversa per fondamentale (vedi [efficiencyNotes])
  double? get efficiency {
    final t = total;
    if (t == 0) return null;
    switch (skill) {
      case 'Battuta':
      case 'Muro':
        return (n('#') - n('=')) / t;
      case 'Attacco':
        return (n('#') - n('=') - n('/')) / t;
      default:
        return (n('#') + n('+') - n('/') - n('=')) / t;
    }
  }

  void addAll(SkillLine o) {
    o.counts.forEach((g, c) => counts[g] = (counts[g] ?? 0) + c);
  }
}

typedef SkillTable = Map<String, SkillLine>;

SkillTable _emptyTable() => {for (final s in reportSkills) s: SkillLine(s)};

SkillTable tableFromCounts(Map<String, Map<String, int>>? bySkill) {
  final t = _emptyTable();
  bySkill?.forEach((skill, grades) {
    final line = t[skill];
    if (line != null) line.addAll(SkillLine(skill, Map.of(grades)));
  });
  return t;
}

class PlayerReport {
  final Player player;
  final SkillTable table;
  PlayerReport(this.player, this.table);

  int get attackPoints => table['Attacco']!.n('#');
  int get blockPoints => table['Muro']!.n('#');
  int get aces => table['Battuta']!.n('#');
  int get points => attackPoints + blockPoints + aces;
  int get errors => table.values.fold(0, (a, l) => a + l.n('='));
  bool get hasData => table.values.any((l) => l.hasData);
}

class Leader {
  final Player player;
  final int value;
  final String detail;
  const Leader(this.player, this.value, this.detail);
}

class MatchReport {
  final MatchData match;
  final MatchSummary summary;
  final SkillTable team;
  final List<PlayerReport> players;
  final int opponentErrors;
  final int opponentPoints;

  MatchReport._(this.match, this.summary, this.team, this.players, this.opponentErrors, this.opponentPoints);

  factory MatchReport.of(MatchData m) {
    final stats = computeStats(m);
    final players = <PlayerReport>[];
    final team = _emptyTable();
    for (final p in m.players) {
      final t = tableFromCounts(stats[p.id]);
      final pr = PlayerReport(p, t);
      for (final s in reportSkills) {
        team[s]!.addAll(t[s]!);
      }
      if (pr.hasData) players.add(pr);
    }
    players.sort((a, b) => b.points != a.points ? b.points.compareTo(a.points) : a.player.number.compareTo(b.player.number));
    var oppErr = 0, oppPts = 0;
    for (final s in m.sets) {
      for (final e in s.events) {
        if (e.type == 'pointUs') oppErr++;
        if (e.type == 'pointThem') oppPts++;
      }
    }
    return MatchReport._(m, summarize(m), team, players, oppErr, oppPts);
  }

  Leader? _best(int Function(PlayerReport) value, String Function(PlayerReport) detail) {
    PlayerReport? best;
    for (final p in players) {
      if (value(p) <= 0) continue;
      if (best == null || value(p) > value(best)) best = p;
    }
    return best == null ? null : Leader(best.player, value(best), detail(best));
  }

  Leader? get topScorer => _best((p) => p.points, (p) => '${p.attackPoints} att · ${p.blockPoints} muro · ${p.aces} ace');

  Leader? get topServer => _best((p) => p.aces, (p) {
        final eff = p.table['Battuta']!.efficiency;
        return '${p.table['Battuta']!.total} battute · eff. ${fmtPct(eff)}';
      });

  Leader? get topBlocker => _best((p) => p.blockPoints, (p) => '${p.table['Muro']!.total} muri toccati');

  Leader? get topAttacker => _best((p) => p.attackPoints, (p) {
        final l = p.table['Attacco']!;
        return '${l.total} attacchi · eff. ${fmtPct(l.efficiency)}';
      });
}

String fmtPct(double? v, {bool sign = false}) {
  if (v == null) return '–';
  final p = (v * 100).round();
  return sign && p > 0 ? '+$p%' : '$p%';
}

/// Valori di squadra di una partita conclusa, per i grafici di tendenza.
class MatchTrend {
  final MatchData match;
  final double? receptionPositivity;
  final double? attackEfficiency;
  final double? serveEfficiency;
  final int blockPoints;
  const MatchTrend(this.match, this.receptionPositivity, this.attackEfficiency, this.serveEfficiency, this.blockPoints);
}

/// Ultime [n] partite concluse, dalla più vecchia alla più recente.
List<MatchTrend> lastMatchesTrend(List<MatchData> all, {int n = 5}) {
  final done = all.where((m) => m.finished).toList()..sort((a, b) => a.date.compareTo(b.date));
  final last = done.length > n ? done.sublist(done.length - n) : done;
  return [
    for (final m in last)
      () {
        final t = MatchReport.of(m).team;
        return MatchTrend(
          m,
          t['Ricezione']!.positivity,
          t['Attacco']!.efficiency,
          t['Battuta']!.efficiency,
          t['Muro']!.n('#'),
        );
      }(),
  ];
}

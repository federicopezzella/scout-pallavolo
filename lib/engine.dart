import 'models.dart';

class ScorePoint {
  final int t;
  final int us;
  final int them;
  const ScorePoint(this.t, this.us, this.them);
}

/// kind: 'T' timeout, 'C' cambio, 'L' libero
class SetMarker {
  final int t;
  final String kind;
  final String label;
  const SetMarker(this.t, this.kind, this.label);
}

class LogItem {
  final int t;
  final String kind;
  final String text;
  const LogItem(this.t, this.kind, this.text);
}

/// +1 punto nostro, -1 punto avversario, 0 la palla continua
int pointFor(String skill, String grade) {
  switch (skill) {
    case 'Battuta':
    case 'Muro':
      if (grade == '#') return 1;
      if (grade == '=') return -1;
      return 0;
    case 'Attacco':
      if (grade == '#') return 1;
      if (grade == '=' || grade == '/') return -1;
      return 0;
    default:
      return grade == '=' ? -1 : 0;
  }
}

class SetState {
  final List<String> court; // indice 0 = posizione 1
  bool weServe;
  final int target;
  int us = 0;
  int them = 0;
  int subsUsed = 0;
  int timeoutsUs = 0;
  int timeoutsThem = 0;
  String? liberoReplaced; // giocatore fuori per il libero
  String? liberoIn; // quale libero è in campo
  final Map<String, String> subOf = {}; // riserva entrata -> titolare uscito
  final Map<String, String> starterReplacedBy = {}; // titolare -> riserva
  final Set<String> exitedSubs = {};
  final Set<String> reEnteredStarters = {};
  final List<ScorePoint> timeline = [const ScorePoint(0, 0, 0)];
  final List<SetMarker> markers = [];
  final List<LogItem> eventsLog = [];
  bool finished = false;

  SetState(this.court, this.weServe, this.target);

  bool get weWon => finished && us > them;
  bool get liberoOnCourt => liberoReplaced != null;
}

SetState replaySet(MatchData m, SetData s) {
  final st = SetState(List.of(s.lineup), s.weServeFirst, s.number == 5 ? 15 : 25);
  for (final e in s.events) {
    _apply(m, s, st, e);
  }
  return st;
}

void _apply(MatchData m, SetData s, SetState st, GameEvent e) {
  switch (e.type) {
    case 'action':
      {
        final p = pointFor(e.skill ?? '', e.grade ?? '');
        if (p == 1) {
          _pointUs(m, s, st, e.t);
        } else if (p == -1) {
          _pointThem(st, e.t);
        }
      }
      break;
    case 'pointUs':
      _pointUs(m, s, st, e.t);
      break;
    case 'pointThem':
      _pointThem(st, e.t);
      break;
    case 'timeout':
      {
      final ours = e.team == 'us';
      if (ours) {
        st.timeoutsUs++;
      } else {
        st.timeoutsThem++;
      }
      final who = ours ? 'noi' : 'avv.';
      st.markers.add(SetMarker(e.t, 'T', 'T $who ${st.us}-${st.them}'));
      st.eventsLog.add(LogItem(e.t, 'T', 'Timeout $who (${st.us}-${st.them})'));
      }
      break;
    case 'sub':
      {
      final out = e.outId;
      final inn = e.inId;
      if (out == null || inn == null) break;
      final idx = st.court.indexOf(out);
      if (idx >= 0) st.court[idx] = inn;
      st.subsUsed++;
      if (st.starterReplacedBy[inn] == out) {
        st.reEnteredStarters.add(inn);
        st.exitedSubs.add(out);
      } else {
        st.subOf[inn] = out;
        st.starterReplacedBy[out] = inn;
      }
      st.markers.add(SetMarker(e.t, 'C', 'C ${m.nr(inn)} x ${m.nr(out)}'));
      st.eventsLog.add(LogItem(
          e.t, 'C', '${m.nr(inn)} entra per ${m.nr(out)} (${st.us}-${st.them})'));
      }
      break;
    case 'liberoIn':
      {
      final out = e.outId;
      final lib = e.inId ?? (s.liberoIds.isEmpty ? null : s.liberoIds.first);
      if (out == null || lib == null || st.liberoReplaced != null) break;
      final idx = st.court.indexOf(out);
      if (idx < 0) break;
      st.court[idx] = lib;
      st.liberoReplaced = out;
      st.liberoIn = lib;
      st.eventsLog.add(LogItem(e.t, 'L', 'Libero entra per ${m.nr(out)}'));
      }
      break;
    case 'liberoOut':
      _liberoOut(m, s, st, e.t);
      break;
    case 'liberoSwap':
      {
        final cur = st.liberoIn;
        final next = e.inId;
        if (cur == null || next == null || next == cur || !s.liberoIds.contains(next)) break;
        final idx = st.court.indexOf(cur);
        if (idx < 0) break;
        st.court[idx] = next;
        st.liberoIn = next;
        st.eventsLog.add(LogItem(e.t, 'L', 'Cambio libero: ${m.nr(next)} per ${m.nr(cur)}'));
      }
      break;
  }
}

void _liberoOut(MatchData m, SetData s, SetState st, int t) {
  final rep = st.liberoReplaced;
  final lib = st.liberoIn;
  if (rep == null || lib == null) return;
  final idx = st.court.indexOf(lib);
  if (idx >= 0) st.court[idx] = rep;
  st.liberoReplaced = null;
  st.liberoIn = null;
  st.eventsLog.add(LogItem(t, 'L', 'Libero esce, rientra ${m.nr(rep)}'));
}

void _rotate(MatchData m, SetData s, SetState st, int t) {
  final old = List.of(st.court);
  for (var i = 0; i < 6; i++) {
    st.court[i] = old[(i + 1) % 6];
  }
  // il libero non può andare in prima linea (posizione 4 = indice 3)
  if (st.liberoReplaced != null && st.court[3] == st.liberoIn) {
    _liberoOut(m, s, st, t);
  }
}

void _pointUs(MatchData m, SetData s, SetState st, int t) {
  if (st.finished) return;
  st.us++;
  if (!st.weServe) {
    _rotate(m, s, st, t);
    st.weServe = true;
  }
  st.timeline.add(ScorePoint(t, st.us, st.them));
  _checkEnd(st);
}

void _pointThem(SetState st, int t) {
  if (st.finished) return;
  st.them++;
  st.weServe = false;
  st.timeline.add(ScorePoint(t, st.us, st.them));
  _checkEnd(st);
}

void _checkEnd(SetState st) {
  if ((st.us >= st.target || st.them >= st.target) &&
      (st.us - st.them).abs() >= 2) {
    st.finished = true;
  }
}

/// Giocatori disponibili in panchina (esclusi libero e chi è fuori per il libero)
List<Player> benchPlayers(MatchData m, SetData s, SetState st) => m.players
    .where((p) =>
        !st.court.contains(p.id) &&
        !s.liberoIds.contains(p.id) &&
        p.id != st.liberoReplaced)
    .toList();

/// null se il cambio è valido, altrimenti il motivo
String? canSub(MatchData m, SetData s, SetState st, String outId, String inId) {
  if (st.subsUsed >= m.maxSubs) return 'Cambi esauriti (${m.maxSubs} su ${m.maxSubs})';
  if (s.liberoIds.contains(outId) || s.liberoIds.contains(inId)) {
    return 'Per il libero usa il pulsante Libero';
  }
  if (!st.court.contains(outId)) return '${m.nr(outId)} non è in campo';
  if (st.court.contains(inId)) return '${m.nr(inId)} è già in campo';
  if (st.exitedSubs.contains(inId)) {
    return '${m.nr(inId)} è già entrato e uscito: non può rientrare';
  }
  if (st.reEnteredStarters.contains(outId)) {
    return '${m.nr(outId)} è già rientrato: non può più uscire';
  }
  final starterOfOut = st.subOf[outId];
  if (starterOfOut != null && starterOfOut != inId) {
    return '${m.nr(outId)} può uscire solo per far rientrare ${m.nr(starterOfOut)}';
  }
  final subOfIn = st.starterReplacedBy[inId];
  if (subOfIn != null && subOfIn != outId) {
    return '${m.nr(inId)} può rientrare solo al posto di ${m.nr(subOfIn)}';
  }
  if (st.subOf.containsKey(inId)) {
    return '${m.nr(inId)} ha già fatto il suo ingresso';
  }
  if (st.starterReplacedBy.containsKey(outId) && starterOfOut == null) {
    return '${m.nr(outId)} è già uscito una volta';
  }
  return null;
}

String? canLiberoIn(SetData s, SetState st, String replacedId) {
  if (s.liberoIds.isEmpty) return 'Nessun libero in formazione';
  if (st.liberoReplaced != null) return 'Il libero è già in campo';
  final idx = st.court.indexOf(replacedId);
  if (idx < 0) return 'Giocatore non in campo';
  if (idx != 0 && idx != 4 && idx != 5) return 'Il libero entra solo in seconda linea';
  if (idx == 0 && st.weServe) return 'Il libero non può battere';
  return null;
}

class MatchSummary {
  int setsUs = 0;
  int setsThem = 0;
  final List<SetState> sets = [];
  bool get over => setsUs >= 3 || setsThem >= 3;
}

MatchSummary summarize(MatchData m) {
  final sum = MatchSummary();
  for (final s in m.sets) {
    final st = replaySet(m, s);
    sum.sets.add(st);
    if (st.finished) {
      if (st.us > st.them) {
        sum.setsUs++;
      } else {
        sum.setsThem++;
      }
    }
  }
  return sum;
}

/// giocatore -> fondamentale -> valutazione -> conteggio
Map<String, Map<String, Map<String, int>>> computeStats(MatchData m,
    {int? setIndex}) {
  final res = <String, Map<String, Map<String, int>>>{};
  for (var i = 0; i < m.sets.length; i++) {
    if (setIndex != null && setIndex != i) continue;
    for (final e in m.sets[i].events) {
      if (e.type != 'action') continue;
      final pid = e.playerId;
      final sk = e.skill;
      final gr = e.grade;
      if (pid == null || sk == null || gr == null) continue;
      final bySkill = res.putIfAbsent(pid, () => {});
      final byGrade = bySkill.putIfAbsent(sk, () => {});
      byGrade[gr] = (byGrade[gr] ?? 0) + 1;
    }
  }
  return res;
}

String fmtClock(int sec) {
  final mm = (sec ~/ 60).toString().padLeft(2, '0');
  final ss = (sec % 60).toString().padLeft(2, '0');
  return '$mm:$ss';
}

String fmtMin(int sec) => "${sec ~/ 60}'";

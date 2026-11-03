import 'package:flutter_test/flutter_test.dart';
import 'package:scout_pallavolo/engine.dart';
import 'package:scout_pallavolo/models.dart';

MatchData _match() {
  final players = [
    for (var i = 1; i <= 9; i++) Player(id: 'p$i', number: i, name: 'G$i', roles: i == 9 ? ['L'] : ['S']),
  ];
  return MatchData(
    id: 'm',
    opponent: 'Test',
    competition: '',
    home: true,
    date: 0,
    teamName: 'Noi',
    jerseyColor: 0xFF1F6FD1,
    liberoColor: 0xFFE9C46A,
    players: players,
  );
}

void main() {
  test('cambio palla fa ruotare', () {
    final m = _match();
    final s = SetData(number: 1, lineup: ['p1', 'p2', 'p3', 'p4', 'p5', 'p6'], liberoId: 'p9', weServeFirst: false);
    m.sets.add(s);
    s.events.add(const GameEvent(type: 'pointUs', t: 0));
    final st = replaySet(m, s);
    expect(st.us, 1);
    expect(st.weServe, true);
    expect(st.court.first, 'p2');
  });

  test('fine set a 25 con due punti di scarto', () {
    final m = _match();
    final s = SetData(number: 1, lineup: ['p1', 'p2', 'p3', 'p4', 'p5', 'p6'], liberoId: null, weServeFirst: true);
    for (var i = 0; i < 24; i++) {
      s.events.add(const GameEvent(type: 'pointUs', t: 0));
      s.events.add(const GameEvent(type: 'pointThem', t: 0));
    }
    s.events.add(const GameEvent(type: 'pointUs', t: 0));
    expect(replaySet(m, s).finished, false);
    s.events.add(const GameEvent(type: 'pointUs', t: 0));
    expect(replaySet(m, s).finished, true);
  });

  test('regola del rientro', () {
    final m = _match();
    final s = SetData(number: 1, lineup: ['p1', 'p2', 'p3', 'p4', 'p5', 'p6'], liberoId: 'p9', weServeFirst: true);
    s.events.add(const GameEvent(type: 'sub', t: 0, outId: 'p2', inId: 'p7'));
    final st = replaySet(m, s);
    expect(st.subsUsed, 1);
    expect(canSub(m, s, st, 'p7', 'p8'), isNotNull);
    expect(canSub(m, s, st, 'p7', 'p2'), isNull);
    expect(canSub(m, s, st, 'p3', 'p2'), isNotNull);
  });

  test('il libero esce quando ruota in prima linea', () {
    final m = _match();
    final s = SetData(number: 1, lineup: ['p1', 'p2', 'p3', 'p4', 'p5', 'p6'], liberoId: 'p9', weServeFirst: false);
    s.events.add(const GameEvent(type: 'liberoIn', t: 0, outId: 'p5'));
    expect(replaySet(m, s).court[4], 'p9');
    s.events.add(const GameEvent(type: 'pointUs', t: 0));
    final st = replaySet(m, s);
    expect(st.court[3], 'p5');
    expect(st.liberoOnCourt, false);
  });

  test('giocatore con ruoli multipli e vecchio formato', () {
    final old = Player.fromJson({'id': 'a', 'number': 3, 'name': 'X', 'role': 'C'});
    expect(old.roles, ['C']);
    final multi = Player(id: 'b', number: 4, name: 'Y', roles: ['S', 'L']);
    expect(multi.canLibero, true);
    expect(multi.onlyLibero, false);
    expect(multi.fieldRoles, ['S']);
    final m = _match()..players.add(multi);
    final s = SetData(number: 1, lineup: ['p1', 'p2', 'p3', 'p4', 'p5', 'p6'], liberoId: 'b', weServeFirst: true);
    expect(m.roleIn(s, 'b'), 'L');
    s.roles['p1'] = 'O';
    expect(m.roleIn(s, 'p1'), 'O');
  });

  test('8 sostituzioni per set', () {
    final m = _match();
    for (var i = 10; i <= 20; i++) {
      m.players.add(Player(id: 'q$i', number: i, name: 'R$i', roles: ['S']));
    }
    final s = SetData(number: 1, lineup: ['p1', 'p2', 'p3', 'p4', 'p5', 'p6'], liberoId: null, weServeFirst: true);
    final outs = ['p1', 'p2', 'p3', 'p4', 'p5', 'p6'];
    for (var i = 0; i < 6; i++) {
      s.events.add(GameEvent(type: 'sub', t: 0, outId: outs[i], inId: 'q${10 + i}'));
    }
    s.events.add(const GameEvent(type: 'sub', t: 0, outId: 'q10', inId: 'p1'));
    var st = replaySet(m, s);
    expect(canSub(m, s, st, 'q11', 'p2'), isNull);
    s.events.add(const GameEvent(type: 'sub', t: 0, outId: 'q11', inId: 'p2'));
    st = replaySet(m, s);
    expect(st.subsUsed, 8);
    expect(canSub(m, s, st, 'q12', 'p3'), isNotNull);
    m.maxSubs = 6;
    expect(canSub(m, s, replaySet(m, s), 'q12', 'p3'), isNotNull);
  });

  test('due liberi: entra il secondo, cambio libero, uscita in rotazione', () {
    final m = _match()..players.add(Player(id: 'p10', number: 10, name: 'L2', roles: ['L']));
    final s = SetData(number: 1, lineup: ['p1', 'p2', 'p3', 'p4', 'p5', 'p6'], liberoIds: ['p9', 'p10'], weServeFirst: false);
    s.events.add(const GameEvent(type: 'liberoIn', t: 0, outId: 'p5', inId: 'p10'));
    var st = replaySet(m, s);
    expect(st.court[4], 'p10');
    expect(m.roleIn(s, 'p10'), 'L');
    s.events.add(const GameEvent(type: 'liberoSwap', t: 0, outId: 'p10', inId: 'p9'));
    st = replaySet(m, s);
    expect(st.court[4], 'p9');
    expect(st.liberoIn, 'p9');
    expect(benchPlayers(m, s, st).any((p) => p.id == 'p10' || p.id == 'p5'), false);
    s.events.add(const GameEvent(type: 'pointUs', t: 0));
    st = replaySet(m, s);
    expect(st.court[3], 'p5');
    expect(st.liberoOnCourt, false);
    expect(canSub(m, s, st, 'p5', 'p10'), isNotNull);
  });

  test('vecchio formato con un solo libero', () {
    final s = SetData.fromJson({'number': 1, 'lineup': ['a', 'b', 'c', 'd', 'e', 'f'], 'liberoId': 'x', 'weServeFirst': true, 'events': []});
    expect(s.liberoIds, ['x']);
  });

  test('schieramento dopo che la palla passa di là', () {
    final players = [
      Player(id: 'P', number: 1, name: 'Pal', roles: ['P']),
      Player(id: 'S1', number: 2, name: 'Sch1', roles: ['S']),
      Player(id: 'C1', number: 3, name: 'Cen1', roles: ['C']),
      Player(id: 'O', number: 4, name: 'Opp', roles: ['O']),
      Player(id: 'S2', number: 5, name: 'Sch2', roles: ['S']),
      Player(id: 'C2', number: 6, name: 'Cen2', roles: ['C']),
    ];
    final m = MatchData(id: 'm', opponent: 'x', competition: '', home: true, date: 0, teamName: 'n',
        jerseyColor: 0, liberoColor: 0, players: players);
    // pos1 P, pos2 S1, pos3 C1, pos4 O, pos5 S2, pos6 C2
    final s = SetData(number: 1, lineup: ['P', 'S1', 'C1', 'O', 'S2', 'C2'], weServeFirst: false);
    var st = replaySet(m, s);
    expect(st.switched, false);
    expect(displayOrder(m, s, st), [3, 2, 1, 4, 5, 0]);
    // in ricezione: ricezione e alzata non spostano nessuno
    s.events.add(const GameEvent(type: 'action', t: 0, playerId: 'S2', skill: 'Ricezione', grade: '+'));
    s.events.add(const GameEvent(type: 'action', t: 0, playerId: 'P', skill: 'Alzata', grade: '+'));
    expect(replaySet(m, s).switched, false);
    // attacco: la palla passa, si va in schieramento
    s.events.add(const GameEvent(type: 'action', t: 0, playerId: 'O', skill: 'Attacco', grade: '+'));
    st = replaySet(m, s);
    expect(st.switched, true);
    final order = displayOrder(m, s, st).map((i) => st.court[i]).toList();
    // prima linea: S1 sx, C1 centro, O dx; seconda: C2 sx, S2 centro, P dx
    expect(order, ['S1', 'C1', 'O', 'C2', 'S2', 'P']);
    // punto: si torna in rotazione
    s.events.add(const GameEvent(type: 'pointUs', t: 0));
    st = replaySet(m, s);
    expect(st.switched, false);
    // ora battiamo noi: dopo la battuta schieramento subito
    s.events.add(GameEvent(type: 'action', t: 0, playerId: st.court[0], skill: 'Battuta', grade: '!'));
    expect(replaySet(m, s).switched, true);
  });
}

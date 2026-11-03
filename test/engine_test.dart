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
}

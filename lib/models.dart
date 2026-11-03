import 'dart:math';

final _rnd = Random();
String newId() =>
    '${DateTime.now().microsecondsSinceEpoch}${_rnd.nextInt(99999)}';

const skills = ['Battuta', 'Ricezione', 'Alzata', 'Attacco', 'Muro', 'Difesa'];
const grades = ['#', '+', '!', '-', '/', '='];
const roles = ['P', 'S', 'C', 'O', 'L'];
const roleNames = {
  'P': 'Palleggiatore',
  'S': 'Schiacciatore',
  'C': 'Centrale',
  'O': 'Opposto',
  'L': 'Libero',
};

class Player {
  String id;
  int number;
  String name;
  /// Ruoli che sa fare, il primo è quello principale. Es. ['S', 'O'] o ['S', 'L'].
  List<String> roles;

  Player({
    required this.id,
    required this.number,
    required this.name,
    required List<String> roles,
  }) : roles = roles.isEmpty ? ['S'] : List.of(roles);

  String get role => roles.first;
  bool get canLibero => roles.contains('L');
  bool get onlyLibero => roles.every((r) => r == 'L');
  List<String> get fieldRoles => roles.where((r) => r != 'L').toList();
  String get rolesShort => roles.join('/');
  String get rolesLabel => roles.map((r) => roleNames[r] ?? r).join(', ');

  Map<String, dynamic> toJson() =>
      {'id': id, 'number': number, 'name': name, 'roles': roles};

  factory Player.fromJson(Map<String, dynamic> j) {
    final raw = j['roles'];
    final roles = raw is List
        ? raw.map((e) => e as String).toList()
        : [(j['role'] as String?) ?? 'S'];
    return Player(
      id: j['id'] as String,
      number: (j['number'] as num).toInt(),
      name: j['name'] as String,
      roles: roles,
    );
  }

  Player copy() => Player(id: id, number: number, name: name, roles: roles);
}

class Team {
  String name;
  int jerseyColor;
  int liberoColor;
  List<Player> players;

  Team({
    required this.name,
    required this.jerseyColor,
    required this.liberoColor,
    required this.players,
  });

  factory Team.empty() => Team(
        name: 'La mia squadra',
        jerseyColor: 0xFF1F6FD1,
        liberoColor: 0xFFE9C46A,
        players: [],
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'jerseyColor': jerseyColor,
        'liberoColor': liberoColor,
        'players': players.map((p) => p.toJson()).toList(),
      };

  factory Team.fromJson(Map<String, dynamic> j) => Team(
        name: j['name'] as String,
        jerseyColor: (j['jerseyColor'] as num).toInt(),
        liberoColor: (j['liberoColor'] as num).toInt(),
        players: (j['players'] as List)
            .map((e) => Player.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Un evento del set. Tutto lo stato (punteggio, rotazioni, cambi) si
/// ricava rigiocando gli eventi: così "Annulla" è solo togliere l'ultimo.
///
/// type: action | pointUs | pointThem | timeout | sub | liberoIn | liberoOut
class GameEvent {
  final String type;
  final int t; // secondi dal cronometro del set
  final String? playerId;
  final String? skill;
  final String? grade;
  final String? team; // 'us' | 'them'
  final String? outId;
  final String? inId;

  const GameEvent({
    required this.type,
    required this.t,
    this.playerId,
    this.skill,
    this.grade,
    this.team,
    this.outId,
    this.inId,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        't': t,
        if (playerId != null) 'playerId': playerId,
        if (skill != null) 'skill': skill,
        if (grade != null) 'grade': grade,
        if (team != null) 'team': team,
        if (outId != null) 'outId': outId,
        if (inId != null) 'inId': inId,
      };

  factory GameEvent.fromJson(Map<String, dynamic> j) => GameEvent(
        type: j['type'] as String,
        t: (j['t'] as num).toInt(),
        playerId: j['playerId'] as String?,
        skill: j['skill'] as String?,
        grade: j['grade'] as String?,
        team: j['team'] as String?,
        outId: j['outId'] as String?,
        inId: j['inId'] as String?,
      );
}

class SetData {
  int number;
  /// 6 id: indice 0 = posizione 1 ... indice 5 = posizione 6
  List<String> lineup;
  String? liberoId;
  bool weServeFirst;
  List<GameEvent> events;
  /// ruolo giocato in questo set (id giocatore -> 'P','S','C','O')
  Map<String, String> roles;
  int clockMs;
  int? runningSince;

  SetData({
    required this.number,
    required this.lineup,
    required this.liberoId,
    required this.weServeFirst,
    List<GameEvent>? events,
    Map<String, String>? roles,
    this.clockMs = 0,
    this.runningSince,
  })  : events = events ?? [],
        roles = roles ?? {};

  bool get running => runningSince != null;

  int elapsedMs() {
    final rs = runningSince;
    if (rs == null) return clockMs;
    return clockMs + (DateTime.now().millisecondsSinceEpoch - rs);
  }

  int elapsedSec() => elapsedMs() ~/ 1000;

  void start() {
    runningSince ??= DateTime.now().millisecondsSinceEpoch;
  }

  void pause() {
    if (runningSince != null) {
      clockMs = elapsedMs();
      runningSince = null;
    }
  }

  Map<String, dynamic> toJson() => {
        'number': number,
        'lineup': lineup,
        'liberoId': liberoId,
        'weServeFirst': weServeFirst,
        'events': events.map((e) => e.toJson()).toList(),
        'roles': roles,
        'clockMs': clockMs,
        'runningSince': runningSince,
      };

  factory SetData.fromJson(Map<String, dynamic> j) => SetData(
        number: (j['number'] as num).toInt(),
        lineup: (j['lineup'] as List).map((e) => e as String).toList(),
        liberoId: j['liberoId'] as String?,
        weServeFirst: j['weServeFirst'] as bool,
        events: (j['events'] as List)
            .map((e) => GameEvent.fromJson(e as Map<String, dynamic>))
            .toList(),
        roles: (j['roles'] as Map?)?.map((k, v) => MapEntry(k as String, v as String)) ?? {},
        clockMs: (j['clockMs'] as num?)?.toInt() ?? 0,
        runningSince: (j['runningSince'] as num?)?.toInt(),
      );
}

class MatchData {
  String id;
  String opponent;
  String competition;
  bool home;
  int date;
  String teamName;
  int jerseyColor;
  int liberoColor;
  List<Player> players;
  List<SetData> sets;
  bool finished;
  /// sostituzioni per set (8 dal nuovo regolamento FIVB 2026, 6 il vecchio)
  int maxSubs;

  MatchData({
    required this.id,
    required this.opponent,
    required this.competition,
    required this.home,
    required this.date,
    required this.teamName,
    required this.jerseyColor,
    required this.liberoColor,
    required this.players,
    List<SetData>? sets,
    this.finished = false,
    this.maxSubs = 8,
  }) : sets = sets ?? [];

  Player? player(String? id) {
    if (id == null) return null;
    for (final p in players) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Ruolo che il giocatore ricopre nel set (L se è il libero del set).
  String roleIn(SetData s, String? id) {
    if (id == null) return '';
    if (id == s.liberoId) return 'L';
    final r = s.roles[id];
    if (r != null) return r;
    final p = player(id);
    if (p == null) return '';
    final f = p.fieldRoles;
    return f.isEmpty ? p.role : f.first;
  }

  /// "#7" per un id giocatore
  String nr(String? id) {
    final p = player(id);
    return p == null ? '?' : '#${p.number}';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'opponent': opponent,
        'competition': competition,
        'home': home,
        'date': date,
        'teamName': teamName,
        'jerseyColor': jerseyColor,
        'liberoColor': liberoColor,
        'players': players.map((p) => p.toJson()).toList(),
        'sets': sets.map((s) => s.toJson()).toList(),
        'finished': finished,
        'maxSubs': maxSubs,
      };

  factory MatchData.fromJson(Map<String, dynamic> j) => MatchData(
        id: j['id'] as String,
        opponent: j['opponent'] as String,
        competition: (j['competition'] as String?) ?? '',
        home: (j['home'] as bool?) ?? true,
        date: (j['date'] as num).toInt(),
        teamName: j['teamName'] as String,
        jerseyColor: (j['jerseyColor'] as num).toInt(),
        liberoColor: (j['liberoColor'] as num).toInt(),
        players: (j['players'] as List)
            .map((e) => Player.fromJson(e as Map<String, dynamic>))
            .toList(),
        sets: (j['sets'] as List)
            .map((e) => SetData.fromJson(e as Map<String, dynamic>))
            .toList(),
        finished: (j['finished'] as bool?) ?? false,
        maxSubs: (j['maxSubs'] as num?)?.toInt() ?? 8,
      );
}

class AppData {
  Team team;
  List<MatchData> matches;
  int? lastBackup;

  AppData({required this.team, required this.matches, this.lastBackup});

  Map<String, dynamic> toJson() => {
        'version': 1,
        'team': team.toJson(),
        'matches': matches.map((m) => m.toJson()).toList(),
        if (lastBackup != null) 'lastBackup': lastBackup,
      };

  factory AppData.fromJson(Map<String, dynamic> j) => AppData(
        team: Team.fromJson(j['team'] as Map<String, dynamic>),
        matches: (j['matches'] as List)
            .map((e) => MatchData.fromJson(e as Map<String, dynamic>))
            .toList(),
        lastBackup: (j['lastBackup'] as num?)?.toInt(),
      );
}

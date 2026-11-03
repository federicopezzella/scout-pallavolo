import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'models.dart';

/// Tutti i dati in un file JSON locale, salvato a ogni modifica.
class AppStore extends ChangeNotifier {
  AppData data = AppData(team: Team.empty(), matches: []);
  File? _file;
  Future<void> _pending = Future.value();

  Future<void> load() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}/scout_data.json');
      _file = f;
      if (await f.exists()) {
        final txt = await f.readAsString();
        try {
          data = AppData.fromJson(jsonDecode(txt) as Map<String, dynamic>);
        } catch (e) {
          // file rovinato: lo mettiamo da parte invece di sovrascriverlo
          await f.copy('${f.path}.bak-${DateTime.now().millisecondsSinceEpoch}');
          debugPrint('Errore lettura dati: $e');
        }
      }
    } catch (e) {
      debugPrint('Errore apertura archivio: $e');
    }
  }

  Future<void> save() {
    notifyListeners();
    _pending = _pending.then((_) => _write());
    return _pending;
  }

  Future<void> _write() async {
    final f = _file;
    if (f == null) return;
    try {
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(jsonEncode(data.toJson()), flush: true);
      await tmp.rename(f.path);
    } catch (e) {
      debugPrint('Errore salvataggio: $e');
    }
  }
}

final store = AppStore();

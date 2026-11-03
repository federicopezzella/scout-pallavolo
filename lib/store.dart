import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Tutti i dati in un JSON locale, salvato a ogni modifica:
/// file su Android/iOS, memoria del browser (localStorage) nella webapp.
class AppStore extends ChangeNotifier {
  static const _webKey = 'scout_data';
  AppData data = AppData(team: Team.empty(), matches: []);
  File? _file;
  SharedPreferences? _prefs;
  Future<void> _pending = Future.value();

  Future<void> load() async {
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        _prefs = prefs;
        final txt = prefs.getString(_webKey);
        if (txt != null) {
          data = AppData.fromJson(jsonDecode(txt) as Map<String, dynamic>);
        }
      } catch (e) {
        debugPrint('Errore lettura dati web: $e');
      }
      return;
    }
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
    if (kIsWeb) {
      try {
        await _prefs?.setString(_webKey, jsonEncode(data.toJson()));
      } catch (e) {
        debugPrint('Errore salvataggio web: $e');
      }
      return;
    }
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

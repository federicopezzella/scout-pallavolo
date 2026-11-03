import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'home.dart';

/// Esporta e importa tutti i dati (rosa + partite) in un file JSON.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _busy = false;

  void _msg(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _fileName() {
    final d = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return 'scout-volley-backup-${d.year}-${two(d.month)}-${two(d.day)}_${two(d.hour)}${two(d.minute)}.json';
  }

  Future<void> _export(BuildContext btnContext) async {
    setState(() => _busy = true);
    try {
      final name = _fileName();
      final json = const JsonEncoder.withIndent(' ').convert(store.data.toJson());
      final bytes = Uint8List.fromList(utf8.encode(json));
      final box = btnContext.findRenderObject() as RenderBox?;
      final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
      final result = await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'application/json', name: name)],
        fileNameOverrides: [name],
        subject: 'Backup Scout Volley',
        sharePositionOrigin: origin,
      ));
      if (result.status != ShareResultStatus.dismissed) {
        store.data.lastBackup = DateTime.now().millisecondsSinceEpoch;
        await store.save();
        _msg('Backup creato: $name');
      }
    } catch (e) {
      _msg('Esportazione non riuscita: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    setState(() => _busy = true);
    try {
      final picked = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
      final bytes = (picked == null || picked.files.isEmpty) ? null : picked.files.first.bytes;
      if (bytes == null) return;
      final AppData incoming;
      try {
        incoming = AppData.fromJson(jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
      } catch (_) {
        _msg('Il file non è un backup di Scout Volley valido');
        return;
      }
      if (!mounted) return;
      final existing = store.data.matches.map((m) => m.id).toSet();
      final newOnes = incoming.matches.where((m) => !existing.contains(m.id)).toList();
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Importa backup'),
          content: Text(
            'Il file contiene ${incoming.matches.length} partite e ${incoming.team.players.length} giocatori '
            '(squadra "${incoming.team.name}").\n\n'
            'Partite non ancora presenti qui: ${newOnes.length}.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
            OutlinedButton(
              onPressed: newOnes.isEmpty ? null : () => Navigator.pop(ctx, 'merge'),
              child: Text('Aggiungi ${newOnes.length} partite'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'replace'),
              child: const Text('Sostituisci tutto'),
            ),
          ],
        ),
      );
      if (choice == 'replace') {
        if (!mounted) return;
        final sure = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Sostituire tutti i dati?'),
            content: const Text('Rosa e partite attuali verranno sostituite da quelle del file. Se vuoi tenerle, esporta prima un backup.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sostituisci')),
            ],
          ),
        );
        if (sure != true) return;
        store.data = incoming;
        await store.save();
        _msg('Dati ripristinati dal backup');
      } else if (choice == 'merge') {
        store.data.matches.addAll(newOnes);
        if (store.data.team.players.isEmpty) store.data.team = incoming.team;
        await store.save();
        _msg('Aggiunte ${newOnes.length} partite');
      }
    } catch (e) {
      _msg('Importazione non riuscita: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final last = store.data.lastBackup;
        return Scaffold(
          appBar: AppBar(title: const Text('Backup')),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(
                    'Dati attuali: ${store.data.team.players.length} giocatori, ${store.data.matches.length} partite.',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    last == null ? 'Ultimo backup: mai' : 'Ultimo backup: ${fmtDate(last)}',
                    style: TextStyle(color: last == null ? C.accent : C.muted),
                  ),
                  const SizedBox(height: 24),
                  Builder(
                    builder: (btnContext) => SizedBox(
                      height: 60,
                      child: FilledButton.icon(
                        onPressed: _busy ? null : () => _export(btnContext),
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Esporta backup', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Crea un file .json con rosa e partite. Salvalo in File, su Drive/iCloud o mandalo a te stesso.',
                    style: TextStyle(color: C.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    height: 60,
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _import,
                      icon: const Icon(Icons.download),
                      label: const Text('Importa backup', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Scegli un file di backup: puoi sostituire tutti i dati oppure aggiungere solo le partite che mancano. '
                    'Serve anche per passare i dati da un dispositivo all\'altro (es. dalla webapp all\'app).',
                    style: TextStyle(color: C.muted, fontSize: 13),
                  ),
                  if (_busy) ...[
                    const SizedBox(height: 24),
                    const Center(child: CircularProgressIndicator()),
                  ],
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}

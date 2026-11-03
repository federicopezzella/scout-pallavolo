# Scout Volley

App Android (Flutter) per lo scout di pallavolo in tempo reale, pensata per tablet in orizzontale. Funziona completamente offline.

## Funzioni (versione 0.1)

- **Rosa e divise**: giocatori con numero, nome e ruolo; colore della divisa e del libero a scelta.
- **Home**: nuova partita, partita in corso con "Riprendi", elenco partite precedenti (tieni premuto per eliminare).
- **Formazione** per ogni set: 6 posizioni, libero, chi batte.
- **Inserimento live** in 3 tocchi: maglia → fondamentale → valutazione (`# + ! - / =`).
- Punteggio, rotazioni e fine set automatici; **Annulla** dell'ultima azione.
- **Cambi** (max 6 per set, regola del rientro) e **libero** separato (solo seconda linea, esce da solo quando ruota in prima linea).
- **Cronometro del set**, minuto di ogni timeout e cambio, **grafico dell'andamento del punteggio** con i marcatori.
- **Statistiche** per partita e per set; efficienza attacco e positività ricezione.

## Come ottenere l'APK

Ogni push su `main` avvia la build in GitHub Actions. L'APK si trova in **Releases** (`scout-volley-N.apk`).

Per aggiornare l'app senza disinstallarla (e senza perdere i dati) serve una firma fissa: va salvata come secret del repository `DEBUG_KEYSTORE_B64` (Settings → Secrets and variables → Actions).

## Sviluppo in locale

```bash
flutter create --platforms=android --org it.scoutvolley --project-name scout_pallavolo .
flutter run
flutter test
```

La cartella `android/` viene generata da `flutter create` e non è nel repository.

## Struttura

- `lib/models.dart` – dati (giocatori, partite, set, eventi)
- `lib/engine.dart` – regole: il set si ricostruisce rigiocando gli eventi
- `lib/store.dart` – salvataggio JSON locale
- `lib/screens/` – schermate
- `lib/widgets.dart` – maglia, grafico, componenti

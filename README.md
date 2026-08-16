# GPS Pointer

GPS Pointer Ã¨ un'app Android per aiutare installatori e tecnici a individuare
la direzione di un radiofaro partendo dalla posizione corrente del telefono.
Fornisce distanza, azimut, mappa, bussola orizzontale, inclinometro per il tilt
dell'antenna e una guida AR approssimativa tramite fotocamera.

Baseline corrente: **1.0.0+21**
Piattaforma: **Android**
Package: `io.github.fraidotube.gpspointer`

## Funzioni principali

- radiofari ordinati automaticamente dal piÃ¹ vicino;
- ricerca per nome, ID o coordinate e filtro entro un raggio configurabile;
- distanza e azimut rispetto alla posizione corrente;
- Google Maps con osservatore, radiofaro e linea di collegamento;
- bussola Azimut in landscape con stabilizzazione e guida illustrata;
- modalitÃ  Tilt in portrait, usando gravitÃ  e accelerometro;
- modalitÃ  AR con istruzioni, stabilizzazione e bersaglio sui due assi;
- guida sonora facoltativa: bip piÃ¹ rapidi avvicinandosi e tono continuo al
  centro;
- archivio locale importabile ed esportabile in formato TXT v3;
- aggiunta manuale con ID automatico e coordinate GPS precompilate;
- identitÃ  leggibile del dispositivo e provenienza dei file esportati.

La bussola e la modalitÃ  AR aiutano il puntamento, ma non sostituiscono la
misura radio o il collaudo tecnico dell'installazione.


## Altimetria e simulazioni (1.0.0+21)

- nuovo pulsante **Altimetria** su ogni radiofaro;
- coordinate di partenza manuali oppure **CALCOLA DA QUI** via GPS;
- profilo terreno Open-Meteo / Copernicus DEM GLO-90;
- stesso motore numerico del server per curvatura terrestre K=4/3, LOS e prima Fresnel;
- distanza, azimut vero, tilt teorico, quote, margini e grafico del profilo;
- archivio locale delle simulazioni;
- eliminazione ed esportazione in formato versionato `.gpspsim`;
- nessun PDF generato dall'app.

## Primo avvio

1. Inserire un nome riconoscibile per il telefono.
2. Importare `radiofari_gps_pointer.txt`.
3. Concedere la posizione quando richiesta.
4. Attendere l'acquisizione GPS: l'elenco viene ordinato dal piÃ¹ vicino.
5. Selezionare un radiofaro e scegliere Mappa, Azimut, Tilt o AR.

Le quote mancanti vengono richieste a Open-Meteo. L'altezza del telefono sopra
il suolo viene chiesta soltanto nelle funzioni che la usano realmente: Tilt e
AR.

## Configurazione sviluppo

Requisiti della baseline:

- Flutter `3.44.8` stable;
- Dart `3.12.2`;
- Android SDK con API compatibile;
- Android minimo API 24;
- dispositivo reale con GPS; magnetometro necessario per Azimut e AR.

La chiave Google Maps Ã¨ letta da `android/local.properties`:

```properties
MAPS_API_KEY=CHIAVE_GOOGLE_MAPS
```

La chiave deve essere limitata almeno al package Android e alla Maps SDK for
Android. L'APK puÃ² essere distribuito ai collaudatori senza consegnare i
sorgenti o il file della chiave.

## Verifica e avvio

```powershell
flutter clean
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter run
```

Gate minimo: nessun errore in `flutter analyze`, tutti i test superati e prova
reale di GPS, Mappa, Azimut, Tilt, AR, audio e persistenza del catalogo.

## APK di test 1.0

```powershell
flutter build apk --release --build-name=1.0.0 --build-number=19
Copy-Item ".\build\app\outputs\flutter-apk\app-release.apk" ".\GPS-Pointer-1.0.0-rev19.apk"
```

Questa baseline usa ancora la firma debug anche per il build `release`: va bene
per il collaudo interno, ma prima di una distribuzione stabile occorre creare e
proteggere una chiave di firma release.

## Documentazione essenziale

- `docs/PROJECT_STATE.md`: fotografia completa per riprendere lo sviluppo.
- `docs/CHANGELOG.md`: evoluzione di tutte le versioni consegnate.
- `docs/ROADMAP.md`: prossimi macroblocchi, a partire dall'autenticazione LDAP.

Il repository Ã¨ privato e non Ã¨ associato a una licenza open source.

# GPS Pointer — Stato consolidato 1.0

Ultimo aggiornamento: 15 agosto 2026  
Baseline operativa: `1.0.0+19`  
Metodo: sviluppo SAFE, file completi, macroblocchi e collaudo su telefono reale.

Questo documento è la chiave di ripartenza del progetto. Descrive lo stato
corrente; la storia delle modifiche è soltanto in `CHANGELOG.md`.

## Identità del progetto

- nome app: `GPS Pointer`;
- progetto Flutter: `gps_pointer`;
- package Android: `io.github.fraidotube.gpspointer`;
- alias pubblico: `fraidotube` / Fraido;
- piattaforma supportata nella V1: Android;
- Android minimo: API 24;
- repository previsto: privato;
- distribuzione V1: APK consegnato direttamente ai colleghi collaudatori.

## Baseline verificata

- Flutter 3.44.8 stable, Dart 3.12.2;
- telefono principale: Samsung SM-A175F, Android 16 API 36;
- ultimo gate automatico comunicato: 63 test superati;
- collaudo reale confermato per Home, filtro raggio, ricerca, persistenza,
  import/export, Mappa, Azimut, Tilt, AR, istruzioni e guida sonora;
- corretto il tono centrato affinché rimanga continuo;
- APK target interno: `GPS-Pointer-1.0.0-rev19.apk`.

L'APK 1.0 è stato compilato impostando nome e build number da riga di comando.
Lo ZIP sorgente ricevuto dopo il collaudo dichiara ancora `0.11.0+18` nel
`pubspec.yaml`: prima del primo commit Git deve essere allineato a
`1.0.0+19`, senza cambiare altro.

Prima del primo commit Git va comunque rieseguito e conservato l'esito di:

```powershell
flutter analyze
flutter test
```

## Flusso dell'app

Al primo avvio l'app genera un ID tecnico casuale e persistente e chiede un nome
leggibile per il dispositivo. Successivamente importa il catalogo TXT v3.

Con un catalogo disponibile acquisisce automaticamente una posizione GPS, senza
bloccare la Home. Mostra tutti i radiofari ordinati dal più vicino e mantiene le
distanze anche con il filtro `Tutti`. Il filtro `Entro X km` limita solo i
risultati; ricerca e raggio possono essere usati insieme.

La sostituzione del catalogo si trova nell'ingranaggio `Impostazioni`. Un file
con nome non standard o proveniente da un altro dispositivo richiede conferma.
La sostituzione avviene soltanto dopo la validazione completa; in caso di errore
il catalogo precedente resta intatto.

## Strumenti di puntamento

### Azimut

- telefono orizzontale, schermata forzata in landscape;
- bussola centrata con informazioni ai lati;
- azimut riferito al nord geografico tramite declinazione Android;
- stabilizzazione temporale obbligatoria;
- indicazioni destra/sinistra e stato centrato;
- guida sonora disattivata inizialmente e attivabile dall'utente.

Il magnetometro è sensibile a pali, antenne, metallo, cavi e magneti. Se il dato
non è stabile il target viene nascosto e viene richiesta una nuova calibrazione.

### Tilt antenna

- telefono verticale in portrait;
- retro del telefono appoggiato al retro piano dell'antenna;
- schermo verso l'installatore e bordo superiore verso l'alto;
- usa gravità e accelerometro, non il magnetometro;
- chiede l'altezza del telefono sopra il suolo;
- indica `Alza`, `Abbassa` o `Tilt centrato`.

### AR

- fotocamera posteriore tramite implementazione Android Camera2;
- direzione orizzontale dalla bussola e verticale dall'accelerometro;
- bersaglio nascosto durante istruzioni e stabilizzazione;
- guide illustrate e pulsante per rivederle;
- stato centrato soltanto quando entrambi gli assi sono nella tolleranza;
- risultato dichiaratamente approssimativo, non topografico.

### Guida sonora

- bip lenti lontano dal target e progressivamente più rapidi avvicinandosi;
- tono continuo quando il motore dichiara `centrato`;
- arresto immediato uscendo dalla tolleranza, disattivando l'audio, aprendo le
  istruzioni, perdendo stabilità o lasciando la schermata;
- implementazione nativa Android tramite `ToneGenerator`.

## Quote e altezza dell'osservatore

- quota terreno del radiofaro: dal TXT oppure da Open-Meteo;
- altezza palo: campo separato nel TXT;
- quota antenna: quota terreno più altezza palo;
- quota terreno dell'osservatore: Open-Meteo;
- altezza osservatore: distanza verticale del telefono dal suolo, inserita a
  mano soltanto per Tilt e AR;
- la quota GPS automatica non viene usata per stimare l'altezza di un tetto o
  di un piano, perché il risultato osservato non è affidabile.

## Formato catalogo TXT v3

Nome standard: `radiofari_gps_pointer.txt`.

```text
GPS_POINTER_RADIOFARI;3
esportato_utc;id_dispositivo;nome_dispositivo
;;
id;nome;latitudine;longitudine;quota_terreno_m;altezza_palo_m;fonte_quota;accuratezza_orizzontale_m;accuratezza_verticale_m
MONTE-SUBASIO;Monte Subasio;43.057259;12.671109;;0;;;
```

Il file iniziale può avere metadata vuoti (`;;`). Ogni esportazione scrive il
timestamp UTC, l'ID tecnico e il nome del dispositivo che sta esportando; non
riutilizza l'identità del file importato. Il parser accetta il separatore `;`,
gestisce campi fra virgolette e rifiuta i decimali con virgola. I file v1 e v2
non sono compatibili con la baseline V1 finale.

L'ID di un radiofaro aggiunto dall'app viene generato dal nome. Le collisioni
ricevono un suffisso progressivo e l'ID non cambia se il nome viene modificato
successivamente.

## Dati locali e servizi esterni

Persistenza interna:

- catalogo validato in JSON nell'area privata dell'app;
- ID installazione e nome dispositivo nell'area privata dell'app;
- nessun archivio radiofari nel cloud dell'app.

Servizi esterni:

- Google Maps SDK for Android per la cartografia;
- Open-Meteo per le quote del terreno;
- servizi Android per GPS, sensori, declinazione magnetica e fotocamera.

La V1 non ha autenticazione, sincronizzazione aziendale o ruoli. La chiave Maps
è caricata dal progetto Android tramite `MAPS_API_KEY` in `local.properties`.
Non riportare mai il valore della chiave nella documentazione o nei log.

Il prossimo sviluppo già deciso è la V2 con autenticazione degli installatori
tramite LDAP aziendale. Requisiti e gate sono fissati in `ROADMAP.md`; endpoint,
schema LDAP e credenziali non sono ancora noti e non devono essere dedotti.

## Struttura del codice

- `lib/core`: modelli, parser, formule geografiche, motori Azimut/Tilt/AR e
  ricerca; non contiene UI;
- `lib/application`: controller dei cataloghi, posizione, puntamento, export e
  audio;
- `lib/infrastructure`: file locali, GPS, Open-Meteo, orientamento Android e
  selettore documenti;
- `lib/presentation`: Home, Mappa, Azimut, Tilt, AR, dialoghi e istruzioni;
- `android`: configurazione Android e canali nativi per declinazione e audio;
- `test`: test automatici di core, controller, persistenza e widget;
- `asset`: icona `fry_app.png`, logo `fry_pointer.png`, splash
  `fry_splash.png`.

## Dipendenze congelate più importanti

- `geolocator 14.0.3`;
- `google_maps_flutter 2.18.0`;
- `camera 0.12.0+2` con `camera_android 0.10.11`;
- `flutter_compass 0.8.1`;
- `sensors_plus 7.1.0`;
- `http 1.6.0`, `share_plus 13.3.0`, `file_selector 1.0.4`;
- `path_provider 2.1.5`, `url_launcher 6.3.2`.

Aggiornare le dipendenze soltanto in un macroblocco dedicato e dopo test di
regressione su dispositivo reale.

## Build, firma e segreti

Il build 1.0 interno viene prodotto con:

```powershell
flutter build apk --release --build-name=1.0.0 --build-number=19
```

La configurazione corrente firma il build release con la chiave debug. È adatta
al collaudo interno, non a una release pubblica o definitiva. Prima di cambiare
firma occorre considerare che Android accetta un aggiornamento soltanto se la
nuova APK è firmata con la stessa chiave dell'app installata.

Il repository è privato per decisione del proprietario. Anche in un repository
privato è preferibile escludere `local.properties`, chiavi di firma e password;
se una chiave Maps viene versionata per scelta esplicita, deve essere limitata a
package, certificato e API necessaria e va ruotata prima di rendere pubblico il
repository.

## Limiti noti

- precisione dipendente dalla qualità reale di GPS e sensori del telefono;
- magnetometro non affidabile vicino a masse metalliche o campi magnetici;
- AR indicativa e non sostitutiva del collaudo radio;
- quote Open-Meteo legate al modello altimetrico, non a una misura locale;
- nessuna autenticazione nella V1;
- nessuna sincronizzazione centralizzata del catalogo;
- compatibilità reale verificata principalmente sul Samsung SM-A175F;
- firma release definitiva non ancora configurata.

## Ripartenza SAFE

Per qualunque sviluppo futuro:

1. partire dallo ZIP o dal commit Git della baseline 1.0 realmente compilata;
2. eseguire `flutter analyze` e `flutter test` prima di modificare;
3. sviluppare un solo macroblocco;
4. non toccare asset o configurazione Maps se non necessario;
5. provare GPS, Azimut, Tilt e AR sul telefono reale;
6. incorporare ogni micro-fix nella baseline successiva;
7. aggiornare `CHANGELOG.md` e questo documento solo quando cambia lo stato.

Prima del primo commit eliminare anche `android/.gradle` e
`android/gps_pointer_android.iml`: sono file generati e non fanno parte della
baseline sorgente.

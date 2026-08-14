# Changelog

Tutte le versioni elencate derivano dai pacchetti realmente consegnati durante
lo sviluppo del 14-15 agosto 2026. Le correzioni minori sono mantenute perché
servono a capire perché il codice corrente contiene determinate scelte.

## 1.0.0+19 — 15 agosto 2026

- congelamento della prima APK destinata al collaudo dei colleghi;
- corretto il segnale centrato: `TONE_PROP_BEEP`, limitato a 35 ms, sostituito
  con un tono Android continuo;
- creato il catalogo pubblico iniziale con Croce di Pale e sei cime reali
  attorno a Foligno;
- CasaPacico e Monte di Test esclusi dal file predefinito destinato a Git.

## 0.11.0+18 — 15 agosto 2026

- acquisizione GPS automatica e non bloccante all'avvio;
- distanze e ordinamento dal più vicino disponibili subito in modalità `Tutti`;
- sostituzione TXT spostata dalla Home a `Impostazioni`;
- configurazione iniziale del nome dispositivo;
- ID tecnico casuale e persistente per installazione;
- nome dispositivo modificabile;
- introdotto il formato TXT v3 con timestamp UTC, ID e nome del dispositivo;
- ammesso il primo file v3 con metadata vuoti;
- conferma per file con nome non standard o provenienza differente;
- gli export usano sempre l'identità del dispositivo corrente;
- nuovo radiofaro precompilato con posizione e accuratezza GPS correnti;
- parser v1/v2 dismessi.

## 0.10.1+17 — 15 agosto 2026

- corretto l'overflow del dialogo raggio con tastiera aperta;
- modalità `Tutti` separata dall'origine GPS: rimuove soltanto il limite di
  distanza, mantenendo distanze e ordinamento già acquisiti.

## 0.10.0+16 — 15 agosto 2026

- filtro `Tutti` / `Entro X km` e raggio personalizzabile;
- ricerca combinata con filtro geografico;
- ordinamento e distanza dal radiofaro più vicino;
- guida sonora facoltativa in Azimut e Tilt;
- cadenza dei bip progressiva e stato centrato previsto come continuo;
- altezza del telefono richiesta soltanto in AR e Tilt;
- eliminata la proposta di misurare automaticamente l'altezza del piano tramite
  differenza fra GPS e modello altimetrico.

## 0.9.1+15 — 14 agosto 2026

- corretti un accesso nullable e una conversione `int`/`double` nel Tilt;
- Bussola Azimut forzata in landscape;
- layout dedicato con dati a sinistra, quadrante centrale e stato a destra;
- pannelli laterali scorrevoli sui display piccoli;
- ripristino del portrait all'uscita.

## 0.9.0+14 — 14 agosto 2026

- separate le modalità `Azimut orizzontale` e `Tilt antenna`;
- guide illustrate e overlay di istruzioni;
- stabilizzazione obbligatoria prima del puntamento;
- guida al movimento a forma di 8 quando la bussola è inaffidabile;
- Tilt portrait con gravità/accelerometro e controllo della posa;
- AR con istruzioni, mirino nascosto fino alla stabilizzazione e pulsante `?`;
- rimossa la falsa rappresentazione dell'accuratezza bussola in gradi;
- ID dei nuovi radiofari generato automaticamente dal nome con gestione delle
  collisioni.

## 0.8.0+13 — 14 agosto 2026

- bussola orizzontale riferita al nord geografico;
- controllo dell'orizzontalità tramite accelerometro;
- arresto controllato sui dispositivi senza magnetometro;
- ricerca locale per nome, ID o coordinate;
- inserimento manuale con validazione completa e sostituzione atomica;
- icona launcher separata `fry_app.png`;
- splash e logo interni mantenuti separati.

## 0.7.0 — 14 agosto 2026

- introdotta Google Maps con marker osservatore/radiofaro e linea geodetica;
- cerchio di accuratezza GPS;
- distanza, azimut, tilt e quote coerenti con AR;
- inquadratura automatica, tipi di mappa e traffico;
- copia coordinate e apertura nell'app Google Maps;
- configurazione Maps tramite `MAPS_API_KEY` in `local.properties`;
- splash Android e branding Fry consolidati.

## 0.6.2 — 14 agosto 2026

- warm-up basato su almeno due secondi di letture stabili;
- dispersione massima di 3 gradi durante la stabilizzazione;
- riavvio della finestra se la direzione deriva;
- timeout a 12 secondi con target nascosto e messaggio di instabilità;
- stessa stabilizzazione applicata alla bussola e all'AR.

## 0.6.1 — 14 agosto 2026

- ripristinata la lettura Android `heading`, verificata sul Samsung;
- rimossa `headingForCameraMode`, che sul dispositivo restava a zero.

## 0.6.0 — 14 agosto 2026

- introdotto il motore di puntamento V2;
- tre campioni GPS e scelta del più accurato;
- posizione e quota osservatore bloccate per la sessione;
- aggiornamento GPS soltanto su richiesta esplicita;
- rilevazione reale del magnetometro;
- declinazione magnetica Android e nord geografico;
- media circolare e filtro adattivo anche sul passaggio 359/0 gradi;
- diagnostica sensori, timeout e ricalibrazione separata.

## 0.5.4 — 14 agosto 2026

- chiusura ordinata di tastiera e dialogo prima dell'apertura AR;
- attesa della transizione per evitare sovrapposizioni nel widget tree e la
  schermata rossa osservata dopo l'inserimento dell'altezza.

## 0.5.3 — 14 agosto 2026

- corretto il segno dell'inclinazione rispetto all'asse ottico della fotocamera
  posteriore;
- puntamento verso l'alto positivo e verso il basso negativo.

## 0.5.2 — 14 agosto 2026

- bersaglio riferito all'area AR reale e non all'intero schermo;
- mirino reso più sottile;
- tolleranze ristrette con isteresi 2/1 gradi in ingresso e 3/1,5 in uscita;
- tema scuro globale;
- nome catalogo fissato a `radiofari_gps_pointer.txt`.

## 0.5.1 — 14 agosto 2026

- filtro passa-basso e limite di movimento per ridurre il rumore;
- prima isteresi di centratura, con soglie separate di ingresso e uscita.

## 0.5.0 — 14 agosto 2026

- puntamento AR completato sui due assi;
- inclinazione verticale da accelerometro;
- bersaglio mobile, frecce fuori campo e verde soltanto con entrambi gli assi
  centrati;
- Camera2 mantenuta come implementazione Android.

## 0.4.3 — 14 agosto 2026

- selezionato esplicitamente `camera_android 0.10.11` e Camera2 per evitare il
  conflitto CameraX/Gradle 9 sul classpath `concurrent-futures`.

## 0.4.2 — 14 agosto 2026

- toolchain Android portata a Java/Kotlin 17;
- aggiornata la configurazione Gradle necessaria alla compilazione AR.

## 0.4.1 — 14 agosto 2026

- micro-correzione lint del costruttore `PointingController`; comportamento
  invariato.

## 0.4.0 — 14 agosto 2026

- primo puntamento operativo con GPS osservatore e quota Open-Meteo;
- distanza, azimut vero, dislivello e tilt;
- bussola live e anteprima fotocamera con bersaglio orizzontale;
- quota GPS esclusa dal calcolo del puntamento;
- altezza osservatore e altezza palo mantenute separate.

## 0.3.1 — 14 agosto 2026

- quota rilevata sul posto esplicitata come MSL;
- attivato `useMSLAltitude` nell'adapter Android di Geolocator;
- sorgente salvata come `gps_msl_rilevato_sul_posto`;
- rimossa un'importazione ridondante nell'export.

## 0.3.0 — 14 agosto 2026

- introdotto TXT v2;
- quota automatica e aggiornamento tramite Open-Meteo;
- misura sul posto di coordinate, quota e accuratezze GPS;
- modifica manuale di quota terreno e altezza palo;
- calcolo quota antenna ed esportazione/condivisione TXT;
- primo branding Fry e splash.

## 0.2.1 — 14 agosto 2026

- micro-correzione lint del costruttore `CatalogueController` tramite factory e
  costruttore privato; comportamento dell'archivio invariato.

## 0.2.0 — 14 agosto 2026

- prima configurazione obbligatoria tramite TXT;
- selettore documenti Android;
- validazione completa prima della sostituzione;
- catalogo persistente e conservazione del precedente in caso di errore;
- prima Home con elenco radiofari.

## 0.1.1 — 14 agosto 2026

- corretti due rilievi lint `prefer_initializing_formals`; comportamento del
  core invariato.

## 0.1.0 — 14 agosto 2026

- modelli immutabili di coordinate, radiofaro e catalogo;
- distanza, azimut e normalizzazione angolare;
- primo parser TXT v1 con errori strutturati;
- repository astratto/in-memory e sostituzione dopo validazione;
- separazione fra quota terreno, altezza palo e quota antenna;
- primi test automatici con CasaPacico.

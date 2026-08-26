# GPS Pointer

GPS Pointer è un'app Android sviluppata in Flutter per supportare attività tecniche sul campo legate a Postazioni Radio, orientamento, analisi preliminare dei collegamenti radio, profili altimetrici, meteo operativo, rapporti d'intervento e servizi condivisi con GPS Pointer Server.

La release documentata è **GPS Pointer 2.7.0**, versione Android/Flutter **2.7.0+70**.

Il progetto è pensato per un utilizzo operativo da smartphone: alcune funzioni lavorano interamente sul dispositivo, altre usano servizi Internet esterni, mentre i dati che devono essere condivisi tra utenti o centralizzati vengono gestiti tramite GPS Pointer Server.

> **Azimuth e AR**
>
> Le funzioni **Azimuth** e **AR** sono sperimentali, ancora in sviluppo e soggette a test comparativi sul campo. Non sono strumenti certificati, non sono da considerarsi definitive e non sostituiscono strumentazione professionale.

## Modello generale

GPS Pointer non è soltanto un visualizzatore di coordinate. L'app riunisce in un unico ambiente strumenti che, durante un intervento, richiederebbero normalmente applicazioni o procedure separate.

Il modello operativo può essere sintetizzato così:

```text
Tecnico sul campo
       |
       v
GPS Pointer Android
       |
       +-- dati e strumenti locali
       |   - posizione e sensori
       |   - calcoli geometrici
       |   - simulazioni
       |   - archivio locale
       |   - PDF e condivisione
       |
       +-- servizi Internet
       |   - altimetria
       |   - meteo
       |   - radar precipitazioni
       |   - mappe e OpenStreetMap
       |   - GitHub Releases per l'updater
       |
       v
HTTPS / API autenticata
       |
       v
GPS Pointer Server
       |
       +-- catalogo condiviso delle Postazioni Radio
       +-- autenticazione e dispositivi
       +-- simulazioni condivise
       +-- Rapporti d'intervento
       +-- database Comida
       +-- feed News & Video
```

Questa separazione permette all'app di continuare a gestire localmente le attività che non richiedono condivisione, mantenendo sul server ciò che deve essere comune a più installazioni o amministrato centralmente.

## Home e organizzazione dell'app

La Home raccoglie le funzioni principali senza esporre direttamente gli strumenti diagnostici o di manutenzione.

Le aree operative correnti sono:

- **Postazioni Radio**
- **Copertura**
- **Punto Punto**
- **News & Video**
- **Comida**
- **Radar meteo**
- **Rapporto d'intervento**
- **Impostazioni**

L'interfaccia può essere visualizzata secondo due temi, **Semplice** e **Pro**. La scelta modifica la presentazione grafica della Home ma non cambia il significato delle funzioni disponibili.

Gli strumenti di Debug e diagnostica rimangono separati dalle normali attività operative e sono raggiungibili dalle Impostazioni.

## Postazioni Radio

La terminologia pubblica dell'app è **Postazioni Radio**. Nel codice possono ancora comparire identificatori storici contenenti termini come `radiofaro`, `radio_beacon` o equivalenti; si tratta di nomenclatura tecnica interna mantenuta per compatibilità con componenti precedenti.

Il catalogo raccoglie le coordinate e i dati necessari alle funzioni che lavorano rispetto a una postazione nota. Dall'app è possibile consultare e ricercare le Postazioni Radio, usarle nelle simulazioni di Copertura e selezionarle negli strumenti di puntamento.

Il catalogo locale può essere aggiornato dal GPS Pointer Server. È inoltre disponibile il flusso per aggiungere una nuova Postazione Radio quando previsto dall'interfaccia.

La disponibilità locale del catalogo evita di rendere ogni consultazione dipendente da una richiesta di rete; il server rimane invece il punto di riferimento per la distribuzione dei dati condivisi.

## Puntamento

Il requisito concettuale del puntamento è semplice: il tecnico può trovarsi sul posto senza conoscere visivamente dove si trovi la Postazione Radio da raggiungere.

A partire dalle coordinate del punto di osservazione e della Postazione Radio, GPS Pointer determina la direzione geometrica del target e utilizza i sensori disponibili sul dispositivo per rappresentare l'orientamento.

Il sistema comprende componenti distinti per posizione, orientamento, calcolo geografico e interfaccia di guida. La separazione tra questi livelli consente di confrontare soluzioni differenti senza alterare automaticamente il comportamento dei componenti storici.

### Azimuth

Azimuth rappresenta la parte sperimentale dedicata alla direzione orizzontale verso il target.

Nel progetto coesistono il motore storico protetto `PointingEngineV2` e componenti sperimentali sviluppati per attività di diagnostica e confronto. La presenza di questi componenti non costituisce una validazione dell'algoritmo sperimentale.

Le prove sul campo vengono utilizzate per raccogliere dati reali dai sensori, confrontare dispositivi e individuare eventuali cause di scostamento. Fino al completamento di tale processo, i risultati di Azimuth devono essere interpretati esclusivamente come supporto sperimentale.

### AR

La modalità AR utilizza la fotocamera e i dati di orientamento per sovrapporre indicazioni alla scena reale.

Lo scopo funzionale è guidare il tecnico verso la direzione della Postazione Radio anche quando il target non sia già riconoscibile a vista. Anche questa funzione rimane sperimentale: accuratezza e stabilità dipendono dai sensori, dall'ambiente e dal comportamento del dispositivo.

Il progetto mantiene separati i componenti AR dalla logica storica di puntamento proprio per poter evolvere e testare il sistema senza attribuire automaticamente ai nuovi algoritmi lo stesso stato delle funzioni consolidate.

### Tilt

Il **Tilt** è gestito come calcolo distinto dall'Azimuth.

Serve a descrivere la componente verticale teorica del collegamento in funzione delle quote, delle altezze considerate e della geometria tra i punti. È utilizzato nelle analisi di Copertura e Punto Punto.

## Copertura

La funzione **Copertura** analizza il collegamento tra una posizione di origine e una Postazione Radio selezionata dal catalogo.

Il punto di partenza può essere ricavato dalla posizione attuale oppure definito tramite coordinate o informazioni provenienti da un link Maps, secondo quanto disponibile nell'interfaccia.

Una simulazione può includere:

- distanza e geometria del collegamento;
- parametri associati ai due estremi;
- profilo altimetrico;
- andamento del terreno;
- linea ottica;
- prima zona di Fresnel;
- rappresentazione cartografica;
- Tilt teorico;
- salvataggio nell'archivio locale;
- esportazione e condivisione;
- invio al GPS Pointer Server.

È disponibile anche la ricerca delle Postazioni Radio più vicine quando richiesta dall'utente, così da confrontare rapidamente più destinazioni potenzialmente utilizzabili.

Il risultato deve essere considerato un supporto alla progettazione e al sopralluogo: dati altimetrici, posizione, modello del terreno e parametri inseriti incidono direttamente sulla qualità dell'analisi.

## Punto Punto (PTP)

**Punto Punto (PTP)** estende lo stesso approccio a un collegamento tra due estremi liberamente definiti.

Punto A e Punto B possono essere impostati usando posizione attuale, coordinate o dati ricavati da un link Maps. Nessuno dei due estremi deve necessariamente coincidere con una Postazione Radio presente nel catalogo.

Il calcolo comprende geometria, distanza, profilo altimetrico, terreno, linea ottica, prima zona di Fresnel, mappa e Tilt tra i due punti.

Le simulazioni PTP possono essere archiviate localmente, condivise, esportate e, quando previsto, inviate al server nello stesso ecosistema utilizzato dalle simulazioni di Copertura.

## Profili altimetrici, terreno, linea ottica e Fresnel

Le analisi radio utilizzano un profilo del terreno campionato lungo il percorso tra i due estremi.

Le quote possono essere ottenute mediante i provider altimetrici integrati nell'app. Il profilo viene quindi utilizzato per costruire una rappresentazione coerente di terreno, linea ottica e prima zona di Fresnel.

Questi elementi sono differenti e non vanno confusi:

- il **profilo altimetrico** descrive la quota del terreno lungo il percorso;
- la **linea ottica** rappresenta la congiungente geometrica tra le quote considerate ai due estremi;
- la **prima zona di Fresnel** aggiunge il volume teorico rilevante attorno alla linea di collegamento;
- il **Tilt** descrive l'angolo verticale teorico tra gli estremi.

Le analisi dipendono dalla qualità dei dati altimetrici disponibili e dalle altezze inserite. GPS Pointer non sostituisce un rilievo topografico o radioelettrico certificato.

## Simulazioni, archivio e formato `.gpspsim`

Le simulazioni possono essere conservate localmente per essere riaperte, revisionate o condivise in un secondo momento.

GPS Pointer dispone di servizi separati per importazione, esportazione, generazione PDF e scambio dei dati.

Il formato di interscambio dell'app è **`.gpspsim`**. Il documento contiene una struttura JSON versionata con i dati della simulazione e informazioni minime sulla sorgente del file. Durante l'importazione vengono verificati schema, versione e presenza dei dati richiesti.

L'associazione del formato con Android permette inoltre di aprire un file compatibile e trasferirlo al flusso di revisione dell'app.

Quando una simulazione viene inviata al GPS Pointer Server, lo stesso modello viene serializzato per la trasmissione autenticata. L'archivio locale e quello server svolgono quindi ruoli complementari: il primo è immediatamente disponibile sul dispositivo, il secondo rende il dato consultabile e gestibile in un contesto condiviso.

## Radar meteo e servizi meteo

Il modulo **Radar meteo** riunisce informazioni utili durante le attività esterne.

La schermata combina previsioni per il punto selezionato e visualizzazione dei frame radar delle precipitazioni. Le integrazioni utilizzate dal progetto hanno scopi distinti:

- **MET Norway** per le informazioni meteo;
- **RainViewer** per il radar precipitazioni;
- **Open-Meteo** per dati altimetrici e servizi di elevazione impiegati nelle funzioni che ne hanno bisogno.

La Home può mostrare anche informazioni meteo sintetiche quando posizione e servizio meteo sono disponibili.

I dati provengono da servizi esterni e possono essere temporaneamente non disponibili, ritardati o incompleti. L'app non modifica né certifica le informazioni ricevute dalle sorgenti.

## News & Video

**News & Video** è il punto di accesso dell'app ai contenuti TLC aggregati dal GPS Pointer Server.

L'app non interroga direttamente ogni singola sorgente editoriale o video. Effettua invece una richiesta autenticata al feed centralizzato del server, che restituisce collezioni distinte di news, video ed eventuali avvisi di raccolta.

Questa architettura consente di mantenere lato server la logica di acquisizione, normalizzazione e aggiornamento delle sorgenti, mentre il client Android rimane concentrato sulla consultazione.

I contenuti continuano ad appartenere alle rispettive fonti: GPS Pointer Server ne aggrega i riferimenti necessari alla visualizzazione e all'apertura dei collegamenti esterni.

## Rapporti d'intervento

La sezione **Rapporto d'intervento** serve a compilare e conservare la documentazione relativa a un'attività tecnica.

Il progetto comprende modello dati, gestione dell'archivio locale, firme, generazione PDF e condivisione del documento.

Il PDF viene costruito da un servizio applicativo dedicato e può essere utilizzato indipendentemente dalla disponibilità del server una volta generato localmente.

Quando l'utente sceglie di inviare il rapporto al GPS Pointer Server, l'app trasmette in modo autenticato i metadati del rapporto e il relativo PDF. Il server costituisce così l'archivio centralizzato dei rapporti condivisi, senza eliminare l'utilità della copia locale sul dispositivo.

## Comida

**Comida** è integrato in GPS Pointer come strumento per trovare, consultare e condividere locali utili durante l'attività sul territorio.

Non è un'app separata: utilizza posizione, accesso server e servizi esterni già presenti nell'ecosistema GPS Pointer.

### Cerca vicino a me

La ricerca parte dalla posizione corrente e utilizza un raggio selezionabile. I risultati provenienti dal database GPS Pointer vengono integrati con i locali ottenuti da OpenStreetMap tramite Overpass.

La ricerca può essere filtrata per testo, tipologia e cucina.

Quando i dati sono disponibili, una scheda può proporre azioni contestuali come:

- ottenere indicazioni;
- chiamare il locale;
- aprire il sito;
- cercare il locale su Google;
- modificare un record già presente nel database GPS Pointer;
- aggiungere al database condiviso un risultato proveniente da OpenStreetMap.

La ricerca Google viene aperta esternamente; GPS Pointer non esegue scraping dei risultati.

### Database GPS Pointer

I locali curati attraverso Comida vengono conservati sul GPS Pointer Server.

Un record può comprendere nome, tipologia, cucina, indirizzo, contatti, sito web, indicazione di prezzo, orario, descrizione, coordinate e bollino.

La distinzione tra risultati server e risultati OpenStreetMap permette di riconoscere i locali già presenti nel database condiviso e quelli ottenuti soltanto dalla sorgente esterna.

### Consigliati

La sezione **Consigliati** utilizza il database GPS Pointer e ordina i risultati in relazione alla posizione corrente.

In questo contesto la ricerca non è limitata allo stesso raggio utilizzato da "Cerca vicino a me", così da poter mostrare anche locali selezionati che si trovano più lontano.

### Aggiunta e modifica

Un locale può essere creato partendo dalla posizione corrente, da una ricerca per nome o indirizzo, da un link Maps oppure da coordinate inserite manualmente.

Quando il punto di partenza è un risultato OpenStreetMap, il form viene precompilato con i dati disponibili e conserva il riferimento alla sorgente OSM. Dopo il salvataggio, il locale diventa parte del database condiviso.

I record già presenti sul server possono essere modificati dall'app con richieste autenticate.

L'orario del locale è volutamente semplice e usa i campi Apertura e Chiusura. Il selettore corrente lavora su ore da 00 a 23 e minuti a intervalli di 15 minuti.

### Bollini

Comida supporta quattro classificazioni grafiche:

- **GOLD**
- **SILVER**
- **BRONZE**
- **SCONSIGLIATO**

Il bollino è un attributo del record Comida e viene distribuito insieme agli altri dati del locale.

### OpenStreetMap e Overpass

I risultati esterni vengono ottenuti da **OpenStreetMap** attraverso Overpass.

L'implementazione include più endpoint di fallback, timeout, cache temporanea e meccanismi di cooldown in caso di errore. Se i dati esterni non sono disponibili, l'app non li sostituisce con risultati inventati.

## GPS Pointer Server

GPS Pointer Server è un componente separato dall'app Android e viene mantenuto in un repository dedicato.

La sua funzione non è eseguire sul server tutti i calcoli dell'app, ma fornire un livello comune per autenticazione, dati condivisi e servizi centralizzati.

Il rapporto tra i due componenti è quindi:

```text
GPS Pointer Android
        |
        | HTTPS
        | autenticazione Bearer
        v
GPS Pointer Server
        |
        +-- account e dispositivi autorizzati
        +-- catalogo Postazioni Radio
        +-- simulazioni condivise
        +-- Rapporti d'intervento
        +-- Comida
        +-- News & Video
```

### Autenticazione e dispositivi

L'accesso ai servizi server parte da username e password.

Durante il login l'app invia anche un identificativo dell'installazione, il nome del dispositivo e la versione applicativa. Il server restituisce i dati dell'utente insieme a token di accesso e refresh.

Le chiamate che richiedono autenticazione usano il token Bearer. Quando possibile, il client tenta il refresh della sessione prima di richiedere un nuovo login.

Il modello è legato anche al dispositivo: una sessione può diventare non valida se il dispositivo viene revocato o se il refresh token non è più utilizzabile.

### Accesso rapido e biometria

L'app può abilitare uno sblocco rapido tramite i meccanismi biometrici o di autenticazione locale supportati da Android.

Quando questa opzione è attiva, il refresh token e le informazioni strettamente necessarie alla sessione vengono conservati tramite `FlutterSecureStorage`. Lo sblocco locale non sostituisce l'autenticazione server: dopo il riconoscimento del dispositivo viene comunque utilizzato il token salvato per ottenere una sessione valida.

Se il token non è più disponibile, è scaduto o è stato revocato, GPS Pointer torna alla normale autenticazione con password.

Il logout locale viene completato anche in assenza di connettività, cancellando i dati della sessione memorizzati sul dispositivo.

### Dati locali e dati condivisi

Non tutto ciò che viene creato nell'app deve necessariamente essere inviato al server.

In termini funzionali:

| Area | Locale sul dispositivo | Condivisione tramite server |
| --- | --- | --- |
| Postazioni Radio | catalogo utilizzabile dall'app | distribuzione/aggiornamento catalogo |
| Simulazioni | archivio, import/export, PDF | archivio condiviso |
| Rapporti | archivio e PDF | metadati e PDF centralizzati |
| Comida | consultazione e interazione client | database condiviso dei locali |
| News & Video | visualizzazione client | raccolta e normalizzazione feed |
| Meteo/radar | elaborazione e presentazione client | non costituisce archivio server GPS Pointer |

La presenza di una funzione server non implica che il corrispondente dato locale venga sempre sincronizzato automaticamente: l'invio avviene nei flussi previsti dall'interfaccia.

## Aggiornamento automatico dell'app

GPS Pointer include un updater Android dedicato.

Il controllo utilizza la **Latest Release** del repository GitHub dell'app. La release deve contenere l'asset `gps-pointer-release.json`, che descrive versione, build, nome dell'APK e hash SHA-256 atteso.

Il flusso è:

```text
GPS Pointer
    |
    +--> GitHub API: Latest Release
    |
    +--> gps-pointer-release.json
    |
    +--> confronto build locale/remota
    |
    +--> download APK
    |
    +--> verifica SHA-256
    |
    +--> installazione tramite Android
```

Un aggiornamento viene proposto solo quando il build number remoto è superiore a quello installato.

Prima dell'installazione l'APK scaricato viene verificato calcolando l'hash SHA-256 e confrontandolo con quello dichiarato nel manifest della release. Se il controllo non coincide, il file viene eliminato e l'aggiornamento viene interrotto.

La numerazione corrente segue il formato:

```text
2.7.0+70
```

`2.7.0` identifica la versione applicativa; `70` è il build number tecnico usato anche dal meccanismo di confronto dell'updater.

## Impostazioni

La sezione Impostazioni raccoglie configurazioni e strumenti che non devono occupare la Home principale.

Le aree comprendono gestione dell'account, aspetto, aggiornamenti, diagnostica, file di simulazione e archivio delle Postazioni Radio.

### Aspetto

L'utente può scegliere tra i temi:

- **Semplice**
- **Pro**

La selezione cambia la presentazione della Home mantenendo le stesse funzioni operative.

### Catalogo

Le impostazioni includono gli strumenti dedicati all'archivio delle Postazioni Radio, compreso l'aggiornamento dal server.

### File di simulazione

Le opzioni legate ai file gestiscono l'associazione e i flussi necessari ad aprire o importare documenti `.gpspsim`.

### Aggiornamenti

La sezione Aggiornamenti espone il controllo della versione e il flusso dell'updater descritto in precedenza.

## Debug e diagnostica

GPS Pointer contiene strumenti diagnostici separati dall'uso normale.

Sono destinati alla raccolta di informazioni durante sviluppo, test e analisi dei sensori. Tra i componenti presenti nel progetto figurano log diagnostici, schermate dedicate alla bussola e strumenti di laboratorio per i motori sperimentali.

Questa separazione è importante soprattutto per Azimuth e AR: una schermata diagnostica può mostrare dati o algoritmi in prova senza che tali risultati diventino automaticamente parte del comportamento operativo consolidato.

I log di diagnostica hanno lo scopo di rendere confrontabili prove eseguite su dispositivi e condizioni differenti; non rappresentano una certificazione della precisione del sensore o dell'algoritmo.

## Architettura del progetto Android

Il codice Flutter è organizzato in quattro aree principali:

```text
lib/
├── application/
├── core/
├── infrastructure/
└── presentation/
```

### `application/`

Coordina i casi d'uso dell'app e i servizi che collegano interfaccia, dominio e integrazioni.

Comprende, tra gli altri, autenticazione, updater, catalogo, Comida, posizione, orientamento, meteo, feed News & Video, simulazioni, rapporti, esportazione e invio al server.

### `core/`

Contiene modelli e logica centrale indipendente dall'interfaccia.

Qui risiedono il dominio delle Postazioni Radio, i modelli delle simulazioni, i calcoli geografici, i componenti di puntamento, AR, Tilt e la logica necessaria ai profili radio.

### `infrastructure/`

Implementa persistenza e integrazioni legate alla piattaforma o a servizi specifici.

Sono presenti repository JSON locali, provider di posizione, provider altimetrici, associazione file e componenti Android necessari all'installazione degli aggiornamenti.

### `presentation/`

Contiene schermate e widget dell'interfaccia.

Fra le schermate correnti figurano Home, Postazioni Radio, Copertura, Punto Punto, Comida, Radar meteo, Rapporti d'intervento, Impostazioni, autenticazione, simulazioni, Tilt, puntamento e strumenti diagnostici.

## Dipendenze esterne e servizi

GPS Pointer utilizza servizi esterni differenti a seconda della funzione.

Quelli esplicitamente integrati nel progetto comprendono:

- **Open-Meteo**, per elevazione e profili altimetrici;
- **MET Norway**, per informazioni meteo;
- **RainViewer**, per radar precipitazioni;
- **OpenStreetMap / Overpass**, per i locali esterni di Comida;
- **Google Maps**, tramite SDK Android per la componente cartografica dell'app;
- **GitHub Releases**, per distribuzione e aggiornamento dell'APK.

Il GPS Pointer Server può a sua volta utilizzare sorgenti esterne per costruire il feed News & Video. Tale raccolta è mantenuta lato server, non nel client Android.

La disponibilità di un servizio terzo non è sotto il controllo di GPS Pointer. Timeout, limiti, indisponibilità temporanee o variazioni delle API possono quindi influire sulle funzioni che ne dipendono.

## Sicurezza e privacy

La sicurezza applicativa è costruita attorno a connessioni HTTPS verso GPS Pointer Server, token di sessione e archiviazione locale sicura dei dati necessari all'accesso rapido.

Le password non vengono utilizzate come meccanismo di sblocco rapido locale: quando l'utente abilita questa funzione, il client conserva il refresh token nel secure storage e richiede l'autenticazione Android prima di riutilizzarlo.

Le chiamate server che richiedono autorizzazione utilizzano token Bearer. Le sessioni possono essere invalidate e i dispositivi possono essere revocati lato server.

Questo README non documenta password, token reali, chiavi, certificati, percorsi di deployment o dettagli dell'infrastruttura privata.

GPS Pointer utilizza inoltre posizione, fotocamera e sensori del dispositivo per le funzioni che ne hanno bisogno. I relativi permessi sono richiesti nel contesto operativo previsto da Android.

## Limiti operativi

GPS Pointer è uno strumento di supporto tecnico.

La precisione dei risultati dipende da fonti che non sono interamente controllabili dall'app: GPS, magnetometro, giroscopio e altri sensori del telefono, calibrazione del dispositivo, interferenze locali, qualità dei dati altimetrici, connettività e disponibilità dei servizi esterni.

Le analisi di Copertura e Punto Punto sono simulazioni basate sui dati disponibili e sui parametri inseriti. Non costituiscono una misura radio reale né una certificazione del collegamento.

Le informazioni meteo e radar sono fornite da servizi terzi.

**Azimuth e AR rimangono funzioni sperimentali**. Sono ancora oggetto di sviluppo e test sul campo e non devono essere considerate definitive, validate o equivalenti a strumenti professionali di puntamento.

## Repository

Il progetto è suddiviso in due componenti principali mantenuti separatamente:

- App Android: `https://github.com/fraidotube/gps-pointer`
- GPS Pointer Server: `https://github.com/fraidotube/gps-pointer-server`

La separazione dei repository riflette anche la separazione architetturale: il client Android contiene interfaccia, logica locale e strumenti da campo; il server gestisce autenticazione, dati condivisi e servizi centralizzati.

Le due componenti evolvono con versioni indipendenti. La versione indicata all'inizio di questo README si riferisce all'app Android.

## Attribuzioni

Comida utilizza dati OpenStreetMap.

**© OpenStreetMap contributors**

I dati OpenStreetMap sono soggetti alla relativa licenza ODbL.

MET Norway, RainViewer, Open-Meteo, Google Maps, GitHub e gli altri servizi o pacchetti utilizzati dal progetto mantengono le rispettive licenze, condizioni d'uso e politiche di disponibilità.

---

Questo README descrive lo stato funzionale della release **GPS Pointer 2.7.0 / build 70**. Le funzioni sperimentali sono indicate esplicitamente come tali; la loro presenza nel repository non implica validazione sul campo o certificazione.

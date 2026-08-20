# GPS Pointer

GPS Pointer è un'app Android sviluppata in Flutter per supportare attività sul campo legate a orientamento, puntamento, **Postazioni Radio**, analisi preliminare dei collegamenti, profili altimetrici, meteo operativo, rapporti d'intervento e servizi condivisi tramite il server GPS Pointer.

Questa documentazione descrive la **release GPS Pointer 2.5**, build **1.0.0+59**, ed è stata verificata sul codice reale della build 59.

> **Azimuth e AR**
>
> Le funzioni Azimuth e AR sono **sperimentali**, ancora in sviluppo e soggette a prove comparative sul campo. Non sono strumenti certificati e non sostituiscono strumentazione professionale.

---

## Postazioni Radio

La terminologia corrente dell'interfaccia è **Postazioni Radio**.

Dalla Home e dal menu sono disponibili funzioni dedicate a:

- consultazione e ricerca del catalogo;
- puntamento verso una postazione;
- download delle postazioni dal server;
- inserimento di una nuova postazione;
- utilizzo delle postazioni nelle funzioni di Copertura.

Nel codice sono ancora presenti alcuni identificatori e messaggi tecnici storici con la parola “radiofari”; il README usa invece la terminologia corrente mostrata nell'interfaccia: **Postazioni Radio**.

---

## Puntamento, Azimuth, AR e Tilt

Il progetto mantiene separati i motori di puntamento e gli strumenti sperimentali.

Sono presenti:

- `PointingEngineV2`, motore storico protetto;
- motori V3 sperimentali;
- stabilizzazione AR dedicata;
- motore Tilt separato.

Questa separazione permette di sviluppare e confrontare nuove soluzioni senza sostituire automaticamente il comportamento storico.

Azimuth e AR rimangono strumenti sperimentali e di supporto.

---

## Copertura

La schermata **Copertura** permette di selezionare una Postazione Radio e un punto di partenza.

Il punto di partenza può essere definito tramite:

- posizione attuale;
- coordinate;
- link Maps.

La schermata comprende:

- parametri del collegamento;
- calcolo Copertura;
- profilo altimetrico;
- terreno;
- linea ottica;
- prima zona di Fresnel;
- mappa del collegamento;
- tilt teorico;
- salvataggio;
- condivisione;
- invio al server.

È inoltre presente il comando per calcolare i **4 più vicini** quando richiesto dall'utente.

---

## Punto Punto (PTP)

La funzione **Punto Punto • PTP** permette di analizzare un collegamento tra Punto A e Punto B.

Per ciascun punto sono disponibili:

- posizione attuale;
- coordinate;
- link Maps.

Il risultato comprende:

- distanza e geometria del collegamento;
- profilo altimetrico;
- terreno;
- linea ottica;
- prima zona di Fresnel;
- mappa;
- tilt A → B;
- salvataggio;
- condivisione;
- invio al server.

---

## Meteo e radar

La build 59 usa servizi distinti per funzioni diverse:

- **MET Norway** per le previsioni meteo;
- **RainViewer** per il radar precipitazioni;
- **Open-Meteo** per quote e dati altimetrici utilizzati nelle funzioni che ne hanno bisogno.

La schermata **Radar meteo** mostra i frame radar disponibili e le previsioni per il punto selezionato.

---

## Rapporti d'intervento

GPS Pointer comprende una sezione dedicata ai **Rapporti d’intervento**.

Nel progetto sono presenti:

- modello dati del rapporto;
- schermate di gestione;
- archivio locale;
- firme;
- generazione PDF;
- condivisione;
- integrazione con il server.

La generazione del PDF è gestita da un servizio applicativo dedicato.

---

# Comida

**Comida** è il modulo introdotto nella release 2.5 per trovare, consultare e condividere locali.

La Home Comida contiene:

- **Cerca vicino a me**
- **Consigliati**
- **Aggiungi locale**

## Cerca vicino a me

La ricerca usa la posizione corrente e un raggio configurabile:

- 5 km
- 10 km
- 20 km
- 30 km
- 50 km

Il raggio iniziale è **10 km**.

I locali presenti nel database GPS Pointer vengono mostrati prima dei risultati OpenStreetMap.

Sono disponibili filtri per:

- testo;
- tipologia;
- cucina.

## OpenStreetMap e Overpass

Comida usa OpenStreetMap tramite Overpass per i locali esterni.

La build 59 contiene fallback sequenziale fra:

1. `overpass-api.de`
2. `overpass.private.coffee`
3. `maps.mail.ru`

Il servizio include inoltre cache temporanea, timeout e cooldown dopo il fallimento degli endpoint.

I dati esterni vengono mostrati solo quando realmente disponibili.

## Database GPS Pointer

I locali curati dalla community vengono salvati sul server GPS Pointer.

Un record Comida può comprendere:

- nome;
- tipologia;
- cucina;
- indirizzo;
- telefono;
- sito web;
- prezzo;
- orario;
- descrizione;
- coordinate;
- bollino.

## Bollini

La build 59 supporta:

- **GOLD**
- **SILVER**
- **BRONZE**
- **SCONSIGLIATO**

## Consigliati

La sezione **Consigliati** usa soltanto il database GPS Pointer.

La richiesta utilizza `all_distances=true`: non applica quindi il limite del raggio della ricerca normale.

I risultati vengono ordinati in base alla distanza dalla posizione corrente.

## Aggiungi locale

La posizione può essere definita tramite:

- **QUI DOVE SONO**
- ricerca per nome locale / indirizzo / località;
- link Google Maps;
- coordinate manuali.

Il form comprende anche:

- tipologia guidata;
- cucina multipla;
- bollino;
- telefono;
- sito;
- prezzo medio a persona;
- apertura;
- chiusura;
- descrizione / nota.

L'orario è volutamente semplice: **un unico orario del locale**, con Apertura e Chiusura; può essere compilato anche solo uno dei due campi.

## Da OSM a Comida

Un locale proveniente da OpenStreetMap può essere selezionato con **AGGIUNGI A COMIDA**.

L'app apre il form con i dati disponibili e conserva il riferimento sorgente OSM (`source_ref`).

Il locale viene quindi inviato al server GPS Pointer e diventa parte del database condiviso.

## Modifica di un locale

Un locale già presente nel database GPS Pointer può essere modificato direttamente dall'app.

La build 59 usa:

- `POST` per creazione/promozione;
- `PATCH` per aggiornamento;
- autenticazione Bearer con il token dell'app;
- un tentativo di refresh del token e una sola ripetizione in caso di `401`.

La modifica viene salvata sul server e diventa disponibile agli altri utenti al successivo aggiornamento dei dati.

## Azioni rapide

Quando i dati sono disponibili, le schede possono offrire:

- **INDICAZIONI**
- **CHIAMA**
- **SITO**
- **CERCA SU GOOGLE**
- **MODIFICA**
- **AGGIUNGI A COMIDA**

La ricerca Google viene aperta esternamente: GPS Pointer non esegue scraping dei risultati Google.

---

# API Comida usate dall'app

La build 59 contiene chiamate verso:

- `GET /api/v1/comida/restaurants`
- `POST /api/v1/comida/restaurants`
- `PATCH /api/v1/comida/restaurants/{id}`
- `GET /api/v1/comida/geocode`
- `POST /api/v1/comida/resolve-map-link`

Le scritture sono autenticate.

---

# Struttura del progetto

La struttura principale verificata della build 59 è:

```text
lib/
├── application/
├── core/
├── infrastructure/
└── presentation/
```

## `application/`

Contiene controller e servizi applicativi, tra cui autenticazione, catalogo, Comida, posizione, meteo e rapporti.

## `core/`

Contiene modelli e logica centrale: dominio, motori geografici, puntamento, Tilt, AR, profili radio, simulazioni e modelli dei rapporti.

## `infrastructure/`

Contiene implementazioni di persistenza, integrazioni e accesso ai dati.

## `presentation/`

Contiene le schermate e i componenti dell'interfaccia, fra cui Home, Postazioni Radio, Copertura, PTP, Comida, Radar meteo, Rapporti, Impostazioni, Debug, AR e Tilt.

---

# Home e temi

La build 59 contiene due presentazioni della Home:

- una variante radar/pro;
- una variante classica/semplice.

Le funzioni operative principali sono rese disponibili da entrambe.

---

# Server GPS Pointer

Il server GPS Pointer è mantenuto in un repository separato e fornisce servizi condivisi all'app.

Repository server:

`https://github.com/fraidotube/gps-pointer-server`

Repository app:

`https://github.com/fraidotube/gps-pointer`

---

# Versione documentata

**GPS Pointer 2.5**

Build Flutter:

**1.0.0+59**

---

# Limiti d'uso

GPS Pointer è uno strumento di supporto.

GPS, sensori del telefono, servizi cartografici, dati altimetrici e dati meteo possono essere soggetti a errori, ritardi o indisponibilità.

Le funzioni **Azimuth** e **AR** sono esplicitamente sperimentali e non sostituiscono strumenti professionali o certificati.

---

# Attribuzioni

Comida utilizza dati OpenStreetMap.

**© OpenStreetMap contributors**

I dati OpenStreetMap sono soggetti alla relativa licenza ODbL.

Gli altri servizi e pacchetti mantengono le rispettive licenze e condizioni d'uso.

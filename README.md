# GPS Pointer 2.4

GPS Pointer è un’app Android pensata per installatori e tecnici che devono individuare, verificare e puntare collegamenti radio verso postazioni radio note.

La release corrente è:

**GPS Pointer 2.4 — build 55**

## Funzioni principali

- Catalogo locale delle postazioni radio.
- Ordinamento delle postazioni per distanza dalla posizione corrente.
- Ricerca e selezione rapida del radiofaro.
- Condivisione della posizione.
- Apertura diretta delle indicazioni stradali.
- Azimut verso la postazione.
- Puntamento AR.
- Calcolo tilt antenna.
- Altimetria.
- Verifica collegamento punto-punto.
- Calcolo copertura radio.
- Archivio simulazioni.
- Rapporto d’intervento con firme e PDF.
- Import/export TXT del catalogo radiofari.
- Sincronizzazione con catalogo server.
- Radar meteo.
- Meteo corrente e previsioni.

## Copertura radio

La funzione Copertura utilizza il profilo altimetrico reale del terreno per valutare il collegamento.

All’apertura vengono analizzati esclusivamente i **4 radiofari più vicini** alla posizione dell’installatore.

Per ciascuno vengono valutati:

- linea di vista;
- zona di Fresnel;
- eventuale altezza aggiuntiva necessaria;
- limite operativo fino a 15 metri di altezza installatore.

Gli altri radiofari possono essere selezionati manualmente dal menu e vengono calcolati solo quando viene richiesto esplicitamente il calcolo della copertura.

Questo evita interrogazioni altimetriche inutili.

## Punto-Punto

La sezione Punto-Punto permette di creare simulazioni tra due coordinate o postazioni radio.

Sono disponibili:

- profilo altimetrico;
- linea di vista;
- Fresnel;
- distanza;
- quote;
- condivisione delle posizioni;
- salvataggio e riapertura delle simulazioni.

## Azimut, AR e Tilt

GPS Pointer integra strumenti dedicati al puntamento sul campo:

- bussola verso il target;
- correzione rispetto al Nord vero;
- modalità AR;
- strumenti diagnostici;
- calcolo inclinazione antenna.

Il motore di puntamento utilizzato sul campo è stato validato tramite prove reali.

## Meteo

Il meteo ordinario utilizza **MET Norway Locationforecast**.

Il radar precipitazioni utilizza **RainViewer**.

Le informazioni meteo sono mostrate:

- nella Home;
- nel dettaglio della postazione radio;
- nella schermata Radar meteo.

## Altimetria

Open-Meteo viene utilizzato esclusivamente per i servizi che richiedono dati altimetrici e profili del terreno.

Non viene utilizzato per il meteo ordinario.

## Catalogo server

L’app può scaricare e aggiornare il catalogo delle postazioni dal server GPS Pointer.

Sono disponibili:

- aggiornamento catalogo;
- import TXT;
- export TXT;
- reset catalogo locale.

## Rapporti di intervento

L’app permette di compilare rapporti di intervento direttamente sul telefono.

Il flusso include:

- dati intervento;
- attività eseguite;
- firme touch;
- generazione PDF;
- archivio locale;
- condivisione;
- invio al server.

## Privacy

GPS Pointer è progettato principalmente per lavorare con dati locali sul dispositivo.

Le informazioni vengono inviate a servizi esterni solo quando una funzione lo richiede, ad esempio:

- meteo;
- radar;
- altimetria;
- sincronizzazione con il server GPS Pointer.

## Piattaforma

- Android
- Flutter
- package: `it.fraido.gpspointer`

## Release

Versione corrente:

`GPS Pointer 2.4`

Build Android:

`1.0.0+55`

Tag Git:

`release-2.4`

Le release precedenti restano disponibili tramite i relativi tag Git.

---

Developed by **fraidotube**

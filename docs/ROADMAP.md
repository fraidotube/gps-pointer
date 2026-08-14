# GPS Pointer — Roadmap

La V1 è destinata al collaudo interno tramite APK. I lavori successivi devono
partire dalla baseline `1.0.0+19` e seguire macroblocchi separati.

## V2 — Primo obiettivo approvato: autenticazione LDAP

La prossima funzione da progettare è l'autenticazione degli installatori contro
il sistema LDAP aziendale.

Architettura consigliata: l'app contatta un endpoint HTTPS aziendale; il server
esegue la verifica su LDAP e restituisce una sessione applicativa. Non è
consigliato esporre LDAP direttamente a Internet né inserire nell'APK account di
servizio o password LDAP.

Prima di scrivere codice servono dati verificati dall'infrastruttura aziendale:

- indirizzo del servizio HTTPS e raggiungibilità da Internet o VPN;
- modalità di autenticazione lato LDAP;
- base DN, filtro utente e gruppi autorizzati;
- certificato TLS e relativa catena di fiducia;
- durata della sessione e regole di revoca;
- comportamento senza rete;
- messaggi ammessi per credenziali errate, account bloccato o server non
  disponibile;
- responsabilità e trattamento dei log di accesso.

Gate del primo macroblocco V2:

1. endpoint di test documentato e raggiungibile;
2. nessuna password persistita o scritta nei log;
3. TLS obbligatorio;
4. login valido, login errato, timeout e server indisponibile testati;
5. sessione revocabile e logout verificato;
6. nessuna regressione delle funzioni offline della V1;
7. collaudo con account tecnico di test, non con credenziali personali
   consegnate in chat.

## V2 — Passi successivi possibili

Da approvare dopo il login LDAP:

- autorizzazione per gruppo o ruolo;
- download autenticato del catalogo radiofari aziendale;
- cache locale cifrata e regole di scadenza;
- confronto versione e provenienza del catalogo;
- disabilitazione o revoca di un dispositivo;
- aggiornamento controllato dell'app.

## Prima di ampliare la distribuzione

- configurare una chiave di firma release definitiva e conservarne il backup;
- limitare e verificare la chiave Google Maps per la firma definitiva;
- provare l'app su almeno un secondo modello Android dotato di magnetometro;
- definire un canale aziendale per APK e aggiornamenti;
- decidere quali coordinate possono rimanere nel catalogo pubblico di esempio;
- effettuare un collaudo sul campo con riferimento radio reale.

## Funzioni candidate, non approvate

- profilo altimetrico e verifica teorica della linea di vista;
- preferiti e ultimi radiofari utilizzati;
- note e fotografie dell'intervento;
- settori, frequenze e coperture;
- rapporto di installazione;
- pannello amministrativo e telemetria controllata.

Queste funzioni non devono essere avviate insieme all'autenticazione LDAP. Ogni
voce diventerà un macroblocco soltanto dopo approvazione esplicita.

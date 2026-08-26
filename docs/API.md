# Kontrakt REST API

Rozhraní mezi mobilní appkou a službou RenoWorkshop API (poběží na RENDCAPP
vedle RenoDesku). Klientskou stranu už plní
[`RestServiceOrderDataSource`](../lib/src/features/orders/data/datasources/rest_service_order_data_source.dart),
ověřenou testy v `test/data/rest_service_order_data_source_test.dart` — server
tedy stačí napsat proti tomuhle dokumentu a appka se na něj napojí beze změny.

## Role služby

Appka **nikdy nemluví s Heliosem přímo**. API stojí mezi nimi a drží dvě
oddělené věci:

| Data | Vlastník | Chování |
|---|---|---|
| zakázka, vozidlo, zákazník, mechanik, termíny | Helios (read-only) | projekce, obnovuje se každých ~5 minut, přepisuje se |
| stav na dílně, poznámky, hotové úkony, stání | RenoWorkshop | vzniká v appce, synchronizace na to nesmí sáhnout |

Spojují se přes číslo zakázky (`reference_subjektu` z Heliosu).

## Základní adresa

Klient si ji skládá relativně, takže **musí končit lomítkem**:

```
https://<host>/renoworkshop/api/
```

Nastavuje se při buildu appky:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://…/renoworkshop/api/
```

Bez té proměnné appka běží na mock datech — tak se staví dnes a tak běží testy.

## Autorizace

Každý požadavek nese Firebase ID token:

```
Authorization: Bearer <firebase id token>
```

Server ho musí ověřit knihovnou `firebase-admin` (projekt `renoworkshop`).
Neověřovat ho jen naoko: appka je jen klient, skutečná kontrola patří sem.

Z tokenu se čte `uid`, `email` a `name` — hodí se jako autor poznámek.
Role zatím nejsou; až se namapují skupiny z Entra ID, přibude kontrola i tady.

| Situace | Kód |
|---|---|
| chybí nebo neplatný token | `401` |
| platný token, ale uživatel nemá právo | `403` |

Appka na obojí reaguje hláškou „Přihlášení vypršelo" a odhlášením.

## Formát

Požadavky i odpovědi jsou `application/json; charset=utf-8`. Datum a čas
v ISO 8601 bez zóny, v místním čase (`2026-08-21T07:15:00`) — tak to appka
parsuje dnes u mock dat.

Chyba má vždycky tenhle tvar; `error.message` se ukazuje uživateli, takže
musí být česky a srozumitelně:

```json
{ "error": { "code": "order_closed", "message": "Zakázka je uzavřená." } }
```

## Endpointy

### GET /orders

Vrací pole aktivních zakázek. Filtrování a hledání dělá appka lokálně, takže
zatím žádné query parametry — až seznam naroste přes pár set položek, přidá se
stránkování.

```json
[
  {
    "id": "ZK-26-0418",
    "licensePlate": "8AB 4721",
    "model": "BMW X5 xDrive40d",
    "customerName": "Petr Novák",
    "status": "in_repair",
    "branch": "brno",
    "receivedAt": "2026-08-21T07:15:00",
    "dueAt": "2026-08-26T16:00:00",
    "vin": "WBAKS4105L9KL83914",
    "mechanicName": "Jan Dvořák",
    "serviceAdvisorName": "Martina Horáková",
    "bay": "Stání 4",
    "notes": [
      {
        "id": "N-0418-1",
        "text": "Výměna zadních tlumičů, dotažení dle předpisu 120 Nm.",
        "author": "Jan Dvořák",
        "createdAt": "2026-08-25T09:40:00"
      }
    ],
    "workItems": [
      {
        "id": "W-0418-1",
        "title": "Diagnostika podvozku",
        "isDone": true,
        "estimatedHours": 1.0
      }
    ]
  }
]
```

Povinné je všechno kromě `mechanicName`, `serviceAdvisorName` a `bay`, které
smějí být `null`. `notes` a `workItems` smějí být prázdné pole.

### GET /orders/{id}

Jedna zakázka ve stejném tvaru. Neexistující vrací `404` — appka to bere jako
„zakázka zmizela", ne jako chybu.

### PATCH /orders/{id}

Posun stavu. Vrací celou aktualizovanou zakázku.

```json
{ "status": "quality_check" }
```

Server má ohlídat, že jde o **posun o jeden krok dopředu** podle pořadí níž,
a odmítnout skok nebo návrat s `409` a srozumitelnou hláškou. Appka nabízí jen
následující stav, ale spoléhat na to nelze.

### POST /orders/{id}/notes

Přidá poznámku, vrací aktualizovanou zakázku.

```json
{ "text": "Objednán vodní chladič, dodání 26. 8.", "author": "Jan Dvořák" }
```

`author` posílá appka podle přihlášeného účtu. Server ho může přepsat podle
tokenu — je to důvěryhodnější zdroj.

### PATCH /orders/{id}/work-items/{workItemId}

Označí úkon za hotový nebo plánovaný, vrací aktualizovanou zakázku.

```json
{ "isDone": true }
```

## Číselníky

Hodnoty musí sedět přesně, appka je mapuje na výčtové typy a neznámou hodnotu
odmítne.

**Stav zakázky** (`status`) — pořadí je zároveň pořadí kroků na dílně:

| Hodnota | Význam |
|---|---|
| `received` | Přijato |
| `diagnostics` | V diagnostice |
| `waiting_for_parts` | Čeká na díly |
| `in_repair` | V opravě |
| `quality_check` | Kontrola kvality |
| `ready_for_pickup` | Připraveno k vyzvednutí |
| `picked_up` | Vyzvednuto |

**Pobočka** (`branch`): `praha`, `brno`, `zlin`

## Fotodokumentace (plánováno)

Není postavená, ale kontrakt s ní počítá, aby se do ní později nemuselo
zasahovat na obou stranách zároveň. Fotky **nepocházejí z Heliosu** - jsou to
naše data jako stav a poznámky.

**V seznamu nikdy nejsou.** `GET /orders` zůstává štíhlý; detail vrací jen
metadata s odkazy, binární data se stahují až na vyžádání:

```json
"photos": [
  {
    "id": "F-0418-1",
    "phase": "intake",
    "url": "/renoworkshop/api/orders/ZK-26-0418/photos/F-0418-1",
    "thumbnailUrl": "/renoworkshop/api/orders/ZK-26-0418/photos/F-0418-1?size=thumb",
    "caption": "Poškozený přední nárazník při příjmu",
    "author": "Jan Dvořák",
    "createdAt": "2026-08-21T07:22:00"
  }
]
```

`phase`: `intake` (příjem) · `finding` (nalezená závada) · `done` (hotovo) ·
`handover` (předání).

**Zamýšlené endpointy**

| Endpoint | Co dělá |
|---|---|
| `POST /orders/{id}/photos` | nahrání (multipart), vrací metadata fotky |
| `GET /orders/{id}/photos/{photoId}` | soubor; `?size=thumb` náhled |
| `PATCH /orders/{id}/photos/{photoId}` | úprava popisku nebo skrytí |

**Append-only.** Fotodokumentace při příjmu slouží k doložení stavu vozu, tedy
se nepřepisuje ani nemaže - nejvýš skryje příznakem. Autor a čas se berou
z tokenu a ze serveru, ne z telefonu.

**Uložení.** Soubory na disku RENDCAPPu, metadata v Postgresu. Appka fotku
před odesláním zmenší (dlouhá hrana ~1600 px, JPEG 80), jinak by při padesáti
zakázkách denně přibýval zhruba gigabajt denně. Doba uchování se musí domluvit
s tím, kdo řeší reklamace.

## Co ještě není vyřešené

- **Sdílený stav dílny.** Dnes appka data načte a drží; když stav posune jiný
  mechanik, ostatní to uvidí až po obnovení. Až to začne vadit, přidá se buď
  krátký polling, nebo websocket.
- **Ruční dotažení z Heliosu.** Chystá se endpoint, kterým appka řekne
  „koukni se do Heliosu hned" — omezený na jedno volání za minutu pro celou
  dílnu, ať se DMS nedá zahltit.
- **Offline zápisy.** Posun stavu bez signálu se dnes ztratí. Až bude potřeba,
  přibude fronta v appce a `409` se bude řešit sloučením.

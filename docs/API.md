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

Bez té proměnné appka běží na mock datech — tak běží testy i `flutter run`
při vývoji.

### Dnešní adresa: zatím bez šifrování

Buildy z CI míří na

```
http://renoworkshop.renocar.cz:8093/api/
```

Nastavuje se na jednom místě, v `ADRESA_API` v hlavičce
[sestaveni.yml](../.github/workflows/sestaveni.yml).

**Je to dočasné.** Server čeká na certifikát a bez něj mobilní aplikace na
HTTPS nedosáhne. Jméno žije jen ve vnitřním DNS, takže provoz nikdy neopustí
firemní síť a mimo ni se telefon nemá kam připojit. Cenou je, že přihlašovací
token jde po síti čitelně — na zaměstnanecké wi-fi, která je oddělená od
zákaznické, je to pro tuhle fázi únosné.

Aby to vůbec fungovalo, jsou v aplikaci **dvě výjimky pro nešifrovaný provoz**,
obě svázané výhradně s tímhle jménem:

| Platforma | Soubor |
|---|---|
| Android | `android/app/src/main/res/xml/network_security_config.xml` |
| iOS | `ios/Runner/Info.plist`, klíč `NSAppTransportSecurity` |

**Až bude certifikát**, zruší se to třemi kroky: v `ADRESA_API` přepsat na
`https://renoworkshop.renocar.cz:8444/api/`, smazat oba soubory s výjimkou
(u iOS jen ten klíč) a odebrat `android:networkSecurityConfig` z manifestu.
Postup vydání certifikátu je v `RenoWorkshopApi/docs/CERTIFIKAT.md`.

## Dílenský stav

Zakázka má dva nezávislé stavy. **Stav z Heliosu** (`heliosStatus`) je jen
ke čtení — posílá se už přeložený číselníkem, tedy `Zpracováváno`, ne číslo.
Aplikace ho zobrazuje zeleně, protože Helios je zelený a je pak na první
pohled poznat, který údaj je z ERP. **Dílenský stav** si vede RenoWorkshop
sám a je podrobnější.

Dílenský stav se **přidává, neposouvá**: oprava po bouračce běží týdny
a stavy se vracejí i přeskakují, takže žádné pravidlo o krocích neplatí.

| Pole | Co je |
|---|---|
| `status` | text aktuálního stavu, `null` u zakázky bez stavu |
| `statusCode` | kód z číselníku, `null` u ručně zapsaného |
| `statusHistory` | celá historie, **nejnovější první**; každý záznam má `id`, `code`, `label`, `note`, `author`, `createdAt` |

Aktuální stav je první záznam historie. Zakázka, které stav nikdo nedal,
má `status: null` — z Heliosu se neodvozuje.

### GET /stavy

Číselník pro nabídku v aplikaci. Spravuje se v databázi, takže nový stav
se v telefonech objeví sám.

```json
[
  { "code": "prijato", "label": "Přijato" },
  { "code": "rozpocet", "label": "Rozpočet" }
]
```

### POST /orders/{id}/stavy

Přidá stav do historie. Buď `code` z číselníku, nebo `label` s vlastním
textem:

```json
{ "code": "lakovna", "note": "stání 4" }
{ "label": "Čeká na díl z Německa" }
```

`note` je nepovinná poznámka ke kroku — kde vůz stojí, na kterém je
zvedáku, na co se čeká.

### DELETE /orders/{id}/stavy/{zaznamId}

Smaže jeden záznam z historie. Oprava omylem přidaného stavu: je to
pracovní přehled dílny, ne auditní doklad. Vrací aktualizovanou zakázku.

Vrací celou aktualizovanou zakázku. Název se ukládá i u číselníkového
stavu — přejmenování v číselníku nesmí zpětně přepsat historii.

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
    "repairSubject": "Zadní nárazník, víko kufru",
    "status": "Klempířské práce",
    "statusCode": "klempirna",
    "statusHistory": [
      {
        "code": "klempirna",
        "label": "Klempířské práce",
        "author": "Jan Dvořák",
        "createdAt": "2026-08-24T08:10:00"
      },
      {
        "code": "ceka_dily",
        "label": "Čeká na díly",
        "author": "Petra Válková",
        "createdAt": "2026-08-21T13:05:00"
      }
    ],
    "branch": { "code": "1", "label": "Brno" },
    "department": { "code": "11211", "label": "Servis BMW Brno" },
    "orderType": { "code": "801", "label": "Běžná" },
    "receivedAt": "2026-08-21T07:15:00",
    "dueAt": "2026-08-26T16:00:00",
    "vin": "WBAKS4105L9KL83914",
    "heliosStatus": "Zpracováváno",
    "mechanicName": "Jan Dvořák",
    "mechanicCode": "1042",
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

Povinné je všechno kromě `mechanicName`, `serviceAdvisorName`, `bay`,
`branch`, `department`, `orderType`, **`receivedAt` a `dueAt`**, které smějí
být `null`. `notes` a `workItems` smějí být prázdné pole.

Ta dvě data chybí častěji, než se čeká: Helios nemá datum přijetí u každé
zakázky a termín se u spousty z nich doplní až později. Aplikace pak
u zakázky ukáže pomlčku, neřadí ji dopředu a nehlásí ji jako opožděnou.
Není to výjimečný stav, ale běžný — první ostrý build na tom spadl, protože
tenhle odstavec dřív tvrdil, že jsou povinná.

`mechanicName` je **zodpovědná osoba z Heliosu** (`hlv.zodpovida`), ne
mechanik, který na voze zrovna dělá. Aplikace ji nikdy nemění — je to údaj
z ERP. `mechanicCode` je její kód, podle kterého se dá filtrovat i po
přejmenování.

`orderType` je typ zakázky, v Heliosu *řada*: `code` je její číslo
(`801` běžná, `802` interní, `803` PDI...), `label` název ze serverové
převodní tabulky. Aplikace význam kódu nezná - zobrazuje `label`,
filtruje podle `code`. Nová řada se tak objeví sama, bez nové verze
aplikace. Zakázka bez vyplněné řady má `null`.

Když řada v převodní tabulce chybí, přijde v `label` samo číslo. Je to
záměr: je vidět, že se má doplnit, a zakázka nezmizí.

### GET /orders/{id}

Jedna zakázka ve stejném tvaru. Neexistující vrací `404` — appka to bere jako
„zakázka zmizela", ne jako chybu.

### GET /orders/search?q=…

Hledání **napříč archivem**, tedy i mezi uzavřenými zakázkami. Prohledává
číslo zakázky, VIN, SPZ a zákazníka; mezery se ignorují, protože z OCR
chodí SPZ jednou s mezerou a jednou bez.

Vrací pole zakázek ve stejném tvaru jako `GET /orders`, nejvýš sto.
Dotaz kratší než tři znaky vrací `400`.

Aplikace to volá, když se v načteném seznamu nic nenajde, nebo když
uživatel načte VIN fotoaparátem.

### Závady u zakázky

Každá zakázka nese pole `defects` - závady (úkony) zapsané poradcem
v Heliosu, v pořadí zápisu. Jen ke čtení, aplikace je nemění.

```json
"defects": [
  { "id": "9001", "code": "001", "text": "Vyměnit zadní nárazník
lakovat do barvy" },
  { "id": "9002", "code": null, "text": "Seřídit geometrii" }
]
```

`text` může mít víc řádků. U rozdělané zakázky se změna v Heliosu projeví
do pěti minut, u ukončené po nočním běhu. Starší verze API pole neposílá -
aplikace ho pak bere jako prázdné.

### PUT /orders/{id}/repair-subject

Předmět opravy - co se na voze opravuje. Zapisuje ho dílna ručně, Helios
ho nezná. Přepisuje se celý, prázdný text ho smaže.

```json
{ "text": "Zadní nárazník, víko kufru" }
```

Vrací celou zakázku. Text delší než 1000 znaků vrací `400`. U zakázky je
v poli `repairSubject`, `null` = zatím nezadáno. Hledání v archivu
(`/orders/search`) prohledává i předmět opravy.

### GET /vehicles/search?q=…

Hledání vozidla podle **SPZ nebo VIN** pro záložku Vozidla. Hledá v zrcadle
vozidel z Heliosu, tedy ve všech vozech, ne jen v těch na dílně. Mezery
a pomlčky se ignorují (`2BK 9485` z fotoaparátu = `2BK9485` z Heliosu),
stačí část značky. Přesná shoda jde první, nejvýš 20 vozidel. Dotaz kratší
než tři znaky vrací `400`.

```json
[
  {
    "id": 51234,
    "licensePlate": "2BK 9485",
    "vin": "WBA8E9C50GK123456",
    "model": "BMW 320d Touring",
    "ownerName": "Stavby Novák s.r.o.",
    "orderCount": 3
  }
]
```

Jedna SPZ může vrátit víc vozidel - značky se po přeregistraci přidělují
znovu. Aplikace po naskenování otevře kartu rovnou jen u jediného výsledku.

### GET /vehicles/{id}

Karta vozidla. `id` je `cislo_subjektu` z Heliosu, neexistující vrací `404`.

```json
{
  "id": 51234,
  "licensePlate": "2BK 9485",
  "vin": "WBA8E9C50GK123456",
  "model": "BMW 320d Touring",
  "series": "F31",
  "fuel": "Nafta",
  "engine": "B47D20",
  "mileage": 123456,
  "soldAt": "2019-05-14",
  "owner": {
    "id": 60001,
    "name": "Stavby Novák s.r.o.",
    "customerNumber": "Z-10042",
    "ico": "12345678",
    "dic": "CZ12345678",
    "street": "Masarykova 123/4",
    "city": "Brno",
    "zip": "60200",
    "phone": "+420 777 123 456",
    "email": "info@stavbynovak.cz"
  },
  "contact": { "id": 7, "name": "Petr Řidič", "phone": "+420 603 000 111", "email": null },
  "orders": [ ]
}
```

- `owner` je **dnešní** majitel vozu. Každá zakázka v `orders` si nese svého
  tehdejšího zákazníka (`customerName`) - po prodeji vozu se rozejdou.
- `orders` jsou **všechny** zakázky vozu, rozdělané i ukončené, od nejnovější,
  ve stejném tvaru jako `GET /orders`. Rozliší je `isActive`.
- `owner` i `contact` mohou být `null`. Domácí adresa kontaktní osoby se
  neposílá, i když ji server má.
- `soldAt` je datum prodeje u RENOCARu, ne rok výroby - ten Helios nevede.

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

### GET /orders/search?q=…

Hledání **napříč archivem**, tedy i mezi uzavřenými zakázkami. Prohledává
číslo zakázky, VIN, SPZ a zákazníka; mezery se ignorují, protože z OCR
chodí SPZ jednou s mezerou a jednou bez.

Vrací pole zakázek ve stejném tvaru jako `GET /orders`, nejvýš sto.
Dotaz kratší než tři znaky vrací `400`.

Aplikace to volá, když se v načteném seznamu nic nenajde, nebo když
uživatel načte VIN fotoaparátem.

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

**Pobočka a útvar** nejsou pevný číselník - appka je bere z dat, takže nová
pobočka v Heliosu se objeví sama, bez nové verze aplikace.

V Heliosu je uložený jen **útvar** (`subjekty.reference_subjektu`), pětimístný
kód typu `12211`. **Pobočku z něj odvozuje API druhou číslicí:**

| Číslice | Pobočka |
|---|---|
| 1 | Brno |
| 2 | Čestlice |
| 3 | Kongresové Centrum |
| 4 | Česká |
| 5 | Bubeneč |

Kód s neznámou druhou číslicí (v datech je například `10005`) dostane
`branch: null`; appka takovou zakázku ukáže jako „Bez pobočky", nezahazuje ji.
Stejně tak zakázka bez vyplněného zpracovatele nemá `department`
a zakázka bez vyplněného typu nemá `orderType`.

Odvození patří na server schválně - kdyby pravidlo přestalo platit nebo
přibyla pobočka, mění se to na jednom místě.

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

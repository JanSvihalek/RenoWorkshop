# RenoWorkshop

Interní mobilní nástroj pro dílnu **RENOCAR a.s.** (BMW / MINI / BMW Motorrad;
pobočky Praha, Brno, Zlín). Mechanici, servisní poradci a vedoucí směny v něm
sledují a posouvají stav servisních zakázek.

**Není to zákaznická aplikace.** Uživatel je vždy zaměstnanec servisu a vidí
všechny zakázky na dílně - filtruje se podle pobočky, stavu a mechanika, ne
podle "mého vozidla". Registrace účtů se nikdy neotevře veřejnosti.

První appka plánované rodiny (RenoWorkshop, RenoSales, …), proto je struktura
vrstvená a design tokeny oddělené - další appka si vezme `lib/src/core/` a
vymění paletu.

## Fáze 1 - rozsah

| Obrazovka | Stav |
|---|---|
| Login (placeholder) | UI kostra, žádné reálné ověřování |
| Seznam zakázek | filtr pobočka / stav / mechanik, hledání, řazení, pull-to-refresh |
| Detail zakázky | časová osa stavů, vozidlo, mechanik, úkony, poznámky, posun stavu |

Data jsou **mock** (`assets/mock/service_orders.json`, 13 zakázek napříč všemi
pobočkami a všemi sedmi stavy). Žádný backend, žádná databáze.

Datumy v mocku jsou pevné (srpen 2026), aby seznam obsahoval i zakázku po
termínu - po delší době se všechny zakázky začnou tvářit jako zpožděné.

## Spuštění

```bash
flutter pub get
flutter run              # Android / iOS zařízení nebo emulátor
flutter test             # 28 testů: doména, datová vrstva, UI flow
flutter analyze
```

Vyžaduje Flutter 3.41+ (Dart 3.11+). Ověřeno na Flutter 3.41.8.

- Package / bundle ID: `dev.svihalek.renoworkshop`
- Fonty IBM Plex Sans + Mono jsou bundlované v `assets/fonts/` (SIL OFL) -
  appka je čitelná i bez sítě, což je na dílně podstatné.

## Struktura

```
lib/src/
  app/                 MaterialApp, router + auth guard
  core/                theme (barvy, typografie, rozměry), platforma, utility
  features/
    auth/              login placeholder
      domain/          Employee, AuthState, AuthRepository (rozhraní)
      data/            PlaceholderAuthRepository
      presentation/    AuthController, LoginScreen
    orders/            sledování zakázek
      domain/          ServiceOrder, OrderStatus, Branch, OrderFilter, repository rozhraní
      data/            DTO, ServiceOrderDataSource + mock, repository implementace
      presentation/    Riverpod providery, obrazovky, widgety
assets/
  fonts/               IBM Plex Sans / Mono
  mock/                service_orders.json
```

Pravidlo závislostí: `presentation -> domain <- data`. Doména je čistý Dart bez
importu Flutteru (barvy stavů žijí až v `presentation/widgets/order_status_visuals.dart`).

Podrobnosti a postup napojení reálného API: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## CI/CD

Po každém pushi běží [GitHub Actions](.github/workflows/build.yml): analyze +
testy, release APK/AAB jako artefakt běhu a podepsané IPA nahrané do TestFlightu
(fastlane, `ios/fastlane/Fastfile`).

Podpisové materiály pro iOS generuje `fastlane match` na macOS runneru, takže
**vývojářský Mac není potřeba** - stačí jednorázově spustit workflow
[iOS bootstrap](.github/workflows/ios-bootstrap.yml).

- [docs/NASTAVENI.md](docs/NASTAVENI.md) - postup krok za krokem (co kam kliknout)
- [docs/CI.md](docs/CI.md) - referenční přehled secretů, workflow a chybových hlášek

## State management: Riverpod

Zvoleno **Riverpod 2.6** (bez code generation), ne Bloc. Důvody:

- **Odstínění datové vrstvy jde přes overrides.** Výměna mocku za REST je jeden
  `serviceOrderDataSourceProvider.overrideWithValue(...)` - a stejný mechanismus
  slouží v testech, takže testy jdou psát bez mock frameworku.
- **Odvozený stav bez boilerplate.** `filteredOrdersProvider` je čistá kompozice
  streamu zakázek a filtru; v Blocu by to znamenalo další bloc a ruční propojení.
- **`AsyncValue`** pokrývá loading / data / error v jednom typu, což je přesně
  tvar, který mají obrazovky nad síťovým zdrojem.
- Menší množství tříd na jednu obrazovku než u Blocu - pro rodinu appek
  udržovanou malým týmem to je praktičtější.

Zůstává prostor pro růst: až přibudou složitější workflow (offline fronta,
optimistic update), stačí přidat `AsyncNotifier` vedle stávajících providerů.

## Co v této fázi záměrně chybí

- Reálná autentizace - jen `PlaceholderAuthRepository`. Cílově Firebase Auth
  s poskytovatelem Microsoft (OIDC / Entra ID) + `local_auth` pro biometrii,
  stejně jako v projektu RenoCharge.
- Jakýkoli backend, databáze, push notifikace.
- Funkce mimo sledování zakázky (prodej, sklad) - patří do dalších appek rodiny.
- Taby "Moje směna" a "Nastavení" jsou vidět kvůli cílové struktuře navigace,
  ale zatím jen oznámí, že se připravují.
- Firemní logo RENOCAR (login používá monogram "RW") a finální branding.

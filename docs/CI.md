# CI/CD - TestFlight a Android build (bez vlastního Macu)

Workflow [.github/workflows/build.yml](../.github/workflows/build.yml) běží
**po každém pushi** do libovolné větve:

| Job | Co dělá | Kde běží |
|---|---|---|
| `config` | zjistí, které podpisové secrety jsou nastavené | ubuntu |
| `test` | `flutter analyze` + `flutter test` | ubuntu |
| `android` | release APK + AAB jako artefakt běhu | ubuntu |
| `ios` | podepsané IPA → upload do TestFlightu | macOS |

Bez nastavených secretů workflow **nespadne**: Android se postaví s debug
podpisem a iOS job se přeskočí s varováním.

**Mac není potřeba.** Certifikát i provisioning profil vygeneruje
[fastlane match](https://docs.fastlane.tools/actions/match/) přímo na macOS
runneru GitHub Actions a uloží je zašifrované do privátního repa. Jediné, co
se dělá ručně, je vyplnění secretů.

- **Android APK**: Actions → konkrétní běh → Artifacts → `android-<číslo>`
  (60 dní). Při pushnutí tagu `v*` se APK i AAB připnou k GitHub Release.
- **iOS**: App Store Connect → TestFlight, zpracování buildu 5-15 minut.
- Číslo buildu = číslo běhu workflow, takže TestFlight nikdy nedostane
  duplicitní build. Verzi (`1.0.0`) drží `pubspec.yaml`.

---

## 1. App Store Connect API klíč

App Store Connect → *Users and Access* → *Integrations* → *App Store Connect API*
→ **Generate API Key** s rolí **Admin** (nižší role nesmí vytvářet certifikáty).
Soubor `.p8` jde stáhnout jen jednou.

| Secret | Hodnota |
|---|---|
| `ASC_KEY_ID` | Key ID (10 znaků) |
| `ASC_ISSUER_ID` | Issuer ID (UUID nad seznamem klíčů) |
| `ASC_KEY_P8` | **celý obsah** `AuthKey_XXXX.p8` včetně `-----BEGIN PRIVATE KEY-----` |

## 2. Privátní repo pro certifikáty

fastlane match potřebuje úložiště. Založ **nový prázdný privátní** repozitář,
např. `JanSvihalek/RenoWorkshop-certificates` (privátní je podmínka - leží
v něm zašifrovaný podpisový klíč).

Přístup pro CI přes personal access token: GitHub → Settings → Developer
settings → **Fine-grained token**, přístup jen k tomu jednomu repu,
oprávnění **Contents: Read and write**.

Hodnotu `MATCH_GIT_BASIC_AUTHORIZATION` vyrob z tokenu (Git Bash):

```bash
printf 'JanSvihalek:github_pat_XXXX' | base64 -w0
```

| Secret | Hodnota |
|---|---|
| `MATCH_GIT_URL` | `https://github.com/JanSvihalek/RenoWorkshop-certificates.git` |
| `MATCH_GIT_BASIC_AUTHORIZATION` | výstup příkazu výše |
| `MATCH_PASSWORD` | heslo, kterým match šifruje obsah repa (vymysli a ulož si ho) |

## 3. Jednorázový bootstrap

Actions → **iOS bootstrap (jednorázově)** → *Run workflow*. Na macOS runneru se:

1. založí App ID `dev.svihalek.renoworkshop` v Developer portálu,
2. založí aplikace v App Store Connect,
3. vygeneruje distribuční certifikát + App Store profil,
4. uloží zašifrované do match repa.

Pak už každý push staví IPA a posílá ho na TestFlight sám. Bootstrap se pouští
znovu jen při expiraci certifikátu (po roce) nebo změně bundle ID.

Zbývá jediná ruční věc v App Store Connect: v TestFlightu založit skupinu
interních testerů a přidat do ní kolegy.

## 4. Android keystore (bez JDK)

Na tomhle počítači není `keytool`, ale je OpenSSL - stačí spustit:

```bash
bash tools/create-android-keystore.sh "silne-heslo"
```

Vznikne `upload-keystore.p12` (**zálohuj mimo počítač** - ztráta znamená, že
aplikaci už nepůjde aktualizovat) a `upload-keystore.p12.base64` pro secret.

| Secret | Hodnota |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | obsah `upload-keystore.p12.base64` |
| `ANDROID_KEYSTORE_PASSWORD` | zadané heslo |
| `ANDROID_KEY_ALIAS` | `upload` |
| `ANDROID_KEY_PASSWORD` | stejné heslo (PKCS#12 používá jedno) |

Bez těchto secretů se APK podepíše debug klíčem: nainstalovat jde, ale nejde
ho později aktualizovat verzí s ostrým podpisem.

Lokálně (mimo CI) se stejné hodnoty píšou do `android/key.properties`
(je v `.gitignore`):

```properties
storeFile=/absolutní/cesta/upload-keystore.p12
storePassword=…
keyAlias=upload
keyPassword=…
storeType=PKCS12
```

## Volitelné proměnné (*Variables*, ne secrets)

| Variable | K čemu |
|---|---|
| `IOS_BUNDLE_ID` | jiné bundle ID než `dev.svihalek.renoworkshop` |
| `IOS_TEAM_ID` | když si match nedokáže odvodit team |
| `ANDROID_KEYSTORE_TYPE` | `JKS`, pokud přineseš keystore z keytoolu |

---

## Časté chyby

| Hláška | Příčina |
|---|---|
| `Could not create another Distribution certificate` | u týmu jsou vyčerpané certifikáty - smaž nepoužívaný v Developer portálu a pusť bootstrap znovu |
| `Authentication credentials are missing or invalid` | špatný `ASC_KEY_P8` (chybí BEGIN/END řádky) nebo klíč nemá roli Admin |
| `No matching provisioning profiles found` | bootstrap ještě neproběhl, nebo se změnilo bundle ID |
| `Couldn't find bundle identifier` | App ID neexistuje - pusť lane `bootstrap` |
| `The provided entity includes an attribute with a value that has already been used` (produce) | aplikace v App Store Connect už existuje; bootstrap pokračuje dál, chyba je neškodná |
| Android: `Keystore file not found` | `ANDROID_KEYSTORE_BASE64` je nastavený, ale zbylé tři secrety chybí |

## Poznámka k viditelnosti repa

`JanSvihalek/RenoWorkshop` je veřejný. Pro Actions to znamená neomezené
minuty včetně macOS runnerů. Když se repo přepne na privátní, macOS minuty
se počítají **desetinásobkem** (2 000 minut ve free tarifu ≈ 200 minut macOS,
tj. zhruba 15 iOS buildů měsíčně). Match repo s certifikáty musí být privátní
v obou případech.

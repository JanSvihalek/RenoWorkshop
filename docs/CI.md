# CI/CD - TestFlight a Android build

Workflow [.github/workflows/build.yml](../.github/workflows/build.yml) běží
**po každém pushi** do libovolné větve:

| Job | Co dělá | Kde běží |
|---|---|---|
| `config` | zjistí, které podpisové secrety jsou nastavené | ubuntu |
| `test` | `flutter analyze` + `flutter test` | ubuntu |
| `android` | release APK + AAB, nahraje je jako artefakt běhu | ubuntu |
| `ios` | podepsané IPA → upload do TestFlightu (fastlane) | macOS |

Bez nastavených secretů workflow **nespadne** - Android se postaví s debug
podpisem a iOS job se přeskočí s varováním.

- **Android APK** se stahuje ze záložky *Actions → konkrétní běh → Artifacts*
  (`android-<číslo běhu>`), platnost 60 dní. Při pushnutí tagu `v*` se APK i AAB
  navíc připnou k GitHub Release.
- **iOS** se po dokončení objeví v App Store Connect → TestFlight
  (zpracování buildu trvá zpravidla 5-15 minut).
- Číslo buildu = číslo běhu workflow (`github.run_number`), takže TestFlight
  nikdy nedostane duplicitní build. Verzi (`1.0.0`) drží `pubspec.yaml`.

---

## Co je potřeba nastavit

Vše se zadává v **Settings → Secrets and variables → Actions** v GitHub repu.

### A) Apple - App Store Connect API klíč

App Store Connect → *Users and Access* → *Integrations* → *App Store Connect API*
→ vygenerovat klíč s rolí **App Manager**. Klíč `.p8` jde stáhnout jen jednou.

| Secret | Hodnota |
|---|---|
| `ASC_KEY_ID` | Key ID (10 znaků, např. `AB12CD34EF`) |
| `ASC_ISSUER_ID` | Issuer ID (UUID, je nad seznamem klíčů) |
| `ASC_KEY_P8` | **celý obsah** souboru `AuthKey_XXXX.p8` včetně řádků `-----BEGIN PRIVATE KEY-----` |

### B) Apple - podpisový certifikát a profil

V Apple Developer portálu (potřebuje Mac na export `.p12`, nebo Xcode na jiném stroji):

1. **App ID** pro bundle `dev.svihalek.renoworkshop` (Identifiers → +).
2. **Apple Distribution certifikát** → v Keychain Access ho exportovat
   i se soukromým klíčem jako `.p12` a nastavit heslo.
3. **Provisioning profile** typu *App Store* pro to App ID → stáhnout
   `.mobileprovision`.
4. **Aplikace v App Store Connect** (My Apps → +) se stejným bundle ID -
   bez ní upload skončí chybou.

Převod do base64:

```bash
base64 -i dist.p12 | pbcopy               # macOS
base64 -i profile.mobileprovision | pbcopy
```

| Secret | Hodnota |
|---|---|
| `IOS_DIST_CERT_P12_BASE64` | base64 z `.p12` |
| `IOS_DIST_CERT_PASSWORD` | heslo, kterým je `.p12` chráněný |
| `IOS_PROVISIONING_PROFILE_BASE64` | base64 z `.mobileprovision` |

Volitelně (*Variables*, ne secrets) - použij, jen když build hlásí, že si
nedokázal přečíst profil:

| Variable | Hodnota |
|---|---|
| `IOS_PROFILE_NAME` | přesný název profilu z portálu |
| `IOS_TEAM_ID` | Team ID (10 znaků) |

> Profil expiruje po roce - pak stačí stáhnout nový a přepsat
> `IOS_PROVISIONING_PROFILE_BASE64`. Až bude appek v rodině víc, vyplatí se
> přejít na `fastlane match` (certifikáty v privátním repu, automatická obnova).

### C) Android - podpisový keystore

Bez něj se APK podepíše debug klíčem: nainstalovat jde, ale nejde ho později
aktualizovat verzí podepsanou ostrým klíčem. Vytvoření (jednou a **zálohovat** -
ztráta keystoru znamená, že aplikaci nejde aktualizovat):

```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA \
  -keysize 2048 -validity 10000 -alias upload
base64 -i upload-keystore.jks | pbcopy
```

| Secret | Hodnota |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | base64 z `.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | heslo ke keystoru |
| `ANDROID_KEY_ALIAS` | alias klíče (výše `upload`) |
| `ANDROID_KEY_PASSWORD` | heslo ke klíči |

Lokálně (mimo CI) se stejné hodnoty dají zapsat do `android/key.properties`
(soubor je v `.gitignore`):

```properties
storeFile=/absolutní/cesta/upload-keystore.jks
storePassword=…
keyAlias=upload
keyPassword=…
```

---

## Lokální spuštění fastlane (na Macu)

```bash
cd ios
bundle install
ASC_KEY_ID=… ASC_ISSUER_ID=… ASC_KEY_P8="$(cat AuthKey_XXX.p8)" \
CERTIFICATE_PATH=dist.p12 CERTIFICATE_PASSWORD=… \
PROVISIONING_PROFILE_PATH=profile.mobileprovision \
bundle exec fastlane beta
```

## Časté chyby

| Hláška | Příčina |
|---|---|
| `No profiles for 'dev.svihalek.renoworkshop' were found` | chybí App Store profil pro tohle App ID, nebo je v secretu starý |
| `Invalid Provisioning Profile … certificate` | `.p12` a profil nepatří k sobě (profil vznikl s jiným certifikátem) |
| `The bundle version must be higher than the previously uploaded version` | build se pouští ručně přes `workflow_dispatch` po přečíslování; stačí znovu pushnout |
| `Authentication credentials are missing or invalid` | špatný `ASC_KEY_P8` (chybí BEGIN/END řádky) nebo klíč nemá roli App Manager |
| Android: `Keystore file not found` | `ANDROID_KEYSTORE_BASE64` je nastavený, ale ostatní tři secrety chybí |

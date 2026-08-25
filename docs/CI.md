# CI/CD — referenční přehled

Workflow: [.github/workflows/sestaveni.yml](../.github/workflows/sestaveni.yml).
Kostra i názvy secretů jsou převzaté z RenoCharge, ať se mezi projekty
nepřepínají různé postupy.

Postup nastavení krok za krokem: [NASTAVENI.md](NASTAVENI.md).

## Kdy se spouští

| Událost | Co běží |
|---|---|
| push do `main` | analýza, testy, APK, IPA → TestFlight |
| ruční spuštění (*Run workflow*) | to samé |
| push do jiné větve | nic |

macOS runner se u privátního repozitáře účtuje desetinásobkem minut, proto
se iOS nestaví z každé větve. Kdyby to mělo běžet i z pracovních větví,
stačí v `on:` přidat `branches: ["**"]`.

## Joby

| Job | Runner | Co dělá |
|---|---|---|
| `kontrola` | ubuntu | `dart format --set-exit-if-changed`, `flutter analyze`, `flutter test`, spočítá číslo buildu |
| `android` | ubuntu | release APK (jeden univerzální), ověří podpis, uloží artefakt |
| `ios` | macOS | podepíše, archivuje, exportuje IPA, nahraje do TestFlightu |

Oba buildy navazují na `kontrola`, takže se analýza pouští jen jednou
a nepodepsané chyby neplýtvají macOS minutami.

## Číslo buildu

`POSUN_BUILDU (100) + github.run_number`. GitHub počítá `run_number` zvlášť
pro každý soubor s workflow — po přejmenování souboru začne od jedničky
a App Store Connect nové buildy odmítne jako už použité. Při přejmenování
souboru se proto posun musí zvýšit nad nejvyšší dosud nahrané číslo.
Snížit ho nejde nikdy.

Job `ios` po archivaci kontroluje, že archiv nese očekávané číslo — jinak by
odmítnutí přišlo až asynchronně od Applu a workflow by zůstal zelený.

## Kde jsou výstupy

- **APK**: Actions → konkrétní běh → dole **Artifacts** → `RenoWorkshop-apk-<číslo>`
  (60 dní). Instaluje se přímo v telefonu.
- **IPA**: stejné místo, `RenoWorkshop-ipa-<číslo>`.
- **TestFlight**: App Store Connect → TestFlight, do ~15 minut po doběhnutí.

## Secrety

### iOS (povinné)

| Secret | Odkud |
|---|---|
| `APP_STORE_CONNECT_KEY_ID` | App Store Connect → Users and Access → Integrations |
| `APP_STORE_CONNECT_ISSUER_ID` | tamtéž, nad seznamem klíčů |
| `APP_STORE_CONNECT_PRIVATE_KEY` | obsah `AuthKey_….p8` |
| `IOS_DIST_CERT_P12_BASE64` | `AppleCerts\distribution.p12.base64.txt` |
| `IOS_DIST_CERT_PASSWORD` | `AppleCerts\p12-heslo.txt` |
| `IOS_PROVISIONING_PROFILE_BASE64` | base64 z `.mobileprovision` |
| `IOS_PROVISIONING_PROFILE_NAME` | přesný název profilu z portálu |
| `APPLE_TEAM_ID` | `CZRDLTZC6L` |

### Android (nepovinné)

| Secret | Odkud |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `tools/create-android-keystore.sh` |
| `ANDROID_KEYSTORE_PASSWORD` | heslo zadané skriptu |
| `ANDROID_KEY_ALIAS` | `upload` |
| `ANDROID_KEY_PASSWORD` | stejné heslo |

Bez nich se APK podepíše ladicím klíčem: nainstalovat jde, ale podpis se mezi
běhy liší, takže před instalací nové verze je nutné tu starou odinstalovat.
Build kvůli tomu nespadne, jen se v běhu objeví poznámka.

Lokálně se stejné hodnoty píšou do `android/key.properties` (v `.gitignore`):

```properties
storeFile=/absolutní/cesta/upload-keystore.p12
storePassword=…
keyAlias=upload
keyPassword=…
storeType=PKCS12
```

## Obnova certifikátu

Distribuční certifikát platí do **4. 8. 2027**. Nový se dá vyrobit na Windows
bez Macu — přesně tak vznikl ten současný:

```bash
cd /c/Users/svihalek/AppleCerts
export MSYS2_ARG_CONV_EXCL="/emailAddress="

# 1) žádost o certifikát (CSR) + soukromý klíč
openssl req -new -newkey rsa:2048 -nodes -keyout distribution-2027.key -out distribution-2027.csr -subj "/emailAddress=jan.svihalek00@gmail.com/CN=Jan Svihalek/C=CZ"
```

2. <https://developer.apple.com/account/resources/certificates/add> →
   **Apple Distribution** → nahraj `distribution-2027.csr` → stáhni `.cer`.

```bash
# 3) .cer -> .pem -> .p12
openssl x509 -in distribution-2027.cer -inform DER -out distribution-2027.pem -outform PEM
openssl pkcs12 -export -inkey distribution-2027.key -in distribution-2027.pem -out distribution-2027.p12 -passout "pass:HESLO"
base64 -w0 distribution-2027.p12 > distribution-2027.p12.base64.txt
```

4. Přepiš secrety `IOS_DIST_CERT_P12_BASE64` a `IOS_DIST_CERT_PASSWORD`.
5. V portálu přegeneruj provisioning profil (nový certifikát = nový profil)
   a přepiš `IOS_PROVISIONING_PROFILE_BASE64`.

## Časté chyby

| Hláška | Příčina |
|---|---|
| `No signing certificate "iOS Distribution" found` | špatný nebo useknutý `IOS_DIST_CERT_P12_BASE64`, nebo nesedí heslo |
| `Provisioning profile "…" doesn't match the bundle identifier` | profil je pro jiné App ID |
| `doesn't include signing certificate` | profil byl vyroben s jiným certifikátem, než je v `.p12` |
| `Archiv nese build X, čekal se Y` | `flutter build ios` neproběhl před archivací, nebo se přepsal Generated.xcconfig |
| `The bundle version must be higher…` | číslo buildu už bylo nahrané — zvýšit `POSUN_BUILDU` |
| `Authentication credentials are missing or invalid` | `APP_STORE_CONNECT_PRIVATE_KEY` bez řádků `BEGIN`/`END`, nebo odvolaný klíč |
| `No suitable application records were found` | aplikace není založená v App Store Connect |
| Android `Keystore file not found` | `ANDROID_KEYSTORE_BASE64` je nastavený, ale zbylé tři secrety chybí |

## Poznámka k viditelnosti repa

`JanSvihalek/RenoWorkshop` je veřejný — Actions jsou tím zdarma včetně macOS
runnerů. Po přepnutí na privátní se macOS minuty počítají desetinásobkem
(2 000 minut ve free tarifu ≈ 200 minut macOS, tj. zhruba 15 iOS buildů měsíčně).

# Nastavení buildů krok za krokem

Postup je stejný jako u RenoCharge — workflow [sestaveni.yml](../.github/workflows/sestaveni.yml)
je z něj převzatý. Kdo dělal nastavení tam, tady nenarazí na nic nového.

**Časová náročnost:** zhruba 20 minut.
**Co budeš potřebovat:** prohlížeč a Git Bash.

**Co se tím zapne:** po pushi do `main` (nebo po ručním spuštění) se sestaví
Android APK ke stažení z Actions a iOS build, který se nahraje do TestFlightu.

**Mac potřeba není.** Distribuční certifikát už máš vyrobený z minula přes
OpenSSL na Windows a leží v `C:\Users\svihalek\AppleCerts\`.

---

## Co už je hotové

| Věc | Stav |
|---|---|
| Distribuční certifikát | `Apple Distribution: Jan Svihalek (CZRDLTZC6L)`, platí do **4. 8. 2027** |
| `.p12` a jeho base64 | `AppleCerts\distribution.p12`, `distribution.p12.base64.txt` |
| Heslo k `.p12` | `AppleCerts\p12-heslo.txt` |
| Team ID | `CZRDLTZC6L` |
| App Store Connect API klíč | existuje (viz krok 1 — doporučuji vyměnit) |

Jeden distribuční certifikát podepisuje libovolný počet aplikací, takže se
pro RenoWorkshop použije ten samý jako pro RenoCharge. Nový je jen provisioning
profil, protože ten je vždycky vázaný na konkrétní bundle ID.

---

## Krok 1: Vyměň App Store Connect klíč

Obsah `AuthKey_7UCAN7LWSU.p8` se objevil v chatu, takže ho ber jako vyzrazený.
Je to klíč s rolí Admin k celému účtu.

1. <https://appstoreconnect.apple.com> → **Users and Access** → **Integrations**
   → **App Store Connect API**.
2. U klíče *GitHub actions* najeď myší na řádek → **Revoke**.
3. Klikni na **+**, jméno třeba `GitHub actions 2`, přístup **Admin** → **Generate**.
4. Stáhni `.p8` (jde to jen jednou) a ulož ho do `C:\Users\svihalek\AppleCerts\`.
5. Poznač si nové **Key ID** ze sloupce v tabulce.

Klíč pro CodeMagic nech být, ten se odvoláním prvního klíče nedotkne.

## Krok 2: App ID pro novou aplikaci

1. <https://developer.apple.com/account/resources/identifiers/list>
2. Modré **+** vedle nadpisu *Identifiers*.
3. Vyber **App IDs** → **Continue** → typ **App** → **Continue**.
4. **Description:** `RenoWorkshop`
5. **Bundle ID:** vyber **Explicit** a napiš `dev.svihalek.renoworkshop`
6. Capabilities nech, jak jsou (appka zatím nic zvláštního nepotřebuje).
7. **Continue** → **Register**.

## Krok 3: Provisioning profil

1. <https://developer.apple.com/account/resources/profiles/list> → modré **+**.
2. V sekci *Distribution* vyber **App Store Connect** → **Continue**.
3. **App ID:** vyber `RenoWorkshop (dev.svihalek.renoworkshop)` → **Continue**.
4. **Certificate:** vyber `Apple Distribution: Jan Svihalek` (ten stávající,
   platný do 4. 8. 2027) → **Continue**.
5. **Provisioning Profile Name:** napiš přesně `RenoWorkshop` — tenhle název
   se pak dává do secretu `IOS_PROVISIONING_PROFILE_NAME`.
6. **Generate** → **Download**. Soubor ulož do `C:\Users\svihalek\AppleCerts\`.

Pak ho v Git Bash převeď na text:

```bash
cd /c/Users/svihalek/AppleCerts
base64 -w0 RenoWorkshop.mobileprovision > RenoWorkshop.mobileprovision.base64.txt
```

## Krok 4: Aplikace v App Store Connect

1. <https://appstoreconnect.apple.com> → **My Apps** → **+** → **New App**.
2. **Platforms:** iOS
3. **Name:** `RenoWorkshop`
4. **Primary Language:** Czech
5. **Bundle ID:** vyber `dev.svihalek.renoworkshop`
6. **SKU:** `renoworkshop` (interní označení, nikde se nezobrazuje)
7. **User Access:** Full Access → **Create**

Bez tohohle kroku upload skončí chybou, že aplikace neexistuje.

## Krok 5: Secrety na GitHubu

github.com/JanSvihalek/RenoWorkshop → **Settings** → v levém sloupci
**Secrets and variables** → **Actions** → tlačítko **New repository secret**.

Postup je u každého stejný: *Name* → *Secret* → **Add secret**.

Soubory otevřeš v Poznámkovém bloku (pravým → Otevřít v aplikaci).

**Jak kopírovat, aby to fungovalo:**

- U `.p8` a u base64 souborů použij **Ctrl+A** a **Ctrl+C** — potřebuješ celý obsah.
- U `p12-heslo.txt` **ne**. Soubor má na konci odřádkování a to se do secretu
  dostat nesmí, jinak `security import` na runneru selže. Klikni na začátek
  řádku, zmáčkni **Shift+End** (označí jen text řádku) a pak Ctrl+C.
- Ověřeno: `distribution.p12.base64.txt` je 4 260 znaků na jednom řádku bez
  odřádkování, heslo má 24 znaků. Když ti Poznámkový blok ukáže něco jiného,
  něco se cestou ztratilo.

| Name | Hodnota |
|---|---|
| `APP_STORE_CONNECT_KEY_ID` | Key ID nového klíče z kroku 1 |
| `APP_STORE_CONNECT_ISSUER_ID` | `7602e4a0-5793-41a3-bb7c-d49934876e3d` |
| `APP_STORE_CONNECT_PRIVATE_KEY` | obsah nového `AuthKey_….p8` (celý, včetně `-----BEGIN PRIVATE KEY-----`) |
| `IOS_DIST_CERT_P12_BASE64` | obsah `AppleCerts\distribution.p12.base64.txt` |
| `IOS_DIST_CERT_PASSWORD` | obsah `AppleCerts\p12-heslo.txt` |
| `IOS_PROVISIONING_PROFILE_BASE64` | obsah `RenoWorkshop.mobileprovision.base64.txt` z kroku 3 |
| `IOS_PROVISIONING_PROFILE_NAME` | `RenoWorkshop` |
| `APPLE_TEAM_ID` | `CZRDLTZC6L` |

## Krok 6: Android podpis (nepovinné, ale doporučené)

Bez vlastního klíče podepisuje Gradle ladicím klíčem — APK jde nainstalovat,
ale při každém buildu je podpis jiný, takže tester musí před instalací nové
verze tu starou odinstalovat.

```bash
cd /c/Users/svihalek/RenoWorkshop
bash tools/create-android-keystore.sh "sem-dej-svoje-heslo"
```

Vzniknou `upload-keystore.p12` a `upload-keystore.p12.base64`.
**Ten `.p12` si zazálohuj mimo počítač** — bez něj už nepůjde vydat aktualizaci
a uživatelé budou muset appku odinstalovat a nainstalovat znovu.

| Name | Hodnota |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | obsah `upload-keystore.p12.base64` |
| `ANDROID_KEYSTORE_PASSWORD` | tvoje heslo |
| `ANDROID_KEY_ALIAS` | `upload` |
| `ANDROID_KEY_PASSWORD` | stejné heslo |

## Krok 7: Spusť build

<https://github.com/JanSvihalek/RenoWorkshop/actions> → vlevo
**Sestavení aplikace** → **Run workflow** → zeleně **Run workflow**.

Trvá 10–20 minut (iOS je pomalejší). Očekávaný výsledek:

- **Analýza a testy** zeleně,
- **Sestavení APK** zeleně, dole na stránce běhu je v sekci *Artifacts*
  soubor `RenoWorkshop-apk-101`,
- **Sestavení a TestFlight** zeleně, build se do ~15 minut objeví
  v App Store Connect → TestFlight.

Od téhle chvíle se to samo spouští při každém pushi do `main`.

## Krok 8: Testeři v TestFlightu

App Store Connect → **My Apps** → **RenoWorkshop** → záložka **TestFlight**
→ vlevo **Internal Testing** → **+** → skupina `Dílna` → **Testers +**
a přidej kolegy. Ti si do telefonu nainstalují aplikaci **TestFlight**
z App Storu, pozvánka jim přijde mailem.

---

## Přehled secretů

| Secret | Krok |
|---|---|
| `APP_STORE_CONNECT_KEY_ID` | 5 |
| `APP_STORE_CONNECT_ISSUER_ID` | 5 |
| `APP_STORE_CONNECT_PRIVATE_KEY` | 5 |
| `IOS_DIST_CERT_P12_BASE64` | 5 |
| `IOS_DIST_CERT_PASSWORD` | 5 |
| `IOS_PROVISIONING_PROFILE_BASE64` | 5 |
| `IOS_PROVISIONING_PROFILE_NAME` | 5 |
| `APPLE_TEAM_ID` | 5 |
| `ANDROID_KEYSTORE_BASE64` | 6 |
| `ANDROID_KEYSTORE_PASSWORD` | 6 |
| `ANDROID_KEY_ALIAS` | 6 |
| `ANDROID_KEY_PASSWORD` | 6 |

Android čtveřice je nepovinná. iOS osmice povinná — bez ní iOS job spadne.

## Co hlídat v kalendáři

| Kdy | Co |
|---|---|
| **4. 8. 2027** | vyprší distribuční certifikát — vyrobit nový (CSR přes OpenSSL, viz [CI.md](CI.md#obnova-certifikátu)) a přegenerovat profily |
| při změně bundle ID | nový App ID i nový profil |

## Na co si dát pozor

- **Necommituj** `.p12`, `.p8`, `.mobileprovision` ani hesla. Jsou v `.gitignore`.
- Secret jde po vytvoření jen přepsat, ne přečíst. Když si nejsi jistý, ulož ho znovu.
- Při kopírování z Poznámkového bloku musí být vždycky **celý** obsah včetně
  prvního řádku — useknutý `.p8` je nejčastější příčina chyby
  *Authentication credentials are missing or invalid*.

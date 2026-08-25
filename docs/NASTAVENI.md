# Nastavení buildů krok za krokem

Postup je stejný jako u RenoCharge — workflow [sestaveni.yml](../.github/workflows/sestaveni.yml)
je z něj převzatý.

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
| Heslo k `.p12` | `AppleCerts\p12-heslo.txt` (24 znaků + odřádkování na konci) |
| Team ID | `CZRDLTZC6L` |
| Issuer ID | `7602e4a0-5793-41a3-bb7c-d49934876e3d` |

Jeden distribuční certifikát podepisuje libovolný počet aplikací, takže se
pro RenoWorkshop použije ten samý jako pro RenoCharge. Nový je jen provisioning
profil, protože ten je vždycky vázaný na konkrétní bundle ID.

---

## Krok 1: Nový App Store Connect klíč — HOTOVO

Klíč vygenerovaný s rolí **App Manager**, `.p8` uložený v `AppleCerts\`,
secrety `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`
a `APP_STORE_CONNECT_PRIVATE_KEY` nastavené.

Starý klíč `7UCAN7LWSU` zatím zůstává aktivní kvůli ostatním projektům —
ruší se až v kroku 9.

---

## Krok 2: App ID pro novou aplikaci

App ID je registrace bundle ID u Applu. Bez něj nejde vyrobit provisioning
profil, takže tohle je první kámen.

**Kde:** <https://developer.apple.com/account/resources/identifiers/list>
(Developer portál — jiný web než App Store Connect, snadno se pletou.)

1. Vpravo nahoře zkontroluj, že jsi přihlášený pod svým Apple ID a že je
   vybraný tým **Jan Svihalek (CZRDLTZC6L)**. Když máš víc týmů, přepíná se
   to v rozbalovátku vedle jména.
2. Vedle nadpisu **Identifiers** klikni na modré **+**.
3. Otevře se *Register a New Identifier* se seznamem přepínačů. Nahoře je
   **App IDs** — vyber ho a dej **Continue** (tlačítko vpravo nahoře, ne dole).
4. *Select a type*: vyber **App** → **Continue**.
5. Vyplň formulář *Register an App ID*:
   - **Platform:** nech **iOS, tvOS, watchOS**
   - **Description:** `RenoWorkshop`
     Apple tady nepovolí tečky, pomlčky ani jiné speciální znaky — když si
     bude stěžovat, napiš prostě `RenoWorkshop` bez ničeho dalšího.
   - **Bundle ID:** přepni přepínač na **Explicit** a do pole napiš přesně:
     ```
     dev.svihalek.renoworkshop
     ```
     Musí to sedět znak po znaku s tím, co je v appce (`applicationId`
     v `android/app/build.gradle.kts` a `PRODUCT_BUNDLE_IDENTIFIER` v Xcode
     projektu). Překlep se projeví až o dva kroky dál jako nesrozumitelná
     chyba při exportu IPA.
6. Sjeď dolů k seznamu *Capabilities*. **Nic nezaškrtávej** — appka zatím
   nemá push notifikace, přihlášení přes Apple ani nic jiného, co by se sem
   muselo hlásit.
7. **Continue** → zkontroluj přehled → **Register**.

**Kontrola:** v seznamu Identifiers přibyl řádek `RenoWorkshop`
s identifikátorem `dev.svihalek.renoworkshop`.

---

## Krok 3: Provisioning profil

Profil je papír, který říká „tenhle certifikát smí podepisovat tuhle
aplikaci". Certifikát zůstává stávající, nový je jen profil.

**Kde:** <https://developer.apple.com/account/resources/profiles/list>

1. Vedle nadpisu **Profiles** klikni na modré **+**.
2. *Register a New Provisioning Profile* — seznam je rozdělený na dvě části:
   **Development** a **Distribution**. Potřebuješ tu druhou: vyber
   **App Store Connect** (v některých verzích portálu ještě *App Store*)
   → **Continue**.

   Pozor, ať to není *Ad Hoc* — ten slouží k instalaci na konkrétní zařízení
   podle UDID a do TestFlightu s ním upload neprojde.
3. *Select an App ID*: v rozbalovátku vyber
   `RenoWorkshop (dev.svihalek.renoworkshop)` → **Continue**.
4. *Select Certificates*: uvidíš seznam distribučních certifikátů. Vyber ten
   s platností **do 4. 8. 2027** — jmenuje se `Apple Distribution` a je to
   ten samý, kterým se podepisuje RenoCharge.

   Kdyby jich bylo víc a nevěděl jsi který, pomůže tenhle příkaz v Git Bash:
   ```bash
   openssl x509 -in /c/Users/svihalek/AppleCerts/distribution-novy.cer -inform DER -noout -dates
   ```
   Vypíše `notAfter=Aug  4 06:07:36 2027 GMT` — v portálu vyber ten se stejným
   datem vypršení. Pak **Continue**.
5. *Review, Name and Generate* → **Provisioning Profile Name:** napiš přesně
   `RenoWorkshop`.

   Tenhle text musí znak po znaku odpovídat secretu
   `IOS_PROVISIONING_PROFILE_NAME`. Kdyby se lišil byť mezerou navíc, export
   IPA spadne na hlášce, že profil nebyl nalezen.
6. **Generate** → na další stránce **Download**. Stáhne se
   `RenoWorkshop.mobileprovision` (kolem 12 kB).
7. Přesuň ho z Downloads do `C:\Users\svihalek\AppleCerts\`.

Pak v **Git Bash** převeď profil na text, který jde vložit do secretu:

```bash
cd /c/Users/svihalek/AppleCerts
base64 -w0 RenoWorkshop.mobileprovision > RenoWorkshop.mobileprovision.base64.txt
wc -c RenoWorkshop.mobileprovision.base64.txt
```

**Kontrola:** `wc -c` má vypsat číslo kolem **16 000**. Když je výrazně menší,
stáhl se jiný soubor; když příkaz vypíše chybu, nejsi ve správném adresáři.

---

## Krok 4: Aplikace v App Store Connect

Bez tohohle kroku projde build i podpis, ale upload skončí hláškou
*No suitable application records were found*.

**Kde:** <https://appstoreconnect.apple.com/apps>

1. Vedle nadpisu **Apps** klikni na modré **+** → **New App**.
2. V dialogu vyplň:
   - **Platforms:** zaškrtni **iOS** (ostatní nech prázdné)
   - **Name:** `RenoWorkshop`

     Jméno musí být unikátní v rámci celého App Storu, i když appku nikdy
     veřejně nevydáš. Kdyby bylo zabrané, dej `RenoWorkshop RENOCAR` —
     na TestFlight to nemá vliv.
   - **Primary Language:** `Czech`
   - **Bundle ID:** v rozbalovátku vyber `dev.svihalek.renoworkshop`

     Když tam není, App ID z kroku 2 se ještě nepropsalo — počkej minutu
     a načti stránku znovu.
   - **SKU:** `renoworkshop`

     Interní označení pro tvoji evidenci, nikde se nezobrazuje a nedá se
     později změnit. Cokoli bez mezer stačí.
   - **User Access:** **Full Access**
3. **Create**.

Aplikaci nemusíš dál nijak vyplňovat — screenshoty, popis ani cenu. Ty jsou
potřeba až při vydání do App Storu, na TestFlight stačí, že existuje.

**Kontrola:** v *My Apps* je dlaždice **RenoWorkshop** se stavem
*Prepare for Submission*.

---

## Krok 5: Pět zbývajících secretů

**Kde:** <https://github.com/JanSvihalek/RenoWorkshop/settings/secrets/actions>

U každého: **New repository secret** → *Name* → *Secret* → **Add secret**.
Názvy piš přesně, velkými písmeny s podtržítky.

### Jak kopírovat, ať to projde

Soubory otevírej v **Poznámkovém bloku** (pravým tlačítkem → Otevřít
v aplikaci → Poznámkový blok), ne v editoru kódu.

- **Base64 soubory a `.p8`:** Ctrl+A, Ctrl+C — potřebuješ úplně všechno.
- **`p12-heslo.txt`:** tady Ctrl+A **ne**. Soubor má na konci odřádkování
  a kdyby se dostalo do secretu, import certifikátu na runneru selže.
  Klikni na začátek řádku → **Shift+End** → Ctrl+C.

### Hodnoty

| Name | Odkud |
|---|---|
| `IOS_DIST_CERT_P12_BASE64` | `AppleCerts\distribution.p12.base64.txt` — 4 260 znaků na jednom řádku |
| `IOS_DIST_CERT_PASSWORD` | `AppleCerts\p12-heslo.txt` — 24 znaků, bez odřádkování |
| `IOS_PROVISIONING_PROFILE_BASE64` | `AppleCerts\RenoWorkshop.mobileprovision.base64.txt` z kroku 3 |
| `IOS_PROVISIONING_PROFILE_NAME` | `RenoWorkshop` — už se nepoužívá, workflow si jméno čte z profilu |
| `APPLE_TEAM_ID` | `CZRDLTZC6L` — už se nepoužívá, team se čte z profilu |

**Kontrola:** na stránce je celkem **osm** secretů — tři z kroku 1 a těchto
pět. Hodnoty už si žádné nepřečteš, jde je jen přepsat; při pochybnostech
secret prostě ulož znovu.

> Poslední dva (`IOS_PROVISIONING_PROFILE_NAME`, `APPLE_TEAM_ID`) workflow
> od 25. 8. 2026 nepotřebuje — jméno profilu, jeho UUID i team si čte přímo
> z nahraného profilu, takže se nemůžou rozejít. Nechat je tam nevadí, ale
> když je smažeš, budou v logu vidět skutečné hodnoty místo `***`, což se
> hodí při hledání chyb.

---

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

---

## Krok 7: Spusť build

<https://github.com/JanSvihalek/RenoWorkshop/actions> → vlevo
**Sestavení aplikace** → **Run workflow** → zeleně **Run workflow**.

| Job | Trvá | Co dělá |
|---|---|---|
| Analýza a testy | ~2 min | formátování, `flutter analyze`, 28 testů |
| Sestavení APK | ~5 min | release APK |
| Sestavení a TestFlight | 10–20 min | podpis, archiv, export IPA, upload |

Výstupy jsou **dole na stránce běhu** v sekci *Artifacts*:
`RenoWorkshop-apk-<číslo>` a `RenoWorkshop-ipa-<číslo>`. APK stáhneš jako zip,
rozbalíš a pošleš na dílnu — telefon si při instalaci řekne o povolení
instalovat z tohohle zdroje.

iOS build se v App Store Connect → TestFlight objeví do ~15 minut, nejdřív
jako *Processing*, pak *Ready to Test*.

Od téhle chvíle se všechno spouští samo při každém pushi do `main`.

---

## Krok 8: Testeři v TestFlightu

App Store Connect → **My Apps** → **RenoWorkshop** → záložka **TestFlight**
→ vlevo **Internal Testing** → **+** → skupina `Dílna` → **Testers +**
a přidej kolegy (musí mít účet v týmu, viz *Users and Access*; interních
testerů může být až 100).

Tester si do telefonu nainstaluje aplikaci **TestFlight** z App Storu,
pozvánka mu přijde mailem.

---

## Krok 9: Dokonči výměnu klíče

Až tady všechno běží, přepiš nový klíč i v ostatních projektech, které
používaly `7UCAN7LWSU`, a teprve pak ten starý zruš:

1. **torkis** → Settings → Secrets → přepiš `ASC_KEY_ID` a `ASC_KEY_BASE64`.
   Pozor, tenhle projekt drží klíč jako base64 (`base64 -w0 AuthKey_….p8`),
   ne jako čistý text.
2. **renocharge** → přepiš `APP_STORE_CONNECT_KEY_ID`
   a `APP_STORE_CONNECT_PRIVATE_KEY` (tam je klíč jako čistý text).
3. V obou pusť build a ověř, že upload do TestFlightu prošel.
4. Teprve pak: App Store Connect → Users and Access → Integrations →
   u klíče *GitHub actions* → **Revoke**.

`ASC_ISSUER_ID` se nemění, ten je pro celý účet stejný. Klíče *CodeMagic*
se to netýká.

---

## Přehled secretů

| Secret | Krok |
|---|---|
| `APP_STORE_CONNECT_KEY_ID` | 1 |
| `APP_STORE_CONNECT_ISSUER_ID` | 1 |
| `APP_STORE_CONNECT_PRIVATE_KEY` | 1 |
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

## Když něco spadne

Klikni na červený job, pak na krok s křížkem. Důležité jsou poslední řádky logu.

| Hláška | Co s tím |
|---|---|
| `No signing certificate "iOS Distribution" found` | špatně zkopírovaný `IOS_DIST_CERT_P12_BASE64` nebo heslo s odřádkováním |
| `doesn't include signing certificate` | profil byl vyroben s jiným certifikátem — přegenerovat profil (krok 3, bod 4) |
| `Provisioning profile … doesn't match the bundle identifier` | profil je pro jiné App ID |
| `No profiles for 'dev.svihalek.renoworkshop' were found` | nesedí `IOS_PROVISIONING_PROFILE_NAME` s názvem v portálu |
| `Authentication credentials are missing or invalid` | useknutý `.p8` (chybí řádky BEGIN/END) |
| `No suitable application records were found` | chybí krok 4 |
| `The bundle version must be higher…` | číslo buildu už bylo použité — zvýšit `POSUN_BUILDU` v workflow |

## Co hlídat v kalendáři

| Kdy | Co |
|---|---|
| **4. 8. 2027** | vyprší distribuční certifikát — vyrobit nový (CSR přes OpenSSL, viz [CI.md](CI.md#obnova-certifikátu)) a přegenerovat profily |
| při změně bundle ID | nový App ID i nový profil |

## Na co si dát pozor

- **Necommituj** `.p12`, `.p8`, `.mobileprovision` ani hesla. Jsou v `.gitignore`.
- Soubory s klíči otevírej v Poznámkovém bloku, ne v editoru kódu.
- Secret jde po vytvoření jen přepsat, ne přečíst.

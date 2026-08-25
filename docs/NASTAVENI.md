# Nastavení buildů krok za krokem

Návod pro zapnutí automatických buildů. Popisuje i kliknutí, která zkušenému
člověku přijdou samozřejmá — nic se nepřeskakuje.

**Časová náročnost:** zhruba 40 minut.
**Co budeš potřebovat:** prohlížeč a Git Bash (nainstalovaný spolu s Gitem).

**Co se tím zapne:** po každém pushi do GitHubu se sám postaví Android APK
(ke stažení z Actions) a iOS build, který se nahraje do TestFlightu.

Pořadí kroků dodrž — krok 6 nefunguje, dokud nejsou hotové kroky 1 až 5.

---

## Slovníček

| Pojem | Co to je |
|---|---|
| **Secret** | Tajná hodnota uložená v GitHubu (heslo, klíč). Workflow ji umí použít, ale nikdo ji už nepřečte — ani ty. |
| **Variable** | To samé, ale netajné — jde přečíst. |
| **Workflow** | Postup, který GitHub spustí sám (u nás: postav appku). Leží v `.github/workflows/`. |
| **Artefakt** | Soubor, který workflow vyrobil (u nás APK) a jde stáhnout. |
| **Certifikát a provisioning profil** | Apple jimi ověřuje, že aplikaci vydáváš ty. Bez nich iOS build neprojde. |
| **match** | Nástroj, který certifikát a profil vyrobí a uloží zašifrované do privátního repozitáře. Díky němu není potřeba Mac. |
| **Keystore** | Podpisový klíč pro Android. Ztráta = konec aktualizací aplikace. |

---

## Krok 1: Otevři si stránku se secrety

1. Jdi na <https://github.com/JanSvihalek/RenoWorkshop>
2. Nahoře klikni na záložku **Settings** (ozubené kolo, vpravo v řadě
   Code / Issues / Pull requests / …).
3. V levém sloupci najdi **Secrets and variables** a klikni na **Actions**.
4. Uvidíš tlačítko **New repository secret** — tím se přidává každá hodnota
   v následujících krocích. Tuhle záložku si nech otevřenou.

Postup pro každý secret je vždycky stejný: **New repository secret** →
do pole *Name* napiš přesný název (velká písmena a podtržítka, bez mezer) →
do pole *Secret* vlož hodnotu → **Add secret**.

> Jestli v Settings nevidíš *Secrets and variables*, nejsi přihlášený pod
> účtem, kterému repozitář patří.

---

## Krok 2: Apple klíč (3 secrety)

Klíč už v App Store Connect máš — jmenuje se **GitHub actions** a má roli
Admin. Stačí ho přenést do GitHubu.

**2a) Otevři soubor s klíčem.** Ve Windows Průzkumníku jdi na:

```
C:\Users\svihalek\AppleCerts\AuthKey_7UCAN7LWSU.p8
```

Klikni na něj pravým tlačítkem → **Otevřít v aplikaci** → **Poznámkový blok**.
Uvidíš pár řádků textu začínajících `-----BEGIN PRIVATE KEY-----`.

Označ **úplně všechno** (Ctrl+A) a zkopíruj (Ctrl+C). Musí to být celé,
včetně prvního a posledního řádku s pomlčkami.

**2b) Vytvoř tyhle tři secrety:**

| Name | Secret |
|---|---|
| `ASC_KEY_ID` | `7UCAN7LWSU` |
| `ASC_ISSUER_ID` | `7602e4a0-5793-41a3-bb7c-d49934876e3d` |
| `ASC_KEY_P8` | vlož (Ctrl+V) obsah souboru z kroku 2a |

> Ten `.p8` soubor nikam nemaž a nikomu neposílej — Apple ho podruhé stáhnout
> nedá. Do chatu ani do commitu nepatří.

---

## Krok 3: Privátní repozitář na certifikáty

Certifikát pro iOS se musí někam ukládat, aby se negeneroval pořád znovu.

1. Jdi na <https://github.com/new>
2. **Repository name:** `RenoWorkshop-certificates`
3. Klikni na **Private** (důležité — bude tam podpisový klíč).
4. Zaškrtni **Add a README file**.
5. **Create repository**.

Hotovo, dovnitř nic nenahrávej — naplní se sám v kroku 6.

---

## Krok 4: Přístupový token pro ten repozitář (2 secrety)

Aby si build uměl certifikát z privátního repa stáhnout, potřebuje token.

**4a) Vyrob token:**

1. Jdi na <https://github.com/settings/personal-access-tokens/new>
   (proklikem: tvoje ikonka vpravo nahoře → Settings → úplně dole
   **Developer settings** → **Personal access tokens** → **Fine-grained tokens**
   → **Generate new token**).
2. **Token name:** `renoworkshop-match`
3. **Expiration:** vyber **1 year**. Za rok token vyprší a bude potřeba tenhle
   krok zopakovat — poznač si to.
4. **Repository access:** vyber **Only select repositories** a v seznamu klikni
   na `RenoWorkshop-certificates`.
5. **Permissions** → rozklikni **Repository permissions** → najdi řádek
   **Contents** → v rozbalovátku vpravo vyber **Read and write**.
   Nic dalšího nastavovat nemusíš.
6. Dole **Generate token**.
7. Zobrazí se dlouhý řetězec začínající `github_pat_…`. **Zkopíruj ho hned** —
   po zavření stránky ho GitHub už neukáže.

**4b) Převeď token do tvaru, kterému rozumí match:**

Otevři **Git Bash** (Start → napiš `Git Bash` → Enter) a vlož tenhle příkaz.
Místo `TVUJ_TOKEN` vlep zkopírovaný token:

```bash
printf 'JanSvihalek:TVUJ_TOKEN' | base64 -w0
```

Vypíše se jeden dlouhý řádek písmen a číslic — to je hodnota do dalšího secretu.

> V Git Bash se vkládá pravým tlačítkem myši → Paste, nebo Shift+Insert.
> Ctrl+V tam nefunguje.

**4c) Vytvoř dva secrety:**

| Name | Secret |
|---|---|
| `MATCH_GIT_URL` | `https://github.com/JanSvihalek/RenoWorkshop-certificates.git` |
| `MATCH_GIT_BASIC_AUTHORIZATION` | ten dlouhý řádek z kroku 4b |

---

## Krok 5: Heslo, kterým se certifikát zašifruje (1 secret)

Match obsah repa šifruje. Vymysli si heslo (klidně dlouhé, psát ho nebudeš)
a **ulož si ho do správce hesel** — bez něj se certifikát nedá znovu použít.

| Name | Secret |
|---|---|
| `MATCH_PASSWORD` | tvoje vymyšlené heslo |

---

## Krok 6: Spusť jednorázový iOS bootstrap

Teď GitHub sám na virtuálním Macu založí, co je pro iOS potřeba.

1. Jdi na <https://github.com/JanSvihalek/RenoWorkshop/actions>
2. V levém sloupci klikni na **iOS bootstrap (jednorázově)**.
3. Vpravo se objeví šedý pruh s tlačítkem **Run workflow** — klikni na něj,
   pak v rozbaleném okénku ještě jednou na zelené **Run workflow**.
4. Za pár vteřin se v seznamu objeví nový běh se žlutým kolečkem. Klikni na něj
   a sleduj průběh (trvá 5–10 minut).

Co se během toho stane:

- v Apple Developer portálu vznikne App ID `dev.svihalek.renoworkshop`,
- v App Store Connect vznikne aplikace **RenoWorkshop**,
- vznikne distribuční certifikát a provisioning profil,
- oboje se zašifrované uloží do `RenoWorkshop-certificates`.

**Až doběhne zeleně, máš iOS hotové.** Tenhle krok se pouští znovu jen za rok,
až certifikát vyprší.

Když spadne červeně, klikni na neúspěšný krok a přečti si poslední řádky.
Nejčastěji je to překlep v secretu; oprav ho a spusť workflow znovu. Přehled
hlášek je v [CI.md](CI.md#časté-chyby).

---

## Krok 7: Podpisový klíč pro Android (4 secrety)

**7a) Vyrob klíč.** V Git Bash spusť (heslo si vymysli a **ulož do správce
hesel**):

```bash
cd /c/Users/svihalek/RenoWorkshop
bash tools/create-android-keystore.sh "sem-dej-svoje-heslo"
```

Vzniknou dva soubory přímo v `C:\Users\svihalek\RenoWorkshop`:

- `upload-keystore.p12` — samotný klíč
- `upload-keystore.p12.base64` — jeho textová podoba pro GitHub

**7b) Zálohuj `upload-keystore.p12`** na OneDrive nebo jinam mimo počítač.
Když o něj přijdeš, nepůjde vydat aktualizaci aplikace a uživatelé ji budou
muset odinstalovat a nainstalovat znovu. Tohle je nejnepříjemnější věc, která
se dá v celém procesu pokazit.

**7c) Otevři `upload-keystore.p12.base64`** v Poznámkovém bloku, Ctrl+A, Ctrl+C.

**7d) Vytvoř čtyři secrety:**

| Name | Secret |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | obsah souboru z kroku 7c |
| `ANDROID_KEYSTORE_PASSWORD` | heslo z kroku 7a |
| `ANDROID_KEY_ALIAS` | `upload` |
| `ANDROID_KEY_PASSWORD` | stejné heslo jako `ANDROID_KEYSTORE_PASSWORD` |

---

## Krok 8: Testeři v TestFlightu

Aby kolegové appku dostali do telefonu:

1. Jdi na <https://appstoreconnect.apple.com> → **My Apps** → **RenoWorkshop**.
2. Nahoře záložka **TestFlight**.
3. Vlevo **Internal Testing** → tlačítko **+** → skupinu pojmenuj třeba
   `Dílna` → **Create**.
4. V ní **Testers +** a přidej kolegy (musí mít účet v tvém Apple týmu — viz
   *Users and Access*).
5. Tester si do telefonu nainstaluje aplikaci **TestFlight** z App Storu;
   pozvánka mu přijde mailem.

---

## Krok 9: Ověření, že to jede

Od téhle chvíle se build spustí sám při každém pushi. Zkontroluj to takhle:

1. <https://github.com/JanSvihalek/RenoWorkshop/actions> → nejnovější běh.
2. Zelené mají být všechny čtyři joby: *Kontrola konfigurace*,
   *Analyze + testy*, *Android (APK + AAB)*, *iOS (TestFlight)*.
3. **Android:** dole na stránce běhu je sekce **Artifacts** a v ní
   `android-<číslo>`. Stáhne se zip s APK — ten pošli komukoli na dílnu,
   nainstaluje se přímo (telefon se zeptá na povolení instalace z tohohle
   zdroje).
4. **iOS:** App Store Connect → TestFlight → build se objeví do ~15 minut
   se stavem *Processing*, pak *Ready to Test*.

---

## Přehled: co všechno má být nastavené

| Secret | Odkud |
|---|---|
| `ASC_KEY_ID` | krok 2 |
| `ASC_ISSUER_ID` | krok 2 |
| `ASC_KEY_P8` | krok 2 |
| `MATCH_GIT_URL` | krok 4 |
| `MATCH_GIT_BASIC_AUTHORIZATION` | krok 4 |
| `MATCH_PASSWORD` | krok 5 |
| `ANDROID_KEYSTORE_BASE64` | krok 7 |
| `ANDROID_KEYSTORE_PASSWORD` | krok 7 |
| `ANDROID_KEY_ALIAS` | krok 7 |
| `ANDROID_KEY_PASSWORD` | krok 7 |

Deset secretů. Když nějaký chybí, build nespadne — jen se příslušná část
přeskočí a v běhu je žluté varování s tím, co chybí.

---

## Co si uložit do správce hesel

- heslo ke keystoru (krok 7)
- `MATCH_PASSWORD` (krok 5)
- kam jsi zazálohoval `upload-keystore.p12`
- datum expirace tokenu z kroku 4

## Na co si dát pozor

- **Necommituj** `upload-keystore.p12`, `.p8` ani hesla. Git je má v
  `.gitignore`, takže by to nemělo hrozit, ale ať to nejde ani ručně.
- Secret jde po vytvoření jen **přepsat**, ne přečíst. Když si nejsi jistý,
  jestli jsi ho vložil správně, ulož ho prostě znovu.
- U hodnot z Poznámkového bloku pozor, ať se zkopíruje úplně všechno včetně
  prvního řádku — useknutý `.p8` je nejčastější příčina chyby
  *Authentication credentials are missing or invalid*.

# Co je nového v RenoWorkshopu

Pro techniky a testery: co přibylo a co se opravilo. Verzi (např. `1.1.0`)
najdete pod přihlášením a v Nastavení → O aplikaci, v závorce je číslo
buildu. Jak se verze číslují, je v [docs/CI.md](docs/CI.md#verze-aplikace).

## 1.1.0 – 22. 9. 2026

**Zakázky**
- Hledání prohledá samo i ukončené zakázky. Výsledky jsou ve dvou částech:
  Otevřené a Ukončené. Tlačítko „Hledat v archivu" už není potřeba.
- Řádková tabulka zakázek vedle karet (přepínač v hlavičce), sloupce podle
  Heliosu. Detail se z tabulky otevře přes celou obrazovku.
- Tlačítko pro načtení nových zakázek z Heliosu v hlavičce seznamu – pro
  zakázku, kterou poradce právě založil.
- Stažení prstem obnoví i tabulku, ne jen karty.
- Detail zakázky na tabletu na šířku ve dvou sloupcích: vlevo údaje
  o voze a příjmu, vpravo postup, poznámky a závady.
- Karta Předmět opravy je zatím schovaná.

**Příjem vozidla a fotodokumentace**
- Příjem jako průvodce po krocích s povinným checklistem kontrol.
- Sériové focení s bleskem, šipkou zpět a náhledem poslední fotky.
- Hromadné mazání vybraných fotek (dlouhý stisk na fotce).
- Fotky se ukládají do složky pobočky na serveru; pobočka jde zvolit
  v nastavení. Volitelně se ukládají i do zařízení.
- Ostatní dokumentace (ikona složky): nahrání PDF a dalších dokumentů
  a zobrazení všeho, co je ve složce zakázky na serveru mimo kategorie
  fotek – i souborů, které tam kolega vložil z počítače.
- Karta Fotodokumentace v detailu počítá fotky i dokumenty.

**Vozidla**
- Záložka Vozidla s lupou: hledání podle SPZ nebo VIN a karta vozidla.
- Na kartě vozidla je Datum registrace (dřív „Prodáno").

**Přihlášení a nastavení**
- Pod přihlášením i v nastavení je vidět, jestli se zařízení dostane na
  server. Při výpadku poradí firemní wi-fi (RenPriv, ISPA, ISPI)
  a samo to zkouší znovu.
- Když přihlášení Microsoftem skončí chybou „missing initial state",
  aplikace poradí zkusit to znovu – druhý pokus projde.
- Vzhled (světlý / tmavý / podle systému) jde přepnout i klepnutím na
  iniciály v hlavičce zakázek.
- Nastavení: zdroj dat Helios Data, verze aplikace, poloha spouště pro
  fotoaparát i skener.

**Pod kapotou**
- Aplikace zapisuje do logu obrazovky, důležité kroky a chyby, aby šlo
  dohledat, jak se technik k chybě dostal. Hledaný text ani text poznámek
  se nezapisují.

## 1.0.0 – 10. 9. 2026

První build na ostrých datech z Heliosu: seznam zakázek na dílně
s filtry, detail zakázky, dílenské stavy s historií a poznámkami, skener
SPZ a VIN, přihlášení firemním účtem Microsoft.

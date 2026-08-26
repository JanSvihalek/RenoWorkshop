# RenoWorkshop – ikona aplikace

Zdroj: varianta D (oboustranný otevřený klíč, 45°, modrý stavový bod).
Barvy: navy #031E49 · bílá #FFFDFE · akcent #4599FE.

## svg/ (vektorové mastery – vždy preferovat)
- renoworkshop-icon.svg — plná ikona (navy plocha)
- renoworkshop-icon-light-bg.svg — inverzní varianta pro světlé podklady
- renoworkshop-adaptive-background.svg — Android adaptive, vrstva pozadí
- renoworkshop-adaptive-foreground.svg — Android adaptive, vrstva motivu (66% safe zone, průhledné)

## png/ (plná ikona, čtvercová, bez zaoblení – masku aplikuje OS)
1024 App Store · 512 Google Play · 180/167/152/120/87/80/60/58/40/29 iOS · 192/144/96/72/48 Android mipmap · 432 adaptive canvas

## png/adaptive/ (průhledné foreground vrstvy pro Android)
432 (xxxhdpi canvas) · 324 · 216 · 162 · 108 (mdpi) — do res/mipmap-*/ic_launcher_foreground.png,
pozadí nastavit jako barvu #031E49 nebo renoworkshop-adaptive-background.svg.

## Poznámky
- iOS: ikona bez alfa kanálu a bez vlastního zaoblení; 1024 nahrát do App Store Connect.
- Android: ic_launcher.xml s <background android:drawable="@color/icon_bg"/> (#031E49)
  a <foreground android:drawable="@mipmap/ic_launcher_foreground"/>.
- Flutter: doporučeno flutter_launcher_icons s image_path = png/renoworkshop-icon-1024.png,
  adaptive_icon_background = "#031E49", adaptive_icon_foreground = png/adaptive/renoworkshop-foreground-432.png.

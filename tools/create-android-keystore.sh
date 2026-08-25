#!/usr/bin/env bash
# Vytvoří podpisový keystore pro Android bez JDK - jen přes OpenSSL,
# který je součástí Git for Windows (Git Bash) i macOS/Linuxu.
#
# Použití:
#   bash tools/create-android-keystore.sh "silne-heslo"
#
# Výstup (oba soubory jsou v .gitignore, nikdy je necommituj):
#   upload-keystore.p12          keystore - ZÁLOHUJ, bez něj nejde appku aktualizovat
#   upload-keystore.p12.base64   obsah pro GitHub secret ANDROID_KEYSTORE_BASE64
set -euo pipefail

PASSWORD="${1:-}"
if [ -z "$PASSWORD" ]; then
  echo 'Použití: bash tools/create-android-keystore.sh "silne-heslo"' >&2
  exit 1
fi

ALIAS="${KEY_ALIAS:-upload}"
SUBJECT="${KEY_SUBJECT:-/CN=RenoWorkshop/O=RENOCAR a.s./C=CZ}"
OUT_DIR="${OUT_DIR:-.}"
KEYSTORE="$OUT_DIR/upload-keystore.p12"

if [ -e "$KEYSTORE" ]; then
  echo "CHYBA: $KEYSTORE už existuje - nepřepisuji, ať nepřijdeš o klíč." >&2
  exit 1
fi

# Git Bash na Windows by z "/CN=..." udělal cestu k adresáři; tohle vyjme
# jen subjekt certifikátu, cesty k souborům se převádět dál musí.
export MSYS2_ARG_CONV_EXCL="/CN="

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Platnost ~27 let, ať certifikát nepřestane platit dřív než aplikace.
if ! openssl req -x509 -newkey rsa:2048 -sha256 -days 10000 -nodes -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -subj "$SUBJECT" 2>"$TMP/openssl.log"; then
  echo "CHYBA při generování klíče:" >&2
  cat "$TMP/openssl.log" >&2
  exit 1
fi

openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" -name "$ALIAS" -out "$KEYSTORE" -passout "pass:$PASSWORD"

# GNU base64 chce -w0, BSD (macOS) tenhle přepínač nezná.
if base64 --help 2>&1 | grep -q -- "-w"; then
  base64 -w0 "$KEYSTORE" > "$KEYSTORE.base64"
else
  base64 "$KEYSTORE" | tr -d '\n' > "$KEYSTORE.base64"
fi

cat <<INFO

Hotovo. Do GitHubu (Settings -> Secrets and variables -> Actions) vlož:

  ANDROID_KEYSTORE_BASE64    = obsah souboru $KEYSTORE.base64
  ANDROID_KEYSTORE_PASSWORD  = heslo, které jsi zadal
  ANDROID_KEY_ALIAS          = $ALIAS
  ANDROID_KEY_PASSWORD       = stejné heslo (PKCS#12 používá jedno)

Soubor $KEYSTORE si zálohuj mimo tenhle počítač.
Ztráta keystoru znamená, že už nepůjde vydat aktualizaci aplikace.
INFO

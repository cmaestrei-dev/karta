#!/usr/bin/env bash
# Crea la llave con que se firman los APK de Karta y deja frontend/android/key.properties apuntando a ella.
# La llave y su contraseña quedan en ~/.karta, fuera del repositorio, y la contraseña no se muestra: haz una copia
# de esa carpeta. Sin la misma llave, un APK nuevo no se instala encima del anterior, y Google Play pide la misma
# para actualizar la app.
set -euo pipefail

raiz="$(cd "$(dirname "$0")/../.." && pwd)"
carpeta="${KARTA_LLAVES:-$HOME/.karta}"
almacen="$carpeta/karta-subida.jks"
copia="$carpeta/key.properties"
propiedades="$raiz/frontend/android/key.properties"
keytool="${JAVA_HOME:+$JAVA_HOME/bin/}keytool"

mkdir -p "$carpeta"
chmod 700 "$carpeta"
if [[ ! -e "$almacen" ]]; then
  KARTA_CLAVE="$(python3 -c 'import secrets; print(secrets.token_urlsafe(24))')"
  export KARTA_CLAVE
  # PKCS12 usa la misma contraseña para el almacén y la llave.
  "$keytool" -genkeypair -keystore "$almacen" -storetype PKCS12 -alias karta -keyalg RSA -keysize 4096 \
    -validity 10000 -dname "CN=Karta, O=Karta, L=Cartagena, C=CO" \
    -storepass:env KARTA_CLAVE -keypass:env KARTA_CLAVE
  chmod 600 "$almacen"
  umask 077
  printf 'storePassword=%s\nkeyPassword=%s\nkeyAlias=karta\nstoreFile=%s\n' \
    "$KARTA_CLAVE" "$KARTA_CLAVE" "$almacen" > "$copia"
  echo "Llave creada en $almacen."
else
  echo "Ya hay una llave en $almacen: se usa esa."
fi
install -m 600 "$copia" "$propiedades"
echo "Listo: $propiedades apunta a la llave. Guarda una copia de $carpeta."

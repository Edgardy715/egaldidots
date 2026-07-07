#!/usr/bin/env bash
# Alterna el layout del teclado entre Inglés (us) y Español (es), estilo Windows.
# Disparado por:  bind = $mainMod, space, exec, ...
#
# Lógica:
#   1. Lee el teclado principal (main:true) de `hyprctl -j devices`.
#   2. Lee su `active_layout_index` (0 = Inglés, 1 = Español en "us,es").
#   3. Pasa al otro índice y lo aplica a TODOS los teclados (así quedan
#      sincronizados incluso con periféricos RGB que figuran como "teclado").
#   4. Notifica cuál quedó activo (notificación efímera vía swaync/notify-send).

set -uo pipefail

DEV="$(hyprctl -j devices)"

# Teclado principal = el que de verdad se usa para escribir.
MAIN="$(printf '%s' "$DEV" | jq -r '.keyboards[] | select(.main) | .name' | head -1)"
[ -z "$MAIN" ] && MAIN="$(printf '%s' "$DEV" | jq -r '.keyboards[0].name')"

# Índice activo en la lista "us,es"  (0 = Inglés, 1 = Español).
CUR="$(printf '%s' "$DEV" | jq -r --arg k "$MAIN" '.keyboards[] | select(.name==$k) | .active_layout_index')"
case "$CUR" in
    0) NEXT=1 ;;   # Inglés -> Español
    *) NEXT=0 ;;   # Español -> Inglés  (o cualquier valor inesperado)
esac

# Aplicar el mismo índice a todos los teclados para mantenerlos sincronizados.
while read -r kb; do
    [ -n "$kb" ] && hyprctl switchxkblayout "$kb" "$NEXT" >/dev/null 2>&1 || true
done < <(printf '%s' "$DEV" | jq -r '.keyboards[].name')

sleep 0.06

# Leer el keymap resultante del teclado principal y notificar.
LABEL="$(hyprctl -j devices | jq -r --arg k "$MAIN" '.keyboards[] | select(.name==$k) | .active_keymap')"
case "$LABEL" in
    *Spanish*) NAME="Español (ES)" ;;
    *)         NAME="Inglés (US)"  ;;
esac

# -e  => transitoria (no se acumula en el centro de notificaciones)
# -t  => 1.5 s;  -u low => prioridad baja;  -i => icono del tema de iconos
notify-send -e -t 1500 -u low -a "Teclado" -i "input-keyboard" "$NAME"

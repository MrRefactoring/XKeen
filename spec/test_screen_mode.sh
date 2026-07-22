#!/bin/sh
# Тесты режима экрана в BusyBox ash
#
# Проверяется, что вывод по умолчанию не стирается, а прежнее поведение
# возвращается через xkeen.json.

pass=0; fail=0
check() {
    if [ "$2" = "$3" ]; then
        printf 'OK   %s\n' "$1"; pass=$((pass+1))
    else
        printf 'FAIL %s\n       ожидалось [%s]\n       получено  [%s]\n' "$1" "$3" "$2"; fail=$((fail+1))
    fi
}

cfg=/tmp/xkeen.json

# smart_clear лежит в scripts/xkeen вперемешку с разбором аргументов, поэтому
# для теста вырезается сама функция — так проверяется тот же код, что в бою,
# без запуска всего диспетчера.
extract_smart_clear() {
    awk '/^smart_clear\(\) \{/,/^\}/' /repo/scripts/xkeen
}

load() {
    xkeen_config="$cfg"
    strip_json_comments() { sed -e 's|^[[:space:]]*//.*$||' "$@"; }
    . /dev/stdin <<EOF
$(awk '/^screen_mode_settings\(\) \{/,/^\}/' /repo/scripts/_xkeen/01_info/01_info_variable.sh)
$(extract_smart_clear)
EOF
    screen_mode_settings
}

# --- по умолчанию конфига нет ---
rm -f "$cfg"
load
check "без конфига режим flow" "$screen_mode" "flow"

LOGICAL_CMD_COUNT=1
out=$(smart_clear | od -c | head -1)
check "flow: smart_clear ничего не печатает" "$(printf '%s' "$out" | grep -c '033')" "0"

# --- пустой конфиг ---
echo '{}' > "$cfg"
load
check "пустой конфиг: режим flow" "$screen_mode" "flow"

# --- явное включение прежнего поведения ---
echo '{"xkeen":{"screen_mode":"clear"}}' > "$cfg"
load
check "screen_mode=clear читается" "$screen_mode" "clear"

LOGICAL_CMD_COUNT=1
out=$(smart_clear | od -c | head -1)
check "clear: экран стирается" "$(printf '%s' "$out" | grep -c '033')" "1"

# Стирание подавляется, когда за раз запущено несколько логических команд —
# иначе вывод предыдущей команды затирался бы следующей
LOGICAL_CMD_COUNT=3
out=$(smart_clear | od -c | head -1)
check "clear: при нескольких командах не стирает" "$(printf '%s' "$out" | grep -c '033')" "0"

# --- мусор в настройке не должен включать стирание ---
echo '{"xkeen":{"screen_mode":"cleer"}}' > "$cfg"
load
check "опечатка в значении не включает стирание" "$screen_mode" "flow"

echo '{"xkeen":{"screen_mode":null}}' > "$cfg"
load
check "null не включает стирание" "$screen_mode" "flow"

# --- битый JSON не должен ронять запуск ---
printf '{ это не json' > "$cfg"
load
check "битый JSON: откат на flow" "$screen_mode" "flow"

# --- комментарии в конфиге ---
printf '{\n  // комментарий\n  "xkeen": { "screen_mode": "clear" }\n}\n' > "$cfg"
load
check "комментарии в конфиге не мешают" "$screen_mode" "clear"

rm -f "$cfg"
printf '\n=== пройдено: %s, провалено: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]

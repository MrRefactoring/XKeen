#!/bin/sh
# Тесты навигации стрелками в BusyBox ash
#
# Псевдотерминал не нужен: read -s -n1 читает и из обычного файла, поэтому
# последовательности клавиш подаются перенаправлением. Определение
# возможностей терминала обходится через _ask_keys_mode.

italic=""; reset=""; red=""; green=""; yellow=""; light_blue=""

. /repo/scripts/_xkeen/04_tools/05_tools_choice/00_choice_ask.sh

pass=0; fail=0
check() {
    if [ "$2" = "$3" ]; then
        printf 'OK   %s\n' "$1"; pass=$((pass+1))
    else
        printf 'FAIL %s\n       ожидалось [%s]\n       получено  [%s]\n' "$1" "$3" "$2"; fail=$((fail+1))
    fi
}

keys=/tmp/keys.bin

# Escape-последовательности держим как строки для printf %b: подстановка
# команд срезала бы завершающий перевод строки, и Enter не доехал бы до read
UP='\033[A'; DOWN='\033[B'; ENTER='\n'; ESC='\033' 

# Принудительно включаем интерактивный путь: сам детектор требует терминала,
# которого в тестовом окружении нет
_ask_keys_mode="yes"

press() { printf '%b' "$1" > "$keys"; }

# --- перемещение и выбор ---
press "$ENTER"
ask_one "T" "1|A" "2|B" "3|C" >/dev/null 2>&1 < "$keys"
check "Enter выбирает первый пункт" "$REPLY_KEY" "1"

press "$DOWN$ENTER"
ask_one "T" "1|A" "2|B" "3|C" >/dev/null 2>&1 < "$keys"
check "стрелка вниз двигает курсор" "$REPLY_KEY" "2"

press "$DOWN$DOWN$ENTER"
ask_one "T" "1|A" "2|B" "3|C" >/dev/null 2>&1 < "$keys"
check "две стрелки вниз" "$REPLY_KEY" "3"

press "$UP$ENTER"
ask_one "T" "1|A" "2|B" "3|C" >/dev/null 2>&1 < "$keys"
check "вверх с первого пункта заворачивает на последний" "$REPLY_KEY" "3"

press "$DOWN$DOWN$DOWN$ENTER"
ask_one "T" "1|A" "2|B" "3|C" >/dev/null 2>&1 < "$keys"
check "вниз с последнего заворачивает на первый" "$REPLY_KEY" "1"

press "$UP$DOWN$ENTER"
ask_one "T" "1|A" "2|B" "3|C" >/dev/null 2>&1 < "$keys"
check "вверх и вниз возвращают на место" "$REPLY_KEY" "1"

# --- цифры продолжают работать ---
press "3"
ask_one "T" "1|A" "2|B" "3|C" >/dev/null 2>&1 < "$keys"
check "цифра выбирает сразу" "$REPLY_KEY" "3"

press "9$ENTER"
ask_one "T" "1|A" "2|B" >/dev/null 2>&1 < "$keys"
check "несуществующая цифра игнорируется" "$REPLY_KEY" "1"

# --- неактивные пункты пропускаются ---
press "$DOWN$ENTER"
ask_one "T" "1|A" "2|Недоступно|dim" "3|C" >/dev/null 2>&1 < "$keys"
check "курсор перепрыгивает неактивный пункт" "$REPLY_KEY" "3"

press "2$ENTER"
ask_one "T" "1|A" "2|Недоступно|dim" "3|C" >/dev/null 2>&1 < "$keys"
check "неактивный пункт не выбрать и цифрой" "$REPLY_KEY" "1"

# --- заголовки и разделители не участвуют в навигации ---
press "$DOWN$ENTER"
ask_one "T" "|Группа" "1|A" "|" "2|B" >/dev/null 2>&1 < "$keys"
check "заголовок и разделитель пропускаются" "$REPLY_KEY" "2"

# --- q ведёт к пункту по умолчанию, Esc больше не выходит ---
press "q"
ask_one "T" "1|A" "0|Отмена|default" >/dev/null 2>&1 < "$keys"
check "q выбирает пункт по умолчанию" "$REPLY_KEY" "0"

# Esc убран как выход (работал медленно из-за секундного таймаута): одиночный
# Esc игнорируется, дальше EOF -> ask_one возвращает 1 и НЕ выбирает default
press "$ESC"
ask_one "T" "1|A" "0|Отмена|default" >/dev/null 2>&1 < "$keys"; esc_rc=$?
check "Esc не выходит (игнорируется)" "$esc_rc" "1"
check "Esc не выбирает пункт по умолчанию" "$REPLY_KEY" ""

press "q$ENTER"
ask_one "T" "1|A" "2|B" >/dev/null 2>&1 < "$keys"
check "без умолчания q не выходит" "$REPLY_KEY" "1"

SP=' '

# --- одиночный выбор: Space активирует пункт под курсором (как Enter) ---
press "$SP"
ask_one "T" "1|A" "2|B" "3|C" >/dev/null 2>&1 < "$keys"
check "Пробел выбирает пункт под курсором (одиночное)" "$REPLY_KEY" "1"

press "$DOWN$SP"
ask_one "T" "1|A" "2|B" "3|C" >/dev/null 2>&1 < "$keys"
check "Пробел на втором пункте (одиночное)" "$REPLY_KEY" "2"

# --- множественный выбор: Space/Enter отмечают, «Подтвердить» (confirm) коммитит ---
# В меню 9 — Подтвердить (confirm), 0 — Пропустить (default). В тестах их
# активируем цифрой, на живом терминале — стрелками + Space/Enter.
press "${SP}9"
ask_many "T" "1|A" "2|B" "3|C" "9|OK|confirm" "0|Skip|default" >/dev/null 2>&1 < "$keys"
check "пробел отмечает пункт под курсором" "$REPLY_KEYS" "1"

press "${SP}${DOWN}${SP}9"
ask_many "T" "1|A" "2|B" "3|C" "9|OK|confirm" "0|Skip|default" >/dev/null 2>&1 < "$keys"
check "отмечаются несколько пунктов" "$REPLY_KEYS" "1 2"

press "${SP}${SP}${DOWN}${SP}9"
ask_many "T" "1|A" "2|B" "3|C" "9|OK|confirm" "0|Skip|default" >/dev/null 2>&1 < "$keys"
check "повторный пробел снимает отметку" "$REPLY_KEYS" "2"

press "${ENTER}9"
ask_many "T" "1|A" "2|B" "3|C" "9|OK|confirm" "0|Skip|default" >/dev/null 2>&1 < "$keys"
check "Enter в мультивыборе отмечает, а не коммитит" "$REPLY_KEYS" "1"

press "3${SP}9"
ask_many "T" "1|A" "2|B" "3|C" "9|OK|confirm" "0|Skip|default" >/dev/null 2>&1 < "$keys"
check "цифра отмечает, пробел отмечает курсор" "$REPLY_KEYS" "1 3"

press "9"
ask_many "T" "1|A" "2|B" "3|C" "9|OK|confirm" "0|Skip|default" >/dev/null 2>&1 < "$keys"
check "Подтвердить без отметок — пустой набор" "$REPLY_KEYS" ""

press "0"
ask_many "T" "1|A" "2|B" "3|C" "9|OK|confirm" "0|Skip|default" >/dev/null 2>&1 < "$keys"
check "Пропустить (default) выходит своим ключом" "$REPLY_KEYS" "0"

# Порядок не должен зависеть от того, в каком порядке нажимали
press "3${SP}29"
ask_many "T" "1|A" "2|B" "3|C" "9|OK|confirm" "0|Skip|default" >/dev/null 2>&1 < "$keys"
check "порядок повторяет меню, а не нажатия" "$REPLY_KEYS" "1 2 3"

press "129"
ask_many "T" "1|A" "2|Недоступно|dim" "3|C" "9|OK|confirm" "0|Skip|default" >/dev/null 2>&1 < "$keys"
check "неактивный пункт не отмечается" "$REPLY_KEYS" "1"

press "${DOWN}${SP}9"
ask_many "T" "1|A" "2|Недоступно|dim" "3|C" "9|OK|confirm" "0|Skip|default" >/dev/null 2>&1 < "$keys"
check "курсор пропускает неактивный пункт" "$REPLY_KEYS" "3"

# Ограничение времени выполнения без timeout: его нет в BusyBox на роутере.
# Регрессия в обработке EOF проявляется зависанием, поэтому сторож обязателен —
# иначе прогон висел бы вечно вместо того, чтобы упасть тестом.
limited() {
    sh -c "$1" >/dev/null 2>&1 &
    _pid=$!
    ( sleep 5; kill -9 "$_pid" 2>/dev/null ) >/dev/null 2>&1 &
    _guard=$!
    wait "$_pid"; _rc=$?
    kill "$_guard" 2>/dev/null
    return $_rc
}

# --- режимы не протекают друг в друга ---
#
# _ask_multi глобальный: если он останется в 1 после множественного выбора,
# следующее одиночное меню нарисуется с чекбоксами, которые ни на что
# не реагируют
press "9"
ask_many "T" "1|A" "2|B" "9|OK|confirm" >/dev/null 2>&1 < "$keys"
press "$ENTER"
out=$(ask_one "T" "1|A" "2|B" 2>&1 < "$keys")
check "после ask_many одиночное меню без отметок" "$(printf '%s' "$out" | grep -c '\[ \]')" "0"

press "9"
out=$(ask_many "T" "1|A" "2|B" "9|OK|confirm" 2>&1 < "$keys")
check "множественное меню с отметками" "$(printf '%s' "$out" | grep -c '\[ \]')" "2"

# --- q как ключ пункта ---
#
# Раньше q перехватывался безусловно, и пункт с таким ключом нельзя было
# выбрать стрелочным режимом, хотя номерами — можно
press "q"
ask_one "T" "q|Быстрый режим" "0|Отмена|default" >/dev/null 2>&1 < "$keys"
check "q выбирает пункт, если это его ключ" "$REPLY_KEY" "q"

press "q"
ask_one "T" "1|A" "0|Отмена|default" >/dev/null 2>&1 < "$keys"
check "q выходит, когда не занят пунктом" "$REPLY_KEY" "0"

# --- обрыв ввода ---
press ""
limited '. /repo/scripts/_xkeen/04_tools/05_tools_choice/00_choice_ask.sh
                 _ask_keys_mode=yes
                 ask_one "T" "1|A" "2|B" < /dev/null'
check "EOF не зацикливает интерактивный режим" "$?" "1"

# --- определение возможностей ---
_ask_keys_mode=""
_ask_keys_available < /dev/null
check "без терминала навигация не включается" "$?" "1"

# Одиночный Esc: здесь он отрабатывает только потому, что чтение из файла
# сразу упирается в EOF. На терминале EOF не наступает, и без -t дочитывание
# продолжения повисло бы до следующих нажатий — поймать это перенаправлением
# из файла невозможно, поэтому проверяется наличие таймаута в самом коде.
src=/repo/scripts/_xkeen/04_tools/05_tools_choice/00_choice_ask.sh
check "продолжение escape-последовательности читается с таймаутом" \
    "$(grep -c 'read -r -s -n 1 -t 1 _ask_ch[23]' "$src")" "2"
check "детектор требует поддержки -t" \
    "$(grep -c 'read -r -s -n 1 -t 1 _ask_probe' "$src")" "1"

# Байт Esc держится в переменной: подстановка команд в паттерне case
# форкала бы процесс на каждое нажатие клавиши
check "Esc не вычисляется подстановкой на каждое нажатие" \
    "$(grep -c '"\$(printf .\\\\033.)")' "$src")" "0"

# Перерисовка через сохранение позиции курсора, а не подсчёт строк:
# длинный пункт в узком терминале переносится, и счёт разъезжается
check "перерисовка не считает строки" "$(grep -c '_ask_lines' "$src")" "0"
check "перерисовка сохраняет позицию курсора" "$(grep -c '033\[u\\033\[J' "$src")" "1"

# Циклы одиночного и множественного выбора объединены: различия задаёт
# _ask_multi, а не копия кода
check "интерактивный цикл один" "$(grep -c '^_ask_interactive() {' "$src")" "1"
check "рендер один" "$(grep -c '^_ask_render() {' "$src")" "1"

rm -f "$keys"
printf '\n=== пройдено: %s, провалено: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]

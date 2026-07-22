#!/bin/sh
# Тесты слоя диалога в BusyBox ash
#
# Ввод подаётся через here-doc, а НЕ через пайп: пайп порождает субшелл,
# и выставленные в нём REPLY_* до вызывающего не доходят.

italic=""; reset=""; red=""; green=""; yellow=""

. /repo/scripts/_xkeen/04_tools/05_tools_choice/00_choice_ask.sh

pass=0; fail=0
check() {
    if [ "$2" = "$3" ]; then
        printf 'OK   %s\n' "$1"; pass=$((pass+1))
    else
        printf 'FAIL %s\n       ожидалось [%s]\n       получено  [%s]\n' "$1" "$3" "$2"; fail=$((fail+1))
    fi
}

# --- ask_one ---
ask_one "Ядро" "1|Xray" "2|Mihomo" "3|Оба" >/dev/null <<'EOF'
2
EOF
check "ask_one: обычный выбор" "$REPLY_KEY" "2"

ask_one "Ядро" "1|Xray" "2|Mihomo" >/dev/null <<'EOF'
9
x
1
EOF
check "ask_one: повтор после неверного ввода" "$REPLY_KEY" "1"

ask_one "Гео" "1|Всё установлено|dim" "2|Обновить" >/dev/null <<'EOF'
1
2
EOF
check "ask_one: dim-пункт не принимается" "$REPLY_KEY" "2"

ask_one "Ядро" "1|Xray" "|" "0|Пропустить" >/dev/null <<'EOF'
0
EOF
check "ask_one: разделитель не ломает список" "$REPLY_KEY" "0"

out=$(ask_one "T" "1|Недоступно|dim" "2|Годно" 2>&1 <<'EOF'
2
EOF
)
check "ask_one: dim выводится в списке" "$(printf '%s' "$out" | grep -c 'Недоступно')" "1"

ask_one "T" "1|Xray + Mihomo, всё сразу" >/dev/null <<'EOF'
1
EOF
check "ask_one: пробелы и запятые в подписи" "$REPLY_KEY" "1"

ask_one "T" "y|Yes" "n|No" >/dev/null <<'EOF'
y
EOF
check "ask_one: буквенные ключи" "$REPLY_KEY" "y"

# --- ask_many ---
ask_many "Гео" "1|A" "2|B" "3|C" "4|D" "5|E" >/dev/null <<'EOF'
1 3 5
EOF
check "ask_many: несколько через пробел" "$REPLY_KEYS" "1 3 5"

ask_many "Гео" "1|A" "2|B" "3|C" >/dev/null <<'EOF'
1,3
EOF
check "ask_many: запятая как разделитель" "$REPLY_KEYS" "1 3"

ask_many "Гео" "1|A" "2|B" >/dev/null <<'EOF'
2 2 1 2
EOF
check "ask_many: повторы отбрасываются" "$REPLY_KEYS" "2 1"

ask_many "Гео" "1|A" "2|B" >/dev/null <<'EOF'
1 9
1
EOF
check "ask_many: неверный номер отклоняет всю строку" "$REPLY_KEYS" "1"

ask_many "Гео" "1|A" "2|B" >/dev/null <<'EOF'

2
EOF
check "ask_many: пустой ввод отклоняется" "$REPLY_KEYS" "2"

ask_many "Гео" "1|A" "2|Нельзя|dim" >/dev/null <<'EOF'
1 2
1
EOF
check "ask_many: dim-пункт недоступен" "$REPLY_KEYS" "1"

ask_many "Гео" "1|A" "2|B" "3|C" >/dev/null <<'EOF'
  1   3
EOF
check "ask_many: лишние пробелы не мешают" "$REPLY_KEYS" "1 3"

# default-пункт («Пропустить») в числовом режиме — либо он один, либо набор без него
ask_many "Гео" "1|A" "2|B" "0|Пропустить|default" >/dev/null <<'EOF'
0
EOF
check "ask_many: Пропустить можно выбрать один" "$REPLY_KEYS" "0"

ask_many "Гео" "1|A" "2|B" "0|Пропустить|default" >/dev/null <<'EOF'
1 0
1 2
EOF
check "ask_many: Пропустить с другими -> перезапрос" "$REPLY_KEYS" "1 2"

# порядок не важен: default в конце тоже отклоняет строку
ask_many "Гео" "1|A" "2|B" "0|Пропустить|default" >/dev/null <<'EOF'
2 0
2
EOF
check "ask_many: Пропустить последним тоже конфликтует" "$REPLY_KEYS" "2"

# обычный набор по-прежнему проходит, default не мешает валидным
ask_many "Гео" "1|A" "2|B" "0|Пропустить|default" >/dev/null <<'EOF'
1 2
EOF
check "ask_many: обычный набор при наличии Пропустить" "$REPLY_KEYS" "1 2"

# confirm-пункт нужен только стрелочному режиму: в числовом Enter коммитит сам,
# поэтому здесь он скрыт и не выбирается
ask_many "Гео" "1|A" "2|B" "9|OK|confirm" "0|Пропустить|default" >/dev/null <<'EOF'
9
1
EOF
check "ask_many: confirm недоступен в числовом режиме" "$REPLY_KEYS" "1"

# --- ask_value ---
ask_value "Час" ask_check_hour "Плохо" >/dev/null <<'EOF'
25
7
EOF
check "ask_value: диапазон часа" "$REPLY_VALUE" "7"

ask_value "Минута" ask_check_minute "Плохо" >/dev/null <<'EOF'
60
59
EOF
check "ask_value: диапазон минуты" "$REPLY_VALUE" "59"

ask_value "Час" ask_check_hour "Плохо" >/dev/null <<'EOF'
abc
12
EOF
check "ask_value: буквы отклоняются" "$REPLY_VALUE" "12"

ask_value "Час" ask_check_hour "Плохо" >/dev/null <<'EOF'
-1
5
EOF
check "ask_value: отрицательное отклоняется" "$REPLY_VALUE" "5"

ask_value "Версия" "" >/dev/null <<'EOF'

v26.6.1
EOF
check "ask_value: без валидатора, пустое отклоняется" "$REPLY_VALUE" "v26.6.1"

ask_value "Час" ask_check_hour "Плохо" >/dev/null <<'EOF'
0
EOF
check "ask_value: ноль — валидное значение, не 'пусто'" "$REPLY_VALUE" "0"

ask_value "Час" ask_check_hour "Плохо" >/dev/null <<'EOF'
08
EOF
check "ask_value: ведущий ноль не ломает арифметику" "$REPLY_VALUE" "08"

# --- ask_yesno ---
if ask_yesno "Продолжить?" >/dev/null <<'EOF'
1
EOF
then r=да; else r=нет; fi
check "ask_yesno: Да -> 0" "$r" "да"

if ask_yesno "Продолжить?" >/dev/null <<'EOF'
0
EOF
then r=да; else r=нет; fi
check "ask_yesno: Нет -> 1" "$r" "нет"

out=$(ask_yesno "Q" "Установить" "Отменить" 2>&1 <<'EOF'
1
EOF
)
check "ask_yesno: свои подписи" "$(printf '%s' "$out" | grep -c 'Установить')" "1"

# --- заголовки групп и пункт по умолчанию ---
out=$(ask_one "T" "|Первая группа" "1|A" "|Вторая группа" "2|B" 2>&1 <<'EOF'
2
EOF
)
check "заголовок группы печатается" "$(printf '%s' "$out" | grep -c 'Первая группа')" "1"
check "заголовок не получает номера" "$(printf '%s' "$out" | grep -c '\. Первая группа')" "0"

# --- счётчик строк _ask_render: кормит якорь перерисовки стрелочного режима ---
_ask_cursor=0; _ask_multi=0
_ask_render "1|A" "2|B" "|" "0|C" >/dev/null
check "_ask_render: пункты + разделитель = 4 строки" "$_ask_render_lines" "4"
_ask_render "1|A" "|Заголовок" "2|B" >/dev/null
check "_ask_render: заголовок считается за 2 строки" "$_ask_render_lines" "4"
_ask_render "1|A" "2|Нельзя|dim" "3|C" >/dev/null
check "_ask_render: dim-пункт тоже строка" "$_ask_render_lines" "3"

ask_one "T" "1|A" "0|B|default" >/dev/null <<'EOF'

EOF
check "default: пустой ввод выбирает пункт по умолчанию" "$REPLY_KEY" "0"

ask_one "T" "1|A" "0|B|default" >/dev/null <<'EOF'
1
EOF
check "default: явный ввод сильнее умолчания" "$REPLY_KEY" "1"

out=$(ask_one "T" "1|A" "0|B|default" 2>&1 <<'EOF'
0
EOF
)
check "default: пункт помечен стрелкой" "$(printf '%s' "$out" | grep -c '> 0\. B')" "1"

ask_one "T" "1|A" "2|B" >/dev/null <<'EOF'

1
EOF
check "без default пустой ввод отклоняется" "$REPLY_KEY" "1"

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

# --- поведение без TTY (EOF) ---
#
# Регрессия здесь проявляется как бесконечный цикл, поэтому каждый вызов
# ограничен таймаутом: зависание должно падать тестом, а не вешать прогон.

limited '. /repo/scripts/_xkeen/04_tools/05_tools_choice/00_choice_ask.sh
                 ask_one "T" "1|A" "2|B" </dev/null'
check "EOF: ask_one не зацикливается" "$?" "1"

limited '. /repo/scripts/_xkeen/04_tools/05_tools_choice/00_choice_ask.sh
                 ask_many "T" "1|A" "2|B" </dev/null'
check "EOF: ask_many не зацикливается" "$?" "1"

limited '. /repo/scripts/_xkeen/04_tools/05_tools_choice/00_choice_ask.sh
                 ask_value "Час" ask_check_hour </dev/null'
check "EOF: ask_value не зацикливается" "$?" "1"

limited '. /repo/scripts/_xkeen/04_tools/05_tools_choice/00_choice_ask.sh
                 ask_yesno "T" </dev/null'
check "EOF: ask_yesno отдаёт код 2" "$?" "2"

# Ввод, оборвавшийся на середине, тоже не должен зацикливать
limited '. /repo/scripts/_xkeen/04_tools/05_tools_choice/00_choice_ask.sh
                 printf "9\n" | { ask_one "T" "1|A" || exit $?; }'
check "EOF: обрыв после неверного ввода" "$?" "1"

printf '\n=== пройдено: %s, провалено: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]

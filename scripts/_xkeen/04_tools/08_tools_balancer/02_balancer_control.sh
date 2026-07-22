# Управление балансировкой по скорости: включение/выключение, автонастройка
# gRPC api Xray, cron, интерактивное меню и статус.

# Жив ли gRPC api (RoutingService). lsrules не зависит от имени балансировщика,
# поэтому годится как проба живости.
sb_api_alive() {
    xray api lsrules -s "$sb_api_addr" >/dev/null 2>&1
}

# Записать одну настройку .xkeen.speed_balancer.KEY = VALUE в xkeen.json.
# Комментарии в xkeen.json при записи теряются — jq их не сохраняет; XKeen и так
# регенерирует xkeen.json при установке. Файл бэкапится и результат проверяется
# до замены, чтобы сбой jq не оставил битый конфиг.
sb_write_setting() {
    local key raw val tmp
    key="$1"; raw="$2"
    case "$raw" in
        true|false)   val="$raw" ;;
        ''|*[!0-9]*)  val="\"$raw\"" ;;   # строка -> в кавычки
        *)            val="$raw" ;;       # число как есть
    esac

    command -v jq >/dev/null 2>&1 || { echo "  jq не найден — настройку не записать"; return 1; }
    [ -f "$xkeen_config" ] || echo '{}' > "$xkeen_config"

    tmp="$xkeen_config.sb.tmp"
    if strip_json_comments "$xkeen_config" \
        | jq --arg k "$key" --argjson v "$val" '.xkeen.speed_balancer[$k] = $v' > "$tmp" 2>/dev/null \
        && jq -e . "$tmp" >/dev/null 2>&1; then
        mv "$tmp" "$xkeen_config"
        return 0
    fi
    rm -f "$tmp"
    echo "  Не удалось записать настройку в $xkeen_config"
    return 1
}

# Гарантировать наличие рабочего gRPC api и probe-inbound. Если api уже живой —
# ничего не делает. Иначе с подтверждением добавляет api-блок, probe-inbound и
# правило маршрутизации api, проверяет конфиг и перезапускает Xray.
#
# Правило api пишется ПЕРВЫМ прямо в routing-файл (по умолчанию 05_routing.json),
# а не отдельным файлом: Xray при мердже confdir заменяет routing.rules последним
# файлом, а не склеивает — правило из отдельного файла потерялось бы. Обновление и
# переустановка XKeen существующий routing-файл не перезаписывают, поэтому правило
# сохраняется; но при РУЧНОЙ перегенерации роутинга (например смене outbound'ов)
# его нужно вернуть повторным `xkeen -sb on`. Это известное ограничение.
sb_ensure_api() {
    sb_api_alive && return 0

    echo
    echo -e "  Для балансировки нужен gRPC api Xray (${yellow}RoutingService${reset}) и probe-inbound для замера."
    printf "  Настроить автоматически? Будут добавлены api и probe, конфигурация Xray перезапущена. [y/N]: "
    read -r ans
    case "$ans" in
        [Yy]*) ;;
        *) echo "  Отменено. Ручная настройка описана в docs/commands.md."; return 1 ;;
    esac

    local bkp
    bkp="$backups_dir/xray-configs-sb-$(date +%s)"
    mkdir -p "$bkp" && cp "$xray_conf_dir"/*.json "$bkp"/ 2>/dev/null
    echo -e "  Бэкап конфигурации Xray: ${yellow}$bkp${reset}"

    # api-блок + api-inbound + probe-inbound одним файлом (мержатся по tag)
    cat > "$sb_api_config" <<EOF
{
  "api": { "tag": "api", "services": ["RoutingService", "StatsService"] },
  "inbounds": [
    { "tag": "api", "listen": "127.0.0.1", "port": 10085,
      "protocol": "dokodemo-door", "settings": { "address": "127.0.0.1" } },
    { "tag": "probe", "listen": "127.0.0.1", "port": 10808,
      "protocol": "http", "settings": {} }
  ]
}
EOF

    # api-правило первым в основной routing.rules, если его там ещё нет
    local rjson has_rule
    rjson="$sb_routing_file"
    if [ -f "$rjson" ]; then
        has_rule=$(strip_json_comments "$rjson" \
            | jq '[.routing.rules[]? | select(.outboundTag=="api")] | length' 2>/dev/null)
        if [ "${has_rule:-0}" = "0" ]; then
            if strip_json_comments "$rjson" \
                | jq '.routing.rules = ([{type:"field",inboundTag:["api"],outboundTag:"api"}] + (.routing.rules // []))' \
                  > "$rjson.tmp" 2>/dev/null && jq -e . "$rjson.tmp" >/dev/null 2>&1; then
                mv "$rjson.tmp" "$rjson"
            else
                rm -f "$rjson.tmp"
                echo -e "  ${red}✗${reset} Не удалось добавить правило api в $rjson"
                cp "$bkp"/*.json "$xray_conf_dir"/ 2>/dev/null
                return 1
            fi
        fi
    fi

    # проверка конфига до рестарта — битый конфиг не должен убить ядро
    if ! XRAY_LOCATION_ASSET="$geo_dir" xray run -confdir "$xray_conf_dir" -test >/dev/null 2>&1; then
        echo -e "  ${red}✗${reset} Конфигурация не прошла проверку — восстанавливаю из бэкапа"
        cp "$bkp"/*.json "$xray_conf_dir"/ 2>/dev/null
        return 1
    fi

    echo -e "  ${yellow}Перезапуск${reset} XKeen для применения api..."
    "$initd_file" restart >/dev/null 2>&1 || "$install_dir/xkeen" -restart >/dev/null 2>&1

    local i=0
    while [ "$i" -lt 20 ]; do
        sb_api_alive && { echo -e "  api ${green}поднят${reset}"; return 0; }
        i=$((i + 1)); sleep 1
    done
    echo -e "  ${red}✗${reset} api не поднялся за 20с — проверьте $xray_error_log"
    return 1
}

# Cron-задача периодического замера. Формат совпадает с install_cron.
sb_install_cron() {
    local path
    path="$cron_dir/$cron_file"
    mkdir -p "$cron_dir"; touch "$path"; chmod +x "$path"
    grep -v "$install_dir/xkeen -sbt" "$path" > "$path.tmp" 2>/dev/null
    mv "$path.tmp" "$path"
    printf '*/%s * * * * %s/xkeen -sbt\n' "$sb_interval" "$install_dir" >> "$path"
    sed -i '/^$/d' "$path"
}

sb_remove_cron() {
    local path
    path="$cron_dir/$cron_file"
    [ -f "$path" ] || return 0
    grep -v "$install_dir/xkeen -sbt" "$path" > "$path.tmp" 2>/dev/null
    mv "$path.tmp" "$path"
    sed -i '/^$/d' "$path"
}

sb_enable() {
    speed_balancer_settings
    sb_ensure_api || { echo -e "  ${red}✗${reset} Балансировка не включена: нет рабочего api."; return 1; }
    sb_write_setting enabled true || return 1
    sb_install_cron
    echo -e "  ${green}✔${reset} Балансировка по скорости включена (замер каждые ${yellow}$sb_interval${reset} мин)."
    echo -e "  Первый замер выполняется сейчас..."
    speed_balancer_settings
    sb_tick
    echo -e "  Готово. Текущая нода: ${yellow}$(sb_current_target)${reset}"
}

sb_disable() {
    speed_balancer_settings
    # снять override — без него выбор залипнет на последней ноде (у bo нет TTL)
    xray api bo -s "$sb_api_addr" -b "$sb_balancer" -r >/dev/null 2>&1
    sb_remove_cron
    sb_write_setting enabled false
    echo -e "  ${green}✔${reset} Балансировка по скорости выключена, override снят."
}

sb_status() {
    speed_balancer_settings
    echo
    if [ "$sb_enabled" = "true" ]; then
        echo -e "  Балансировка по скорости: ${green}включена${reset}"
    else
        echo -e "  Балансировка по скорости: ${yellow}выключена${reset}"
    fi
    echo -e "  Балансировщик: ${yellow}$sb_balancer${reset}   Интервал: ${yellow}$sb_interval${reset} мин   Порог переключения: ${yellow}$sb_hysteresis${reset}%"

    # «Текущая нода» — единственное живое состояние: за ним идёт запрос к Xray
    # (bi заодно и проба живости, отдельный sb_api_alive не нужен). Старт бинаря
    # xray не мгновенный, поэтому на TTY показываем плейсхолдер «получаю…» и
    # перетираем его результатом: \r — в начало строки, \033[K гасит хвост. Без
    # TTY (пайп, лог) управляющих последовательностей не печатаем.
    local cur tty=0
    [ -t 1 ] && tty=1
    [ "$tty" = 1 ] && printf '  Текущая нода: %sполучаю…%s' "$italic" "$reset"
    cur=$(sb_current_target)
    [ "$tty" = 1 ] && printf '\r\033[K'
    if [ -n "$cur" ]; then
        echo -e "  Текущая нода: ${yellow}$cur${reset}"
    else
        echo -e "  Текущая нода: ${yellow}—${reset}  (api недоступен либо выбор ещё не сделан)"
    fi

    if [ -f "$sb_log_file" ]; then
        echo "  Последние события:"
        tail -n 8 "$sb_log_file" | sed 's/^/    /'
    fi
}

# Пауза «нажмите Enter» — даёт прочитать вывод действия до того, как следующая
# итерация меню очистит экран. Без TTY (тест, cron) сразу возвращается и ввод
# не трогает.
sb_pause() {
    [ -t 0 ] || return 0
    local _k
    printf '\n  %bНажмите Enter для продолжения…%b ' "$italic" "$reset"
    read -r _k 2>/dev/null || true
}

# Интерактивное меню через слой ask_one (стрелки/номера, EOF-безопасно).
# In-place: на TTY экран очищается в начале каждой итерации, поэтому меню
# обновляется НА МЕСТЕ, а не накапливает блоки статуса вниз. Вывод действия
# (вкл/выкл/замер) показывается и удерживается паузой до Enter, затем меню
# перерисовывается уже с обновлённым статусом. Очистка — только под TTY,
# чтобы не сорить управляющими последовательностями в пайп/лог.
sb_menu() {
    local toggle_label
    while true; do
        [ -t 1 ] && printf '\033[H\033[J'
        sb_status                       # уже подгружает настройки (sb_enabled)
        [ "$sb_enabled" = "true" ] && toggle_label="Выключить балансировку" \
                                   || toggle_label="Включить балансировку"

        # «Прогнать замер» показываем только на включённой балансировке — без
        # неё замерять нечего. «Выход» помечен default: слой ask_* трактует
        # одиночный Esc (и q, и пустой Enter) как выбор пункта по умолчанию,
        # так что из меню можно выйти по Esc.
        set -- "1|$toggle_label"
        [ "$sb_enabled" = "true" ] && set -- "$@" "2|Прогнать замер сейчас"
        set -- "$@" "|" "0|Выход|default"

        ask_one "Выберите действие:" "$@" || return 0

        case "$REPLY_KEY" in
            0) return 0 ;;
            1)
                if [ "$sb_enabled" = "true" ]; then sb_disable; else sb_enable; fi
                sb_pause
                ;;
            2)
                echo -e "  ${yellow}Замер...${reset}"; sb_tick; echo -e "  ${green}✔${reset} Замер завершён."
                sb_pause
                ;;
        esac
    done
}

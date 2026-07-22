# Определение статуса для задач cron
get_existing_cron_time() {
    crontab -l 2>/dev/null | grep 'xkeen -ug' | head -n1 | awk '{print $1,$2,$3,$4,$5}'
}

format_cron_time() {
    cron="$1"

    minute=$(echo "$cron" | awk '{print $1}')
    hour=$(echo "$cron" | awk '{print $2}')
    dow=$(echo "$cron" | awk '{print $5}')

    formatted_hour=$(printf "%02d" "$hour")
    formatted_minute=$(printf "%02d" "$minute")

    case "$dow" in
        "*") day="Ежедневно" ;;
        1) day="Понедельник" ;;
        2) day="Вторник" ;;
        3) day="Среда" ;;
        4) day="Четверг" ;;
        5) day="Пятница" ;;
        6) day="Суббота" ;;
        0) day="Воскресенье" ;;
        *) day="Неизвестно" ;;
    esac

    echo "$day в $formatted_hour:$formatted_minute"
}

choice_update_cron() {
    has_updatable_cron_tasks=false
    [ "$info_update_geofile_cron" = "installed" ] && has_updatable_cron_tasks=true

    existing_cron=$(get_existing_cron_time)
    
    if [ -n "$existing_cron" ]; then
        echo
        echo -e "  Время обновления ${yellow}геофайлов${reset} установлено на: ${green}$(format_cron_time "$existing_cron")${reset}"
    fi

    choice_cancel_cron_select=false
    choice_geofile_cron_select=false
    choice_delete_all_cron_select=false

    [ "$info_update_geofile_cron" != "installed" ] && geofile_choice="Включить" || geofile_choice="Обновить"

    # Выключить автообновление можно только если задача уже заведена. Раньше
    # недоступный пункт всё равно принимался, печатал ошибку и уводил на
    # повторный проход — теперь он показан неактивным и не выбирается.
    if [ "$has_updatable_cron_tasks" = true ]; then
        disable_cron_item="2|Выключить автообновление"
    else
        disable_cron_item="2|Автообновление не включено|dim"
    fi

    ask_one "Выберите номер действия для автообновления ${yellow}GeoFile/GeoIPSET${reset}" \
        "1|$geofile_choice задачу" \
        "$disable_cron_item" \
        "|" \
        "0|Пропустить|default"

    case "$REPLY_KEY" in
        1)
            choice_geofile_cron_select=true
            if [ "$info_update_geofile_cron" = "installed" ]; then
                echo -e "  ${yellow}Будет выполнено${reset} обновление задачи GeoFile/GeoIPSET"
            else
                echo -e "  ${yellow}Будет выполнено${reset} включение задачи GeoFile/GeoIPSET"
            fi
            ;;
        2)
            delete_cron_geofile
            echo -e "  Автообновление баз GeoFile/GeoIPSET ${green}выключено${reset}"
            echo
            ;;
        0)
            choice_cancel_cron_select=true
            echo "  Выполнен пропуск настройки автообновления"
            echo
            return
            ;;
    esac
}

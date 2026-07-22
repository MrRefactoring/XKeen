# Определение времени для задач cron
choice_cron_time() {
    [ "$choice_geofile_cron_select" != true ] && return

    echo
    echo -e "  Время автоматического обновления ${yellow}геофайлов${reset}:"

    ask_one "Выберите день" \
        "1|Понедельник" \
        "2|Вторник" \
        "3|Среда" \
        "4|Четверг" \
        "5|Пятница" \
        "6|Суббота" \
        "7|Воскресенье" \
        "8|Ежедневно" \
        "|" \
        "0|Отмена|default"
    day_choice="$REPLY_KEY"

    [ "$day_choice" -eq 0 ] && {
        echo -e "  Включение автоматического обновления ${yellow}геофайлов${reset} отменено"
        echo
        return
    }

    echo

    ask_value "Выберите час (0-23)" ask_check_hour "Некорректный час. Пожалуйста, попробуйте снова"
    hour="$REPLY_VALUE"

    ask_value "Выберите минуту (0-59)" ask_check_minute "Некорректные минуты. Пожалуйста, попробуйте снова"
    minute="$REPLY_VALUE"

    if [ "$day_choice" -eq 8 ]; then
        cron_expression="$minute $hour * * *"
        day_name="Ежедневно"
    else
        case "$day_choice" in
            1) dow=1; day_name="Понедельник" ;;
            2) dow=2; day_name="Вторник" ;;
            3) dow=3; day_name="Среда" ;;
            4) dow=4; day_name="Четверг" ;;
            5) dow=5; day_name="Пятница" ;;
            6) dow=6; day_name="Суббота" ;;
            7) dow=0; day_name="Воскресенье" ;;
        esac
        cron_expression="$minute $hour * * $dow"
    fi

    formatted_hour=$(printf "%02d" "$hour")
    formatted_minute=$(printf "%02d" "$minute")

    echo
    echo -e "  Выбранное время обновления ${yellow}геофайлов${reset}: $day_name в $formatted_hour:$formatted_minute"
    echo

    choice_geofile_cron_time="$cron_expression"
}
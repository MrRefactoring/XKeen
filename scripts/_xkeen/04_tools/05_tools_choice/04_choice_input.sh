# Функция для выбора пользователя между "Да" и "Нет" с номерами 1 и 0
input_concordance_list() {
    ask_yesno "$1"
}

toggle_param() {
    param="$1"
    description="$2"
    restart_needed="$3"
    force_state="$4"

    echo
    if [ ! -f "$initd_file" ]; then
        echo -e "  ${red}✗ Ошибка${reset}: Не найден файл ${yellow}S05xkeen${reset}"
        return 1
    fi

    current_state=$(grep -m 1 -E "^[[:space:]]*$param=" "$initd_file" | cut -d'=' -f2 | tr -d '"[:space:]')

    if [ "$force_state" = "on" ] || [ "$force_state" = "off" ]; then
        if [ "$current_state" = "$force_state" ]; then
            if [ "$current_state" = "on" ]; then
                echo -e "  Состояние ${description} уже ${green}включено${reset}"
            else
                echo -e "  Состояние ${description} уже ${red}отключено${reset}"
            fi
            [ "$apply" = "restart" ] && echo
            return 0
        fi
        desired_state="$force_state"
    elif [ "$bypass_autostart_msg" = "yes" ]; then
        if [ "$current_state" = "on" ]; then
            desired_state="off"
        else
            desired_state="on"
        fi
    else
        echo -e "  Текущее состояние ${description}:"

        if [ "$current_state" = "on" ]; then
            echo -e "  ${green}Включено${reset}"
            desired_state="off"
            toggle_action="Отключить"
        else
            echo -e "  ${red}Отключено${reset}"
            desired_state="on"
            toggle_action="Включить"
        fi

        ask_one "" "1|$toggle_action" "0|Оставить без изменений|default"

        if [ "$REPLY_KEY" = "0" ]; then
            echo
            if [ "$current_state" = "on" ]; then
                echo -e "  Состояние ${description} ${green}оставлено включённым${reset}"
            else
                echo -e "  Состояние ${description} ${red}оставлено отключённым${reset}"
            fi
            return 0
        fi
    fi

    if awk -v param="$param" -v value="$desired_state" '
        !found && $0 ~ "^[[:space:]]*" param "=" {
            sub(/"[^"]*"/, "\"" value "\"")
            found=1
        }
        {print}
    ' "$initd_file" > "$initd_file.tmp" && mv "$initd_file.tmp" "$initd_file"; then

        [ "$bypass_autostart_msg" = "yes" ] && return 0

        if [ "$desired_state" = "on" ]; then
            echo -e "  Новое состояние ${description} ${green}включено${reset}"
        else
            echo -e "  Новое состояние ${description} ${red}отключено${reset}"
        fi

        if [ "$restart_needed" = "reboot" ]; then
            echo
            echo -e "  ${yellow}Перезагрузите роутер для применения изменений${reset}"
        elif [ "$restart_needed" = "restart" ] && [ "$apply" != "restart" ]; then
            echo
            echo -e "  ${yellow}Перезапустите XKeen для применения изменений${reset}"
        fi

        add_chmod_init
    else
        echo
        echo -e "  ${red}✗ Ошибка${reset} при изменении параметра $param"
        return 1
    fi
}

choice_menu() {
    ask_yesno "$1" "$2" "$3"
}
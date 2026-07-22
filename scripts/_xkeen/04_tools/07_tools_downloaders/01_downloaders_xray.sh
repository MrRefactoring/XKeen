# Сформировать download_url и extension для указанной версии Xray.
# $1 = version_selected (например v25.4.30)
# Устанавливает глобальные переменные: download_url, filename, extension
# Возврат: 0 — успех, 1 — неизвестная архитектура
_xray_build_url() {
    _xbu_version="$1"
    _xbu_base="${xray_zip_url}/$_xbu_version"
    case "$architecture" in
        "arm64-v8a") download_url="$_xbu_base/Xray-linux-arm64-v8a.zip" ;;
        "mips32le")  download_url="$_xbu_base/Xray-linux-mips32le.zip" ;;
        "mips32")    download_url="$_xbu_base/Xray-linux-mips32.zip" ;;
        *)           download_url=; return 1 ;;
    esac
    filename=$(basename "$download_url")
    extension="${filename##*.}"
    return 0
}

# Функция для проверки и загрузки выбранной версии Xray
# $1 = version_selected
_xray_perform_install() {
    local version="$1"
    if ! _xray_build_url "$version"; then
        printf "  ${red}✗ Ошибка${reset}: Не удалось получить URL для загрузки Xray\n"
        return 1
    fi
    mkdir -p "$tmp_ram"

    if ! _network_probe "$download_url" "версии $version"; then
        return 1
    fi

    printf "  ${yellow}Выполняется загрузка${reset} Xray %s\n" "$version"
    if ! _network_download "$download_url" "$tmp_ram/xray.$extension" "Xray" "$max_attempts" "$delay"; then
        return 1
    fi

    printf "  Xray ${green}успешно загружен${reset}\n"
    return 0
}

# Загрузка Xray
download_xray() {
    USE_JSDELIVR=""
    printf "\n  ${green}Запрос информации${reset} о релизах ${yellow}Xray${reset}\n"
    fetch_release_tags "$xray_api_url" "$xray_jsd_url" "10"

    # --- АВТОМАТИЧЕСКИЙ РЕЖИМ ---
    if [ "$autoinstall_mode" = "true" ]; then
        version_selected=$(echo "$RELEASE_TAGS" | head -1)
        [ "$USE_JSDELIVR" = "true" ] && version_selected="v$version_selected"
        printf "  ${green}Авто-режим${reset}: выбрана последняя версия ${yellow}%s${reset}\n" "$version_selected"

        if _xray_perform_install "$version_selected"; then
            return 0
        else
            exit 1
        fi
    fi

    # --- ИНТЕРАКТИВНЫЙ РЕЖИМ ---
    #
    # Список релизов строится на лету, поэтому пункты накапливаются в
    # позиционных параметрах — в POSIX sh это единственная замена массиву.
    # Здесь это безопасно: download_xray собственных аргументов не имеет.
    #
    # Ручной ввод получил нечисловой ключ. Раньше он занимал номер 9, а
    # релизов запрашивается десять, из-за чего девятый релиз был недостижим,
    # а десятый не проходил проверку [0-9].
    # ВНИМАНИЕ: set -- затирает аргументы функции. Сейчас это безопасно,
    # потому что download_xray их не принимает. Если функции когда-нибудь понадобится
    # параметр, его нужно сохранить в переменную ДО этой строки, иначе
    # он потеряется, а падение произойдёт ниже по коду и с невнятным
    # симптомом.
    set --
    releases_count=0
    while IFS= read -r release_tag; do
        [ -z "$release_tag" ] && continue
        releases_count=$((releases_count + 1))
        set -- "$@" "$releases_count|$release_tag"
    done <<EOF
$RELEASE_TAGS
EOF
    set -- "$@" "|" "m|Ручной ввод версии" "0|Пропустить загрузку Xray|default"

    while true; do
        ask_one "Выберите релиз ${yellow}Xray${reset} для загрузки" "$@" || {
            bypass_xray="true"
            return
        }

        if [ "$REPLY_KEY" = "0" ]; then
            bypass_xray="true"
            printf "  Загрузка Xray ${yellow}пропущена${reset}\n"
            return
        fi

        if [ "$REPLY_KEY" = "m" ]; then
            ask_value "Введите версию Xray для загрузки (например: v26.6.1)" || return
            version_selected=$(echo "$REPLY_VALUE" | sed 's/^v//')
            version_selected="v$version_selected"
        else
            version_selected=$(echo "$RELEASE_TAGS" | awk -v line="$REPLY_KEY" 'NR == line {print $0; exit}')
            [ "$USE_JSDELIVR" = "true" ] && version_selected="v$version_selected"
        fi

        if _xray_perform_install "$version_selected"; then
            return 0
        fi
    done
}
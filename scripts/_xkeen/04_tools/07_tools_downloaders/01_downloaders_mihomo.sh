# Загрузка Mihomo
download_mihomo() {
    USE_JSDELIVR=""
    printf "\n  ${green}Запрос информации${reset} о релизах ${yellow}Mihomo${reset}\n"
    fetch_release_tags "$mihomo_api_url" "$mihomo_jsd_url" "10"

    # Пункты списка релизов накапливаются в позиционных параметрах: список
    # строится на лету, а массивов в POSIX sh нет. download_mihomo своих
    # аргументов не принимает, поэтому перезапись $@ здесь безопасна.
    #
    # Ручной ввод получил нечисловой ключ: раньше он занимал номер 9 при
    # десяти запрошенных релизах, из-за чего девятый релиз был недостижим,
    # а десятый не проходил проверку [0-9].
    # ВНИМАНИЕ: set -- затирает аргументы функции. Сейчас это безопасно,
    # потому что download_mihomo их не принимает. Если функции когда-нибудь понадобится
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
    set -- "$@" "|" "m|Ручной ввод версии" "0|Пропустить загрузку Mihomo|default"

    while true; do
        ask_one "Выберите релиз ${yellow}Mihomo${reset} для загрузки" "$@" || {
            bypass_mihomo="true"
            return 0
        }

        if [ "$REPLY_KEY" = "0" ]; then
            bypass_mihomo="true"
            printf "  Загрузка Mihomo ${yellow}пропущена${reset}\n"
            return 0
        fi

        if [ "$REPLY_KEY" = "m" ]; then
            ask_value "Введите версию Mihomo для загрузки (например: v1.19.26)" || return 0
            version_selected=$(echo "$REPLY_VALUE" | sed 's/^v//')
            version_selected="v$version_selected"
        else
            version_selected=$(echo "$RELEASE_TAGS" | awk -v line="$REPLY_KEY" 'NR == line {print $0; exit}')
            [ "$USE_JSDELIVR" = "true" ] && version_selected="v$version_selected"
        fi

        VERSION_ARG="$version_selected"
        URL_BASE="${mihomo_gz_url}/$VERSION_ARG"
        yq_download_base_url="$(get_yq_dist_url)"

        case "$architecture" in
            "arm64-v8a")
                download_url="$URL_BASE/mihomo-linux-arm64-$VERSION_ARG.gz"
                download_yq="$yq_download_base_url/yq_linux_arm64"
            ;;
            "mips32le")
                if [ "$softfloat" = "true" ]; then
                    download_url="$URL_BASE/mihomo-linux-mipsle-softfloat-$VERSION_ARG.gz"
                else
                    download_url="$URL_BASE/mihomo-linux-mipsle-hardfloat-$VERSION_ARG.gz"
                fi
                download_yq="$yq_download_base_url/yq_linux_mipsle"
            ;;
            "mips32")
                download_url="$URL_BASE/mihomo-linux-mips-hardfloat-$VERSION_ARG.gz"
                download_yq="$yq_download_base_url/yq_linux_mips"
            ;;
            *)
                download_url=""
                download_yq=""
            ;;
        esac

        if [ -z "$download_url" ] || [ -z "$download_yq" ]; then
            printf "  ${red}✗ Ошибка${reset}: Не удалось получить URL для загрузки Mihomo\n"
            exit 1
        fi

        filename=$(basename "$download_url")
        extension="${filename##*.}"
        mkdir -p "$tmp_ram"
        yq_available="false"

        if ! _network_probe "$download_url" "версии Mihomo $version_selected"; then
            continue
        fi

        if "$install_dir/yq" --version >/dev/null 2>&1; then
            yq_available="true"
            printf "  ${yellow}Используется${reset} установленный парсер конфигурационных файлов Mihomo - Yq\n"
        else
            printf "  ${yellow}Выполняется загрузка${reset} парсера конфигурационных файлов Mihomo - Yq"
            if _network_probe "$download_yq" "Yq"; then
                if _network_download "$download_yq" "$install_dir/yq" "Yq" "$max_attempts" "$delay"; then
                    chmod +x "$install_dir/yq"
                    yq_available="true"
                    printf "  Yq ${green}успешно загружен и установлен${reset}\n"
                fi
            fi
        fi

        if [ "$yq_available" != "true" ]; then
            printf "  ${red}✗ Ошибка${reset}: Для работы Mihomo требуется Yq. Установка прервана\n"
            return 1
        fi

        printf "  ${yellow}Выполняется загрузка${reset} Mihomo %s\n" "$version_selected"

        if ! _network_download "$download_url" "$tmp_ram/mihomo.$extension" "Mihomo" "$max_attempts" "$delay"; then
            continue
        fi

        printf "  Mihomo ${green}успешно загружен${reset}\n"
        return 0
    done
}

# Загрузка и обновление Yq
download_yq() {
    local yq_base_url
    yq_base_url="$(get_yq_dist_url)"
    local download_url=""
    local yq_max_attempts=1
    local yq_delay=2

    if [ -n "$retries_download" ] && [ "$retries_download" -gt 1 ] 2>/dev/null; then
        yq_max_attempts=$retries_download
    fi
    yq_delay=${retry_delay_download:-2}

    case "$architecture" in
        "arm64-v8a") download_url="$yq_base_url/yq_linux_arm64" ;;
        "mips32le")  download_url="$yq_base_url/yq_linux_mipsle" ;;
        "mips32")    download_url="$yq_base_url/yq_linux_mips" ;;
        *)
            printf "  ${red}✗ Ошибка${reset}: Архитектура %s не поддерживается для Yq\n" "$architecture"
            return 1
            ;;
    esac

    if ! _network_probe "$download_url" "Yq"; then
        return 1
    fi

    if _network_download "$download_url" "$install_dir/yq" "Yq" "$yq_max_attempts" "$yq_delay"; then
        chmod +x "$install_dir/yq"
        printf "  Yq ${green}успешно обновлен/установлен${reset}\n"
        return 0
    else
        return 1
    fi
}
# Функция для удаления GeoIPSET
delete_geoipset() {
    if ! ask_yesno "Желаете удалить российские IP-адреса из исключений проксирования?" \
        "Да. Загруженные файлы подсетей будут удалены, а списки очищены" \
        "Нет. Отмена удаления"; then
        echo
        printf "  Отмена удаления списков GeoIPSET.\n\n"
        return 0
    fi
    echo

    ipset flush geo_exclude 2>/dev/null
    ipset flush geo_exclude6 2>/dev/null

    [ -f "$ru_exclude_ipv4" ] && rm -f "$ru_exclude_ipv4" 2>/dev/null
    [ -f "$ru_exclude_ipv6" ] && rm -f "$ru_exclude_ipv6" 2>/dev/null
    # [ -d "$ipset_cfg" ] && rm -rf "$ipset_cfg"

    printf "  Списки исключений GeoIPSET ${green}успешно удалены${reset}\n\n"
    return 0
}

delete_geoipset_key() {
    ipset flush geo_exclude 2>/dev/null
    ipset flush geo_exclude6 2>/dev/null

    [ -f "$ru_exclude_ipv4" ] && rm -f "$ru_exclude_ipv4" 2>/dev/null
    [ -f "$ru_exclude_ipv6" ] && rm -f "$ru_exclude_ipv6" 2>/dev/null
    # [ -d "$ipset_cfg" ] && rm -rf "$ipset_cfg"
}
#!/bin/sh
# Тесты объявления попыток при переборе зеркал
#
# Главное, что здесь проверяется: сообщения идут в stderr и не попадают в
# stdout. Stdout у _get_expected_size несёт размер файла и читается через
# $(), поэтому любая печать туда молча испортила бы значение.

italic=""; reset=""; red=""; green=""; yellow=""; light_blue=""
gh_proxy_user=""
gh_proxy1="https://gh-proxy.com"
gh_proxy2="https://ghfast.top"

. /repo/scripts/_xkeen/04_tools/07_tools_downloaders/00_fetch_with_mirrors.sh

# Кэш выбранного зеркала мешает предсказуемости: убираем перед каждым тестом
rm -f "$_mirror_cache"

pass=0; fail=0
check() {
    if [ "$2" = "$3" ]; then
        printf 'OK   %s\n' "$1"; pass=$((pass+1))
    else
        printf 'FAIL %s\n       ожидалось [%s]\n       получено  [%s]\n' "$1" "$3" "$2"; fail=$((fail+1))
    fi
}

# --- имена источников ---
_mirror_label ""
check "пустой префикс — это прямая загрузка" "$_mirror_name" "напрямую с GitHub"

_mirror_label "$_DIRECT_TOKEN"
check "токен прямой загрузки распознаётся" "$_mirror_name" "напрямую с GitHub"

_mirror_label "https://gh-proxy.com"
check "из https-адреса берётся хост" "$_mirror_name" "gh-proxy.com"

_mirror_label "http://example.org/path/to"
check "http и путь отбрасываются" "$_mirror_name" "example.org"

# --- подсчёт источников ---
_mirror_total "$(printf 'a\nb\nc\n')"
check "считает три источника" "$_mirror_count" "3"

_mirror_total "$(printf 'a\n')"
check "считает один источник" "$_mirror_count" "1"

_mirror_total ""
check "пустой список — ноль" "$_mirror_count" "0"

# --- объявление идёт в stderr, а не в stdout ---
out=$(_mirror_announce 2 "https://ghfast.top" 3 2>/dev/null)
check "объявление не пишет в stdout" "$out" ""

err=$(_mirror_announce 2 "https://ghfast.top" 3 2>&1 >/dev/null)
check "объявление пишет в stderr" "$err" "    [2/3] ghfast.top"

err=$(_mirror_failed 2>&1 >/dev/null)
check "отказ пишет в stderr" "$err" "          недоступно"

out=$(_mirror_failed 2>/dev/null)
check "отказ не пишет в stdout" "$out" ""

# --- главный инвариант: stdout _get_expected_size не засорён ---
#
# Подменяем curl: прямая загрузка отказывает, gh-proxy отдаёт заголовки
# с Content-Length. Решение принимается по адресу, а не по счётчику
# вызовов: curl здесь вызывается внутри $(), то есть в субшелле, и
# изменяемый счётчик каждый раз обнулялся бы.
curl_with_timeout() {
    case "$*" in
        *gh-proxy.com*)
            printf 'HTTP/1.1 200 OK\r\nContent-Length: 17784192\r\n\r\n'
            return 0
            ;;
        *) return 7 ;;
    esac
}

rm -f "$_mirror_cache"
size=$(_get_expected_size "https://example.com/geoip.dat" 2>/dev/null)
check "stdout содержит только размер" "$size" "17784192"

rm -f "$_mirror_cache"
noise=$(_get_expected_size "https://example.com/geoip.dat" 2>&1 >/dev/null | grep -c 'Определение размера')
check "заголовок фазы ушёл в stderr" "$noise" "1"

rm -f "$_mirror_cache"
attempts=$(_get_expected_size "https://example.com/geoip.dat" 2>&1 >/dev/null | grep -c '^    \[')
check "попытки перечислены в stderr" "$attempts" "2"

# Фаза определения размера раньше молчала об отказах, хотя ради неё
# добавлялся отдельный заголовок — то есть половина тишины оставалась
rm -f "$_mirror_cache"
fails=$(_get_expected_size "https://example.com/geoip.dat" 2>&1 >/dev/null | grep -c 'недоступно')
check "отказ в фазе размера озвучен" "$fails" "1"

# Успешная попытка не должна помечаться отказом
rm -f "$_mirror_cache"
noise=$(_get_expected_size "https://example.com/geoip.dat" 2>&1 >/dev/null | grep -c 'недоступно')
check "успех не помечается отказом" "$noise" "1"

# --- fetch_with_mirrors: stdout тоже должен остаться чистым ---
curl_with_timeout() { return 7; }
rm -f "$_mirror_cache"
out=$(fetch_with_mirrors "https://example.com/f.dat" /tmp/xk_fetch_test 10 2>/dev/null)
check "fetch не пишет в stdout" "$out" ""

rm -f "$_mirror_cache"
lines=$(fetch_with_mirrors "https://example.com/f.dat" /tmp/xk_fetch_test 10 2>&1 >/dev/null | grep -c '^    \[')
check "fetch объявляет все три источника" "$lines" "3"

rm -f "$_mirror_cache"
fails=$(fetch_with_mirrors "https://example.com/f.dat" /tmp/xk_fetch_test 10 2>&1 >/dev/null | grep -c 'недоступно')
check "fetch сообщает о каждом отказе" "$fails" "3"

# --- при заданном пользовательском прокси источник ровно один ---
gh_proxy_user="https://my-proxy.example"
rm -f "$_mirror_cache"
lines=$(fetch_with_mirrors "https://example.com/f.dat" /tmp/xk_fetch_test 10 2>&1 >/dev/null | grep -c '^    \[1/1\]')
check "пользовательский прокси — единственный источник" "$lines" "1"
gh_proxy_user=""

rm -f /tmp/xk_fetch_test "$_mirror_cache"
printf '\n=== пройдено: %s, провалено: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]

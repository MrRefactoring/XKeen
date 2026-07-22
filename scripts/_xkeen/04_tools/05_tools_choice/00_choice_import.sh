# Импорт модулей выбора пользователя

# 00_choice_ask.sh здесь не подключается: он поднят в import.sh выше модулей
# информации, установки и удаления, которые тоже вызывают ask_*.

# Модули выбора
. "$xtools_dir/05_tools_choice/01_choice_cores.sh"
. "$xtools_dir/05_tools_choice/02_choice_xkeen.sh"
. "$xtools_dir/05_tools_choice/03_choice_geofile.sh"
. "$xtools_dir/05_tools_choice/04_choice_input.sh"

. "$xtools_dir/05_tools_choice/05_choice_cron/00_cron_import.sh"

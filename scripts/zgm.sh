#!/bin/sh

BASE_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
SCRIPTS_DIR="$BASE_DIR/scripts"
PROFILES_DIR="$BASE_DIR/profiles"
STATE_DIR="$BASE_DIR/state"

. "$SCRIPTS_DIR/lib_ui.sh"
. "$SCRIPTS_DIR/lib_profiles.sh"
. "$SCRIPTS_DIR/lib_state.sh"
. "$SCRIPTS_DIR/lib_log.sh"

main_menu() {
    while true; do
        ui_header "zapret-gateway-manager"
        echo "1) Показать профили"
        echo "2) Выбрать профиль"
        echo "3) Показать текущее состояние"
        echo "4) Показать последние записи лога"
        echo "5) Выход"
        echo
        printf "Выбери пункт: "
        read -r choice

        case "$choice" in
            1)
                ui_header "Доступные профили"
                show_profiles
                ui_pause
                ;;
            2)
                select_profile_flow
                ;;
            3)
                ui_header "Текущее состояние"
                show_state
                ui_pause
                ;;
            4)
                ui_header "Последние записи лога"
                show_last_logs 20
                ui_pause
                ;;
            5)
                log_info "Программа завершена пользователем"
                echo "Выход."
                exit 0
                ;;
            *)
                ui_error "Неверный пункт меню"
                ui_pause
                ;;
        esac
    done
}

select_profile_flow() {
    ui_header "Выбор профиля"
    list_profiles_numbered
    echo
    printf "Введи номер профиля: "
    read -r profile_num

    profile_path="$(get_profile_by_number "$profile_num")"

    if [ -z "$profile_path" ]; then
        ui_error "Профиль не найден"
        log_error "Попытка выбрать несуществующий профиль: $profile_num"
        ui_pause
        return
    fi

    if ! load_profile "$profile_path"; then
        ui_error "Не удалось загрузить профиль"
        log_error "Не удалось загрузить профиль: $profile_path"
        ui_pause
        return
    fi

    save_active_profile "$profile_path"

    log_info "Выбран профиль: $NAME ($profile_path)"
    ui_success "Профиль сохранён как активный"
    echo
    echo "Имя:        $NAME"
    echo "Описание:   $DESCRIPTION"
    echo "Backend:    $BACKEND"
    echo "Аргументы:  $NFQWS_ARGS"
    echo "Check set:  $CHECK_SET"
    echo "Priority:   $PRIORITY"
    echo
    echo "Применение backend-логики будет добавлено следующим этапом."
    ui_pause
}

bootstrap() {
    ensure_state_dir
    ensure_log_file
}

bootstrap
main_menu
#!/bin/sh

BASE_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
SCRIPTS_DIR="$BASE_DIR/scripts"
PROFILES_DIR="$BASE_DIR/profiles"
STATE_DIR="$BASE_DIR/state"
LISTS_DIR="$BASE_DIR/lists"

. "$SCRIPTS_DIR/lib_ui.sh"
. "$SCRIPTS_DIR/lib_profiles.sh"
. "$SCRIPTS_DIR/lib_state.sh"
. "$SCRIPTS_DIR/lib_log.sh"
. "$SCRIPTS_DIR/lib_targets.sh"
. "$SCRIPTS_DIR/lib_checks.sh"
. "$SCRIPTS_DIR/lib_backend.sh"

main_menu() {
    while true; do
        ui_header "zapret-gateway-manager"
        echo "1) Показать профили"
        echo "2) Выбрать профиль"
        echo "3) Применить активный профиль"
        echo "4) Показать статус backend"
        echo "5) Сбросить backend"
        echo "6) Запустить standard checks"
        echo "7) Показать текущее состояние"
        echo "8) Показать последние записи лога"
        echo "9) Выход"
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
                apply_active_profile_flow
                ;;
            4)
                backend_status_flow
                ;;
            5)
                backend_reset_flow
                ;;
            6)
                run_standard_checks_flow
                ;;
            7)
                ui_header "Текущее состояние"
                show_state
                ui_pause
                ;;
            8)
                ui_header "Последние записи лога"
                show_last_logs 20
                ui_pause
                ;;
            9)
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
    echo "Реальное применение system/backend-логики на хосте будет добавлено следующим этапом."
    ui_pause
}

apply_active_profile_flow() {
    ui_header "Применение активного профиля"

    if active_path="$(get_active_profile_path 2>/dev/null)"; then
        if ! load_profile "$active_path"; then
            ui_error "Активный профиль найден, но не загрузился"
            log_error "Apply: не удалось загрузить активный профиль: $active_path"
            ui_pause
            return
        fi
    else
        ui_error "Сначала выбери профиль"
        log_error "Apply запущен без активного профиля"
        ui_pause
        return
    fi

    ui_info "Активный профиль: $NAME"
    ui_info "Backend: $BACKEND"
    echo

    if backend_apply_profile "$active_path"; then
        save_last_action "backend_applied"
        log_info "Профиль применён через backend: $NAME"
        ui_success "Backend runtime-state обновлён"
    else
        save_last_action "backend_apply_failed"
        log_error "Не удалось применить профиль через backend: $NAME"
        ui_error "Не удалось применить профиль"
    fi

    ui_pause
}

backend_status_flow() {
    ui_header "Статус backend"
    backend_status
    ui_pause
}

backend_reset_flow() {
    ui_header "Сброс backend"

    if backend_reset; then
        save_last_action "backend_reset"
        log_info "Backend сброшен"
        ui_success "Backend runtime-state сброшен"
    else
        save_last_action "backend_reset_failed"
        log_error "Не удалось сбросить backend"
        ui_error "Не удалось сбросить backend"
    fi

    ui_pause
}

run_standard_checks_flow() {
    ui_header "Standard checks"

    if active_path="$(get_active_profile_path 2>/dev/null)"; then
        if ! load_profile "$active_path"; then
            ui_error "Активный профиль найден, но не загрузился"
            log_error "Checks: не удалось загрузить активный профиль: $active_path"
            ui_pause
            return
        fi
    else
        ui_error "Сначала выбери профиль"
        log_error "Checks запущены без активного профиля"
        ui_pause
        return
    fi

    ui_info "Активный профиль: $NAME"
    ui_info "Backend: $BACKEND"
    echo

    if run_standard_checks; then
        save_last_action "standard_checks_ok"
    else
        save_last_action "standard_checks_failed"
    fi

    ui_pause
}

bootstrap() {
    ensure_state_dir
    ensure_log_file
}

bootstrap
main_menu
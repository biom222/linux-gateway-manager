#!/bin/sh

ACTIVE_PROFILE_FILE="$STATE_DIR/active_profile.state"
LAST_ACTION_FILE="$STATE_DIR/last_action.state"
LAST_CHECK_STATUS_FILE="$STATE_DIR/last_check_status.state"
LAST_CHECK_TIME_FILE="$STATE_DIR/last_check_time.state"
LAST_CHECK_DETAILS_FILE="$STATE_DIR/last_check_details.state"
LAST_CHECK_RESULTS_FILE="$STATE_DIR/last_check_results.txt"

ensure_state_dir() {
    [ -d "$STATE_DIR" ] || mkdir -p "$STATE_DIR"
}

save_last_action() {
    action_name="$1"
    printf "%s\n" "$action_name" > "$LAST_ACTION_FILE"
}

save_active_profile() {
    profile_path="$1"
    printf "%s\n" "$profile_path" > "$ACTIVE_PROFILE_FILE"
    save_last_action "profile_selected"
}

get_active_profile_path() {
    if [ -f "$ACTIVE_PROFILE_FILE" ]; then
        cat "$ACTIVE_PROFILE_FILE"
        return 0
    fi
    return 1
}

show_state() {
    if active_path="$(get_active_profile_path 2>/dev/null)"; then
        echo "Активный профиль: $active_path"
        if load_profile "$active_path"; then
            echo "Имя:              $NAME"
            echo "Описание:         $DESCRIPTION"
            echo "Backend:          $BACKEND"
            echo "Аргументы:        $NFQWS_ARGS"
            echo "Check set:        $CHECK_SET"
            echo "Priority:         $PRIORITY"
        else
            echo "Профиль существует в state, но не загрузился."
        fi
    else
        echo "Активный профиль пока не выбран."
    fi

    echo

    if [ -f "$LAST_ACTION_FILE" ]; then
        echo "Последнее действие: $(cat "$LAST_ACTION_FILE")"
    else
        echo "Последнее действие: не записано"
    fi

    if [ -f "$LAST_CHECK_STATUS_FILE" ]; then
        echo "Последняя проверка: $(cat "$LAST_CHECK_STATUS_FILE")"
    else
        echo "Последняя проверка: не запускалась"
    fi

    if [ -f "$LAST_CHECK_TIME_FILE" ]; then
        echo "Время проверки:    $(cat "$LAST_CHECK_TIME_FILE")"
    fi

    if [ -f "$LAST_CHECK_DETAILS_FILE" ]; then
        echo "Детали проверки:   $(cat "$LAST_CHECK_DETAILS_FILE")"
    fi

    if [ -f "$LAST_CHECK_RESULTS_FILE" ]; then
        echo "Файл результатов:  $LAST_CHECK_RESULTS_FILE"
    fi

    echo
    show_backend_runtime_summary
}
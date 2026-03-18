#!/bin/sh

ACTIVE_PROFILE_FILE="$STATE_DIR/active_profile.state"
LAST_ACTION_FILE="$STATE_DIR/last_action.state"

ensure_state_dir() {
    [ -d "$STATE_DIR" ] || mkdir -p "$STATE_DIR"
}

save_active_profile() {
    profile_path="$1"
    printf "%s\n" "$profile_path" > "$ACTIVE_PROFILE_FILE"
    printf "%s\n" "profile_selected" > "$LAST_ACTION_FILE"
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

    if [ -f "$LAST_ACTION_FILE" ]; then
        echo "Последнее действие: $(cat "$LAST_ACTION_FILE")"
    else
        echo "Последнее действие: не записано"
    fi
}
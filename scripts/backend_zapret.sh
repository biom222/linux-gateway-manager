#!/bin/sh

ZAPRET_BACKEND_STATE_FILE="$STATE_DIR/backend_zapret_runtime.state"

zapret_backend_write_state() {
    runtime_status="$1"
    runtime_profile_path="$2"
    runtime_time="$(timestamp_now)"

    cat > "$ZAPRET_BACKEND_STATE_FILE" <<EOF
BACKEND_NAME="zapret"
BACKEND_STATUS="$runtime_status"
APPLIED_PROFILE_PATH="$runtime_profile_path"
APPLIED_PROFILE_NAME="$NAME"
APPLIED_AT="$runtime_time"
NFQWS_ARGS="$NFQWS_ARGS"
CHECK_SET="$CHECK_SET"
EOF
}

zapret_backend_apply() {
    profile_path="$1"

    [ -n "$profile_path" ] || return 1
    [ -n "$NAME" ] || return 1
    [ -n "$NFQWS_ARGS" ] || return 1

    zapret_backend_write_state "applied" "$profile_path"
    return 0
}

zapret_backend_status() {
    if [ ! -f "$ZAPRET_BACKEND_STATE_FILE" ]; then
        echo "Backend: zapret"
        echo "Статус:  не применялся"
        return 0
    fi

    . "$ZAPRET_BACKEND_STATE_FILE"

    echo "Backend:          $BACKEND_NAME"
    echo "Статус:           $BACKEND_STATUS"
    echo "Профиль:          $APPLIED_PROFILE_NAME"
    echo "Путь профиля:     $APPLIED_PROFILE_PATH"
    echo "Применён в:       $APPLIED_AT"
    echo "Аргументы:        $NFQWS_ARGS"
    echo "Check set:        $CHECK_SET"
}

zapret_backend_reset() {
    runtime_time="$(timestamp_now)"

    cat > "$ZAPRET_BACKEND_STATE_FILE" <<EOF
BACKEND_NAME="zapret"
BACKEND_STATUS="reset"
APPLIED_PROFILE_PATH=""
APPLIED_PROFILE_NAME=""
APPLIED_AT="$runtime_time"
NFQWS_ARGS=""
CHECK_SET=""
EOF

    return 0
}

zapret_backend_summary() {
    echo "Backend runtime:"

    if [ ! -f "$ZAPRET_BACKEND_STATE_FILE" ]; then
        echo "  Backend:        zapret"
        echo "  Статус:         не применялся"
        return 0
    fi

    . "$ZAPRET_BACKEND_STATE_FILE"

    echo "  Backend:        $BACKEND_NAME"
    echo "  Статус:         $BACKEND_STATUS"

    if [ -n "$APPLIED_PROFILE_NAME" ]; then
        echo "  Профиль:        $APPLIED_PROFILE_NAME"
    fi

    if [ -n "$APPLIED_AT" ]; then
        echo "  Время:          $APPLIED_AT"
    fi
}
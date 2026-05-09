#!/bin/sh

. "$SCRIPTS_DIR/backend_zapret.sh"

backend_apply_profile() {
    profile_path="$1"

    case "$BACKEND" in
        zapret)
            zapret_backend_apply "$profile_path"
            return $?
            ;;
        *)
            ui_error "Неизвестный backend: $BACKEND"
            log_error "Неизвестный backend: $BACKEND"
            return 1
            ;;
    esac
}

backend_status() {
    zapret_backend_status
}

backend_reset() {
    zapret_backend_reset
}

show_backend_runtime_summary() {
    zapret_backend_summary
}
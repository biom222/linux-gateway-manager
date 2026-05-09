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

find_profile_by_name() {
    target_name="$1"

    for file in "$PROFILES_DIR"/*.conf; do
        [ -f "$file" ] || continue

        unset NAME DESCRIPTION BACKEND NFQWS_ARGS CHECK_SET PRIORITY
        . "$file"

        if [ "$NAME" = "$target_name" ]; then
            echo "$file"
            return 0
        fi
    done

    return 1
}

select_profile() {
    profile_name="$1"
    profile_path="$(find_profile_by_name "$profile_name")"

    if [ -z "$profile_path" ]; then
        echo "PROFILE_NOT_FOUND"
        return 1
    fi

    if ! load_profile "$profile_path"; then
        echo "PROFILE_LOAD_FAILED"
        return 1
    fi

    save_active_profile "$profile_path"
    log_info "API: выбран профиль $NAME"
    echo "OK"
    return 0
}

apply_active_profile() {
    if active_path="$(get_active_profile_path 2>/dev/null)"; then
        if ! load_profile "$active_path"; then
            echo "ACTIVE_PROFILE_LOAD_FAILED"
            return 1
        fi
    else
        echo "NO_ACTIVE_PROFILE"
        return 1
    fi

    if backend_apply_profile "$active_path"; then
        save_last_action "backend_applied"
        log_info "API: профиль применён $NAME"
        echo "OK"
        return 0
    fi

    echo "BACKEND_APPLY_FAILED"
    return 1
}

reset_backend_runtime() {
    if backend_reset; then
        save_last_action "backend_reset"
        log_info "API: backend сброшен"
        echo "OK"
        return 0
    fi

    echo "BACKEND_RESET_FAILED"
    return 1
}

run_checks_action() {
    if active_path="$(get_active_profile_path 2>/dev/null)"; then
        if ! load_profile "$active_path"; then
            echo "ACTIVE_PROFILE_LOAD_FAILED"
            return 1
        fi
    else
        echo "NO_ACTIVE_PROFILE"
        return 1
    fi

    if run_standard_checks; then
        save_last_action "standard_checks_ok"
        echo "OK"
        return 0
    fi

    save_last_action "standard_checks_failed"
    echo "CHECKS_FAILED"
    return 1
}

bootstrap() {
    ensure_state_dir
    ensure_log_file
}

bootstrap

case "$1" in
    select-profile)
        select_profile "$2"
        ;;
    apply-active)
        apply_active_profile
        ;;
    reset-backend)
        reset_backend_runtime
        ;;
    run-checks)
        run_checks_action
        ;;
    *)
        echo "UNKNOWN_ACTION"
        exit 1
        ;;
esac
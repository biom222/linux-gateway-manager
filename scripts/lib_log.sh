#!/bin/sh

LOG_FILE="$STATE_DIR/zgm.log"

ensure_log_file() {
    [ -f "$LOG_FILE" ] || : > "$LOG_FILE"
}

timestamp_now() {
    date "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "unknown-time"
}

log_info() {
    message="$1"
    printf "[%s] [INFO] %s\n" "$(timestamp_now)" "$message" >> "$LOG_FILE"
}

log_error() {
    message="$1"
    printf "[%s] [ERROR] %s\n" "$(timestamp_now)" "$message" >> "$LOG_FILE"
}

show_last_logs() {
    lines="${1:-20}"

    if [ ! -f "$LOG_FILE" ]; then
        echo "Лог пока не создан."
        return 0
    fi

    tail -n "$lines" "$LOG_FILE" 2>/dev/null || cat "$LOG_FILE"
}
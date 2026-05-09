#!/bin/sh

LAST_CHECK_STATUS_FILE="$STATE_DIR/last_check_status.state"
LAST_CHECK_TIME_FILE="$STATE_DIR/last_check_time.state"
LAST_CHECK_DETAILS_FILE="$STATE_DIR/last_check_details.state"
LAST_CHECK_RESULTS_FILE="$STATE_DIR/last_check_results.txt"

CHECK_TIMEOUT="${CHECK_TIMEOUT:-5}"
PING_COUNT="${PING_COUNT:-3}"

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

save_check_result() {
    status="$1"
    details="$2"

    printf "%s\n" "$status" > "$LAST_CHECK_STATUS_FILE"
    printf "%s\n" "$(timestamp_now)" > "$LAST_CHECK_TIME_FILE"
    printf "%s\n" "$details" > "$LAST_CHECK_DETAILS_FILE"
}

reset_results_file() {
    : > "$LAST_CHECK_RESULTS_FILE"
}

append_result_line() {
    printf "%s\n" "$1" >> "$LAST_CHECK_RESULTS_FILE"
}

detect_unsupported_tls() {
    text="$1"

    printf '%s' "$text" | grep -Eqi \
        'not supported|unsupported protocol|protocol.*not supported|unsupported feature|unknown option|unrecognized option|tls.*not supported|ssl.*not supported'
}

detect_ssl_problem() {
    text="$1"

    printf '%s' "$text" | grep -Eqi \
        'certificate|ssl certificate problem|self-signed|certificate verify failed|unable to get local issuer certificate'
}

run_http_variant() {
    variant="$1"
    url="$2"

    case "$variant" in
        http11)
            label="HTTP"
            output="$(curl -I -s -m "$CHECK_TIMEOUT" -o /dev/null -w "%{http_code}" --http1.1 "$url" 2>&1)"
            exit_code=$?
            ;;
        tls12)
            label="TLS1.2"
            output="$(curl -I -s -m "$CHECK_TIMEOUT" -o /dev/null -w "%{http_code}" --tlsv1.2 --tls-max 1.2 "$url" 2>&1)"
            exit_code=$?
            ;;
        tls13)
            label="TLS1.3"
            output="$(curl -I -s -m "$CHECK_TIMEOUT" -o /dev/null -w "%{http_code}" --tlsv1.3 --tls-max 1.3 "$url" 2>&1)"
            exit_code=$?
            ;;
        *)
            echo "UNKNOWN:ERROR"
            return 1
            ;;
    esac

    if [ "$exit_code" -eq 0 ] && printf '%s' "$output" | grep -Eq '^[0-9][0-9][0-9]$'; then
        echo "$label:OK"
        return 0
    fi

    if detect_ssl_problem "$output"; then
        echo "$label:SSL"
        return 1
    fi

    if detect_unsupported_tls "$output"; then
        echo "$label:UNSUP"
        return 1
    fi

    echo "$label:ERROR"
    return 1
}

run_ping_check() {
    host="$1"

    if ! command_exists ping; then
        echo "PING:N/A"
        return 1
    fi

    ping_output="$(ping -c "$PING_COUNT" -W 2 "$host" 2>/dev/null)"
    ping_exit=$?

    if [ "$ping_exit" -ne 0 ]; then
        echo "PING:Timeout"
        return 1
    fi

    avg_ms="$(printf '%s\n' "$ping_output" | sed -n 's/.*= [^/]*\/\([^/]*\)\/.*/\1 ms/p' | tail -n 1)"

    if [ -n "$avg_ms" ]; then
        echo "PING:$avg_ms"
    else
        echo "PING:OK"
    fi

    return 0
}

run_standard_checks() {
    targets_file="$(get_targets_file)"

    if [ ! -f "$targets_file" ]; then
        ui_error "Не найден файл целей проверок: $targets_file"
        log_error "Не найден файл целей проверок: $targets_file"
        save_check_result "failed" "targets-file-missing"
        return 1
    fi

    if ! command_exists curl; then
        ui_error "Для проверок нужен curl"
        log_error "Проверки невозможны: curl не найден"
        save_check_result "failed" "curl-not-found"
        return 1
    fi

    reset_results_file

    total_targets=0
    http_ok=0
    http_error=0
    http_unsup=0
    ping_ok=0
    ping_fail=0

    while IFS= read -r raw_line || [ -n "$raw_line" ]; do
        if ! parse_target_line "$raw_line"; then
            continue
        fi

        total_targets=$((total_targets + 1))

        printf "%s" "$TARGET_NAME"
        name_len="${#TARGET_NAME}"
        while [ "$name_len" -lt 24 ]; do
            printf " "
            name_len=$((name_len + 1))
        done

        if [ "$TARGET_KIND" = "url" ]; then
            token_http="$(run_http_variant http11 "$TARGET_URL")"
            token_tls12="$(run_http_variant tls12 "$TARGET_URL")"
            token_tls13="$(run_http_variant tls13 "$TARGET_URL")"
            token_ping="$(run_ping_check "$TARGET_HOST")"

            printf "%s  %s  %s  %s\n" "$token_http" "$token_tls12" "$token_tls13" "$token_ping"
            append_result_line "$TARGET_NAME | $token_http | $token_tls12 | $token_tls13 | $token_ping"

            for token in "$token_http" "$token_tls12" "$token_tls13"; do
                case "$token" in
                    *:OK)
                        http_ok=$((http_ok + 1))
                        ;;
                    *:UNSUP)
                        http_unsup=$((http_unsup + 1))
                        ;;
                    *)
                        http_error=$((http_error + 1))
                        ;;
                esac
            done

            case "$token_ping" in
                PING:Timeout|PING:N/A)
                    ping_fail=$((ping_fail + 1))
                    ;;
                *)
                    ping_ok=$((ping_ok + 1))
                    ;;
            esac
        else
            token_ping="$(run_ping_check "$TARGET_HOST")"

            printf "%s\n" "$token_ping"
            append_result_line "$TARGET_NAME | $token_ping"

            case "$token_ping" in
                PING:Timeout|PING:N/A)
                    ping_fail=$((ping_fail + 1))
                    ;;
                *)
                    ping_ok=$((ping_ok + 1))
                    ;;
            esac
        fi
    done < "$targets_file"

    echo
    echo "=== ANALYTICS ==="
    echo "Targets:      $total_targets"
    echo "HTTP OK:      $http_ok"
    echo "HTTP ERR:     $http_error"
    echo "HTTP UNSUP:   $http_unsup"
    echo "Ping OK:      $ping_ok"
    echo "Ping FAIL:    $ping_fail"

    summary="targets=$total_targets http_ok=$http_ok http_error=$http_error http_unsup=$http_unsup ping_ok=$ping_ok ping_fail=$ping_fail"

    if [ "$http_ok" -gt 0 ] || [ "$ping_ok" -gt 0 ]; then
        save_check_result "ok" "$summary"
        log_info "Standard checks completed: $summary"
        ui_success "Проверки завершены"
        return 0
    fi

    save_check_result "failed" "$summary"
    log_error "Standard checks failed: $summary"
    ui_error "Проверки завершились неудачно"
    return 1
}
#!/bin/sh

get_targets_file() {
    echo "$LISTS_DIR/targets.txt"
}

parse_target_line() {
    line="$1"

    trimmed="$(printf '%s\n' "$line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"

    case "$trimmed" in
        ""|\#*)
            return 1
            ;;
    esac

    TARGET_NAME="$(printf '%s\n' "$trimmed" | sed -n 's/^\([A-Za-z0-9_][A-Za-z0-9_]*\)[[:space:]]*=[[:space:]]*".*"$/\1/p')"
    TARGET_VALUE="$(printf '%s\n' "$trimmed" | sed -n 's/^[A-Za-z0-9_][A-Za-z0-9_]*[[:space:]]*=[[:space:]]*"\(.*\)"$/\1/p')"

    [ -n "$TARGET_NAME" ] || return 1
    [ -n "$TARGET_VALUE" ] || return 1

    case "$TARGET_VALUE" in
        PING:*)
            TARGET_KIND="ping"
            TARGET_URL=""
            TARGET_HOST="${TARGET_VALUE#PING:}"
            ;;
        http://*|https://*)
            TARGET_KIND="url"
            TARGET_URL="$TARGET_VALUE"
            TARGET_HOST="$(printf '%s\n' "$TARGET_URL" | sed 's#^[a-zA-Z]*://##; s#/.*$##')"
            ;;
        *)
            return 1
            ;;
    esac

    return 0
}
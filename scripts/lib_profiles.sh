#!/bin/sh

show_profiles() {
    found=0

    for file in "$PROFILES_DIR"/*.conf; do
        [ -f "$file" ] || continue
        found=1

        unset NAME DESCRIPTION BACKEND NFQWS_ARGS CHECK_SET PRIORITY
        . "$file"

        echo "Имя:       $NAME"
        echo "Описание:  $DESCRIPTION"
        echo "Backend:   $BACKEND"
        echo "Аргументы: $NFQWS_ARGS"
        echo "Check set: $CHECK_SET"
        echo "Priority:  $PRIORITY"
        echo "Файл:      $file"
        echo "----------------------------------------"
    done

    [ "$found" -eq 1 ] || echo "Профили не найдены."
}

list_profiles_numbered() {
    found=0
    index=1

    for file in "$PROFILES_DIR"/*.conf; do
        [ -f "$file" ] || continue
        found=1

        unset NAME DESCRIPTION BACKEND NFQWS_ARGS CHECK_SET PRIORITY
        . "$file"

        echo "$index) $NAME — $DESCRIPTION"
        index=$((index + 1))
    done

    [ "$found" -eq 1 ] || echo "Профили не найдены."
}

get_profile_by_number() {
    target="$1"
    index=1

    for file in "$PROFILES_DIR"/*.conf; do
        [ -f "$file" ] || continue

        if [ "$index" = "$target" ]; then
            echo "$file"
            return 0
        fi

        index=$((index + 1))
    done

    return 1
}

load_profile() {
    profile_file="$1"
    [ -f "$profile_file" ] || return 1

    unset NAME DESCRIPTION BACKEND NFQWS_ARGS CHECK_SET PRIORITY
    . "$profile_file"

    [ -n "$NAME" ] || return 1
    return 0
}
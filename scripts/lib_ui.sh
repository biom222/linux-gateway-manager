#!/bin/sh

ui_header() {
    title="$1"
    clear 2>/dev/null
    echo "========================================"
    echo "$title"
    echo "========================================"
    echo
}

ui_error() {
    echo "[ERROR] $1"
}

ui_success() {
    echo "[OK] $1"
}

ui_info() {
    echo "[INFO] $1"
}

ui_pause() {
    echo
    printf "Нажми Enter для продолжения..."
    read -r _
}
#!/bin/bash
# Master Sleep Timer Manager Script
# Actions: start, cancel, status, extend-30, extend-60, or GUI if no arguments

# Config
ENDTIME_FILE="$HOME/.sleep-timer-endtime"
SLEEP_DELAY_SECONDS=3600  # Default 1 hour for start

# Functions

start_timer() {
    cancel_timer quiet # Always clean previous timers first
    local target_time=$(date -d "+1 hour" +%s)
    echo "$target_time" > "$ENDTIME_FILE"
    (sleep $SLEEP_DELAY_SECONDS && systemctl suspend) &
    echo $! > "$ENDTIME_FILE.pid"
    notify-send "Sleep Timer Started" "System will suspend in 1 hour."
}

cancel_timer() {
    local quiet="$1"
    if [[ -f "$ENDTIME_FILE.pid" ]]; then
        kill $(cat "$ENDTIME_FILE.pid") 2>/dev/null
        rm -f "$ENDTIME_FILE.pid"
    fi
    rm -f "$ENDTIME_FILE"

    if [[ "$quiet" != "quiet" ]]; then
	notify-send "Sleep Timer Canceled" "Sleep timer has been canceled."
    fi
}

status_timer() {
    if [[ ! -f "$ENDTIME_FILE" ]]; then
        zenity --info --text="No sleep timer is currently active."
        exit 0
    fi
    local current_time=$(date +%s)
    local target_time=$(cat "$ENDTIME_FILE")
    local seconds_left=$((target_time - current_time))

    if (( seconds_left <= 0 )); then
        zenity --info --text="Sleep timer expired."
        rm -f "$ENDTIME_FILE"
        rm -f "$ENDTIME_FILE.pid"
        exit 0
    fi

    local minutes_left=$((seconds_left / 60))
    zenity --info --text="Sleep timer will trigger in $minutes_left minutes."
}

extend_timer() {
    local extension_minutes="$1"
    if [[ ! -f "$ENDTIME_FILE" ]]; then
        zenity --error --text="No active sleep timer to extend."
        exit 1
    fi
    local extension_seconds=$((extension_minutes * 60))

    local current_time=$(date +%s)
    local target_time=$(cat "$ENDTIME_FILE")
    local seconds_left=$((target_time - current_time))

    if (( seconds_left <= 0 )); then
        zenity --info --text="Timer already expired. Starting new timer."
        start_timer
        exit 0
    fi

    local new_total_seconds=$((seconds_left + extension_seconds))

    cancel_timer

    # Relaunch new timer
    (sleep $new_total_seconds && systemctl suspend) &
    echo $! > "$ENDTIME_FILE.pid"
    echo $((current_time + new_total_seconds)) > "$ENDTIME_FILE"

    local minutes_left=$((new_total_seconds / 60))
    zenity --info --text="Sleep timer extended. New sleep in $minutes_left minutes."
}

show_menu() {
    local choice=$(zenity --list \
        --title="Sleep Timer Menu" \
        --column="Action" --width=300 --height=250 \
        "Start Sleep Timer" \
        "Cancel Sleep Timer" \
        "Check Timer Status" \
        "Extend Timer by 30 Minutes" \
        "Extend Timer by 60 Minutes")

    case "$choice" in
        "Start Sleep Timer")
            start_timer
            ;;
        "Cancel Sleep Timer")
            cancel_timer
            ;;
        "Check Timer Status")
            status_timer
            ;;
        "Extend Timer by 30 Minutes")
            extend_timer 30
            ;;
        "Extend Timer by 60 Minutes")
            extend_timer 60
            ;;
        *)
            exit 0
            ;;
    esac
}

# Dispatcher
case "$1" in
    start)
        start_timer
        ;;
    cancel)
        cancel_timer
        ;;
    status)
        status_timer
        ;;
    extend-30)
        extend_timer 30
        ;;
    extend-60)
        extend_timer 60
        ;;
    "")
        show_menu
        ;;
    *)
        echo "Usage: $0 {start|cancel|status|extend-30|extend-60}"
        exit 1
        ;;
esac

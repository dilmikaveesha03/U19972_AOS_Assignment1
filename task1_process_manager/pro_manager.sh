#!/bin/bash

# University Data Centre Process & Resource Management System

# System Administration Tool

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="$BASE_DIR/logs/system_monitor_log.txt"
ARCHIVE_DIR="$BASE_DIR/ArchiveLogs"
LOG_SIZE_THRESHOLD=52428800   
ARCHIVE_SIZE_LIMIT=1073741824 

CRITICAL_PROCESSES=("init" "systemd" "kthreadd" "kworker" "ksoftirqd" "migration" "rcu_" "watchdog")

log_action() {
    local action="$1"
    local response="$2"
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] USER_ACTION: $action | SYSTEM_RESPONSE: $response" >> "$LOG_FILE"
}

print_header() {
    echo ""
    echo "============================================================"
    echo "  $1"
    echo "============================================================"
}

pause() {
    echo ""
    read -rp "  Press [Enter] to return to the main menu..."
}

# Process Monitoring
monitor_system_resources() {
    print_header "System Resource Monitor"

    echo ""
    echo "--- CPU Usage (top snapshot) ---"
    top -bn1 | head -5

    echo ""
    echo "--- Memory Usage (free -h) ---"
    free -h

    echo ""
    echo "--- Virtual Memory Statistics (vmstat) ---"
    vmstat 1 1

    log_action "View system resources" "Displayed CPU, memory, and vmstat output"
    pause
}

# Process Management
manage_processes() {
    print_header "Process Management"

    echo ""
    echo "--- Top 10 Memory-Consuming Processes ---"
    echo ""

    ps aux --sort=-%mem | awk 'NR==1 || NR<=11 {printf "%-8s %-12s %-6s %-6s %s\n", $2, $1, $3, $4, $11}'

    echo ""
    read -rp "  Enter PID to terminate (or 0 to cancel): " pid

    if ! [[ "$pid" =~ ^[0-9]+$ ]] || [ "$pid" -eq 0 ]; then
        echo "  [INFO] No process selected. Returning to menu."
        log_action "Terminate process" "User cancelled or invalid PID entered"
        pause
        return
    fi

    proc_name=$(ps -p "$pid" -o comm= 2>/dev/null)
    if [ -z "$proc_name" ]; then
        echo "  [ERROR] PID $pid does not exist or is no longer running."
        log_action "Terminate PID $pid" "Failed – process not found"
        pause
        return
    fi

    for critical in "${CRITICAL_PROCESSES[@]}"; do
        if [[ "$proc_name" == *"$critical"* ]]; then
            echo ""
            echo "  *** WARNING: '$proc_name' (PID $pid) is a critical system process. ***"
            echo "  *** Termination is BLOCKED to protect system stability.            ***"
            log_action "Attempt to terminate critical process '$proc_name' (PID $pid)" "BLOCKED – critical process protection"
            pause
            return
        fi
    done

    echo ""
    echo "  You are about to terminate: $proc_name (PID $pid)"
    read -rp "  Are you sure? (Y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        kill -15 "$pid" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "  [SUCCESS] Process $proc_name (PID $pid) has been terminated."
            log_action "Terminate process '$proc_name' (PID $pid)" "Success – SIGTERM sent"
        else
            echo "  [ERROR] Could not terminate PID $pid. Insufficient permissions?"
            log_action "Terminate process '$proc_name' (PID $pid)" "Failed – permission denied"
        fi
    else
        echo "  [INFO] Termination cancelled."
        log_action "Terminate process '$proc_name' (PID $pid)" "Cancelled by user"
    fi

    pause
}

# Disk Usage Inspection
inspect_disk_usage() {
    print_header "Disk Usage Inspection"

    echo ""
    read -rp "  Enter the directory path to inspect: " dir_path

    if [ ! -d "$dir_path" ]; then
        echo "  [ERROR] Directory '$dir_path' does not exist."
        log_action "Inspect disk usage of '$dir_path'" "Failed – directory not found"
        pause
        return
    fi

    echo ""
    echo "--- Overall Disk Usage (df -h) ---"
    df -h "$dir_path"

    echo ""
    echo "--- Directory Size (du -sh) ---"
    du -sh "$dir_path"

    echo ""
    echo "--- Top 10 Largest Subdirectories ---"
    du -h --max-depth=1 "$dir_path" 2>/dev/null | sort -rh | head -10

    log_action "Inspect disk usage of '$dir_path'" "Displayed df and du output"
    pause
}

# Log File Detection and Archiving
archive_large_logs() {
    print_header "Log File Detection & Archiving"

    echo ""
    read -rp "  Enter directory to scan for large log files: " scan_dir

    if [ ! -d "$scan_dir" ]; then
        echo "  [ERROR] Directory '$scan_dir' does not exist."
        log_action "Scan for large logs in '$scan_dir'" "Failed – directory not found"
        pause
        return
    fi

    if [ ! -d "$ARCHIVE_DIR" ]; then
        mkdir -p "$ARCHIVE_DIR"
        echo "  [INFO] Created ArchiveLogs directory at: $ARCHIVE_DIR"
        log_action "Create ArchiveLogs directory" "Created at $ARCHIVE_DIR"
    fi

    echo ""
    echo "--- Scanning '$scan_dir' for log files larger than 50 MB ---"
    echo ""

    found_files=()
    while IFS= read -r -d '' file; do
        found_files+=("$file")
    done < <(find "$scan_dir" -type f -name "*.log" -size +50M -print0 2>/dev/null)

    if [ ${#found_files[@]} -eq 0 ]; then
        echo "  [INFO] No log files larger than 50 MB found."
        log_action "Scan for large logs in '$scan_dir'" "No oversized log files found"
    else
        echo "  Found ${#found_files[@]} oversized log file(s):"
        for file in "${found_files[@]}"; do
            file_size=$(du -sh "$file" | cut -f1)
            echo "    - $file ($file_size)"
        done

        echo ""
        read -rp "  Archive all listed files? (Y/N): " confirm_archive

        if [[ "$confirm_archive" =~ ^[Yy]$ ]]; then
            timestamp=$(date "+%Y%m%d_%H%M%S")
            archived_count=0

            for file in "${found_files[@]}"; do
                base_name=$(basename "$file")
                archive_name="${base_name%.log}_${timestamp}.log.gz"
                archive_path="$ARCHIVE_DIR/$archive_name"

                gzip -c "$file" > "$archive_path"
                if [ $? -eq 0 ]; then
                    rm -f "$file"  
                    echo "  [ARCHIVED] $base_name -> $archive_name"
                    log_action "Archive log '$file'" "Compressed to $archive_path and original removed"
                    ((archived_count++))
                else
                    echo "  [ERROR] Failed to compress: $file"
                    log_action "Archive log '$file'" "Failed – compression error"
                fi
            done

            echo ""
            echo "  [DONE] $archived_count file(s) archived successfully."
        else
            echo "  [INFO] Archiving cancelled."
            log_action "Archive large logs in '$scan_dir'" "Cancelled by user"
        fi
    fi

    # Archive Directory Size Warning 
    archive_size=$(du -sb "$ARCHIVE_DIR" 2>/dev/null | cut -f1)
    archive_size=${archive_size:-0}

    echo ""
    archive_human=$(du -sh "$ARCHIVE_DIR" 2>/dev/null | cut -f1)
    echo "  ArchiveLogs current size: $archive_human"

    if [ "$archive_size" -gt "$ARCHIVE_SIZE_LIMIT" ]; then
        echo ""
        echo "  *** WARNING: ArchiveLogs directory exceeds 1 GB ($archive_human). ***"
        echo "  *** Consider clearing old archives to free disk space.             ***"
        log_action "Check ArchiveLogs size" "WARNING: Size exceeds 1 GB ($archive_human)"
    fi

    pause
}

# MAIN MENU
main_menu() {
    while true; do
        clear
        echo ""
        echo "  ╔══════════════════════════════════════════════════════════╗"
        echo "  ║       University Data Centre Management System           ║"
        echo "  ║                                                          ║"
        echo "  ╚══════════════════════════════════════════════════════════╝"
        echo ""
        echo "  1. Monitor System Resources (CPU / Memory)"
        echo "  2. Process Management (View & Terminate)"
        echo "  3. Disk Usage Inspection"
        echo "  4. Log File Detection & Archiving"
        echo "  5. Exit"
        echo ""
        read -rp "  Select an option [1-5]: " choice

        case "$choice" in
            1) monitor_system_resources ;;
            2) manage_processes ;;
            3) inspect_disk_usage ;;
            4) archive_large_logs ;;
            5)
                echo ""
                read -rp "  Are you sure you want to exit? (Y/N): " exit_confirm
                if [[ "$exit_confirm" =~ ^[Yy]$ ]]; then
                    log_action "Exit system" "User confirmed exit"
                    echo ""
                    echo "  Goodbye! Thank you for using the Data Centre Management System."
                    echo ""
                    exit 0
                else
                    echo "  [INFO] Exit cancelled. Returning to menu."
                    log_action "Exit system" "Cancelled by user"
                fi
                ;;
            *)
                echo "  [ERROR] Invalid option. Please enter a number between 1 and 5."
                log_action "Menu input '$choice'" "Invalid option – prompt re-displayed"
                sleep 1
                ;;
        esac
    done
}

# Entry Point 
mkdir -p "$(dirname "$LOG_FILE")"
log_action "System started" "Data Centre Management System initialised by user: $(whoami)"

main_menu

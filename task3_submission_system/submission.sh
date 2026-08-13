#!/bin/bash

# Secure Examination Submission and Access Control System

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

SUBMISSION_DIR="$SCRIPT_DIR/submissions"       
HASH_DB="$SCRIPT_DIR/hash_database.txt"       
LOG_FILE="$BASE_DIR/logs/submission_log.txt"   
VALIDATOR="$SCRIPT_DIR/validator.py"           

# Login State 
MAX_ATTEMPTS=3
LOGIN_WINDOW=60   

declare -A FAILED_ATTEMPTS   
declare -A LOCKED_ACCOUNTS    
declare -A FIRST_ATTEMPT_TIME 

log_action() {
    local actor="$1"
    local action="$2"
    local status="$3"
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] USER: $actor | ACTION: $action | STATUS: $status" >> "$LOG_FILE"
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

# Submit Assignment

submit_assignment() {
    print_header "Submit Assignment"

    echo ""
    read -rp "  Enter your Student ID: " student_id
    if [ -z "$student_id" ]; then
        echo "  [ERROR] Student ID cannot be empty."
        log_action "UNKNOWN" "Submit assignment" "REJECTED – empty student ID"
        pause; return
    fi

    read -rp "  Enter full path to the file to submit: " file_path

    if [ ! -f "$file_path" ]; then
        echo "  [ERROR] File not found: $file_path"
        log_action "$student_id" "Submit '$file_path'" "REJECTED – file not found"
        pause; return
    fi

    extension="${file_path##*.}"
    extension_lower=$(echo "$extension" | tr '[:upper:]' '[:lower:]')
    if [[ "$extension_lower" != "pdf" && "$extension_lower" != "docx" ]]; then
        echo "  [ERROR] Invalid file format '.$extension'. Only .pdf and .docx are accepted."
        log_action "$student_id" "Submit '$file_path'" "REJECTED – invalid format .$extension"
        pause; return
    fi

    file_size=$(stat -c%s "$file_path" 2>/dev/null)
    max_size=5242880
    if [ "$file_size" -gt "$max_size" ]; then
        size_mb=$(echo "scale=2; $file_size / 1048576" | bc)
        echo "  [ERROR] File size ${size_mb}MB exceeds the 5MB limit."
        log_action "$student_id" "Submit '$file_path'" "REJECTED – file too large (${size_mb}MB)"
        pause; return
    fi

    echo ""
    echo "  Checking for duplicate submission..."
    dup_result=$(python3 "$VALIDATOR" check_hash "$file_path" "$HASH_DB" 2>&1)
    if [ $? -ne 0 ]; then
        echo "  [ERROR] Validator error: $dup_result"
        log_action "$student_id" "Submit '$file_path'" "ERROR – validator failed"
        pause; return
    fi

    if [ "$dup_result" == "DUPLICATE" ]; then
        echo "  [REJECTED] This file has already been submitted (duplicate content detected)."
        log_action "$student_id" "Submit '$file_path'" "REJECTED – duplicate hash"
        pause; return
    fi

    mkdir -p "$SUBMISSION_DIR"
    base_name=$(basename "$file_path")
    dest="$SUBMISSION_DIR/${student_id}_${base_name}"
    cp "$file_path" "$dest"

    python3 "$VALIDATOR" register_hash "$file_path" "$HASH_DB"

    echo "  [SUCCESS] File '${base_name}' submitted successfully."
    echo "  Stored as: $dest"
    log_action "$student_id" "Submit '$base_name'" "ACCEPTED – saved to submissions"
    pause
}

# Validate / Check if File Already Submitted

validate_file() {
    print_header "Check File Submission Status"

    echo ""
    read -rp "  Enter full path to the file to check: " file_path

    if [ ! -f "$file_path" ]; then
        echo "  [ERROR] File not found: $file_path"
        pause; return
    fi

    dup_result=$(python3 "$VALIDATOR" check_hash "$file_path" "$HASH_DB" 2>&1)
    if [ "$dup_result" == "DUPLICATE" ]; then
        echo "  [INFO] This file HAS already been submitted."
    else
        echo "  [INFO] This file has NOT been submitted previously."
    fi
    log_action "SYSTEM" "Validate '$file_path'" "Result: $dup_result"
    pause
}

# List Submitted Files

list_submitted_files() {
    print_header "Submitted Assignments"

    if [ ! -d "$SUBMISSION_DIR" ] || [ -z "$(ls -A "$SUBMISSION_DIR" 2>/dev/null)" ]; then
        echo ""
        echo "  No files have been submitted yet."
    else
        echo ""
        echo "  Files in the submission directory:"
        echo ""
        count=0
        for file in "$SUBMISSION_DIR"/*; do
            if [ -f "$file" ]; then
                fname=$(basename "$file")
                fsize=$(du -sh "$file" | cut -f1)
                echo "    [$((++count))] $fname  ($fsize)"
            fi
        done
        echo ""
        echo "  Total: $count file(s)"
    fi
    log_action "SYSTEM" "List submitted files" "Listed $count file(s)"
    pause
}

# Simulate Login Attempt

simulate_login() {
    print_header "Secure Login Simulation"

    echo ""
    read -rp "  Enter Student ID: " student_id
    if [ -z "$student_id" ]; then
        echo "  [ERROR] Student ID cannot be empty."
        pause; return
    fi

    if [ "${LOCKED_ACCOUNTS[$student_id]}" == "locked" ]; then
        echo "  [LOCKED] Account for '$student_id' is locked due to too many failed attempts."
        echo "  Please contact your system administrator."
        log_action "$student_id" "Login attempt" "DENIED – account locked"
        pause; return
    fi

    read -rsp "  Enter Password: " password
    echo ""

    now=$(date +%s)
    first_time="${FIRST_ATTEMPT_TIME[$student_id]:-0}"
    elapsed=$(( now - first_time ))

    if [ "$first_time" -ne 0 ] && [ "$elapsed" -le "$LOGIN_WINDOW" ]; then
        current_count="${FAILED_ATTEMPTS[$student_id]:-0}"
        if [ "$current_count" -ge 2 ]; then
            echo ""
            echo "  *** SUSPICIOUS ACTIVITY DETECTED ***"
            echo "  Multiple login attempts detected for '$student_id' within ${LOGIN_WINDOW}s."
            log_action "$student_id" "Login attempt" "WARNING – suspicious activity (multiple attempts within ${LOGIN_WINDOW}s)"
        fi
    else
        FIRST_ATTEMPT_TIME[$student_id]=$now
        FAILED_ATTEMPTS[$student_id]=0
    fi

    if [ "$password" == "$student_id" ]; then
        echo "  [SUCCESS] Login successful. Welcome, $student_id!"
        FAILED_ATTEMPTS[$student_id]=0
        FIRST_ATTEMPT_TIME[$student_id]=0
        log_action "$student_id" "Login attempt" "SUCCESS"
    else
        (( FAILED_ATTEMPTS[$student_id]++ ))
        attempts="${FAILED_ATTEMPTS[$student_id]}"
        remaining=$(( MAX_ATTEMPTS - attempts ))

        echo "  [FAILED] Incorrect password. Attempts remaining: $remaining"
        log_action "$student_id" "Login attempt" "FAILED (attempt $attempts of $MAX_ATTEMPTS)"

        if [ "$attempts" -ge "$MAX_ATTEMPTS" ]; then
            LOCKED_ACCOUNTS[$student_id]="locked"
            echo ""
            echo "  *** ACCOUNT LOCKED ***"
            echo "  Account for '$student_id' has been locked after $MAX_ATTEMPTS failed attempts."
            log_action "$student_id" "Account lockout" "LOCKED after $MAX_ATTEMPTS failed attempts"
        fi
    fi

    pause
}

# MAIN MENU

main_menu() {
    while true; do
        clear
        echo ""
        echo "  ╔═════════════════════════════════════════════════════════=╗"
        echo "  ║           Secure Examination Submission System           ║"
        echo "  ║                                                          ║"
        echo "  ╚══════════════════════════════════════════════════════════╝"
        echo ""
        echo "  1. Submit Assignment"
        echo "  2. Check if File Already Submitted"
        echo "  3. List Submitted Files"
        echo "  4. Simulate Login Attempt"
        echo "  5. Exit"
        echo ""
        read -rp "  Select an option [1-5]: " choice

        case "$choice" in
            1) submit_assignment ;;
            2) validate_file ;;
            3) list_submitted_files ;;
            4) simulate_login ;;
            5)
                echo ""
                read -rp "  Are you sure you want to exit? (Y/N): " exit_confirm
                if [[ "$exit_confirm" =~ ^[Yy]$ ]]; then
                    log_action "SYSTEM" "Exit" "System exited by user"
                    echo ""
                    echo "  Goodbye! Secure Submission System terminated."
                    echo ""
                    exit 0
                else
                    echo "  [INFO] Exit cancelled."
                    log_action "SYSTEM" "Exit cancelled" "User chose to remain"
                fi
                ;;
            *)
                echo "  [ERROR] Invalid option '$choice'. Enter a number between 1 and 5."
                log_action "SYSTEM" "Menu input '$choice'" "Invalid option"
                sleep 1
                ;;
        esac
    done
}

# Entry Point 
mkdir -p "$(dirname "$LOG_FILE")"
log_action "SYSTEM" "System started" "Secure Submission System initialised by user: $(whoami)"
main_menu







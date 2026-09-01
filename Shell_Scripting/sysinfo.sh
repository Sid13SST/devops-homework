#!/bin/bash
#
# sysinfo.sh - System Information Script
# Shell Scripting Homework Task
#
# Demonstrates: variables, read -p, echo, date, hostname, whoami,
#               df, ps, mkdir, touch and > output redirection.
# ---------------------------------------------------------------

# ---------- Variables holding system data ----------
CURRENT_DATE=$(date)
HOST_NAME=$(hostname)
USER_NAME=$(whoami)
DISK_USAGE=$(df -h)

echo "=================================================="
echo "            SYSTEM INFORMATION REPORT"
echo "=================================================="
echo

# ---------- 1. Current date ----------
echo "--- Current Date ---"
echo "$CURRENT_DATE"
echo

# ---------- 2. Hostname ----------
echo "--- Hostname ---"
echo "$HOST_NAME"
echo

# ---------- 3. Username ----------
echo "--- Logged in User ---"
echo "$USER_NAME"
echo

# ---------- 4. Disk usage ----------
echo "--- Disk Usage (df -h) ---"
echo "$DISK_USAGE"
echo

# ---------- 5. Running processes ----------
echo "--- Running Processes (ps aux) ---"
ps aux
echo

# ---------- 6. Take user input with read -p ----------
read -p "Enter a name for the report directory: " DIR_NAME
read -p "Enter a name for the report file: " FILE_NAME

# Fall back to defaults if the user just pressed Enter
DIR_NAME=${DIR_NAME:-sysinfo_reports}
FILE_NAME=${FILE_NAME:-processes.txt}

echo
echo "You chose directory : $DIR_NAME"
echo "You chose file      : $FILE_NAME"
echo

# ---------- 7. Create the directory with mkdir ----------
mkdir -p "$DIR_NAME"
echo "Created directory: $DIR_NAME"

# ---------- 8. Create the file with touch ----------
REPORT_PATH="$DIR_NAME/$FILE_NAME"
touch "$REPORT_PATH"
echo "Created file: $REPORT_PATH"
echo

# ---------- 9. Store running processes in the file using > redirection ----------
ps aux > "$REPORT_PATH"
echo "Saved running-process list to $REPORT_PATH using > redirection."
echo

# ---------- 10. Prove the file was written ----------
echo "--- Line count of the saved report ---"
wc -l "$REPORT_PATH"
echo

echo "--- First 10 lines of $REPORT_PATH ---"
head -10 "$REPORT_PATH"
echo

echo "--- Directory listing ---"
ls -l "$DIR_NAME"
echo

echo "=================================================="
echo "  Report complete. Saved at: $REPORT_PATH"
echo "=================================================="

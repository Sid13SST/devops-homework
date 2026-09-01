# Shell Scripting — Homework

Source task: **Shell Scripting Homework Task — System Information Script.**

| File | What it is |
|---|---|
| [`sysinfo.sh`](sysinfo.sh) | The script |
| [`sysinfo-output.txt`](sysinfo-output.txt) | Full run on a minimal Ubuntu container |
| [`sysinfo-output-systemd.txt`](sysinfo-output-systemd.txt) | Full run on a busier host, so `ps aux` shows real services |

---

## Requirements checklist

Every item the task asked for, and where it is done in the script:

| Requirement | How it is met |
|---|---|
| Prints the current date | `CURRENT_DATE=$(date)` then `echo "$CURRENT_DATE"` |
| Prints the hostname | `HOST_NAME=$(hostname)` |
| Prints the username | `USER_NAME=$(whoami)` |
| Prints the disk usage | `DISK_USAGE=$(df -h)` |
| Prints the running processes | `ps aux` |
| Uses variables to store and use data | `CURRENT_DATE`, `HOST_NAME`, `USER_NAME`, `DISK_USAGE`, `DIR_NAME`, `FILE_NAME`, `REPORT_PATH` |
| Takes user input using `read -p` | `read -p "Enter a name for the report directory: " DIR_NAME` (twice) |
| Creates a directory using `mkdir` | `mkdir -p "$DIR_NAME"` |
| Creates a file using `touch` | `touch "$REPORT_PATH"` |
| Stores running processes in the file using `>` | `ps aux > "$REPORT_PATH"` |

Commands used, as specified: `mkdir`, `touch`, `echo`, `df`, `ps`, `read -p`, variables, `>` output redirection.

---

## The script

```bash
#!/bin/bash
#
# sysinfo.sh - System Information Script
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
```

---

## How to run it

```bash
chmod +x sysinfo.sh
./sysinfo.sh
```

`chmod +x` sets the execute bit — without it you get "Permission denied". The `#!/bin/bash` shebang on line 1 tells the kernel which interpreter to use.

---

## Full run with output

Run on a host with systemd and nginx so the process list is representative. The two prompts were answered with `devops_reports` and `running_processes.txt`.

```
$ chmod +x sysinfo.sh
$ ./sysinfo.sh

==================================================
            SYSTEM INFORMATION REPORT
==================================================

--- Current Date ---
Tue Sep  1 13:10:05 UTC 2026

--- Hostname ---
af19e2d3d43e

--- Logged in User ---
root

--- Disk Usage (df -h) ---
Filesystem      Size  Used Avail Use% Mounted on
overlay        1007G   24G  933G   3% /
tmpfs            64M     0   64M   0% /dev
shm              64M     0   64M   0% /dev/shm
/dev/sdd       1007G   24G  933G   3% /etc/hosts
tmpfs           1.6G  8.1M  1.6G   1% /run
tmpfs           5.0M     0  5.0M   0% /run/lock

--- Running Processes (ps aux) ---
USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root         1  0.0  0.1  20692 11952 ?        Ss   13:04   0:00 /lib/systemd/systemd
root        23  0.0  0.1  25632  8784 ?        S<s  13:04   0:00 /usr/lib/systemd/systemd-journald
message+   186  0.0  0.0   9444  5184 ?        Ss   13:05   0:00 @dbus-daemon --system --address=systemd: --nofork --nopidfile --systemd-activation --syslog-only
root       189  0.0  0.0  17520  7920 ?        Ss   13:05   0:00 /usr/lib/systemd/systemd-logind
root       533  0.0  0.0   4324  3456 ?        Ss   13:09   0:00 bash -c ... ./sysinfo.sh
root       627  0.0  0.0   4324  3312 ?        S    13:10   0:00 /bin/bash ./sysinfo.sh
root       632  0.0  0.0   7888  4032 ?        R    13:10   0:00 ps aux


You chose directory : devops_reports
You chose file      : running_processes.txt

Created directory: devops_reports
Created file: devops_reports/running_processes.txt

Saved running-process list to devops_reports/running_processes.txt using > redirection.

--- Line count of the saved report ---
8 devops_reports/running_processes.txt

--- First 10 lines of devops_reports/running_processes.txt ---
USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root         1  0.0  0.1  20692 11952 ?        Ss   13:04   0:00 /lib/systemd/systemd
root        23  0.0  0.1  25632  8784 ?        S<s  13:04   0:00 /usr/lib/systemd/systemd-journald
message+   186  0.0  0.0   9444  5184 ?        Ss   13:05   0:00 @dbus-daemon --system --address=systemd: --nofork --nopidfile --systemd-activation --syslog-only
root       189  0.0  0.0  17520  7920 ?        Ss   13:05   0:00 /usr/lib/systemd/systemd-logind
root       533  0.0  0.0   4324  3456 ?        Ss   13:09   0:00 bash -c ... ./sysinfo.sh
root       627  0.0  0.0   4324  3312 ?        S    13:10   0:00 /bin/bash ./sysinfo.sh
root       635  0.0  0.0   7888  4176 ?        R    13:10   0:00 ps aux

--- Directory listing ---
total 4
-rw-r--r-- 1 root root 896 Sep  1 13:10 running_processes.txt

==================================================
  Report complete. Saved at: devops_reports/running_processes.txt
==================================================
```

The directory and file were created, and the process list was written into the file — the last `head -10` reads it back from disk to prove the `>` redirection worked.

> **Why the two prompts are not visible in that transcript.** The run was fed its answers from a pipe so the output could be captured to a file:
>
> ```bash
> printf 'devops_reports\nrunning_processes.txt\n' | ./sysinfo.sh
> ```
> Bash only writes a `read -p` prompt when **stdin is a terminal**, so with piped input the prompt text is suppressed — which is why you see a blank gap where the two prompts would be, followed by the values the script actually received.
>
> Run interactively at a real terminal, the same section looks like this:
>
> ```
> Enter a name for the report directory: devops_reports
> Enter a name for the report file: running_processes.txt
>
> You chose directory : devops_reports
> You chose file      : running_processes.txt
> ```

---

## Explanation of each command used

### Variables and command substitution

```bash
CURRENT_DATE=$(date)
```

`$(...)` is **command substitution** — it runs the command and substitutes its *output*. Note the rules: **no spaces around `=`** (`VAR = value` is a syntax error, because bash would read `VAR` as a command), and always **quote when expanding** (`"$VAR"`) so that values containing spaces or newlines survive intact. `$(df -h)` is multi-line, and `echo "$DISK_USAGE"` preserves those newlines — unquoted, they would collapse onto one line.

`${VAR:-default}` supplies a fallback when the variable is empty, which is why pressing Enter at the prompts still produces a working run.

### `read -p`

```bash
read -p "Enter a name for the report directory: " DIR_NAME
```

`read` takes a line from standard input and stores it in a variable. `-p` prints a prompt **on the same line** without needing a separate `echo`. Useful relatives: `-r` (do not treat backslash as an escape — recommended for paths), `-s` (silent, for passwords), `-t N` (timeout).

### `date`, `hostname`, `whoami`

Report *when*, *where* and *who* — the three things every diagnostic report needs so it is still interpretable weeks later.

### `df -h`

**D**isk **F**ree, per mounted filesystem. `-h` is human-readable (`933G` rather than `978432000`). The column that matters is **Use%** — this is the command you run first when something fails with "no space left on device".

### `ps aux`

Every running process. The BSD-style flags: **`a`** all users' processes, **`u`** user-oriented format (adds %CPU/%MEM), **`x`** include processes with no controlling terminal — i.e. daemons and background services, which is precisely what you want on a server.

The `STAT` column: `S` sleeping, `R` running, `Z` zombie, `s` session leader, `<` high priority.

### `mkdir -p`

`-p` creates parent directories as needed **and does not error if the directory already exists** — which makes the script safely re-runnable (idempotent). Without `-p`, a second run would fail.

### `touch`

Creates an empty file, or updates the timestamp of one that exists. Here it guarantees the file exists before anything writes to it.

### `>` output redirection

```bash
ps aux > "$REPORT_PATH"
```

Redirects **stdout** into a file, **truncating** it first.

| Operator | Effect |
|---|---|
| `>` | Overwrite (truncate then write) |
| `>>` | Append |
| `2>` | Redirect stderr |
| `&>` or `> f 2>&1` | Redirect both stdout and stderr |
| `\|` | Pipe stdout into another command |
| `\| tee f` | Show on screen **and** write to a file |

---

## Notes on quality

* Every variable expansion is **double-quoted** (`"$DIR_NAME"`), so directory or file names containing spaces still work.
* `mkdir -p` makes the script safe to run repeatedly.
* `${VAR:-default}` means the script never creates a file literally named nothing if the user just hits Enter.
* Comments are grouped in numbered sections matching the task requirements.

A production version would also start with `set -euo pipefail` — exit on error, treat unset variables as errors, and fail a pipeline if any stage fails. It is left out here because the task is explicitly about demonstrating the individual commands, and `set -e` would abort the run on the first non-zero exit rather than showing the full report.

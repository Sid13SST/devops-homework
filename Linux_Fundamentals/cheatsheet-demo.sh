#!/bin/bash
run() { echo "\$ $*"; eval "$@" 2>&1; echo; }
sec() { echo; echo "##################################################"; echo "## $1"; echo "##################################################"; echo; }

mkdir -p /tmp/cheat && cd /tmp/cheat

sec "A. NAVIGATION"
run "pwd"
run "cd /etc && pwd"
run "cd /tmp/cheat && pwd"
run "ls /"
run "ls -lh /etc/hostname"
run "ls -la /root | head -6"

sec "B. CREATING AND REMOVING"
run "mkdir -p project/src/utils"
run "tree project 2>/dev/null || find project -print"
run "touch project/src/app.py project/README.md"
run "ls -R project"
run "cp project/README.md project/README.bak"
run "mv project/README.bak project/OLD.md"
run "rm project/OLD.md && echo removed"
run "rm -r project/src/utils && echo 'recursively removed'"

sec "C. VIEWING FILE CONTENT"
printf 'line one\nline two\nline three\nline four\nline five\n' > sample.txt
run "cat sample.txt"
run "head -2 sample.txt"
run "tail -2 sample.txt"
run "wc -l sample.txt"
run "wc -w sample.txt"
run "nl sample.txt"
echo "\$ less sample.txt   # interactive pager - q to quit (not run here)"; echo

sec "D. SEARCHING"
run "grep 'three' sample.txt"
run "grep -n 'line' sample.txt"
run "grep -c 'line' sample.txt"
run "grep -i 'LINE ONE' sample.txt"
run "grep -v 'line one' sample.txt"
run "find /tmp/cheat -name '*.txt'"
run "find /tmp/cheat -type d"
run "which bash"
run "whereis ls"

sec "E. PERMISSIONS AND OWNERSHIP"
run "ls -l sample.txt"
run "chmod 644 sample.txt && ls -l sample.txt"
run "chmod +x sample.txt && ls -l sample.txt"
run "chmod 600 sample.txt && ls -l sample.txt"
echo "--- rwx = 4+2+1. 644 = rw-r--r-- ; 755 = rwxr-xr-x ; 600 = rw-------"; echo
run "useradd -m demo 2>/dev/null; chown demo:demo sample.txt && ls -l sample.txt"
run "chown root:root sample.txt && ls -l sample.txt"

sec "F. PROCESSES"
run "ps"
run "ps aux | head -5"
run "ps -ef | head -5"
sleep 300 &
BGPID=$!
run "ps -p $BGPID -o pid,ppid,cmd,%cpu,%mem"
run "kill $BGPID && echo 'sent SIGTERM to $BGPID'"
sleep 1
run "ps -p $BGPID -o pid= || echo 'process is gone'"
echo "\$ top      # interactive live process viewer (not run here)"
echo "\$ htop     # nicer version of top, needs installing"; echo

sec "G. DISK AND MEMORY"
run "df -h"
run "df -h /"
run "du -sh /tmp/cheat"
run "du -h --max-depth=1 /tmp/cheat"
run "free -h"

sec "H. SYSTEM INFORMATION"
run "uname -a"
run "uname -r"
run "hostname"
run "whoami"
run "id"
run "date"
run "uptime"
run "cat /etc/os-release | head -4"

sec "I. TEXT PROCESSING PIPELINE"
printf 'alice,30,engineer\nbob,25,designer\ncarol,35,manager\n' > people.csv
run "cat people.csv"
run "cut -d, -f1 people.csv"
run "cut -d, -f1,3 people.csv"
run "sort -t, -k2 -n people.csv"
run "awk -F, '{print \$1 \" is a \" \$3}' people.csv"
run "sed 's/engineer/developer/' people.csv"
run "cat people.csv | tr 'a-z' 'A-Z'"
run "uniq -c <(printf 'a\na\nb\n')"

sec "J. REDIRECTION AND PIPES"
run "echo 'written with >' > out.txt; cat out.txt"
run "echo 'appended with >>' >> out.txt; cat out.txt"
run "ls /nonexistent 2> err.txt; cat err.txt"
run "ls /nonexistent > all.txt 2>&1; cat all.txt"
run "ps aux | grep -c bash"

sec "K. ARCHIVES AND COMPRESSION"
run "tar -czf archive.tar.gz sample.txt people.csv && ls -lh archive.tar.gz"
run "tar -tzf archive.tar.gz"
run "mkdir -p extracted && tar -xzf archive.tar.gz -C extracted && ls extracted"
run "gzip -k sample.txt && ls -l sample.txt.gz"
run "gunzip sample.txt.gz && echo decompressed"

sec "L. LINKS AND ENVIRONMENT"
run "ln -s /tmp/cheat/sample.txt /tmp/cheat/link.txt && ls -l link.txt"
run "echo \$HOME"
run "echo \$PATH"
run "export MYVAR='hello devops'; echo \$MYVAR"
run "env | head -5"
run "history 2>/dev/null | tail -3 || echo '(history is a shell builtin, empty in non-interactive shells)'"

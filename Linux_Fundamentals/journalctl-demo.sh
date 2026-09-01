#!/bin/bash
run() { echo "\$ $*"; eval "$@"; echo; }

echo "===== 0. Confirm we are on a systemd host (journald is part of systemd) ====="
run "systemctl is-system-running"
run "systemctl --version | head -2"

echo "===== 1. Install a real service to generate logs ====="
apt-get update -qq >/dev/null 2>&1
apt-get install -y -qq nginx >/dev/null 2>&1
run "systemctl enable --now nginx >/dev/null 2>&1; systemctl is-active nginx"

echo "===== 2. journalctl with NO arguments shows the whole journal (oldest first) ====="
echo "\$ journalctl --no-pager | head -5"
journalctl --no-pager | head -5; echo

echo "===== 3. -n N : the last N entries (most useful quick check) ====="
run "journalctl --no-pager -n 10"

echo "===== 4. -u UNIT : logs for ONE specific service  <<< the key one >>> ====="
run "journalctl --no-pager -u nginx"

echo "===== 5. Restart the service and watch its log grow ====="
run "systemctl restart nginx"
run "journalctl --no-pager -u nginx -n 8"

echo "===== 6. systemctl status also shows the last few journal lines ====="
run "systemctl status nginx --no-pager | head -14"

echo "===== 7. -b : logs from the current boot only ====="
run "journalctl --no-pager -b -n 5"
run "journalctl --list-boots --no-pager"

echo "===== 8. -p : filter by priority (err and worse) ====="
run "journalctl --no-pager -p err -b || echo '(no error-level entries this boot)'"

echo "===== 9. --since / --until : time filtering ====="
run "journalctl --no-pager --since '10 minutes ago' -u nginx | tail -5"

echo "===== 10. -k : kernel messages only (dmesg equivalent) ====="
echo "\$ journalctl --no-pager -k -n 3"
journalctl --no-pager -k -n 3 2>&1 || echo "(kernel ring buffer not exposed inside a container)"
echo

echo "===== 11. -o : output formats ====="
run "journalctl --no-pager -u nginx -n 1 -o short-iso"
run "journalctl --no-pager -u nginx -n 1 -o json-pretty | head -20"

echo "===== 12. Journal housekeeping ====="
run "journalctl --disk-usage"
echo "\$ journalctl --vacuum-time=2d      (delete entries older than 2 days)"
journalctl --vacuum-time=2d 2>&1 | tail -2; echo

echo "===== 13. Follow mode (-f) streams live - shown here with a timeout ====="
echo "\$ journalctl -f -u nginx     # Ctrl+C to stop; runs forever, so bounded here:"
echo "\$ timeout 4 journalctl -f -u nginx &  then: systemctl reload nginx"
timeout 4 journalctl -f -u nginx --no-pager &
sleep 1
systemctl reload nginx
wait
echo
echo "===== Cleanup ====="
run "systemctl stop nginx; systemctl is-active nginx || true"

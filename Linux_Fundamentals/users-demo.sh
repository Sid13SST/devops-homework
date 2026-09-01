#!/bin/bash
run() { echo "\$ $*"; eval "$@"; echo; }

echo "===== 1. What are these two commands? ====="
run "which useradd adduser"
run "file -L /usr/sbin/useradd"
run "file -L /usr/sbin/adduser"
echo "--- useradd is a compiled binary from the 'passwd'/shadow-utils package."
echo "--- adduser is a Perl script: a friendly, policy-driven WRAPPER around useradd."
echo
run "dpkg -S /usr/sbin/useradd /usr/sbin/adduser"

echo "===== 2. LOW LEVEL: useradd with no options ====="
run "useradd testuser1"
run "grep '^testuser1:' /etc/passwd"
echo "\$ ls -la /home/   (note: NO home directory was created)"
ls -la /home/; echo
echo "\$ test -d /home/testuser1 && echo 'home exists' || echo 'NO HOME DIRECTORY CREATED'"
test -d /home/testuser1 && echo 'home exists' || echo 'NO HOME DIRECTORY CREATED'; echo
run "passwd -S testuser1"
echo "--- 'L' means the account is LOCKED: useradd set no password at all."
echo

echo "===== 3. RECOMMENDED ON UBUNTU/DEBIAN: adduser ====="
echo "Interactive form (what you would normally type):"
echo "    \$ sudo adduser testuser2"
echo "It then PROMPTS for password, Full Name, Room Number, Phone, etc."
echo "Here it is run non-interactively so the output is capturable:"
run "adduser --disabled-password --gecos '' testuser2"
run "grep '^testuser2:' /etc/passwd"
echo "\$ ls -la /home/testuser2   (home directory created AND populated)"
ls -la /home/testuser2; echo
run "passwd -S testuser2"
run "groups testuser2"

echo "===== 4. Side-by-side comparison ====="
echo "\$ grep -E '^testuser1:|^testuser2:' /etc/passwd"
grep -E '^testuser1:|^testuser2:' /etc/passwd
echo
echo "Field order: name:passwd:UID:GID:GECOS:home_dir:login_shell"
echo
echo "  testuser1 (useradd)  -> shell /bin/sh, home listed but NOT created, no group of its own populated"
echo "  testuser2 (adduser)  -> shell /bin/bash, home created + skel files copied, user group created"
echo

echo "===== 5. Making useradd behave like adduser (the options you must remember) ====="
run "useradd -m -s /bin/bash -c 'Test User Three' testuser3"
run "grep '^testuser3:' /etc/passwd"
run "ls -la /home/testuser3"
echo "--- -m creates the home dir, -s sets the shell, -c sets the GECOS comment."
echo

echo "===== 6. Cleaning up test users ====="
run "userdel -r testuser1 2>/dev/null; echo 'testuser1 removed'"
run "deluser --remove-home testuser2 2>&1 | tail -2"
run "userdel -r testuser3 2>/dev/null; echo 'testuser3 removed'"
run "grep -cE '^testuser' /etc/passwd || echo '0 test users remain'"

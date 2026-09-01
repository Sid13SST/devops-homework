#!/bin/bash
# Soft link vs hard link demonstration
run() { echo "\$ $*"; eval "$@"; echo; }

cd /tmp && rm -rf linkdemo && mkdir linkdemo && cd linkdemo

echo "===== 1. Create the original file ====="
run "echo 'Original content, written once.' > original.txt"
run "cat original.txt"

echo "===== 2. Create a HARD link (ln) and a SOFT link (ln -s) ====="
run "ln original.txt hardlink.txt"
run "ln -s original.txt softlink.txt"

echo "===== 3. Inspect: -i shows the inode number, column 2 is the link count ====="
run "ls -li"

echo "===== 4. All three read the same data right now ====="
run "cat original.txt hardlink.txt softlink.txt"

echo "===== 5. Writing through the hard link changes the same inode ====="
run "echo 'Appended via hardlink.' >> hardlink.txt"
run "cat original.txt"

echo "===== 6. DELETE THE ORIGINAL - the decisive test ====="
run "rm original.txt"
run "ls -li"

echo "--- hard link still works (inode still has a reference) ---"
run "cat hardlink.txt"

echo "--- soft link is now DANGLING (it pointed at a NAME that is gone) ---"
echo "\$ cat softlink.txt"
cat softlink.txt; echo "exit code = $?"
echo
run "readlink softlink.txt"
echo "\$ test -e softlink.txt && echo EXISTS || echo 'BROKEN (target missing)'"
test -e softlink.txt && echo EXISTS || echo 'BROKEN (target missing)'
echo

echo "===== 7. Hard links cannot cross filesystems or link directories ====="
echo "\$ ln /tmp/linkdemo/hardlink.txt /dev/shm/nope.txt   (different filesystem)"
ln /tmp/linkdemo/hardlink.txt /dev/shm/nope.txt 2>&1 || true
echo
run "mkdir realdir"
echo "\$ ln realdir dirhardlink   (hard link to a directory)"
ln realdir dirhardlink 2>&1 || true
echo
echo "\$ ln -s realdir dirsoftlink   (soft link to a directory - allowed)"
ln -s realdir dirsoftlink && ls -ld dirsoftlink
echo

echo "===== 8. Deleting links ====="
run "rm softlink.txt"
run "unlink dirsoftlink"
run "ls -li"

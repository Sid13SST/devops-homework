# Linux Fundamentals — Homework

Source task: **Linux Homework Tasks** (Task 1 soft/hard links, Task 2 `adduser` vs `useradd`, Task 3 `journalctl`, Task 4 command cheat sheet).

Every command below was actually executed and the output is copied verbatim. Full transcripts are in this folder:

| File | What it is |
|---|---|
| [`links-demo.sh`](links-demo.sh) / [`links-output.txt`](links-output.txt) | Task 1 script + full output |
| [`users-demo.sh`](users-demo.sh) / [`users-output.txt`](users-output.txt) | Task 2 script + full output |
| [`journalctl-demo.sh`](journalctl-demo.sh) / [`journalctl-output.txt`](journalctl-output.txt) | Task 3 script + full output |
| [`cheatsheet-demo.sh`](cheatsheet-demo.sh) / [`cheatsheet-output.txt`](cheatsheet-output.txt) | Task 4 script + full output |

> **Environment note.** The host machine is Windows 11. All Linux commands were run inside Linux containers on that machine: `ubuntu:24.04` for Tasks 1, 2 and 4, and a systemd-enabled Ubuntu 24.04 container for Task 3 (`journalctl` needs a running `systemd-journald`, which a normal container does not have).

---

## Task 1 — Soft Link & Hard Link

### The difference

Every file on Linux is really two things: an **inode** (the actual data plus metadata) and a **directory entry** (a name pointing at that inode).

| | Hard link | Soft link (symbolic link) |
|---|---|---|
| Command | `ln target linkname` | `ln -s target linkname` |
| Points to | The **inode** (the data itself) | The **pathname** (a string) |
| Own inode? | No — shares the target's inode | Yes — it is a separate small file |
| Link count (`ls -li` col 2) | Increases | Unchanged on the target |
| If the original is deleted | **Still works** — data survives until the last link goes | **Breaks** — becomes a dangling link |
| Across filesystems | Not allowed | Allowed |
| To a directory | Not allowed | Allowed |
| Size | Same as the file | Size of the path string |

### Commands to create both

```bash
ln  original.txt hardlink.txt     # hard link
ln -s original.txt softlink.txt   # soft / symbolic link
ls -li                            # -i shows inode numbers, column 2 is the link count
readlink softlink.txt             # show what a symlink points at
rm softlink.txt                   # delete a link
unlink softlink.txt               # same thing
```

### Practice — creating

```
$ ln original.txt hardlink.txt
$ ln -s original.txt softlink.txt

$ ls -li
total 8
389511 -rw-r--r-- 2 root root 32 Sep  1 13:01 hardlink.txt
389511 -rw-r--r-- 2 root root 32 Sep  1 13:01 original.txt
389512 lrwxrwxrwx 1 root root 12 Sep  1 13:01 softlink.txt -> original.txt
```

Read that carefully — it is the whole lesson:

* `original.txt` and `hardlink.txt` share inode **389511**, and their link count is **2**.
* `softlink.txt` has its **own** inode **389512**, a link count of **1**, type `l`, and displays `-> original.txt`.

Writing through the hard link edits the same inode:

```
$ echo 'Appended via hardlink.' >> hardlink.txt
$ cat original.txt
Original content, written once.
Appended via hardlink.
```

### Practice — deleting (the decisive test)

```
$ rm original.txt

$ ls -li
total 4
389511 -rw-r--r-- 1 root root 55 Sep  1 13:01 hardlink.txt
389512 lrwxrwxrwx 1 root root 12 Sep  1 13:01 softlink.txt -> original.txt
```

The hard link's count dropped from 2 to 1, but the inode is still referenced, so the data is intact:

```
$ cat hardlink.txt
Original content, written once.
Appended via hardlink.
```

The soft link pointed at the *name* `original.txt`, which no longer exists:

```
$ cat softlink.txt
cat: softlink.txt: No such file or directory
exit code = 1

$ readlink softlink.txt
original.txt

$ test -e softlink.txt && echo EXISTS || echo 'BROKEN (target missing)'
BROKEN (target missing)
```

### The two hard-link restrictions

```
$ ln /tmp/linkdemo/hardlink.txt /dev/shm/nope.txt   (different filesystem)
ln: failed to create hard link '/dev/shm/nope.txt' => '/tmp/linkdemo/hardlink.txt': Invalid cross-device link

$ ln realdir dirhardlink   (hard link to a directory)
ln: realdir: hard link not allowed for directory

$ ln -s realdir dirsoftlink   (soft link to a directory - allowed)
lrwxrwxrwx 1 root root 7 Sep  1 13:01 dirsoftlink -> realdir
```

Inode numbers are only unique **within one filesystem**, so a hard link cannot cross one. Hard links to directories are forbidden because they would let you build loops in the directory tree that `fsck` and `find` could not escape.

### Interview answer (the 30-second version)

> A hard link is an additional **name for the same inode** — the file has two equal names and a link count of 2, and deleting either one leaves the data reachable through the other. A soft link is a **separate small file containing a path string**; it is resolved at access time, so if the target is renamed or deleted the symlink dangles. Hard links cannot cross filesystems or point at directories because inode numbers are per-filesystem and directory hard links would create cycles. Symlinks can do both, which is why `/usr/bin` and package managers use them everywhere.

Follow-ups worth knowing:

* **Does `rm` delete the file?** No — `unlink()` removes a *name* and decrements the link count. The data is freed when the count hits 0 **and** no process holds the file open. That is why deleting a huge log a running process has open does not free disk space until you restart it.
* **`ls -l` link count on a directory?** It is 2 + the number of subdirectories (`.` inside it, plus its entry in the parent, plus each child's `..`).
* **Copying a symlink?** `cp` follows it by default; `cp -P` (or `cp -a`) preserves the link itself.

---

## Task 2 — `adduser` vs `useradd`

### The difference

```
$ file -L /usr/sbin/useradd
/usr/sbin/useradd: ELF 64-bit LSB pie executable, x86-64, ... stripped

$ file -L /usr/sbin/adduser
/usr/sbin/adduser: Perl script text executable

$ dpkg -S /usr/sbin/useradd /usr/sbin/adduser
passwd: /usr/sbin/useradd
adduser: /usr/sbin/adduser
```

That single output explains everything:

* **`useradd`** is a **compiled binary** from the `passwd` (shadow-utils) package. It is the low-level tool present on *every* Linux distro. It does exactly what you tell it and nothing more.
* **`adduser`** is a **Perl script** from the `adduser` package — a friendly, policy-driven **wrapper that calls `useradd` for you**. It is Debian/Ubuntu-specific.

| | `useradd` | `adduser` |
|---|---|---|
| Type | Compiled binary | Perl wrapper script |
| Package | `passwd` (shadow-utils) | `adduser` |
| Portability | All distros | Debian / Ubuntu only |
| Interactive | No | **Yes** — prompts for password and GECOS info |
| Home directory | Only with `-m` | Created automatically |
| Copies `/etc/skel` | Only with `-m` | Yes |
| Default shell | `/bin/sh` (from `/etc/default/useradd`) | `/bin/bash` (from `/etc/adduser.conf`) |
| Sets a password | No (account left locked) | Prompts for one |
| Best for | **Scripts and automation** | **Humans at a terminal** |

### Which is preferred on Ubuntu, and why

**`adduser` is the recommended command on Ubuntu/Debian for creating a normal user by hand.** Ubuntu's own man page for `useradd` calls it "a low level utility for adding users" and notes that Debian administrators should generally use `adduser` instead.

The reason is that `adduser` applies Debian **policy** from `/etc/adduser.conf` — correct UID range, a matching user group, a real home directory populated from `/etc/skel`, a sane shell, and a password prompt — so you get a **usable, correctly configured account in one step**. Raw `useradd` gives you an account that is subtly broken for interactive use unless you remember every flag.

The flip side: because `adduser` is interactive and Debian-only, **`useradd` is the right choice inside scripts, Dockerfiles and Ansible/cloud-init**, where you want no prompts and cross-distro behaviour.

### Proof — `useradd` with no options

```
$ useradd testuser1

$ grep '^testuser1:' /etc/passwd
testuser1:x:1001:1001::/home/testuser1:/bin/sh

$ ls -la /home/   (note: NO home directory was created)
total 12
drwxr-xr-x 3 root   root   4096 Aug 10 14:55 .
drwxr-xr-x 1 root   root   4096 Sep  1 13:02 ..
drwxr-x--- 2 ubuntu ubuntu 4096 Aug 10 14:55 ubuntu

$ test -d /home/testuser1 && echo 'home exists' || echo 'NO HOME DIRECTORY CREATED'
NO HOME DIRECTORY CREATED

$ passwd -S testuser1
testuser1 L 2026-09-01 0 99999 7 -1
```

`/etc/passwd` *claims* a home of `/home/testuser1`, but the directory was never created — the user would land in a non-existent directory on login. The `L` from `passwd -S` means **locked**: no password was set at all.

### Creating the test user with the recommended command

The normal interactive form is:

```bash
sudo adduser testuser2
```

…which then prompts for the password and the Full Name / Room Number / Phone fields. To capture the output here it was run non-interactively:

```
$ adduser --disabled-password --gecos '' testuser2
info: Adding user `testuser2' ...
info: Selecting UID/GID from range 1000 to 59999 ...
info: Adding new group `testuser2' (1002) ...
info: Adding new user `testuser2' (1002) with group `testuser2 (1002)' ...
info: Creating home directory `/home/testuser2' ...
info: Copying files from `/etc/skel' ...
info: Adding new user `testuser2' to supplemental / extra groups `users' ...
info: Adding user `testuser2' to group `users' ...

$ grep '^testuser2:' /etc/passwd
testuser2:x:1002:1002:,,,:/home/testuser2:/bin/bash

$ ls -la /home/testuser2   (home directory created AND populated)
total 20
drwxr-x--- 2 testuser2 testuser2 4096 Sep  1 13:03 .
drwxr-xr-x 1 root      root      4096 Sep  1 13:03 ..
-rw-r--r-- 1 testuser2 testuser2  220 Sep  1 13:03 .bash_logout
-rw-r--r-- 1 testuser2 testuser2 3771 Sep  1 13:03 .bashrc
-rw-r--r-- 1 testuser2 testuser2  807 Sep  1 13:03 .profile

$ groups testuser2
testuser2 : testuser2 users
```

`adduser` created the group, the home directory, copied the skeleton dotfiles, joined the `users` group and set `/bin/bash` — none of which plain `useradd` did.

### Side by side

```
$ grep -E '^testuser1:|^testuser2:' /etc/passwd
testuser1:x:1001:1001::/home/testuser1:/bin/sh
testuser2:x:1002:1002:,,,:/home/testuser2:/bin/bash
```

Field order is `name:passwd:UID:GID:GECOS:home_dir:login_shell`. Note `/bin/sh` vs `/bin/bash`, and the empty GECOS vs `,,,`.

### Making `useradd` behave like `adduser`

```
$ useradd -m -s /bin/bash -c 'Test User Three' testuser3

$ grep '^testuser3:' /etc/passwd
testuser3:x:1003:1003:Test User Three:/home/testuser3:/bin/bash

$ ls -la /home/testuser3
-rw-r--r-- 1 testuser3 testuser3  220 Mar 31  2024 .bash_logout
-rw-r--r-- 1 testuser3 testuser3 3771 Mar 31  2024 .bashrc
-rw-r--r-- 1 testuser3 testuser3  807 Mar 31  2024 .profile
```

`-m` creates and populates the home directory, `-s` sets the login shell, `-c` sets the GECOS comment. You would still need `passwd testuser3` to set a password.

### Deleting users

```bash
userdel -r testuser1          # -r also removes the home directory and mail spool
deluser --remove-home testuser2
```

---

## Task 3 — `journalctl`

### What it is for

`journalctl` is the query tool for the **systemd journal**. `systemd-journald` collects log data from the kernel ring buffer, early boot, stdout/stderr of every service, and syslog, then stores it in a **structured, indexed binary format** under `/run/log/journal` (volatile) or `/var/log/journal` (persistent).

Why that matters versus plain text files in `/var/log`:

* One place for **everything** — no hunting through `syslog`, `auth.log`, `nginx/error.log` separately.
* Every entry carries **metadata fields** (unit, PID, UID, boot ID, priority), so you can filter precisely instead of `grep`-ing.
* Rotation, size limits and integrity are handled by journald itself.

```
$ systemctl is-system-running
running

$ systemctl --version | head -2
systemd 255 (255.4-1ubuntu8.16)
```

### Viewing system logs

```bash
journalctl                 # everything, oldest first, in a pager
journalctl -n 10           # last 10 entries
journalctl -f              # follow live (like tail -f)
journalctl -r              # newest first
journalctl --no-pager      # do not pipe through less
```

```
$ journalctl --no-pager -n 10
Sep 01 13:05:05 af19e2d3d43e systemd[1]: Reloading finished in 28 ms.
Sep 01 13:05:05 af19e2d3d43e systemd[1]: Reached target network-online.target - Network is Online.
Sep 01 13:05:05 af19e2d3d43e systemd[1]: Starting nginx.service - A high performance web server and a reverse proxy server...
Sep 01 13:05:05 af19e2d3d43e systemd[1]: Started nginx.service - A high performance web server and a reverse proxy server.
```

### Checking logs for a specific service — the one that matters

`-u` / `--unit` filters to a single systemd unit. This is the flag you will use daily.

```
$ journalctl --no-pager -u nginx
Sep 01 13:05:05 af19e2d3d43e systemd[1]: Starting nginx.service - A high performance web server and a reverse proxy server...
Sep 01 13:05:05 af19e2d3d43e systemd[1]: Started nginx.service - A high performance web server and a reverse proxy server.
```

Restarting the service and watching its own log grow:

```
$ systemctl restart nginx

$ journalctl --no-pager -u nginx -n 8
Sep 01 13:05:05 af19e2d3d43e systemd[1]: Starting nginx.service ...
Sep 01 13:05:05 af19e2d3d43e systemd[1]: Started nginx.service ...
Sep 01 13:05:05 af19e2d3d43e systemd[1]: Stopping nginx.service ...
Sep 01 13:05:05 af19e2d3d43e systemd[1]: nginx.service: Deactivated successfully.
Sep 01 13:05:05 af19e2d3d43e systemd[1]: Stopped nginx.service ...
Sep 01 13:05:05 af19e2d3d43e systemd[1]: Starting nginx.service ...
Sep 01 13:05:05 af19e2d3d43e systemd[1]: Started nginx.service ...
```

`systemctl status` shows the same journal tail inline:

```
$ systemctl status nginx --no-pager | head -14
* nginx.service - A high performance web server and a reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; enabled; preset: enabled)
     Active: active (running) since Tue 2026-09-01 13:05:05 UTC; 9ms ago
    Process: 467 ExecStartPre=/usr/sbin/nginx -t -q -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
   Main PID: 470 (nginx)
      Tasks: 19 (limit: 9280)
     Memory: 15.0M (peak: 15.4M)
```

### Filtering — the flags worth memorising

| Command | What it does |
|---|---|
| `journalctl -u nginx` | One unit |
| `journalctl -u nginx -f` | Follow one unit live |
| `journalctl -b` | Current boot only |
| `journalctl -b -1` | Previous boot (post-crash forensics) |
| `journalctl --list-boots` | All recorded boots |
| `journalctl -p err` | Priority `err` and worse |
| `journalctl --since "1 hour ago"` | Time window |
| `journalctl --since today --until "12:00"` | Time range |
| `journalctl -k` | Kernel messages (`dmesg`) |
| `journalctl _PID=1234` | By structured field |
| `journalctl -o json-pretty` | Full structured output |
| `journalctl --disk-usage` | How much disk the journal uses |
| `journalctl --vacuum-time=7d` | Delete entries older than 7 days |

Priority levels run `emerg(0) alert(1) crit(2) err(3) warning(4) notice(5) info(6) debug(7)`.

Real output:

```
$ journalctl --list-boots --no-pager
IDX BOOT ID                          FIRST ENTRY                 LAST ENTRY
  0 e401deb34e53433fa8013524605c78f0 Tue 2026-09-01 13:04:13 UTC Tue 2026-09-01 13:05:05 UTC

$ journalctl --no-pager -p err -b
Sep 01 13:04:13 af19e2d3d43e kernel: PCI: Fatal: No config space access function found
Sep 01 13:04:13 af19e2d3d43e kernel: misc dxg: dxgk: dxgkio_query_adapter_info: Ioctl failed: -22
Sep 01 13:04:13 af19e2d3d43e kernel: virtiofs: Unknown parameter 'negative_dentry_timeout'

$ journalctl --no-pager -k -n 3
Sep 01 13:04:13 af19e2d3d43e kernel: docker0: port 10(veth7a3f563) entered blocking state
Sep 01 13:04:13 af19e2d3d43e kernel: docker0: port 10(veth7a3f563) entered forwarding state
Sep 01 13:04:13 af19e2d3d43e systemd-journald[23]: Collecting audit messages is disabled.

$ journalctl --disk-usage
Archived and active journals take up 8.0M in the file system.

$ journalctl --vacuum-time=2d
Vacuuming done, freed 0B of archived journals from /var/log/journal.
```

Structured output shows the metadata that makes the journal more than a text file:

```
$ journalctl --no-pager -u nginx -n 1 -o json-pretty | head -20
{
	"_HOSTNAME" : "af19e2d3d43e",
	"_CMDLINE" : "/lib/systemd/systemd",
	"CODE_FILE" : "src/core/job.c",
	"JOB_TYPE" : "start",
	"_BOOT_ID" : "e401deb34e53433fa8013524605c78f0",
	"MESSAGE_ID" : "39f53479d3a045ac8e11786248231fbf",
	"_SYSTEMD_UNIT" : "init.scope",
	"UNIT" : "nginx.service",
	...
```

Follow mode, captured live while the service was reloaded:

```
$ journalctl -f -u nginx
Sep 01 13:05:06 af19e2d3d43e systemd[1]: Reloading nginx.service ...
Sep 01 13:05:06 af19e2d3d43e nginx[509]: 2026/09/01 13:05:06 [notice] 509#509: signal process started
Sep 01 13:05:06 af19e2d3d43e systemd[1]: Reloaded nginx.service ...
```

### Making the journal persistent

By default many systems keep the journal only in `/run` (RAM), so it is lost on reboot:

```bash
sudo mkdir -p /var/log/journal
sudo systemd-tmpfiles --create --prefix /var/log/journal
sudo systemctl restart systemd-journald
```

Or set `Storage=persistent` in `/etc/systemd/journald.conf`.

---

## Task 4 — Linux Command Cheat Sheet

Every command in this section was executed; the complete transcript with all output is in **[`cheatsheet-output.txt`](cheatsheet-output.txt)**. Purpose and usage summarised below.

### A. Navigation

| Command | Purpose |
|---|---|
| `pwd` | Print working directory |
| `cd /path` | Change directory (`cd ~` home, `cd -` previous, `cd ..` up) |
| `ls` | List files |
| `ls -l` | Long format: permissions, owner, size, mtime |
| `ls -a` | Include hidden dotfiles |
| `ls -lh` | Human-readable sizes |
| `ls -R` | Recurse into subdirectories |

### B. Creating and removing

| Command | Purpose |
|---|---|
| `mkdir dir` | Create a directory |
| `mkdir -p a/b/c` | Create the whole path, no error if it exists |
| `touch file` | Create an empty file / update its timestamp |
| `cp src dst` | Copy a file |
| `cp -r src dst` | Copy a directory tree |
| `mv src dst` | Move **or** rename |
| `rm file` | Delete a file |
| `rm -r dir` | Delete a directory tree |
| `rm -rf dir` | Force, no prompts — **dangerous, no undo** |
| `rmdir dir` | Delete an *empty* directory |

### C. Viewing file content

| Command | Purpose |
|---|---|
| `cat f` | Dump the whole file |
| `less f` | Scroll interactively (`q` quits) — best for big files |
| `head -n 20 f` | First 20 lines |
| `tail -n 20 f` | Last 20 lines |
| `tail -f f` | Follow a growing log live |
| `wc -l f` | Count lines (`-w` words, `-c` bytes) |
| `nl f` | Number the lines |

### D. Searching

| Command | Purpose |
|---|---|
| `grep 'x' f` | Lines matching `x` |
| `grep -n` | Show line numbers |
| `grep -i` | Case-insensitive |
| `grep -v` | **Invert** — lines that do *not* match |
| `grep -c` | Count matches |
| `grep -r 'x' dir` | Recurse through a directory |
| `find . -name '*.log'` | Find by name |
| `find . -type d` | Find directories |
| `find . -size +100M` | Find by size |
| `which cmd` | Path of the executable that would run |
| `whereis cmd` | Binary, source and man page locations |

### E. Permissions and ownership

Permissions are three triads — **user, group, other** — each `r`(4) `w`(2) `x`(1).

| Octal | Symbolic | Typical use |
|---|---|---|
| `644` | `rw-r--r--` | Normal file |
| `755` | `rwxr-xr-x` | Script / directory |
| `600` | `rw-------` | Private file (SSH keys) |
| `777` | `rwxrwxrwx` | Everyone everything — **avoid** |

```
$ chmod 644 sample.txt && ls -l sample.txt
-rw-r--r-- 1 root root 50 Sep  1 13:05 sample.txt

$ chmod +x sample.txt && ls -l sample.txt
-rwxr-xr-x 1 root root 50 Sep  1 13:05 sample.txt

$ chmod 600 sample.txt && ls -l sample.txt
-rw------- 1 root root 50 Sep  1 13:05 sample.txt
```

`chown user:group file` changes ownership; `chown -R` recurses; `sudo cmd` runs as root.

### F. Processes

| Command | Purpose |
|---|---|
| `ps` | Processes in this shell |
| `ps aux` | Every process, BSD format |
| `ps -ef` | Every process, System V format |
| `top` | Live interactive process/CPU view |
| `htop` | Friendlier `top` |
| `kill PID` | Send SIGTERM (graceful) |
| `kill -9 PID` | SIGKILL — unconditional, no cleanup |
| `killall name` | Kill by process name |
| `jobs` / `fg` / `bg` | Shell job control |
| `cmd &` | Run in background |
| `nohup cmd &` | Keep running after logout |

```
$ ps -p 210 -o pid,ppid,cmd,%cpu,%mem
    PID    PPID CMD                         %CPU %MEM
    210     207 sleep 300                    0.0  0.0

$ kill 210
$ ps -p 210 -o pid= || echo 'process is gone'
process is gone
```

### G. Disk and memory

| Command | Purpose |
|---|---|
| `df -h` | Free space per mounted filesystem |
| `du -sh dir` | Total size of a directory |
| `du -h --max-depth=1` | Size of each immediate child — finds the space hog |
| `free -h` | RAM and swap |

```
$ df -h
Filesystem      Size  Used Avail Use% Mounted on
overlay        1007G   24G  933G   3% /
tmpfs            64M     0   64M   0% /dev
```

### H. System information

| Command | Purpose |
|---|---|
| `uname -a` | Kernel, host, architecture |
| `uname -r` | Kernel release only |
| `hostname` | Machine name |
| `whoami` | Current username |
| `id` | UID, GID and group membership |
| `date` | Current date and time |
| `uptime` | Time since boot + load average |
| `cat /etc/os-release` | Distribution and version |

### I. Text processing

| Command | Purpose |
|---|---|
| `cut -d, -f1 f` | Extract column 1, comma-delimited |
| `sort f` | Sort lines (`-n` numeric, `-r` reverse, `-k` by field) |
| `uniq -c` | Collapse duplicates and count (input must be sorted) |
| `awk -F, '{print $1}' f` | Field-aware processing |
| `sed 's/old/new/' f` | Stream edit / substitute |
| `tr 'a-z' 'A-Z'` | Translate characters |

```
$ awk -F, '{print $1 " is a " $3}' people.csv
alice is a engineer
bob is a designer
carol is a manager

$ sed 's/engineer/developer/' people.csv
alice,30,developer
bob,25,designer
carol,35,manager
```

### J. Redirection and pipes

| Syntax | Meaning |
|---|---|
| `cmd > f` | stdout to file, **overwriting** |
| `cmd >> f` | stdout to file, **appending** |
| `cmd 2> f` | stderr to file |
| `cmd > f 2>&1` | stdout **and** stderr to the same file |
| `cmd < f` | Read stdin from a file |
| `a \| b` | Pipe a's stdout into b's stdin |
| `cmd \| tee f` | Show on screen **and** save to file |

### K. Archives and compression

| Command | Purpose |
|---|---|
| `tar -czf a.tar.gz dir` | Create a gzip'd tarball |
| `tar -xzf a.tar.gz` | Extract |
| `tar -tzf a.tar.gz` | List contents without extracting |
| `tar -xzf a.tar.gz -C /dest` | Extract somewhere specific |
| `gzip f` / `gunzip f.gz` | Compress / decompress a single file |
| `zip -r a.zip dir` / `unzip a.zip` | Zip format |

Mnemonic: **c**reate, e**x**tract, **t**list — **z** gzip, **f** file, **v** verbose.

### L. Environment

| Command | Purpose |
|---|---|
| `echo $HOME` | Expand a variable |
| `echo $PATH` | Directories searched for commands |
| `export VAR=value` | Set a variable for child processes |
| `env` | Print the whole environment |
| `history` | Previously run commands |
| `man cmd` | Manual page |
| `cmd --help` | Quick usage summary |

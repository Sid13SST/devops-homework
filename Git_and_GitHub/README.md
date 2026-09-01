# Git and GitHub — Homework

Source task: **Git Homework Tasks** (Task 1 `git commit -a -m` vs `git commit -m`, Task 2 cherry-pick).

Every command below was actually executed in a real Git repository and the output is copied verbatim.

| File | What it is |
|---|---|
| [`git-demo.sh`](git-demo.sh) | The script that runs every command in this document |
| [`git-output.txt`](git-output.txt) | The complete unedited transcript |

---

## Task 1 — `git commit -a -m` vs `git commit -m`

### The short answer

| Command | What it commits |
|---|---|
| `git commit -m "msg"` | **Only what is already staged** with `git add` |
| `git commit -a -m "msg"` | Automatically stages every **modified** and **deleted** file that Git is **already tracking**, then commits |

The critical detail that catches people out: **`-a` does not include untracked (brand new) files.** It is shorthand for `git add -u`, not `git add -A`.

Git has three areas — the **working directory** (your files), the **staging area / index** (what will go into the next commit), and the **repository** (committed history). `-a` is a shortcut that skips the staging step for files Git already knows about.

### Test 1 — `-a -m` ignores untracked files

A brand new file is untracked, so `-a` will not pick it up:

```
$ echo 'version 1' > app.txt

$ git status --short
?? app.txt

$ git commit -a -m 'attempt to commit an untracked file'
On branch main

Initial commit

Untracked files:
  (use "git add <file>..." to include in what will be committed)
	app.txt

nothing added to commit but untracked files present (use "git add" to track)
```

**Nothing was committed.** The `??` in `git status --short` means untracked. The file must be staged explicitly first:

```
$ git add app.txt

$ git commit -m 'commit 1: add app.txt'
[main (root-commit) 2f5f576] commit 1: add app.txt
 1 file changed, 1 insertion(+)
 create mode 100644 app.txt
```

### Test 2 — `-m` alone commits nothing when nothing is staged

Now that `app.txt` is tracked, modify it:

```
$ echo 'version 2' > app.txt

$ git status --short
 M app.txt
```

` M` (leading space, then M) means a **tracked** file was modified but **not staged**. Committing with `-m` alone:

```
$ git commit -m 'commit with -m only'
On branch main
Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git restore <file>..." to discard changes in working directory)
	modified:   app.txt

no changes added to commit (use "git add" and/or "git commit -a")
```

**Refused** — nothing was staged, so there was nothing to commit. Git even suggests the two ways forward: `git add`, or `git commit -a`.

### Test 3 — `-a -m` stages and commits tracked modifications in one step

```
$ git commit -a -m 'commit 2: update app.txt using -a -m'
[main c4fd096] commit 2: update app.txt using -a -m
 1 file changed, 1 insertion(+), 1 deletion(-)

$ git log --oneline
c4fd096 commit 2: update app.txt using -a -m
2f5f576 commit 1: add app.txt
```

Committed in one step, with no separate `git add`. This is exactly what `-a` is for.

### Test 4 — the decisive side-by-side

Now do both at once: modify a **tracked** file and create a **new untracked** one.

```
$ echo 'version 3' > app.txt
$ echo 'brand new file' > newfile.txt

$ git status --short
 M app.txt
?? newfile.txt

$ git commit -a -m 'commit 3: -a picks up app.txt but not newfile.txt'
[main 54b22c1] commit 3: -a picks up app.txt but not newfile.txt
 1 file changed, 1 insertion(+), 1 deletion(-)

$ git status --short
?? newfile.txt
```

**"1 file changed"** — `app.txt` went in, `newfile.txt` did not. It is still sitting there as `??`. To commit it you must add it explicitly:

```
$ git add newfile.txt && git commit -m 'commit 4: add newfile.txt explicitly'
[main 377c54d] commit 4: add newfile.txt explicitly
 1 file changed, 1 insertion(+)
 create mode 100644 newfile.txt

$ git status --short

$ git log --oneline
377c54d commit 4: add newfile.txt explicitly
54b22c1 commit 3: -a picks up app.txt but not newfile.txt
c4fd096 commit 2: update app.txt using -a -m
2f5f576 commit 1: add app.txt
```

### Summary

* `git commit -m "msg"` → commits **only staged** changes.
* `git commit -a -m "msg"` → auto-stages all **modified and deleted tracked** files, then commits. **Still ignores untracked files.**
* `-a` is equivalent to `git add -u` followed by `git commit`.
* `git add -A` (or `git add .`) is what actually catches new files.

**Why it matters in practice:** `-a` is a convenient shortcut for a quick fix to existing files, but it is a blunt instrument — it sweeps up *every* modified tracked file in the repo, including ones you did not mean to include. Staging deliberately with `git add <specific files>` gives you clean, reviewable, single-purpose commits. Use `-a` when you know the whole working tree is one logical change; use `git add` the rest of the time.

**Related flags:**

| Command | Effect |
|---|---|
| `git commit -am "msg"` | Same as `-a -m`, combined |
| `git add -u` | Stage tracked modifications/deletions only |
| `git add -A` | Stage everything, including new files |
| `git add -p` | Interactively stage individual hunks |
| `git commit --amend` | Rewrite the previous commit |

---

## Task 2 — Git Cherry-Pick

### What cherry-pick does

`git cherry-pick <commit>` takes the **diff introduced by one specific commit** and replays it as a **new commit on your current branch**. Use it when you want *one* change from another branch without merging everything else — the classic case being an urgent hotfix sitting on a feature branch that is not ready to ship.

### Step 1 — commits on `main`

Task 1 left four commits on `main`:

```
$ git branch --show-current
main

$ git log --oneline
377c54d commit 4: add newfile.txt explicitly
54b22c1 commit 3: -a picks up app.txt but not newfile.txt
c4fd096 commit 2: update app.txt using -a -m
2f5f576 commit 1: add app.txt
```

### Step 2 — create a new branch

```
$ git checkout -b feature
Switched to a new branch 'feature'

$ git branch
* feature
  main
```

`git checkout -b` creates the branch and switches to it in one go. The `*` marks the current branch.

### Step 3 — three commits on the new branch

```
$ echo 'feature: login form' > login.txt && git add login.txt && git commit -m 'feat: add login form'
[feature 975b08b] feat: add login form
 1 file changed, 1 insertion(+)
 create mode 100644 login.txt

$ echo 'feature: URGENT security patch' > security-patch.txt && git add security-patch.txt && git commit -m 'fix: URGENT security patch'
[feature b13bf89] fix: URGENT security patch
 1 file changed, 1 insertion(+)
 create mode 100644 security-patch.txt

$ echo 'feature: experimental dashboard' > dashboard.txt && git add dashboard.txt && git commit -m 'feat: experimental dashboard'
[feature 1455084] feat: experimental dashboard
 1 file changed, 1 insertion(+)
 create mode 100644 dashboard.txt
```

The scenario: the middle commit is an **urgent security patch** that must reach `main` immediately. The login form and the experimental dashboard are **not** ready and must stay on `feature`.

### Step 4 — use `git log` to identify the specific commit

```
$ git log --oneline
1455084 feat: experimental dashboard
b13bf89 fix: URGENT security patch
975b08b feat: add login form
377c54d commit 4: add newfile.txt explicitly
54b22c1 commit 3: -a picks up app.txt but not newfile.txt
c4fd096 commit 2: update app.txt using -a -m
2f5f576 commit 1: add app.txt
```

The commit we want is **`b13bf89`**. Its full SHA:

```
$ git log --format='%H' --grep='URGENT security patch'
b13bf891065a45eb3eb91d87bf70ba075c481907
```

Confirm it contains exactly what we expect before picking it:

```
$ git show --stat b13bf89
commit b13bf891065a45eb3eb91d87bf70ba075c481907
Author: Siddhant <siddhant.prasad8@gmail.com>
Date:   Tue Sep 1 13:11:06 2026 +0000

    fix: URGENT security patch

 security-patch.txt | 1 +
 1 file changed, 1 insertion(+)
```

One file, one insertion. Exactly the change we want and nothing else.

### Step 5 — switch back to `main` and confirm the change is not there

```
$ git checkout main
Switched to branch 'main'

$ git log --oneline
377c54d commit 4: add newfile.txt explicitly
54b22c1 commit 3: -a picks up app.txt but not newfile.txt
c4fd096 commit 2: update app.txt using -a -m
2f5f576 commit 1: add app.txt

$ ls -1
app.txt
newfile.txt

$ test -f security-patch.txt && echo present || echo 'security-patch.txt NOT on main yet'
security-patch.txt NOT on main yet
```

`main` is untouched — four commits, two files, no patch.

### Step 6 — cherry-pick that one commit

```
$ git cherry-pick b13bf89
[main adfb258] fix: URGENT security patch
 Date: Tue Sep 1 13:11:06 2026 +0000
 1 file changed, 1 insertion(+)
 create mode 100644 security-patch.txt
```

### Step 7 — verify the change is now on `main`

```
$ git log --oneline
adfb258 fix: URGENT security patch
377c54d commit 4: add newfile.txt explicitly
54b22c1 commit 3: -a picks up app.txt but not newfile.txt
c4fd096 commit 2: update app.txt using -a -m
2f5f576 commit 1: add app.txt

$ ls -1
app.txt
newfile.txt
security-patch.txt

$ cat security-patch.txt
feature: URGENT security patch
```

And — just as importantly — the commits we did **not** pick did not come along:

```
$ test -f login.txt && echo 'login.txt present' || echo 'login.txt NOT on main (correct - not cherry-picked)'
login.txt NOT on main (correct - not cherry-picked)

$ test -f dashboard.txt && echo 'dashboard.txt present' || echo 'dashboard.txt NOT on main (correct - not cherry-picked)'
dashboard.txt NOT on main (correct - not cherry-picked)
```

**Verified.** The security patch is on `main`; the login form and dashboard stayed behind on `feature`.

### Step 8 — the cherry-picked commit is a *new* commit

This is the part people miss:

```
$ git log --format='%h %s' -1 main
adfb258 fix: URGENT security patch

$ git log --format='%h %s' --grep='URGENT' feature
b13bf89 fix: URGENT security patch
```

Same message, same content, **different SHA** (`adfb258` vs `b13bf89`). A commit hash covers its content *and* its parent, so replaying the diff onto a different parent necessarily produces a different commit. Cherry-pick **copies a change; it does not move a commit.**

The branch graph makes it visible:

```
$ git log --oneline --graph --all
* 1455084 feat: experimental dashboard
* b13bf89 fix: URGENT security patch
* 975b08b feat: add login form
| * adfb258 fix: URGENT security patch
|/
* 377c54d commit 4: add newfile.txt explicitly
* 54b22c1 commit 3: -a picks up app.txt but not newfile.txt
* c4fd096 commit 2: update app.txt using -a -m
* 2f5f576 commit 1: add app.txt
```

Both branches share history up to `377c54d`, then diverge. The same logical change now exists on both sides with two different hashes.

### Useful cherry-pick options

| Command | Purpose |
|---|---|
| `git cherry-pick <sha>` | Pick one commit |
| `git cherry-pick <sha1> <sha2>` | Pick several |
| `git cherry-pick A..B` | Pick a range (exclusive of A) |
| `git cherry-pick -n <sha>` | Apply to the working tree but **do not** commit |
| `git cherry-pick -x <sha>` | Record "cherry picked from commit ..." in the message — good practice for release branches |
| `git cherry-pick --abort` | Bail out of a conflicted pick |
| `git cherry-pick --continue` | Resume after resolving conflicts |

**If it conflicts:** Git stops and leaves the conflict markers in place. Edit the files, `git add` them, then `git cherry-pick --continue` — or `git cherry-pick --abort` to undo the whole thing.

**When *not* to use it:** cherry-picking the same change onto two branches that will later be merged creates duplicate commits and can cause avoidable conflicts. For anything more than a one-off hotfix, prefer a proper `merge` or `rebase`.

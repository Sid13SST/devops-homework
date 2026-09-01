#!/bin/bash
run() { echo "\$ $*"; eval "$@" 2>&1; echo; }
sec() { echo; echo "=================================================="; echo "== $1"; echo "=================================================="; echo; }

export GIT_PAGER=cat
git config --global user.name "Siddhant"
git config --global user.email "siddhant.prasad8@gmail.com"
git config --global init.defaultBranch main
git config --global advice.detachedHead false

rm -rf /tmp/gitdemo && mkdir -p /tmp/gitdemo && cd /tmp/gitdemo
run "git init"

sec "TASK 1 - git commit -m   VS   git commit -a -m"

echo "### Step 1: create a file and make the FIRST commit."
echo "### A brand new file is UNTRACKED, so it must be staged with 'git add' first."
run "echo 'version 1' > app.txt"
run "git status --short"
echo "--- '??' means untracked. Try committing with -a -m and watch it be ignored:"
run "git commit -a -m 'attempt to commit an untracked file'"
echo ">>> RESULT: nothing was committed. -a does NOT pick up UNTRACKED files."
echo
run "git add app.txt"
run "git commit -m 'commit 1: add app.txt'"

echo "### Step 2: MODIFY the now-tracked file."
run "echo 'version 2' > app.txt"
run "git status --short"
echo "--- ' M' means a TRACKED file was modified but not staged."
echo
echo "### Step 3: 'git commit -m' alone commits NOTHING here, because nothing is staged."
run "git commit -m 'commit with -m only'"
echo ">>> RESULT: refused - 'no changes added to commit'."
echo

echo "### Step 4: 'git commit -a -m' stages all MODIFIED TRACKED files automatically."
run "git commit -a -m 'commit 2: update app.txt using -a -m'"
echo ">>> RESULT: committed in one step - no separate 'git add' needed."
run "git log --oneline"

echo "### Step 5: side-by-side proof with BOTH a modified tracked file and a new untracked file."
run "echo 'version 3' > app.txt"
run "echo 'brand new file' > newfile.txt"
run "git status --short"
run "git commit -a -m 'commit 3: -a picks up app.txt but not newfile.txt'"
run "git status --short"
echo ">>> app.txt was committed. newfile.txt is STILL untracked ('??')."
echo
run "git add newfile.txt && git commit -m 'commit 4: add newfile.txt explicitly'"
run "git status --short"
run "git log --oneline"

echo
echo "SUMMARY OF TASK 1"
echo "-----------------"
echo "  git commit -m 'msg'      -> commits ONLY what is already staged (git add)."
echo "  git commit -a -m 'msg'   -> automatically stages every MODIFIED and DELETED"
echo "                              TRACKED file, then commits. It still IGNORES"
echo "                              untracked (brand new) files."

sec "TASK 2 - GIT CHERRY-PICK"

echo "### Step 1: main branch already has 4 commits. View them with git log."
run "git branch --show-current"
run "git log --oneline"
run "git log --oneline --graph --all"

echo "### Step 2: create a new branch and switch to it."
run "git checkout -b feature"
run "git branch"

echo "### Step 3: make 3 commits on the feature branch."
run "echo 'feature: login form' > login.txt && git add login.txt && git commit -m 'feat: add login form'"
run "echo 'feature: URGENT security patch' > security-patch.txt && git add security-patch.txt && git commit -m 'fix: URGENT security patch'"
run "echo 'feature: experimental dashboard' > dashboard.txt && git add dashboard.txt && git commit -m 'feat: experimental dashboard'"

echo "### Step 4: view the feature branch history and IDENTIFY the commit we want."
run "git log --oneline"
echo "--- We want ONLY the security patch, not the login form or the dashboard."
echo
PATCH_SHA=$(git log --format='%H' --grep='URGENT security patch')
PATCH_SHORT=$(git log --format='%h' --grep='URGENT security patch')
echo "\$ PATCH_SHA=\$(git log --format='%H' --grep='URGENT security patch')"
echo "Identified commit: $PATCH_SHA"
echo
run "git show --stat $PATCH_SHORT"

echo "### Step 5: switch back to main. Note the patch file is NOT here."
run "git checkout main"
run "git log --oneline"
run "ls -1"
echo "\$ test -f security-patch.txt && echo present || echo 'security-patch.txt NOT on main yet'"
test -f security-patch.txt && echo present || echo 'security-patch.txt NOT on main yet'
echo

echo "### Step 6: CHERRY-PICK just that one commit onto main."
run "git cherry-pick $PATCH_SHORT"

echo "### Step 7: VERIFY the change is now on main."
run "git log --oneline"
run "ls -1"
echo "\$ cat security-patch.txt"
cat security-patch.txt
echo
echo "\$ test -f login.txt && echo 'login.txt present' || echo 'login.txt NOT on main (correct - not cherry-picked)'"
test -f login.txt && echo 'login.txt present' || echo 'login.txt NOT on main (correct - not cherry-picked)'
echo "\$ test -f dashboard.txt && echo 'dashboard.txt present' || echo 'dashboard.txt NOT on main (correct - not cherry-picked)'"
test -f dashboard.txt && echo 'dashboard.txt present' || echo 'dashboard.txt NOT on main (correct - not cherry-picked)'
echo

echo "### Step 8: the cherry-picked commit is a NEW commit with a DIFFERENT SHA."
echo "\$ git log --oneline -1 main   (new SHA on main)"
git log --format='%h %s' -1 main
echo "\$ git log --format='%h %s' --grep='URGENT' feature   (original SHA on feature)"
git log --format='%h %s' --grep='URGENT' feature
echo
echo "--- Same content and message, different commit hash: cherry-pick REPLAYS"
echo "--- the diff as a brand new commit on the current branch."
echo
run "git log --oneline --graph --all"

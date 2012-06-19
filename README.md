combs_sync
==========

### a simple ruby script that uses git to keep your files in sync across multiple machines.

### Setup: ###

* get the script
 
```bash
git clone git@github.com:wcombs/combs_sync.git /code/dir/combs_sync
```

* setup shared ssh keys to server box, be sure you can ssh server_machine_hostname with no problems

* setup a bare repo on the server box
	* if repo/files already exist just do a git clone --bare and put it in place somewhere on server box
	* if new do git init --bare reponame.git on server box

* on client box pull the repo down:
	* go to dir you want to keep the main sync dir in, then

```bash
git clone wcombs@server_machine_hostname:synced.git
```
* paste the following into your .git/config file in the endpoint repos (note the 'url' line):

```git
[core]
    repositoryformatversion = 0
    filemode = true
    bare = false
    logallrefupdates = true
    ignorecase = true
[remote "origin"]
    fetch = +refs/heads/*:refs/remotes/origin/*
    url = (this should be right if you cloned it, but if its not then set it to the url to the server repo)
[branch "master"]
    remote = origin
    merge = refs/heads/master
[merge]
    tool = combsmerge
```

* paste the following into your .gitignore in the endpoint main repo dir (and anything else you want to keep local and not synced in that dir):

```
big_files/
[Tt]humbs.db
*.DS_Store
```

* then run:

```bash
git add .
git commit -m 'gitignore'
git push origin master
```
 
* paste the following into /code/dir/combs_sync/combs_sync.cfg on your endpoint machine:
** lock_path is on the server machine
** unique_id must be unique between client boxes
** big_files_thresh is in bytes (below is 10 MB)

```
git_exe_location: /usr/local/bin/git
this_repo_gitdir: /Users/wcombs/synced/.git
this_repo_worktree: /Users/wcombs/synced
lock_path: /some/remote/dir/combs_sync_lock
lock_retries: 5
lock_wait_time: 5
remote_server: server_machine_hostname
ssh_user: wcombs
merge_script: /code/dir/combs_sync/merge.sh
unique_id: combsrepo1
big_files_dir: /Users/wcombs/synced/big_files
big_files_thresh: 10000000
dock_notify: on
dockbadge_post_url: http://localhost:12345/post.html
```

* cron it up (below is every min):

```bash
* * * * * bash -c 'source /etc/bashrc && source /Users/wcombs/.rvm/scripts/rvm && /usr/bin/env ruby /Users/wcombs/code/combs_sync/do_sync.rb --config=/Users/wcombs/code/combs_sync/combs_sync.cfg >> /tmp/log 2>&1'
```

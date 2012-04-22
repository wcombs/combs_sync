#!/usr/bin/ruby
# first of all - check working dir for changes, if any changes, commit them
#
# get current commit rev hash from this repo and central
# if they are same, stop.
# if they are diff
#	figure out which is newer
#	if central is newer, do a pull
#	if this is newer, do a push
#	if either of these are ff, then we're done
#	if either require merging, deal with that somehow
#		ideas:	exit script, making user edit them offline, then rerun
#				or somehow do it inline while script it going
# goal of script is that this and central will have same git tree and current rev
#
# need to think about:
#	-locking, only allow one sync operation at a time (ie, laptop to central, desktop to central)
#

require 'net/ssh'
require 'yaml'

Config = YAML.load_file('combs_sync.cfg')

def ssh_exec!(ssh, command)
	stdout_data = ""
	stderr_data = ""
	exit_code = nil
	exit_signal = nil
	ssh.open_channel do |channel|
		channel.exec(command) do |ch, success|
			unless success
				abort "FAILED: couldn't execute command (ssh.channel.exec)"
			end
			channel.on_data do |ch,data|
				stdout_data+=data
			end
			channel.on_extended_data do |ch,type,data|
				stderr_data+=data
			end
			channel.on_request("exit-status") do |ch,data|
				exit_code = data.read_long
			end
			channel.on_request("exit-signal") do |ch, data|
				exit_signal = data.read_long
			end
		end
	end
	ssh.loop
	[stdout_data, stderr_data, exit_code, exit_signal]
end

def check_and_set_lock
	Net::SSH.start(Config["remote_server"], Config["ssh_user"]) do |ssh|
		ret = ssh_exec!(ssh, "ls " + Config["lock_path"])
		if ret[0].chomp == Config["lock_path"]
			puts "Sync in progress, try again later"
			exit
		else
			ret = ssh_exec!(ssh, "touch " + Config["lock_path"])
			if ret[2] != 0
				puts "Error setting lock!"
				puts "Got this error on remote host: " + ret[1]
			end
		end
	end
end

def remove_lock
	Net::SSH.start(Config["remote_server"], Config["ssh_user"]) do |ssh|
		ret = ssh_exec!(ssh, "rm " + Config["lock_path"])
		if ret[2] != 0
			puts "Error removing lock!"
			puts "Got this error on remote host: " + ret[1]
		end
	end
end


check_and_set_lock

# check for changes in local repo
cmd = "git --git-dir=" + Config["this_repo_gitdir"] + " --work-tree=" + Config["this_repo_worktree"] + " status --porcelain"
this_repo_status = %x[ #{cmd} ]

if this_repo_status == ""
	puts "no changes in local work tree, moving on"
else
	puts "changes found in work tree, committing them"
	# add untracked files
	cmd = "git --git-dir=" + Config["this_repo_gitdir"] + " --work-tree=" + Config["this_repo_worktree"] + " add ."
	this_add_return = %x[ #{cmd} ]
	# commit changes
	cmd = "git --git-dir=" + Config["this_repo_gitdir"] + " --work-tree=" + Config["this_repo_worktree"] + " commit -a -m 'combs_sync auto-commit'"
	this_commit_return = %x[ #{cmd} ]
end

# get current rev hashes of this and central
cmd = "git --git-dir=" + Config["this_repo_gitdir"] + " log --format=format:%H -n 1"
this_repo_current_commit = %x[ #{cmd} ]
cmd = "git --git-dir=" + Config["central_repo_gitdir"] + " log --format=format:%H -n 1"
central_repo_current_commit = %x[ #{cmd} ]

if this_repo_current_commit == central_repo_current_commit
	puts "up to date, nothing to do here"
	remove_lock
	exit
else
	puts "they are diff, checking"
end

# check which one is more up to date
# is central newer?
cmd = "git --git-dir=" + Config["central_repo_gitdir"] + " log --format=format:%H -n 1 " + this_repo_current_commit + " 2>/dev/null"
puts cmd
check_central_repo_for_this_commit = %x[ #{cmd} ]

if check_central_repo_for_this_commit == this_repo_current_commit
	puts "looks like central is newer, lets pull (fetch and merge) from central"
	cmd = "git --git-dir=" + Config["this_repo_gitdir"] + " --work-tree=" + Config["this_repo_worktree"] + " pull"
	pull_return = %x[ #{cmd} ]
	puts pull_return
	puts "done pulling"
elsif
	cmd = "git --git-dir=" + Config["this_repo_gitdir"] + " log --format=format:%H -n 1 " + central_repo_current_commit + " 2>/dev/null"
	check_this_repo_for_central_commit = %x[ #{cmd} ]
	if check_this_repo_for_central_commit == central_repo_current_commit
		puts "looks like local is newer, lets push it up to central"
		cmd = "git --git-dir=" + Config["this_repo_gitdir"] + " --work-tree=" + Config["this_repo_worktree"] + " push"
		push_return = %x[ #{cmd} ]
		puts push_return
		puts "done pushing"
	else
		puts "something is up, couldn't find which one was newer"
	end
end

remove_lock

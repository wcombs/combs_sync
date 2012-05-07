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
# merging -
#	if 2 diff locations have same file edited in diff spots, they are merged togeth sent back out
#	if editing same line(s) one loc gets pushed, but then other loc pulls, notices same file, renames it ORIGNAME.conflicted-fromLOCATION
#
# todo
# check how symlinks are handled, maybe use them for git repos, and track them sep
# make it a daemon, wiht start, restart, etc, and make it read conf file on start
# daemon just fires off syncs every 5,10 mins or so, as defined in conf
# make it wait 5s or so (conf value) and try again a number of times if there is a lock (make a num_retries conf val as well) so techincally could have 4 try at same time and they'd all get their chance
# finish tie in with dock icon, make installation and maint of that aspect simple and easy:

require 'rubygems'
require 'net/ssh'
require 'yaml'
require 'optparse'

OptionParser.new do |o|
  o.on('--config CONFIGFILE') { |filename| $config_file_loc = filename }
  o.on('-h') { puts o; exit }
  o.parse!
end

Config = YAML.load_file($config_file_loc)

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

cmd = "git --git-dir=" + Config["this_repo_gitdir"] + " --work-tree=" + Config["this_repo_worktree"] + " pull"
pull_return = %x[ #{cmd} ]
puts pull_return
puts "done pulling"


cmd = Config["merge_script"] + " " + Config["this_repo_worktree"]
merge_return = %x[ #{cmd} ]
puts merge_return

# add files from merge if there was one
cmd = "git --git-dir=" + Config["this_repo_gitdir"] + " --work-tree=" + Config["this_repo_worktree"] + " add ."
this_add_return = %x[ #{cmd} ]
# commit merge if there was one
cmd = "git --git-dir=" + Config["this_repo_gitdir"] + " --work-tree=" + Config["this_repo_worktree"] + " commit -a -m 'combs_sync merge-fix auto-commit'"
this_commit_return = %x[ #{cmd} ]
puts "done merging"
cmd = "git --git-dir=" + Config["this_repo_gitdir"] + " --work-tree=" + Config["this_repo_worktree"] + " push"
push_return = %x[ #{cmd} ]
puts push_return
puts "done pushing"

remove_lock

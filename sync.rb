#!/usr/bin/ruby
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

require 'yaml'

config = YAML.load_file('syncer.cfg')

#puts config["this_repo_gitdir"]
#exit

# get current rev hashes of this and central
cmd = "git --git-dir=" + config["this_repo_gitdir"] + " log --format=format:%H -n 1"
this_repo_current_commit = %x[ #{cmd} ]
cmd = "git --git-dir=" + config["central_repo_gitdir"] + " log --format=format:%H -n 1"
central_repo_current_commit = %x[ #{cmd} ]
#puts central_repo_current_commit

if this_repo_current_commit == central_repo_current_commit
	puts "up to date, nothing to do here"
	exit
else
	puts "they are diff, checking"
end

# check which one is more up to date
# is central newer?
cmd = "git --git-dir=" + config["central_repo_gitdir"] + " log --format=format:%H -n 1 " + this_repo_current_commit + " 2>/dev/null"
check_central_repo_for_this_commit = %x[ #{cmd} ]

if check_central_repo_for_this_commit == this_repo_current_commit
	puts "looks like central is newer"
elsif
	cmd = "git --git-dir=" + config["this_repo_gitdir"] + " log --format=format:%H -n 1 " + central_repo_current_commit + " 2>/dev/null"
	check_this_repo_for_central_commit = %x[ #{cmd} ]
	if check_this_repo_for_central_commit == central_repo_current_commit
		puts "looks like this is newer"
	else
		puts "something is up, couldn't find which one was newer"
	end
end



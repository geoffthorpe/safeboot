#!/bin/bash

# See applicable comments in run_mgmt.sh, I won't repeat them here.
exec 1> /msgbus/enrollsvc-repl
exec 2>&1

. /hcp/enrollsvc/common.sh

expect_root

TAILWAIT=/hcp/tail_wait.pl

echo "Running 'enrollsvc-repl' service (git-daemon)"

# TODO: consider these choices. E.g. "--verbose"?
# TODO: this crude "daemonize" logic has the standard race-condition, namely
# that we spawn the process but move forward too quickly and something then
# assumes the backgrounded service is ready before it actually is. This could
# probably be fixed by dy doing a tail_wait on our own output to pick up the
# telltale signs from the child process that the service is listening.
(drop_privs_db /usr/lib/git-core/git-daemon \
	--reuseaddr --verbose \
	--listen=0.0.0.0 \
	--base-path=$ENROLLSVC_STATE_PREFIX \
	$REPO_PATH) &
THEPID=$!
disown %
echo "Backgrounded (pid=$THEPID)"

echo "Waiting for 'die' message on /msgbus/enrollsvc-repl-ctrl"
$TAILWAIT /msgbus/enrollsvc-repl-ctrl "die"
echo "Got the 'die' message"
rm /msgbus/enrollsvc-repl-ctrl
kill $THEPID
echo "Killed the git-daemon process"

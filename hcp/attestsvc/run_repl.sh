#!/bin/bash

# See comments in hcp/enrollsvc/run_mgmt.sh for many observations that
# apply here, I won't repeat them.

exec 1> /msgbus/attestsvc-repl
exec 2>&1

. /hcp/common.sh

expect_root

TAILWAIT=/hcp/tail_wait.pl

echo "Running 'attestsvc-repl' service"

(drop_privs_hcp /hcp/updater_loop.sh) &
THEPID=$!
disown %
echo "Backgrounded (pid=$THEPID)"

echo "Waiting for 'die' message on /msgbus/attestsvc-repl-ctrl"
$TAILWAIT /msgbus/attestsvc-repl-ctrl "die"
echo "Got the 'die' message"
rm /msgbus/attestsvc-repl-ctrl
kill $THEPID
echo "Killed the backgrounded task"

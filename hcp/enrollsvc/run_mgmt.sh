#!/bin/bash

# The "msgbus" idea is simply a directory and a couple of assumptions. In it;
# - we redirect our stdout and stderr to a file with the same name as the
#   service (/msgbus/enrollsvc-mgmt), and
# - we will shutdown whenever we see a "die" string written to a file of the
#   same name plus a "-ctrl" suffix (/msgbus/envollsvc-mgmt-ctrl).
# The host can bind-mount whatever is appropriate to that directory path
# (and/or those two file paths).

exec 1> /msgbus/enrollsvc-mgmt
exec 2>&1

. /hcp/common.sh

expect_root

TAILWAIT=/hcp/tail_wait.pl

echo "Running 'enrollsvc-mgmt' service"

# TODO: this crude "daemonize" logic has the standard race-condition, namely
# that we might spawn the process and move forward too quickly, such that
# something assumes our backgrounded service is ready before it actually is.
# This could probably be fixed by dy doing a tail_wait on our own output to
# pick up the telltale signs from the child process that the service is
# genuinely listening and ready.
(drop_privs_flask /hcp/flask_wrapper.sh) &
THEPID=$!
disown %
echo "Backgrounded (pid=$THEPID)"

echo "Waiting for 'die' message on /msgbus/enrollsvc-mgmt-ctrl"
$TAILWAIT /msgbus/enrollsvc-mgmt-ctrl "die"
echo "Got the 'die' message"
rm /msgbus/enrollsvc-mgmt-ctrl
kill $THEPID
echo "Killed the backgrounded task"

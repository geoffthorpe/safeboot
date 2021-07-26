#!/bin/bash

. /hcp/common.sh

MSGBUS_OUT=/msgbus/swtpm
MSGBUS_CTRL=/msgbus/swtpm-ctrl
TPMPORT1=9876
TPMPORT2=9877

# Redirect stdout and stderr to our msgbus file
exec 1> $MSGBUS_OUT
exec 2>&1

echo "Running 'swtpm' service (for $ENROLL_HOSTNAME)"

# Start the software TPM

# TODO: this crude "daemonize" logic has the standard race-condition, namely
# that we might spawn the process and move forward too quickly, such that
# something assumes our backgrounded service is ready before it actually is.
# This could probably be fixed by dy doing a tail_wait on our own output to
# pick up the telltale signs from the child process that the service is
# genuinely listening and ready.
swtpm socket --tpm2 --tpmstate dir=$STATE_PREFIX \
	--server type=tcp,bindaddr=0.0.0.0,port=$TPMPORT1 \
	--ctrl type=tcp,bindaddr=0.0.0.0,port=$TPMPORT2 \
	--flags startup-clear &
TPMPID=$!
disown %
echo "TPM running (pid=$TPMPID)"

# Wait for the command to tear down
echo "Waiting for 'die' message on $MSGBUS_CTRL"
/hcp/tail_wait.pl $MSGBUS_CTRL "die"
echo "Got the 'die' message"
rm $MSGBUS_CTRL

# Kill the software TPM
kill $TPMPID
echo "TPM stopped, done"

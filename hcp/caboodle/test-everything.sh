#!/bin/bash

set -e

# NOTES
#  - the processes started by this test do not get stopped, so attempting to
#    run it a second time will fail.
#    - however, exiting the container will stop them.
#  - the one-time setup in this test is backed onto persistent storage, so
#    restarting the container will not automatically return you to a pristine
#    state.
#    - however "make hcp_clearall" will clear out the persistent storage.

# HCP Enrollment Service.
if [[ ! -d $HCP_ENROLLSVC_STATE_PREFIX/enrolldb.git ]]; then
	/hcp/enrollsvc/setup_enrolldb.sh
fi
/hcp/enrollsvc/run_mgmt.sh &
/hcp/enrollsvc/run_repl.sh &

# We _could_ tail_wait.pt the enrollsvc msgbus outputs to make sure they're
# truly listening before we launch things (like attestsvc) that depend on it.
# But ... nah. Let's just sleep for a second instead.
sleep 1

if [[ ! -d $HCP_ATTESTSVC_STATE_PREFIX/A ]]; then
	/hcp/attestsvc/setup_repl.sh
fi
/hcp/attestsvc/run_repl.sh &
/hcp/attestsvc/run_hcp.sh &

# Same comment;
sleep 1

if [[ ! -f $HCP_SWTPMSVC_STATE_PREFIX/ek.pub ]]; then
	/hcp/swtpmsvc/setup_swtpm.sh
fi
/hcp/swtpmsvc/run_swtpm.sh &

# Same comment;
sleep 1

/hcp/client/run_client.sh


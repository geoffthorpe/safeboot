#!/bin/bash

set -e

# HCP Enrollment Service.
if [[ ! -d $ENROLLSVC_STATE_PREFIX/enrolldb.git ]]; then
	/hcp/enrollsvc/setup_enrolldb.sh
fi
/hcp/enrollsvc/run_mgmt.sh &
/hcp/enrollsvc/run_repl.sh &

if [[ ! -d $ATTESTSVC_STATE_PREFIX/A ]]; then
	/hcp/attestsvc/setup_repl.sh
fi
/hcp/attestsvc/run_repl.sh &
/hcp/attestsvc/run_hcp.sh &

if [[ ! -d $SWTPMSVC_STATE_PREFIX/ek.pub ]]; then
	/hcp/swtpmsvc/setup_swtpm.sh
fi
/hcp/swtpmsvc/run_swtpm.sh &

/hcp/client/run_client.sh

# TODO: the following doesn't work yet because of process control issues. (The wrapper
# scripts get terminated, but some child processes keep running.)
#echo die > /msgbus/enrollsvc-mgmt-ctrl
#echo die > /msgbus/enrollsvc-repl-ctrl
#echo die > /msgbus/attestsvc-repl-ctrl
#echo die > /msgbus/attestsvc-hcp-ctrl
#echo die > /msgbus/swtpmsvc-ctrl

#!/bin/bash

. /hcp/swtpmsvc/common.sh

TPMPORT1=9876
TPMPORT2=9877

# Handle in-place upgrade of the next-oldest version (which is the absence of
# any version tag!).
if [[ ! -f $HCP_SWTPMSVC_STATE_PREFIX/version ]]; then
	/hcp/swtpmsvc/upgrade.sh
fi

# Validate that version is an exact match (obviously we need the same major,
# but right now we expect+tolerate nothing other than the same minor too).
(state_version=`cat $HCP_SWTPMSVC_STATE_PREFIX/version` &&
	[[ $state_version == $HCP_VER ]]) ||
(echo "Error: expected version $HCP_VER, but got '$state_version' instead" &&
	exit 1) || exit 1

echo "Running 'swtpmsvc' service (for $HCP_SWTPMSVC_ENROLL_HOSTNAME)"

# Start the software TPM

swtpm socket --tpm2 --tpmstate dir=$HCP_SWTPMSVC_STATE_PREFIX/tpm \
	--server type=tcp,bindaddr=0.0.0.0,port=$TPMPORT1 \
	--ctrl type=tcp,bindaddr=0.0.0.0,port=$TPMPORT2 \
	--flags startup-clear

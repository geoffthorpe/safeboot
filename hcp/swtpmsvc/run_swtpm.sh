#!/bin/bash

. /hcp/swtpmsvc/common.sh

TPMPORT1=9876
TPMPORT2=9877

echo "Running 'swtpmsvc' service (for $HCP_SWTPMSVC_ENROLL_HOSTNAME)"

# Start the software TPM

swtpm socket --tpm2 --tpmstate dir=$HCP_SWTPMSVC_STATE_PREFIX \
	--server type=tcp,bindaddr=0.0.0.0,port=$TPMPORT1 \
	--ctrl type=tcp,bindaddr=0.0.0.0,port=$TPMPORT2 \
	--flags startup-clear

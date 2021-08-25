#!/bin/bash

. /hcp/swtpmsvc/common.sh

MSGBUS_OUT=/msgbus/swtpmsvc
MSGBUS_CTRL=/msgbus/swtpmsvc-ctrl
TPMPORT1=9876
TPMPORT2=9877

# Redirect stdout and stderr to our msgbus file
exec 1> $MSGBUS_OUT
exec 2>&1

echo "Running 'swtpmsvc' service (for $HCP_SWTPMSVC_ENROLL_HOSTNAME)"

# Start the software TPM

swtpm socket --tpm2 --tpmstate dir=$HCP_SWTPMSVC_STATE_PREFIX \
	--server type=tcp,bindaddr=0.0.0.0,port=$TPMPORT1 \
	--ctrl type=tcp,bindaddr=0.0.0.0,port=$TPMPORT2 \
	--flags startup-clear

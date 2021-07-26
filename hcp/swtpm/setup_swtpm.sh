#!/bin/bash

. /hcp/common.sh

# common.sh takes care of STATE_PREFIX and STATE_HOSTNAME. We also need
# ENROLL_URL when doing the setup.
echo "      ENROLL_URL=$ENROLL_URL" >&2
if [[ -z "$ENROLL_URL" ]]; then
	echo "Error, ENROLL_URL (\"$ENROLL_URL\") is not set" >&2
	exit 1
fi

echo "Setting up a software TPM for $ENROLL_HOSTNAME"

# Initialize a software TPM
swtpm_setup --tpm2 --createek --display --tpmstate $STATE_PREFIX --config /dev/null

# Temporarily start the TPM on an unusual port (and sleep a second to be sure
# it's alive before we hit it). TODO: Better would be to tail_wait the output.
swtpm socket --tpm2 --tpmstate dir=$STATE_PREFIX \
	--server type=tcp,bindaddr=127.0.0.1,port=19283 \
	--ctrl type=tcp,bindaddr=127.0.0.1,port=19284 \
	--flags startup-clear &
echo "Started temporary instance of swtpm"
sleep 1

# Now pressure it into creating the EK (and why doesn't "swtpm_setup
# --createek" already do this?)
export TPM2TOOLS_TCTI=swtpm:host=localhost,port=19283
tpm2 createek -c $STATE_PREFIX/ek.ctx -u $STATE_PREFIX/ek.pub
echo "Software TPM state created;"
tpm2 print -t TPM2B_PUBLIC $STATE_PREFIX/ek.pub

# Now, enroll this TPM/host combination with the enrollment service.  The
# enroll.py script hits the API endpoint specified by $ENROLL_URL, and enrolls
# the TPM EK public key found at $TPM_EKPUB and binds it to the hostname
# specified by $ENROLL_HOSTNAME. (Gotcha: the latter needs to be the host that
# will _attest_ using this (sw)TPM, not the docker container running the swtpm
# itself, which is what $HOSTNAME is set to!) ENROLL_HOSTNAME and ENROLL_URL
# are passed in via the Dockerfile, which leaves TPM_EKPUB.
export TPM_EKPUB=$STATE_PREFIX/ek.pub
echo "Enrolling TPM against hostname '$ENROLL_HOSTNAME'"
python3 /hcp/enroll.py

#!/bin/bash

. /hcp/common.sh

MSGBUS_OUT=/msgbus/$ENROLL_HOSTNAME # <-- passed in from "docker run" cmd-line
MSGBUS_CTRL=/msgbus/$ENROLL_HOSTNAME-ctrl
MSGBUS_SWTPM=/msgbus/swtpm-$ENROLL_HOSTNAME
export TPM2TOOLS_TCTI # <-- passed in from "docker run" cmd-line
export ATTEST_URL     # <-- passed in from "docker run" cmd-line

# Redirect stdout and stderr to our msgbus file
exec 1> $MSGBUS_OUT
exec 2>&1

echo "Running 'client' container as $ENROLL_HOSTNAME"

# Check that our TPM is configured and alive
tpm2_pcrread

# Now keep trying to get a successful attestation. It may take a few seconds
# for our TPM enrollment to propagate to the attestation server, so it's normal
# for this to fail a couple of times before succeeding.
counter=0
while true
do
	echo "Trying an attestation..."
	unset itfailed
	./sbin/tpm2-attest attest $ATTEST_URL > secrets || itfailed=1
	if [[ -z "$itfailed" ]]; then
		echo "Success!"
		break
	fi
	((counter++)) || true
	echo "Failure #$counter"
	if [[ $counter -gt 10 ]]; then
		echo "Giving up"
		exit 1
	fi
	echo "Sleeping 5 seconds before retrying"
	sleep 5
done

echo "Extracting the attestation output;"
tar xvf secrets || (echo "Hmmm, tar reports some kind of error." &&
	echo "Copying to safeboot/sbin for inspection" &&
	cp secrets ./sbin)

echo "Client ($ENROLL_HOSTNAME) ending"

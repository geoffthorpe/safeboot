#!/bin/bash

set -e

# Print the base configuration
echo "Running '$0'" >&2
echo " ENROLL_HOSTNAME=$ENROLL_HOSTNAME" >&2
echo "      ATTEST_URL=$ATTEST_URL" >&2
echo "  TPM2TOOLS_TCTI=$TPM2TOOLS_TCTI" >&2
echo "          MSGBUS=$MSGBUS" >&2
echo "   MSGBUS_PREFIX=$MSGBUS_PREFIX" >&2

if [[ -z "$ENROLL_HOSTNAME" ]]; then
	echo "Error, ENROLL_HOSTNAME (\"$ENROLL_HOSTNAME\") is not set" >&2
	exit 1
fi
if [[ -z "$ATTEST_URL" ]]; then
	echo "Error, ATTEST_URL (\"$ATTEST_URL\") is not set" >&2
	exit 1
fi
if [[ -z "$TPM2TOOLS_TCTI" ]]; then
	echo "Error, TPM2TOOLS_TCTI (\"$TPM2TOOLS_TCTI\") is not set" >&2
	exit 1
fi
if [[ -z "$MSGBUS" ]]; then
	echo "Error, MSGBUS (\"$MSGBUS\") is not set" >&2
	exit 1
fi
if [[ -z "$MSGBUS_PREFIX" || ! -d "$MSGBUS_PREFIX" ]]; then
	echo "Error, MSGBUS_PREFIX (\"$MSGBUS_PREFIX\") is not a valid path" >&2
	exit 1
fi

if [[ ! -d /safeboot/sbin ]]; then
	echo "Error, Safeboot scripts aren't installed" >&2
	exit 1
fi
export PATH=/safeboot/sbin:$PATH

cd /safeboot

# passed in from "docker run" cmd-line
export ENROLL_HOSTNAME
export TPM2TOOLS_TCTI
export ATTEST_URL

echo "Running 'client' container as $ENROLL_HOSTNAME"

# Check that our TPM is configured and alive
tpm2_pcrread > $MSGBUS_PREFIX/pcrread 2>&1
echo "tpm2_pcrread results at $MSGBUS/pcrread"

# Now keep trying to get a successful attestation. It may take a few seconds
# for our TPM enrollment to propagate to the attestation server, so it's normal
# for this to fail a couple of times before succeeding.
counter=0
while true
do
	echo "Trying an attestation, output at $MSGBUS/attestation.$counter"
	unset itfailed
	./sbin/tpm2-attest attest $ATTEST_URL > secrets \
		2> $MSGBUS_PREFIX/attestation.$counter || itfailed=1
	if [[ -z "$itfailed" ]]; then
		echo "Success!"
		break
	fi
	((counter++)) || true
	echo "Failure #$counter"
	if [[ $counter -gt 4 ]]; then
		echo "Giving up"
		exit 1
	fi
	echo "Sleeping 5 seconds before retrying"
	sleep 5
done

echo "Extracting the attestation result, output at $MSGBUS/extraction;"
tar xvf secrets > $MSGBUS_PREFIX/extraction 2>&1 || \
	(echo "Error of some kind." && \
	echo "Copying 'secrets' to $MSGBUS/ for inspection" && \
	cp secrets $MSGBUS_PREFIX/ && exit 1)

echo "Client ($ENROLL_HOSTNAME) ending"

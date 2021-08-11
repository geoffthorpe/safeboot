#!/bin/bash

set -e

# Print the base configuration
echo "Running '$0'" >&2
echo "      CLIENT_ATTEST_URL=$CLIENT_ATTEST_URL" >&2
echo "         TPM2TOOLS_TCTI=$TPM2TOOLS_TCTI" >&2
echo "                 MSGBUS=$MSGBUS" >&2
echo "          MSGBUS_PREFIX=$MSGBUS_PREFIX" >&2

if [[ -z "$CLIENT_ATTEST_URL" ]]; then
	echo "Error, CLIENT_ATTEST_URL (\"$CLIENT_ATTEST_URL\") is not set" >&2
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
echo "Adding /safeboot/sbin to PATH" >&2

if [[ -d "/install/bin" ]]; then
	export PATH=$PATH:/install/bin
	echo "Adding /install/sbin to PATH" >&2
fi

if [[ -d "/install/lib" ]]; then
	export LD_LIBRARY_PATH=/install/lib:$LD_LIBRARY_PATH
	echo "Adding /install/lib to LD_LIBRARY_PATH" >&2
	if [[ -d /install/lib/python3/dist-packages ]]; then
		export PYTHONPATH=/install/lib/python3/dist-packages:$PYTHONPATH
		echo "Adding /install/lib/python3/dist-packages to PYTHONPATH" >&2
	fi
fi

# The following helps to convince the safeboot scripts to find safeboot.conf
# and functions.sh
export DIR=/safeboot
cd $DIR

# passed in from "docker run" cmd-line
export TPM2TOOLS_TCTI
export CLIENT_ATTEST_URL

echo "Running 'client'"

# TODO: this is a temporary and bad fix. The swtpm assumes that connections
# that are set up (tpm2_startup) but not gracefully terminated (tpm2_shutdown)
# are suspicious, and if it happens enough (3 or 4 times, it seems) the TPM
# locks itself to protect against possible dictionary attack. However Our
# client is calling a high-level util ("tpm2-attest attest"), so it is not
# clear where tpm2_startup is happening, and it is even less clear where to add
# a matching tpm2_shutdown. Instead, we rely on the swtpm having non-zero
# tolerance to preceed each run of the client (after it has already failed at
# least once to tpm2_shutdown), and on there being no dictionary policy in
# place to prevent us from simply resetting the suspicion counter!! On proper
# TPMs (e.g. GCE vTPM), this dictionarylockout call will actually fail so has
# to be commented out.
tpm2_dictionarylockout --clear-lockout

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
	./sbin/tpm2-attest attest $CLIENT_ATTEST_URL > secrets \
		2> $MSGBUS_PREFIX/attestation.$counter || itfailed=1
	if [[ -z "$itfailed" ]]; then
		echo "Success!"
		break
	fi
	((counter++)) || true
	echo "Failure #$counter (we expect a couple of these before success)"
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

echo "Client ending"

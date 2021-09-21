#!/bin/bash

. /hcp/attestsvc/common.sh

expect_root

# Detect in-place upgrade of the next-oldest version (which is the absence of
# any version tag!). The upgrade is done by attestsvc-repl, so we just spin
# waiting for it to happen.
while [[ ! -f $HCP_ATTESTSVC_STATE_PREFIX/version ]]; do
	echo "Warning: stalling 'attestsvc-hcp' until in-place upgrade!" >&2
	sleep 30
done

# Validate that version is an exact match (obviously we need the same major,
# but right now we expect+tolerate nothing other than the same minor too).
(state_version=`cat $HCP_ATTESTSVC_STATE_PREFIX/version` &&
	[[ $state_version == $HCP_VER ]]) ||
(echo "Error: expected version $HCP_VER, but got '$state_version' instead" &&
	exit 1) || exit 1

echo "Running 'attestsvc-hcp' service"

drop_privs_hcp /hcp/attestsvc/wrapper-attest-server.sh

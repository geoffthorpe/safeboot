#!/bin/bash

. /hcp/attestsvc/common.sh

expect_root

# Handle in-place upgrade of the next-oldest version (which is the absence of
# any version tag!).
if [[ ! -f $HCP_ATTESTSVC_STATE_PREFIX/version ]]; then
	drop_privs_hcp /hcp/attestsvc/upgrade.sh
fi

# Validate that version is an exact match (obviously we need the same major,
# but right now we expect+tolerate nothing other than the same minor too).
(state_version=`cat $HCP_ATTESTSVC_STATE_PREFIX/version` &&
	[[ $state_version == $HCP_VER ]]) ||
(echo "Error: expected version $HCP_VER, but got '$state_version' instead" &&
	exit 1) || exit 1

echo "Running 'attestsvc-repl' service"

drop_privs_hcp /hcp/attestsvc/updater_loop.sh

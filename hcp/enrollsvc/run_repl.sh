#!/bin/bash

# See applicable comments in run_mgmt.sh, I won't repeat them here.
exec 1> /msgbus/enrollsvc-repl
exec 2>&1

. /hcp/enrollsvc/common.sh

expect_root

echo "Running 'enrollsvc-repl' service (git-daemon)"

# TODO: consider these choices. E.g. "--verbose"?
drop_privs_db /usr/lib/git-core/git-daemon \
	--reuseaddr --verbose \
	--listen=0.0.0.0 \
	--base-path=$HCP_ENROLLSVC_STATE_PREFIX \
	$REPO_PATH

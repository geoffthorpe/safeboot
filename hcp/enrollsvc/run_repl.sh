#!/bin/bash

. /hcp/enrollsvc/common.sh

expect_root

echo "Running 'enrollsvc-repl' service (git-daemon)"

# TODO: consider these choices. E.g. "--verbose"?
drop_privs_db /usr/lib/git-core/git-daemon \
	--reuseaddr --verbose \
	--listen=0.0.0.0 \
	--base-path=$HCP_ENROLLSVC_STATE_PREFIX \
	$REPO_PATH

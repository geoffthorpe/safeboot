#!/bin/bash

. /hcp/attestsvc/common.sh

expect_hcp_user

cd $HCP_ATTESTSVC_STATE_PREFIX

if [[ -f version ]]; then
	echo "Error, upgrade.sh called when it shouldn't have been" >&2
	exit 1
fi

(cd A && git remote add twin ../B && git fetch twin) ||
	 (echo "Error, in-place upgrade of 'A' failed" >&2 && exit 1) ||
	 exit 1

(cd B && git remote add twin ../A && git fetch twin) ||
	 (echo "Error, in-place upgrade of 'B' failed" >&2 && exit 1) ||
	 exit 1

echo "1:1" > version

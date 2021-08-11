#!/bin/bash

. /hcp/attestsvc/common.sh

expect_hcp_user

cd $ATTESTSVC_STATE_PREFIX

if [[ -d A || -d B || -h current || -h next || -h thirdwheel ]]; then
	echo "Error, updater state half-baked?"
	exit 1
fi

echo "First-time initialization of $ATTESTSVC_STATE_PREFIX. Two clones and two symlinks."
git clone $ATTESTSVC_REMOTE_REPO A
git clone $ATTESTSVC_REMOTE_REPO B
ln -s A current
ln -s B next

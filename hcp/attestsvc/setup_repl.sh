#!/bin/bash

. /hcp/attestsvc/common.sh

expect_root

# This is the one-time init hook, so make sure the mounted dir has appropriate ownership
chown $HCP_USER:$HCP_USER $HCP_ATTESTSVC_STATE_PREFIX

drop_privs_hcp /hcp/attestsvc/init_clones.sh

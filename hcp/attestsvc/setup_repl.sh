#!/bin/bash

. /hcp/common.sh

expect_root

# This is the one-time init hook, so make sure the mounted dir has appropriate ownership
chown $HCP_USER:$HCP_USER $STATE_PREFIX

drop_privs_hcp /hcp/init_clones.sh

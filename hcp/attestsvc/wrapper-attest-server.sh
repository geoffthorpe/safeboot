#!/bin/bash

. /hcp/attestsvc/common.sh

expect_hcp_user

# The following helps to convince the safeboot scripts to find safeboot.conf
# and functions.sh
export DIR=/safeboot
cd $DIR

# Steer attest-server (and attest-verify) towards our source of truth
export SAFEBOOT_DB_DIR="$ATTESTSVC_STATE_PREFIX/current"

attest-server 8080

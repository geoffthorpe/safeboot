#!/bin/bash

. /hcp/common.sh

expect_hcp_user

# It is only here (in the -hcp half of the attestsvc, inside the drop-priv'd
# script that starts safeboot-sbin/attest-server) that we need the safeboot
# stuff. So we extend the PATH here (rather than in common.sh, say) to include
# the safeboot executables, and we cd to /safeboot so that they can find
# "safeboot.conf" and "functions.sh".
export PATH=$PATH:/safeboot/sbin
cd /safeboot

# Steer attest-server (and attest-verify) towards our source of truth
export SAFEBOOT_DB_DIR="$STATE_PREFIX/current"

attest-server 8080

#!/bin/bash

# See comments in hcp/enrollsvc/run_mgmt.sh for many observations that
# apply here, I won't repeat them.

exec 1> /msgbus/attestsvc-hcp
exec 2>&1

. /hcp/attestsvc/common.sh

expect_root

echo "Running 'attestsvc-hcp' service"

drop_privs_hcp /hcp/attestsvc/wrapper-attest-server.sh

#!/bin/bash

. /hcp/attestsvc/common.sh

expect_root

echo "Running 'attestsvc-hcp' service"

drop_privs_hcp /hcp/attestsvc/wrapper-attest-server.sh

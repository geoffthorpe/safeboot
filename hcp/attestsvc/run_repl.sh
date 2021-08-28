#!/bin/bash

. /hcp/attestsvc/common.sh

expect_root

echo "Running 'attestsvc-repl' service"

drop_privs_hcp /hcp/attestsvc/updater_loop.sh

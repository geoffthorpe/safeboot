#!/bin/bash

. /hcp/enrollsvc/common.sh

expect_root

echo "Running 'enrollsvc-mgmt' service"

drop_privs_flask /hcp/enrollsvc/flask_wrapper.sh

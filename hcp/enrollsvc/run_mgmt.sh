#!/bin/bash

# The "msgbus" idea is simply a directory and some assumptions. In it we
# redirect our stdout and stderr to a file with the same name as the service
# (/msgbus/enrollsvc-mgmt). The host can bind-mount whatever is appropriate to
# that directory path (and/or that file path).

exec 1> /msgbus/enrollsvc-mgmt
exec 2>&1

. /hcp/enrollsvc/common.sh

expect_root

echo "Running 'enrollsvc-mgmt' service"

drop_privs_flask /hcp/enrollsvc/flask_wrapper.sh

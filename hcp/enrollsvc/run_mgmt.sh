#!/bin/bash

. /hcp/enrollsvc/common.sh

expect_root

echo "Chowning asset-signing keys for use by db_user"

chown db_user:db_user $SIGNING_KEY_PRIV $SIGNING_KEY_PUB

echo "Running 'enrollsvc-mgmt' service"

drop_privs_flask /hcp/enrollsvc/flask_wrapper.sh

#!/bin/bash

export DB_IN_SETUP=1

. /hcp/common.sh

expect_root

# This is the one-time init hook, so make sure the mounted dir has appropriate ownership
chown $DB_USER:$DB_USER $STATE_PREFIX

drop_privs_db /hcp/init_repo.sh

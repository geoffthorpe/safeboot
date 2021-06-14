#!/bin/bash

export DB_IN_SETUP=1

. /common.sh

expect_root

# This is the one-time init hook, so make sure the mounted dir has appropriate ownership
chown $DB_USER:$DB_USER $DB_PREFIX

drop_privs_db /init_repo.sh

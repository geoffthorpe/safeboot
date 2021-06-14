#!/bin/bash

. /common.sh

expect_root

# This is the one-time init hook, so make sure the mounted dir has appropriate ownership
chown $USERNAME:$USERNAME $STATE_PREFIX

drop_privs /init_clones.sh

#!/bin/bash

set -e

exec 1> /msgbus/git
exec 2>&1

TAILWAIT=/safeboot/tail_wait.pl

echo "Running x509 service"

. /app/lib/mgmt.sh

respawn() {
    while true; do
        test -f /var/run/start.pause || $@
        sleep 1
    done
}

server-ctl() {
    rm -f /var/run/ctl.sock
    socat UNIX-LISTEN:/var/run/ctl.sock,fork,user=lighttpd,group=lighttpd \
          SYSTEM:/app/bin/ctl.sh
}

respawn /usr/sbin/lighttpd -D -f /opt/ca/etc/lighttpd.conf &
PIDA=$!
disown %
echo "Launched lightttpd (pid=$PIDA)"

respawn server-ctl &
PIDB=$!
disown %
echo "Launched socat (pid=$PIDB)"

echo "Waiting for 'die' message on /msgbus/x509-ctrl"
$TAILWAIT /msgbus/x509-ctrl "die"
echo "Got the 'die' message"
rm -f /msgbus/x509-ctrl
kill $PIDA
kill $PIDB
echo "Killed the backgrounded tasks"

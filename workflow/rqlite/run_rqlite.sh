#!/bin/bash

# Launch rqlited with the appropriate args
#
# For list of options, I found nothing better than;
# https://github.com/rqlite/rqlite/blob/master/cmd/rqlited/main.go

set -e

# Obligatory
[[ -v NODE_ID ]] || (echo "Error, must set NODE_ID" && exit 1)
exec 1> /msgbus/$NODE_ID
exec 2>&1
IDX=`echo $NODE_ID | sed -e "s/^.*node-//"`
NODE_PORT=4001
echo "GTDBG: NODE_ID=$NODE_ID -> IDX=$IDX"
echo "GTDBG: NODE_PORT=$NODE_PORT"
[[ $MODE == 'rw' ]] || [[ $MODE == 'ro' ]] || (echo "Error, MODE must be 'rw' or 'ro'" && exit 1)
[[ $MODE == 'rw' ]] && export RAFT_NON_VOTER= || /bin/true
[[ $MODE == 'ro' ]] && export RAFT_NON_VOTER=-raft-non-voter || /bin/true

# There's a race condition we'd like to avoid: if there is no cluster and then
# multiple 'rw' nodes start in parallel, they could theoretically all look in
# /msgbus/leaders at the same time, before any of them have put themselves in
# there for the others to find. In that case, they'd all start up without any
# "-join" arguments to build a consensus network. This condition is known as
# "split-brain". The fix is for each node to put itself inside /msgbus/leaders
# _before_ looking to see who else is in there. This guarantees that, in a
# startup race between two new leaders, at least one of them will see the
# other. In fact, they may both see each other, so that each starts up with a
# -join argument pointing to the other, and yet neither is able to find the
# other on the first attempt, but _that_ race is harmless given the retry
# behavior.
#
# So, we're left with a "complementary" race-condition at the other end of the
# life-cycle. If the cluster is about to end because the last leader is
# leaving, and this races against a new leader starting up, then the new leader
# might see the last leader and thinks there's a consensus network to join, but
# it's gone before it could connect. (So it can't learn "you're on your own
# now" as the leader exits.) This is very hard to fix, but fortunately it's
# quite easy to live with. The consequence in this race condition is that the
# new leader will timeout after a few retries of its "-join" argument (i.e.
# failing to join the cluster that disappeared as it was joining) and then exit
# with failure. Upshot: starting a rw node may fail if it races against the
# last remaining rw node exiting. Unless you hit this case, nodes can
# dynamically enter and exit the cluster, including when it oscillates between
# empty and non-empty. It is better to have a failure-to-start, which can only
# happen if you have a dynamic cluster size that flirts with zero, than to
# allow a split-brain condition to arise that gets treated as "success".
mkdir -p /msgbus/leaders
if [[ $MODE == 'rw' ]]; then
	touch /msgbus/leaders/$NODE_ID:$NODE_PORT
	echo "Added the leader registration"
fi
LEADERS=`cd /msgbus/leaders/ && ls`
echo "GTDBG: LEADERS=$LEADERS"
if [[ -v LEADERS ]]; then
	for i in $LEADERS; do
		# Strip the port number off
		j=`echo $i | sed -e "s/:[0-9]*//"`
		echo "GTDBG: i=$i,j=$j"
		# We don't join ourself
		[[ $j == $NODE_ID ]] && continue
		# If this isn't the first node, comma-separate
		[[ -v JOIN_ADDR ]] && JOIN_ADDR="$JOIN_ADDR,"
		JOIN_ADDR="$JOIN_ADDR$i"
	done
fi
[[ -v JOIN_ADDR ]] && JOIN_ADDR="-join $JOIN_ADDR"
export JOIN_ADDR

# Options
[[ -v HTTP_ADDR ]] || export HTTP_ADDR=0.0.0.0:4001
[[ -v HTTP_ADV_ADDR ]] || \
	( [[ -v HTTP_ADV_PORT ]] && export HTTP_ADV_ADDR=$NODE_ID:$HTTP_ADV_PORT) || \
	(echo "Error, must set HTTP_ADV_ADDR or HTTP_ADV_PORT" && exit 1)
[[ -v RAFT_ADDR ]] || export RAFT_ADDR=0.0.0.0:4002
[[ -v RAFT_ADV_ADDR ]] || \
	( [[ -v RAFT_ADV_PORT ]] && export RAFT_ADV_ADDR=$NODE_ID:$RAFT_ADV_PORT) || \
	(echo "Error, must set RAFT_ADV_ADDR or RAFT_ADV_PORT" && exit 1)
[[ -v RQLITE_FILE_PATH ]] || export RQLITE_FILE_PATH=/rqlite/file/data

# Launch
echo "Launching rqlited with parameters;"
echo "  NODE_ID=$NODE_ID"
echo "  HTTP_ADDR=$HTTP_ADDR"
echo "  RAFT_ADDR=$RAFT_ADDR"
echo "  JOIN_ADDR=$JOIN_ADDR"
echo "  RAFT_NON_VOTER=$RAFT_NON_VOTER (from MODE=$MODE)"
echo "  RQLITE_FILE_PATH=$RQLITE_FILE_PATH"
echo "  rqlited -node-id $NODE_ID \\"
echo "	    -http-addr \"$HTTP_ADDR\" -raft-addr \"$RAFT_ADDR\" \\"
echo "	    $JOIN_ADDR $RAFT_NON_VOTER \\"
echo "	    -on-disk \\"
echo "	    $RQLITE_FILE_PATH"

rqlited -node-id $NODE_ID \
	-http-addr "$HTTP_ADDR" -raft-addr "$RAFT_ADDR" \
	$JOIN_ADDR $RAFT_NON_VOTER \
	-on-disk \
	$RQLITE_FILE_PATH &
RQPID=$!
disown %
echo "rqlited running (pid=$RQPID)"

echo "Waiting for stop command"
/safeboot/tail_wait.pl /msgbus/stop-$NODE_ID "stop"
echo "Got stop command!"

kill $RQPID
echo "Killed the rqlited process"

rm /msgbus/stop-$NODE_ID
echo "Removed the 'stopfile'"
if [[ $MODE == 'rw' ]]; then
	rm /msgbus/leaders/$NODE_ID:$NODE_PORT
	echo "Removed the leader registration"
fi
echo "Done"

#!/bin/bash

# This script checks out a given branch/tag/commit, builds the images, and tags
# them with a given prefix and suffix before cleaning up.
#
# IT WILL CHANGE THE WORKING TREE BY SWITCHING TO DIFFERENT GIT COMMITS!!!
#
# You have been warned.
#
# Parameters;
#
# $1 = the git branch/tag/commit/hash to be built.
#
# $2 = the prefix for tagging the resulting images.
#
# $3 = the suffix for tagging the resulting images.
#
# The working directory will be left in whatever state this test gets to when
# it exits, successfully or otherwise. It does not make any attempt to save and
# restore the state before the script was invoked.

set -e

[[ -n $1 ]] && [[ -n $2 ]] && [[ -n $3 ]] ||
	(echo "Error, missing arguments" && echo "" &&
	echo "Usage:    create-images.sh <refspec> <image-prefix> <image-suffix>" &&
	exit 1) || exit 1
git describe $1 || (echo "Error, '$1' is not a valid refspec" && exit 1) || exit 1

# Pick new output directories for build artifacts
export HCP_OUT=`mktemp -d`
# Similarly, pick a new prefix for the images/networks. The while loop is
# copied from hcp/ci-script.sh
while /bin/true; do
	TMPFILE=`mktemp -t tupgrade_XXXX_`
	SAFEBOOT_HCP_DSPACE=`basename $TMPFILE`
	echo $SAFEBOOT_HCP_DSPACE | egrep "[A-Z]" > /dev/null 2>&1 || break
	rm $TMPFILE
done
export SAFEBOOT_HCP_DSPACE
export SAFEBOOT_HCP_DTAG=temp

function cleanup_trap()
{
	echo "On-exit dump of settings;"
	echo "HCP_OUT=$HCP_OUT"
	echo "SAFEBOOT_HCP_DSPACE=$HCP_OUT"
	echo "SAFEBOOT_HCP_DTAG=$HCP_OUT"
}
trap cleanup_trap EXIT

# $1 == new prefix
# $2 == new suffix
# $3 == image name
function do_tagging_item()
{
	docker tag $SAFEBOOT_HCP_DSPACE$3:$SAFEBOOT_HCP_DTAG $1$3:$2
}
# $1 & $2 only
function do_tagging()
{
	do_tagging_item $1 $2 enrollsvc
	do_tagging_item $1 $2 attestsvc
	do_tagging_item $1 $2 swtpmsvc
	do_tagging_item $1 $2 client
	do_tagging_item $1 $2 caboodle
}

git checkout $1
git submodule update --init

make hcp_buildall ||
	(echo "Failed, dumping output" && cat $TMPFILE && exit 1) ||
	exit 1

do_tagging $2 $3

make clean_hcp ||
	(echo "Failed, dumping output" && cat $TMPFILE && exit 1) ||
	exit 1

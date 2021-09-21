#!/bin/bash

# This script is provided to test the ability of upgrade HCP services to
# perform in-place upgrades of global state (that was initialized and
# maintained by older software).
#
# It assumes that the before and after images have already been built, and are
# available in the docker repository. (If this isn't the case,
# hcp/create-images.sh is your friend.)
#
# The script uses the "direct" workflow, by running "make -f hcp/run/Makefile"
# and setting the relevant environment variables ahead of time. In this way,
# there are no dependencies declared between the service operations
# (initializing state, start and stopping, etc) and any build rules.
#
# Parameters;
#
# $1 and $2 = the prefix and suffix for the "before" container images. These
#      will be used to perform initialization of one-time state, as well as
#      starting and running the services and performing the standard self-test.
#
# $3 and $4 = the prefix and suffix for the "after" container images. These
#      will be started on top of the state left over from when the "before"
#      images were running. I.e. this emulates an "upgrade".
#
# $5, $6, ... = optional. If any further arguments are supplied, they will be
#      treated as a shell command to be executed while the "before" images are
#      running (prior to upgrade) and once the "after" images are running
#      (after the upgrade). I.e. this allows you to execute some test cases or
#      other steps to produce and process non-trivial service state prior to
#      the "upgrade". Note, if you want this command to be able to run other
#      make targets (using the same Makefile, environment, etc), use "\$MYMAKE"
#      (with an escaped '$').
#
# Set HCP_NOCLEAN=1 if you don't want the script to clean up after itself. (If
# the test fails, it won't perform any cleanup in any case.)
#
# Set HCP_MAKECMD="<makeprogram> -f <makefilepath>" to override the default
# assumption of "make -f `pwd`/hcp/run/Makefile".
#
# Set HCP_UTIL_IMAGE=<containerimage> to override the default assumption of
# "debian:bullseye-slim".
#
# Set HCP_ASSIST_CLEANUP=<path-to-assist_cleanup.sh> to override the default
# assumption of `pwd`/hcp/assist_cleanup.sh
#
# Set HCP_SERVICES to override the default assumption of "enroll attest swtpm"

set -e

function usage()
{
	echo "Usage:    upgrade-test.sh <prefix1> <suffix1> <prefix2> <suffix2> [shell command ...]"
	echo ""
	echo "- prefix1/suffix1 are used to identify initialization/pre-upgrade images to run."
	echo "- prefix2/suffix2 are used to identify post-upgrade images to run."
	echo "- the optional shell command is run on the pre-upgraded services and state in order"
	echo "  to exercise the services and/or evolve the state before it passes through the"
	echo "  in-place upgrade process."
	echo "  - if no shell command is provided, the default is;"
	echo "       \\\$MYMAKE client_start"
	echo "  - to avoid having the default run, provide something harmless, like;"
	echo "       /bin/true"
	echo ""
	echo "Note that upgrade-test.sh consumes and defines many environment variables. Of"
	echo "particular note is 'MYMAKE', which is a command preamble to invoke make and specify"
	echo "the Makefile - e.g. 'make -f \`pwd\`/hcp/run/Makefile'. The environment variables"
	echo "within upgrade-test.sh can be used within the given shell command by escaping all"
	echo "references to them. See the default shell command (above), for example."
	echo ""
	echo "If the test passes, all services will be stopped and all state will be cleaned up."
	echo "If the test fails, any running services will remain running and no state is cleaned"
	echo "up. Instead, a sourceable script will be created, containing a dump of environment"
	echo "variables allowing the user to manually interact with the service instances and"
	echo "their state."
	echo "E.g; '\$MYMAKE <stopall|startall|initall|cleanall|enter|...>"
	echo ""
}

# Ensure we have arguments
[[ -n $1 ]] && [[ -n $2 ]] && [[ -n $3 ]] || [[ -n $4 ]] ||
	(echo "Error, missing arguments" && echo "" && usage && exit 1) || exit 1

prefix1=$1
suffix1=$2
prefix2=$3
suffix2=$4

shift 4

usercmd=$@
if [[ $# < 1 ]]; then
	usercmd="\$MYMAKE client_start"
fi

# Check that our prefix/suffix pairs correspond to images we can run
function check_image_item()
{
	docker image inspect $1$3:$2 > /dev/null
}
function check_images()
{
	check_image_item $1 $2 enrollsvc
	check_image_item $1 $2 attestsvc
	check_image_item $1 $2 swtpmsvc
	check_image_item $1 $2 client
	check_image_item $1 $2 caboodle
}
check_images $prefix1 $suffix1 || (echo "Error, prefix1/suffix1 aren't usable" && usage && exit 1) || exit 1
check_images $prefix2 $suffix2 || (echo "Error, prefix2/suffix2 aren't usable" && usage && exit 1) || exit 1

# This is how we run make. Override by setting HCP_MAKECMD
export MYMAKE=${HCP_MAKECMD:-make -f `pwd`/hcp/run/Makefile}

# Cleanup routines need an image they can count on.
export HCP_RUN_UTIL_IMAGE=${HCP_UTIL_IMAGE:-debian:bullseye-slim}

# And we need a script to provide such cleanup routines.
export HCP_RUN_ASSIST_CLEANUP=${HCP_ASSIST_CLEANUP:-`pwd`/hcp/assist_cleanup.sh}

# Choose a temporary directory for all our instance state
export HCP_RUN_TOP=`mktemp -d`

# We use all the services for the upgrade test
export HCP_RUN_SERVICES=${HCP_SERVICES:-enroll attest swtpm}

# Choose a temporary docker network for the testing to occur on
while /bin/true; do
	TMPFILE=`mktemp -t tupgrade_XXXX`
	export HCP_RUN_DNETWORKS=`basename $TMPFILE`
	echo $HCP_RUN_DNETWORKS | egrep "[A-Z]" > /dev/null 2>&1 || break
	rm $TMPFILE
done

# The services will run entirely within a private docker network, we want to
# suppress the default behavior of publishing service ports on host interfaces
# (likely to conflict in many development situations).
HARMLESSP=--env=HARMLESSP=harmlessp
export HCP_RUN_ENROLL_XTRA_MGMT=$HARMLESSP
export HCP_RUN_ENROLL_XTRA_REPL=$HARMLESSP
export HCP_RUN_ATTEST_XTRA_REPL=$HARMLESSP
export HCP_RUN_ATTEST_XTRA_HCP=$HARMLESSP
export HCP_RUN_SWTPM_XTRA=$HARMLESSP

# Settings required by the services
export HCP_RUN_ENROLL_SIGNER_AUTOCREATE=yes
export HCP_RUN_ATTEST_REMOTE_REPO=git://enrollsvc_repl/enrolldb
export HCP_RUN_ATTEST_UPDATE_TIMER=1
export HCP_RUN_SWTPM_ENROLL_HOSTNAME=example_host.wherever.xyz
export HCP_RUN_SWTPM_ENROLL_URL=http://enrollsvc_mgmt:5000/v1/add
export HCP_RUN_CLIENT_TPM2TOOLS_TCTI=swtpm:host=swtpmsvc,port=9876
export HCP_RUN_CLIENT_ATTEST_URL=http://attestsvc_hcp:8080

export V=1

# Unless everything goes perfectly, we're going to want to preserve all these
# settings so that the developer/operator can investigate, clean up, etc. Dump
# everything to a sourceable script, using the network name (plus a ".sh"
# suffix) as the name.
cat >> $HCP_RUN_DNETWORKS.sh <<EOF
echo "- Running a subshell with all the environment settings for the current"
echo "  instances. Exit from here to return to where you were."
echo "- Call 'use_before' or 'use_after' to set HCP_RUN_DSPACE/HCP_RUN_DTAG!"
echo "- 'make' is now aliased to use the right Makefile."
[[ -f ~/.bashrc ]] && source ~/.bashrc
export MYMAKE="$MYMAKE"
export HCP_RUN_SERVICES="$HCP_RUN_SERVICES"
export HCP_RUN_TOP="$HCP_RUN_TOP"
export HCP_RUN_DNETWORKS="$HCP_RUN_DNETWORKS"
export HCP_RUN_UTIL_IMAGE="$HCP_RUN_UTIL_IMAGE"
export HCP_RUN_ASSIST_CLEANUP="$HCP_RUN_ASSIST_CLEANUP"
HARMLESSP="--env=HARMLESSP=harmlessp"
export HCP_RUN_ENROLL_XTRA_MGMT="$HARMLESSP"
export HCP_RUN_ENROLL_XTRA_REPL="$HARMLESSP"
export HCP_RUN_ATTEST_XTRA_REPL="$HARMLESSP"
export HCP_RUN_ATTEST_XTRA_HCP="$HARMLESSP"
export HCP_RUN_SWTPM_XTRA="$HARMLESSP"
export HCP_RUN_ENROLL_SIGNER_AUTOCREATE="$HCP_RUN_ENROLL_SIGNER_AUTOCREATE"
export HCP_RUN_ATTEST_REMOTE_REPO="$HCP_RUN_ATTEST_REMOTE_REPO"
export HCP_RUN_ATTEST_UPDATE_TIMER="$HCP_RUN_ATTEST_UPDATE_TIMER"
export HCP_RUN_SWTPM_ENROLL_HOSTNAME="$HCP_RUN_SWTPM_ENROLL_HOSTNAME"
export HCP_RUN_SWTPM_ENROLL_URL="$HCP_RUN_SWTPM_ENROLL_URL"
export HCP_RUN_CLIENT_TPM2TOOLS_TCTI="$HCP_RUN_CLIENT_TPM2TOOLS_TCTI"
export HCP_RUN_CLIENT_ATTEST_URL="$HCP_RUN_CLIENT_ATTEST_URL"
export prefix1="$prefix1"
export suffix1="$suffix1"
export prefix2="$prefix2"
export suffix2="$suffix2"
export usercmd="$usercmd"
alias use_before='export HCP_RUN_DSPACE=$prefix1 && export HCP_RUN_DTAG=$suffix1'
alias use_after='export HCP_RUN_DSPACE=$prefix2 && export HCP_RUN_DTAG=$suffix2'
alias make='$MYMAKE'
EOF

# Whatever causes us to exit, good or bad, dump this info on the way out
unset itfailed
function cleanup_trap()
{
	set +e
	if [[ -n $itfailed ]]; then
		echo "Failure: $itfailed"
		echo ""
		echo "To investigate, start a (sub)shell as follows;"
		echo "  bash --rcfile $HCP_RUN_DNETWORKS.sh -i"

	else
		echo "Stopping services and cleaning their state"
		$MYMAKE stopall
		$MYMAKE cleanall
		echo "Removing docker network"
		docker network inspect $HCP_RUN_DNETWORKS > /dev/null 2>&1 &&
			docker network rm $HCP_RUN_DNETWORKS > /dev/null 2>&1
		echo "Removing mgmt state"
		$MYMAKE clean_hcp_run
		echo "Removing temporary settings"
		rm $HCP_RUN_DNETWORKS.sh
	fi
}
trap cleanup_trap EXIT

# Create the temporary docker network
docker network create $HCP_RUN_DNETWORKS


echo ""
echo "--------------------------------------------------------"
echo "Starting pre-upgrade services, triggering initialization"
echo "--------------------------------------------------------"
echo ""
export HCP_RUN_DSPACE=$prefix1
export HCP_RUN_DTAG=$suffix1
[[ -n $itfailed ]] || $MYMAKE startall || itfailed=pre-upgrade-startall
[[ -n $itfailed ]] && exit 1

echo ""
echo "--------------------"
echo "Running user command"
echo "--------------------"
echo ""
[[ -n $itfailed ]] || bash -c "$usercmd" || itfailed=pre-upgrade-usercmd
[[ -n $itfailed ]] && exit 1

echo ""
echo "-----------------------------"
echo "Stopping pre-upgrade services"
echo "-----------------------------"
echo ""
[[ -n $itfailed ]] || $MYMAKE stopall || itfailed=pre-upgrade-stopall
[[ -n $itfailed ]] && exit 1

echo ""
echo "--------------------------------------------------------"
echo "Starting upgraded services, triggering in-place upgrades"
echo "--------------------------------------------------------"
echo ""
export HCP_RUN_DSPACE=$prefix2
export HCP_RUN_DTAG=$suffix2
[[ -n $itfailed ]] || $MYMAKE startall || itfailed=post-upgrade-startall
[[ -n $itfailed ]] && exit 1

echo ""
echo "--------------------"
echo "Running user command"
echo "--------------------"
echo ""
[[ -n $itfailed ]] || bash -c "$usercmd" || itfailed=post-upgrade-usercmd
[[ -n $itfailed ]] && exit 1

/bin/true

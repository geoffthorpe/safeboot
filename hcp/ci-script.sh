#!/bin/bash

# This script is used as a single point of entry for automated CI.
#
# * The main purpose for it is to ensure a unique prefix on Docker objects
#   (container images, and networks when running them), to allow for
#   concurrency and independence between builds, even if they're running on the
#   same host using the same account. If the HCP_BUILD_PREFIX environment
#   variable is set, it will be used, otherwise a unique (randomly-generated)
#   value is derived (from mktemp).
#
# * It does its best to ensure all build and test artifacts are cleaned out,
#   even if the build or tests fail in some way. (After all, if we knew they'd
#   never fail, why would we run CI?) In a development environment, it makes
#   sense to immediately abort a build process when it encounters failure, to
#   aid investigation. On CI however, the opposite is usually true - if a build
#   process fails, the output and result will reflect that, but we have every
#   interest in trying to "unwind" and clear out any build artifacts before
#   propagating the failure result. It is one thing to rely on garbage
#   collection strategies within the CI environment to clean out source
#   checkouts for old CI runs, it is quite another to rely on it to clean out
#   container images and build artifacts, which are frequently orders of
#   magnitude larger. If a CI build fails, nobody is "going in" to use the
#   filesystem or docker repository to investigate, and if many builds are
#   failing at once and leaving lots of detritus in the system, we may exhaust
#   system resources or force the use of overly aggressive garbage collection.
#
# * It sets verbose mode (V=1), as the stdout/stderr of the build process is
#   the _only_ state we retain (and that can be consulted) at the conclusion of
#   a CI run, whether it succeeded or failed.
#
# * This also allows for control (from CI configuration) over the way Docker
#   tags the generated container images (the default is usually "latest"). This
#   script will use the HCP_BUILD_TAG environment variable, if it is set,
#   otherwise it will default to "ci_build".
#
# * The typical pattern for using HCP_BUILD_PREFIX and HCP_BUILD_TAG is to rely
#   on them to produce image names and tags that are, by default, marked as not
#   being for production use. Then, specific CI invocations (as determined from
#   action, source and/or destination branch, [...]) can override with specific
#   prefixes and/or tags to mark the generated images for specific purposes and
#   consumption. E.g. "prod", or "prod-$VERSION" for some deployment versioning
#   scheme, or "prod-$DEPLOYMENT" if the branch/build is specific to a
#   particular site, region, use-case, instance, etc.
#
# * This also takes extra steps to isolate the testing from concurrent/cotenant
#   activities;
#    - removing "--publish" entries so that services host ports aren't
#      forwarded to containers. (Services and functions within the same run get
#      their own private network and can hit each other there. The binding of
#      host ports is only to support exposing services for extrernal access
#      and/or to help dev and debug.)

set -e

# Weird. Docker insists on lower-case names+tags for images, but mktemp has no
# obvious way to eliminate upper-case. So we loop until we get what we want...
while /bin/true; do
	TMPFILE=`mktemp -t cijob_XXXX_`
	DPREFIX=`basename $TMPFILE`
	echo $DPREFIX | egrep "[A-Z]" > /dev/null 2>&1 || break
	rm $TMPFILE
done

export SAFEBOOT_HCP_DSPACE=${HCP_BUILD_PREFIX:-$DPREFIX}
export SAFEBOOT_HCP_DTAG=${HCP_BUILD_TAG:-ci_build}
export V=1

# Set harmless and meaningless --env's to these variables so that the defaults
# (which contain --publish) don't get used.
HARMLESSP=--env=HARMLESSP=harmlessp
export HCP_RUN_ENROLL_XTRA_MGMT=$HARMLESSP
export HCP_RUN_ENROLL_XTRA_REPL=$HARMLESSP
export HCP_RUN_ATTEST_XTRA_REPL=$HARMLESSP
export HCP_RUN_ATTEST_XTRA_HCP=$HARMLESSP
export HCP_RUN_SWTPM_XTRA=$HARMLESSP

# When we run the tools (rather than building them), we deliberately put the
# stdout and stderr into temporary files. Why? Well, we use a trap to make sure
# we "make clean" on exit, no matter the circumstances of the exit, and this
# clean (like the build) generates a lot of output. When a developer is looking
# at the log of a CI run, it can be very annoying to have to scroll back
# through umpteen pages of "make clean" output in order to see the far more
# interesting output (especially the conclusion) of the tests. It can be
# alternatively annoying to scroll down through umpteen pages of the build
# process. Rather than playing "pick your poison", we redirect the test output
# and then replay it to stdout/stderr after the clean!
DEFER_STDOUT=`mktemp`
DEFER_STDERR=`mktemp`

# This gets set to the stage ("build", "basic_test") that fails, if a stage
# fails. As such, we can perform cleanup and still propagate the failure
# informatively.
unset itfailed

# We set this EXIT trap to run on any/all exit paths. This includes; the
# success path, any explicit "exit"s, and any implicit (set -e) exits. The
# strange error handling is to ensure that we exit with failure if the clean
# fails, or if we were already going to exit with failure before entering the
# trap.
#
# Note, the sleep is a horrible sin and here's why. A ctrl-c kind of
# interruption can cause a docker front-end process to exit and our cleanup
# trap to start running while the docker back-end (daemon) is _asynchronously_
# removing a container in reaction to our interruption. Now, the "make clean"
# rules try to "pre-clean" any exited-but-not-removed container images, because
# docker sometimes leaves these lying around when Dockerfile commands fail
# (even if we provide "--rm" flags everywhere), and those exited containers can
# block the "clean" logic from removing underlying container images. So the
# sleep in our trap is to just give the daemon time to finish removing anything
# it is removing, so we only try to remove things that it _won't_ remove. There
# appears to be no other obvious way to do this...
function cleanup_trap
{
	sleep 1
	unset cleanfailed
	echo ""
	echo "-------------------------------------"
	echo "Cleaning up with 'make clean FORCE=1'"
	echo "-------------------------------------"
	echo ""
	make clean FORCE=1 || cleanfailed=1
	if [[ -z $itfailed && -n $cleanfailed ]]; then
		itfailed=clean
	fi

	echo ""
	echo "-----------------------------------------------------"
	echo "Replaying (deferred) stdout/stderr from 'make runall'"
	echo "-----------------------------------------------------"
	echo ""
	cat $DEFER_STDOUT
	cat $DEFER_STDERR >&2

	# Remove the temp files
	rm $TMPFILE
	rm $DEFER_STDOUT
	rm $DEFER_STDERR
	echo

	# Report the outcome and exit with the corresponding status

	if [[ -n $itfailed ]]; then
	echo ""
	echo "==============="
	echo "Result: FAILURE (in stage $itfailed)"
	echo "==============="
	if [[ -n $cleanfailed ]]; then
	echo "Cleanup also failed!"
	fi
	exit 1
	fi

	echo ""
	echo "==============="
	echo "Result: SUCCESS"
	echo "==============="
	exit 0
}

trap cleanup_trap EXIT

echo "======================="
echo "Running HCP 'CI' script"
echo "======================="
echo ""
echo "Using;"
echo "   SAFEBOOT_HCP_DSPACE=$SAFEBOOT_HCP_DSPACE"
echo "     SAFEBOOT_HCP_DTAG=$SAFEBOOT_HCP_DTAG"
echo ""
echo "-------------------------------------------"
echo "Running full build with 'make hcp_buildall'"
echo "-------------------------------------------"
echo ""

make hcp_buildall || itfailed=build

if [[ -z $itfailed ]]; then
echo ""
echo "--------------------------------------------"
echo "Running typical test case with 'make runall'"
echo "--------------------------------------------"
echo "NB: stdout/stderr are deferred until the end of the log output."
echo ""
make runall > $DEFER_STDOUT 2> $DEFER_STDERR || itfailed=basic_test
fi

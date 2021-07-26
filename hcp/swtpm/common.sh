# This is an include-only file. So no shebang header and no execute perms.

set -e

# Print the base configuration
echo "Running '$0'" >&2
echo "    STATE_PREFIX=$STATE_PREFIX" >&2
echo " ENROLL_HOSTNAME=$ENROLL_HOSTNAME" >&2

if [[ -z "$STATE_PREFIX" || ! -d "$STATE_PREFIX" ]]; then
	echo "Error, STATE_PREFIX (\"$STATE_PREFIX\") is not a valid path" >&2
	exit 1
fi
if [[ -z "$ENROLL_HOSTNAME" ]]; then
	echo "Error, ENROLL_HOSTNAME (\"$ENROLL_HOSTNAME\") is not set" >&2
	exit 1
fi

if [[ -d /install/bin ]]; then
	export PATH=/install/bin:$PATH
	echo "Adding /install/bin to PATH" >&2
fi
if [[ -d /install/lib ]]; then
	export LD_LIBRARY_PATH=/install/lib:$LD_LIBRARY_PATH
	echo "Adding /install/lib to LD_LIBRARY_PATH" >&2
	if [[ -d /install/lib/python3/dist-packages ]]; then
		export PYTHONPATH=/install/lib/python3/dist-packages:$PYTHONPATH
		echo "Adding /install/lib/python3/dist-packages to PYTHONPATH" >&2
	fi
fi

cd $STATE_PREFIX

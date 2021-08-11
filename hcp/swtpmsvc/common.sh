# This is an include-only file. So no shebang header and no execute perms.

set -e

# Print the base configuration
echo "Running '$0'" >&2
echo "    SWTPMSVC_STATE_PREFIX=$SWTPMSVC_STATE_PREFIX" >&2
echo " SWTPMSVC_ENROLL_HOSTNAME=$SWTPMSVC_ENROLL_HOSTNAME" >&2

if [[ -z "$SWTPMSVC_STATE_PREFIX" || ! -d "$SWTPMSVC_STATE_PREFIX" ]]; then
	echo "Error, SWTPMSVC_STATE_PREFIX (\"$SWTPMSVC_STATE_PREFIX\") is not a valid path" >&2
	exit 1
fi
if [[ -z "$SWTPMSVC_ENROLL_HOSTNAME" ]]; then
	echo "Error, SWTPMSVC_ENROLL_HOSTNAME (\"$SWTPMSVC_ENROLL_HOSTNAME\") is not set" >&2
	exit 1
fi

if [[ ! -d "/safeboot/sbin" ]]; then
	echo "Error, /safeboot/sbin is not present" >&2
	exit 1
fi
export PATH=$PATH:/safeboot/sbin
echo "Adding /safeboot/sbin to PATH" >&2

if [[ -d "/install/bin" ]]; then
	export PATH=$PATH:/install/bin
	echo "Adding /install/sbin to PATH" >&2
fi

if [[ -d "/install/lib" ]]; then
	export LD_LIBRARY_PATH=/install/lib:$LD_LIBRARY_PATH
	echo "Adding /install/lib to LD_LIBRARY_PATH" >&2
	if [[ -d /install/lib/python3/dist-packages ]]; then
		export PYTHONPATH=/install/lib/python3/dist-packages:$PYTHONPATH
		echo "Adding /install/lib/python3/dist-packages to PYTHONPATH" >&2
	fi
fi

cd $SWTPMSVC_STATE_PREFIX

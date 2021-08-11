# This file is modeled heavily on hcp/enrollsvc/common.sh so please consult
# that for explanatory matter. (When the same comments apply here, they are
# removed.)

set -e

if [[ `whoami` != "root" ]]; then
	if [[ -z "$HCP_ENVIRONMENT_SET" ]]; then
		echo "Running in reduced non-root environment (sudo probably)." >&2
		cat /etc/environment >&2
		source /etc/environment
	fi
fi

if [[ -z "$ATTESTSVC_STATE_PREFIX" || ! -d "$ATTESTSVC_STATE_PREFIX" ]]; then
	echo "Error, ATTESTSVC_STATE_PREFIX (\"$ATTESTSVC_STATE_PREFIX\") is not a valid path" >&2
	exit 1
fi
if [[ -z "$HCP_USER" || ! -d "/home/$HCP_USER" ]]; then
	echo "Error, HCP_USER (\"$HCP_USER\") is not a valid user" >&2
	exit 1
fi
if [[ -z "$ATTESTSVC_REMOTE_REPO" ]]; then
	echo "Error, ATTESTSVC_REMOTE_REPO (\"$ATTESTSVC_REMOTE_REPO\") must be set" >&2
	exit 1
fi
if [[ -z "$ATTESTSVC_UPDATE_TIMER" ]]; then
	echo "Error, ATTESTSVC_UPDATE_TIMER (\"$ATTESTSVC_UPDATE_TIMER\") must be set" >&2
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

if [[ `whoami` == "root" ]]; then
	echo "# HCP settings, put here so that non-root environments" >> /etc/environment
	echo "# always get known-good values." >> /etc/environment
	echo "HCP_USER=$HCP_USER" >> /etc/environment
	echo "ATTESTSVC_STATE_PREFIX=$ATTESTSVC_STATE_PREFIX" >> /etc/environment
	echo "ATTESTSVC_REMOTE_REPO=$ATTESTSVC_REMOTE_REPO" >> /etc/environment
	echo "ATTESTSVC_UPDATE_TIMER=$ATTESTSVC_UPDATE_TIMER" >> /etc/environment
	echo "HCP_ENVIRONMENT_SET=1" >> /etc/environment
fi

# Print the base configuration
echo "Running '$0'" >&2
echo "                HCP_USER=$HCP_USER" >&2
echo "  ATTESTSVC_STATE_PREFIX=$ATTESTSVC_STATE_PREFIX" >&2
echo "   ATTESTSVC_REMOTE_REPO=$ATTESTSVC_REMOTE_REPO" >&2
echo "  ATTESTSVC_UPDATE_TIMER=$ATTESTSVC_UPDATE_TIMER" >&2

# Basic functions

function expect_root {
	if [[ `whoami` != "root" ]]; then
		echo "Error, running as \"`whoami`\" rather than \"root\"" >&2
		exit 1
	fi
}

function expect_hcp_user {
	if [[ `whoami` != "$HCP_USER" ]]; then
		echo "Error, running as \"`whoami`\" rather than \"$HCP_USER\"" >&2
		exit 1
	fi
}

function drop_privs_hcp {
	su -c "$1 $2 $3 $4 $5" - $HCP_USER
}

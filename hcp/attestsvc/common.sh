# This is an include-only file. So no shebang header and no execute perms.
#
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

if [[ -z "$STATE_PREFIX" || ! -d "$STATE_PREFIX" ]]; then
	echo "Error, STATE_PREFIX (\"$STATE_PREFIX\") is not a valid path" >&2
	exit 1
fi
if [[ -z "$HCP_USER" || ! -d "/home/$HCP_USER" ]]; then
	echo "Error, HCP_USER (\"$HCP_USER\") is not a valid user" >&2
	exit 1
fi
if [[ -z "$REMOTE_REPO" ]]; then
	echo "Error, REMOTE_REPO (\"$REMOTE_REPO\") must be set" >&2
	exit 1
fi
if [[ -z "$UPDATE_TIMER" ]]; then
	echo "Error, UPDATE_TIMER (\"$UPDATE_TIMER\") must be set" >&2
	exit 1
fi

if [[ `whoami` == "root" ]]; then
	echo "# HCP settings, put here so that non-root environments" >> /etc/environment
	echo "# always get known-good values." >> /etc/environment
	echo "HCP_USER=$HCP_USER" >> /etc/environment
	echo "STATE_PREFIX=$STATE_PREFIX" >> /etc/environment
	echo "REMOTE_REPO=$REMOTE_REPO" >> /etc/environment
	echo "UPDATE_TIMER=$UPDATE_TIMER" >> /etc/environment
	echo "HCP_ENVIRONMENT_SET=1" >> /etc/environment
fi

# Print the base configuration
echo "Running '$0'" >&2
echo "      HCP_USER=$HCP_USER" >&2
echo "  STATE_PREFIX=$STATE_PREFIX" >&2
echo "   REMOTE_REPO=$REMOTE_REPO" >&2
echo "  UPDATE_TIMER=$UPDATE_TIMER" >&2

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

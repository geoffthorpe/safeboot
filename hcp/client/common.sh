# This is an include-only file. So no shebang header and no execute perms.

set -e

# Print the base configuration
echo "Running '$0'" >&2
echo " ENROLL_HOSTNAME=$ENROLL_HOSTNAME" >&2
echo "      ATTEST_URL=$ATTEST_URL" >&2
echo "  TPM2TOOLS_TCTI=$TPM2TOOLS_TCTI" >&2

if [[ -z "$ENROLL_HOSTNAME" ]]; then
	echo "Error, ENROLL_HOSTNAME (\"$ENROLL_HOSTNAME\") is not set" >&2
	exit 1
fi
if [[ -z "$ATTEST_URL" ]]; then
	echo "Error, ATTEST_URL (\"$ATTEST_URL\") is not set" >&2
	exit 1
fi
if [[ -z "$TPM2TOOLS_TCTI" ]]; then
	echo "Error, TPM2TOOLS_TCTI (\"$TPM2TOOLS_TCTI\") is not set" >&2
	exit 1
fi

if [[ ! -d /safeboot/sbin ]]; then
	echo "Error, Safeboot scripts aren't installed" >&2
	exit 1
fi
export PATH=/safeboot/sbin:$PATH

cd /safeboot

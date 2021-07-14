#!/usr/bin/python3

# A crude way to do this task with a single command-line (using curl and jq) is;
#
# curl -v -F ekpub=@$TPM_EKPUB \
#         -F hostname=$HCP_SWTPMSVC_ENROLL_HOSTNAME \
#         $HCP_SWTPMSVC_ENROLL_URL | jq -r '.returncode'
#
# This will be '0' on success, '1' on failure.


# The following python script can be used to automate the enrollment of a host
# with the HCP Enrollment Service. The latter exposes an API end-point
# (typically at <URL-base>/v1/add) for us to hit, and takes 2 parameters that
# are both specified via environment variables;
#
# - hostname: specified by the "HCP_SWTPMSVC_ENROLL_HOSTNAME" environment
#   variable.
#
# - ekpub: the public part of the TPM's "Endorsement Key", either in its raw
#   TPM binary format or PEM-encoded. The "TPM_EKPUB" environment variable
#   provides the path to this file.
#
# The URL for this API must also be provided by the "HCP_SWTPMSVC_ENROLL_URL"
# environment variable.
#
# In the safeboot.dev implementation, part of the HCP (Host Cryptographic
# Provisioning) architecture, this script gets used when initializing a
# containerized instance of the software TPM ("sTPM" or "swtpm"). The
# newly-created sTPM state is immediately registered with the Enrollment
# Service via this script, so the architecture makes the assumption that a sTPM
# instance is only ever created when the intended hostname to associate it with
# is already known.

import json
import requests
import os
import sys

ekpub = os.environ.get('TPM_EKPUB')
hostname = os.environ.get('HCP_SWTPMSVC_ENROLL_HOSTNAME')
api_url = os.environ.get('HCP_SWTPMSVC_ENROLL_URL')

assert ekpub, "'TPM_EKPUB' must be set to the path of ek.pub"
assert hostname, "'HCP_SWTPMSVC_ENROLL_HOSTNAME' must be the hostname enrolled with this TPM key"
assert api_url, "'HCP_SWTPMSVC_ENROLL_URL' must be set to the enrollment API URL"

form_data = {
    'ekpub': ('ek.pub', open(ekpub, 'rb')),
    'hostname': (None, hostname)
}

response = requests.post(api_url, files=form_data)

jr = json.loads(response.content)

print("Response from the enrollment service;")
print(jr)

rcode = jr['returncode']

print(f"Return code = {rcode}")

if (rcode != 0):
    print("Failure")
else:
    print("Success")

sys.exit(rcode)

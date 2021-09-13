#!/bin/bash

set -e

# NOTES
#  - the processes started by this test do not get stopped, so attempting to
#    run it a second time will fail unless you first kill them manually.
#  - however, exiting the container will stop them, and will also destroy all
#    state.

mkdir /state
mkdir /state/{enrollsvc,attestsvc,swtpmsvc}
mkdir /creds
mkdir /creds/{asset-signer,asset-verifier}
openssl genrsa -out /creds/asset-signer/key.priv
openssl rsa -pubout -in /creds/asset-signer/key.priv -out /creds/asset-signer/key.pem
cp /creds/asset-signer/key.pem /creds/asset-verifier/
chown db_user:db_user /creds/asset-signer/key.*
export HCP_ENROLLSVC_STATE_PREFIX=/state/enrollsvc
export HCP_RUN_ENROLL_SIGNER=/creds/asset-signer
export HCP_ATTESTSVC_STATE_PREFIX=/state/attestsvc
export HCP_ATTESTSVC_REMOTE_REPO=git://localhost/enrolldb
export HCP_ATTESTSVC_UPDATE_TIMER=10
export HCP_SWTPMSVC_STATE_PREFIX=/state/swtpmsvc
export HCP_SWTPMSVC_ENROLL_HOSTNAME=localhost
export HCP_SWTPMSVC_ENROLL_URL=http://localhost:5000/v1/add
export HCP_RUN_CLIENT_VERIFIER=/creds/asset-verifier
export HCP_CLIENT_ATTEST_URL=http://localhost:8080
export TPM2TOOLS_TCTI=swtpm:host=localhost,port=9876

# HCP Enrollment Service.
/hcp/enrollsvc/setup_enrolldb.sh
/hcp/enrollsvc/run_mgmt.sh &
/hcp/enrollsvc/run_repl.sh &

# We _could_ tail_wait.pt the enrollsvc msgbus outputs to make sure they're
# truly listening before we launch things (like attestsvc) that depend on it.
# But ... nah. Let's just sleep for a second instead.
sleep 1

/hcp/attestsvc/setup_repl.sh
/hcp/attestsvc/run_repl.sh &
/hcp/attestsvc/run_hcp.sh &

# Same comment;
sleep 1

/hcp/swtpmsvc/setup_swtpm.sh
/hcp/swtpmsvc/run_swtpm.sh &

# Same comment;
sleep 1

/hcp/client/run_client.sh


#!/bin/bash

openssl genrsa -out $HCP_RUN_ENROLL_SIGNER/key.priv
openssl rsa -pubout -in $HCP_RUN_ENROLL_SIGNER/key.priv -out $HCP_RUN_ENROLL_SIGNER/key.pem
cp $HCP_RUN_ENROLL_SIGNER/key.pem $HCP_RUN_CLIENT_VERIFIER/
chown db_user:db_user /creds/asset-signer/key.*

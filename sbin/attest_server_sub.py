"""
Quote and Eventlog validating Attestation Server Utility Function.

Takes an attestation request body as an argument, returns a tuple of an HTTP
status code and a response body.
"""
import os
import logging
import tempfile
import sys
import subprocess
import yaml
import hashlib

# hard code the hashing algorithm used
alg = 'sha256'

def attest_verify(quote_data):
	# write post data into a file
	tmp_file = tempfile.NamedTemporaryFile()
	tmp_file.write(quote_data)
	tmp_file.flush()
	quote_file = tmp_file.name

	# verify that the Endorsment Key came from an authorized TPM,
	# that the quote is signed by a valid Attestation Key
	sub = subprocess.run(["./sbin/tpm2-attest", "verify", quote_file ],
		stdout=subprocess.PIPE,
		stderr=sys.stderr,
	)

	quote_valid = sub.returncode == 0

	# The output contains YAML formatted hash of the EK and the PCRs
	quote = yaml.safe_load(sub.stdout)
	if 'ekhash' in quote:
		ekhash = quote['ekhash']
	else:
		quote_valid = False
		ekhash = "UNKNOWN"

	with open("/tmp/quote.yaml", "w") as y:
		y.write(str(quote))

	# Validate that the every computed PCR in the eventlog
	# matches a quoted PCRs.
	# This makes no statements about the validitiy of the
	# event log, only that it is consistent with the quote.
	# Other PCRs may have values, which is the responsibility
	# of the verifier to check.
	if alg not in quote['pcrs']:
		logging.warning(f"{ekhash=}: quote does not have hash {alg}")
	quote_pcrs = quote['pcrs'][alg]

	# XXX We need a way to configure whether the eventlog is optional
	if quote['eventlog-pcrs'] != None:
		eventlog_pcrs = quote['eventlog-pcrs'][alg]

		for pcr_index in eventlog_pcrs:
			eventlog_pcr = eventlog_pcrs[pcr_index]

			if pcr_index in quote_pcrs:
				quote_pcr = quote_pcrs[pcr_index]
				if quote_pcr != eventlog_pcr:
					logging.warning(f"{ekhash=}: {pcr_index=} {quote_pcr=} != {eventlog_pcr=}")
					quote_valid = False
				else:
					logging.info(f"{ekhash=}: {pcr_index=} {quote_pcr=} good")

	if quote_valid:
		logging.info(f"{ekhash=}: so far so good")
	else:
		logging.warning(f"{ekhash=}: not good at all")

	# the quote, eventlog and PCRS are consistent, so ask the verifier to
	# process the eventlog and decide if the eventlog meets policy for
	# this ekhash.
	sub = subprocess.run(["./sbin/attest-verify", "verify", str(quote_valid)],
		input=bytes(str(quote), encoding="utf-8"),
		stdout=subprocess.PIPE,
		stderr=sys.stderr,
	)

	if sub.returncode != 0:
		return (403, "ATTEST_VERIFY FAILED")

	# read the (binary) response from the sub process stdout
	response = sub.stdout

	result = subprocess.run(["./sbin/tpm2-attest", "seal", quote_file, ],
		input=response,
		capture_output=True
	)

	if result.returncode != 0:
		return (403, "ATTEST_SEAL FAILED")

	return (200, result.stdout)

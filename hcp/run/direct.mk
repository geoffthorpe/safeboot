# This file is an example of using the hcp/run workflow directly. The settings
# below allow hcp/run/Makefile to be included and have all the required inputs.
# To use this, set the HCP_RUN_SETTINGS environment variable to the path for
# this settings file, and then use hcp/run directly;
#
#     $ export HCP_RUN_SETTINGS=./hcp/run/direct.mk
#     $ make -f ./hcp/run/Makefile [targets...]
#
# Or if you are in the source environment but want to use the hcp/run workflow
# directly anyway, _and_ you don't want to pass a "-f" argument to make, _and_
# you want tab-completion to keep working ... create a symlink for GNUmakefile
# in the top-level directory, which (GNU) make will prefer over the standard
# safeboot "Makefile";
#
#     $ export HCP_RUN_SETTINGS=./hcp/run/direct.mk
#     $ ln -s ./hcp/run/Makefile GNUmakefile
#     $ make [...]
#
# Though the settings below allow hcp/run/Makefile to be used directly, without
# dependence on the safeboot source environment, they also get used when using
# the source environment is present. I.e. the build system automatically sets
# HCP_RUN_SETTINGS to point to this file, provides HCP_RUN_*** values for the
# "images and paths" properties, and then includes hcp/run/Makefile and relies
# on this file being automatically included to provide the HCP_RUN_*** values
# for "application properties".
#
# So from within the dev/debug workflow we can operate the services _or_ we can
# pivot to the hcp/run workflow to operate them directly. The application
# settings in this file get used in both cases so should result in the
# same/interchangable usage, and that is how we can maintain this
# operation/production-focussed workflow while developing in the dev/debug
# workflow.

####################
# Images and paths #
####################

# In the dev/debug workflow, "make" is always run from the top-level directory
# of the source tree, puts all build-related and other generated artifacts
# under ./build, with HCP related stuff under ./build/hcp, and the runtime
# state (and logs, [etc]) under ./build/hcp/run
TOP ?= $(shell pwd)
HCP_RUN_TOP ?= $(TOP)/build/hcp/run
# If the default gets used, it requires this dep
$(TOP)/build/hcp/run: | $(TOP)/build/hcp

# In the dev/debug workflow, the default "DSPACE" (naming prefix used for all
# objects on the local Docker instance) "DTAG" (colon-separated suffix for all
# container images) are;
HCP_RUN_DSPACE ?= safeboot_hcp_
HCP_RUN_DTAG ?= devel

# In the dev/debug workflow, all containers default to attaching to a network
# called "$(DSPACE)network_hcp";
HCP_RUN_DNETWORKS ?= $(HCP_RUN_DSPACE)network_hcp

# In the dev/debug workflow, the required script is at this path;
HCP_RUN_ASSIST_CLEANUP ?= $(TOP)/hcp/assist_cleanup.sh

# In the dev/debug workflow, the default "util_image" (for doing
# container-based cleanup) comes from hcp/settings.mk, which sets
# SAFEBOOT_HCP_BASE to this value. (Note, keep them synchronized!)
HCP_RUN_UTIL_IMAGE ?= debian:bullseye-slim

##########################
# Application properties #
##########################

# - Commented-out settings show defaults.
# - The CI script (hcp/ci-script.sh) intentionally stubs out all XTRA settings
#   to avoid any --publish arguments in a CI pipeline. If you add something
#   other than --publish args to an XTRA variable, consider the implications!

#HCP_RUN_ENROLL_SIGNER ?= $(HCP_RUN_TOP)/creds/asset-signer
HCP_RUN_ENROLL_SIGNER_AUTOCREATE ?= yes
#HCP_RUN_ENROLL_UWSGI ?= uwsgi_python3
#HCP_RUN_ENROLL_UWSGI_PORT ?= 5000
#HCP_RUN_ENROLL_UWSGI_FLAGS ?= --http :5000 --stats :5001
#HCP_RUN_ENROLL_UWSGI_OPTIONS ?= --processes 2 --threads 2
#HCP_RUN_ENROLL_GITDAEMON ?= /usr/lib/git-core/git-daemon
#HCP_RUN_ENROLL_GITDAEMON_FLAGS ?= --reuseaddr --verbose --listen=0.0.0.0 --port=9418
HCP_RUN_ENROLL_XTRA_MGMT ?= --publish=5000:5000 --publish=5001:5001
HCP_RUN_ENROLL_XTRA_REPL ?= --publish=9418:9418

HCP_RUN_ATTEST_REMOTE_REPO ?= git://enrollsvc_repl/enrolldb
HCP_RUN_ATTEST_UPDATE_TIMER ?= 10
#HCP_RUN_ATTEST_UWSGI ?= uwsgi_python3
#HCP_RUN_ATTEST_UWSGI_PORT ?= 8080
#HCP_RUN_ATTEST_UWSGI_FLAGS ?= --http :8080 --stats :8081
#HCP_RUN_ATTEST_UWSGI_OPTIONS ?= --processes 2 --threads 2
#HCP_RUN_ATTEST_XTRA_REPL ?=
HCP_RUN_ATTEST_XTRA_HCP ?= --publish=8080:8080 --publish=8081:8081

HCP_RUN_SWTPM_ENROLL_HOSTNAME ?= example_host.wherever.xyz
HCP_RUN_SWTPM_ENROLL_URL ?= http://enrollsvc_mgmt:5000/v1/add
HCP_RUN_SWTPM_XTRA ?= --publish=9876:9876

#HCP_RUN_CLIENT_VERIFIER ?= $(HCP_RUN_TOP)/creds/asset-verifier
HCP_RUN_CLIENT_TPM2TOOLS_TCTI ?= swtpm:host=swtpmsvc,port=9876
HCP_RUN_CLIENT_ATTEST_URL ?= http://attestsvc_hcp:8080

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
# The settings below are intended to match those used (by default) in the
# safeboot source environment. I.e. once HCP images are built using the source
# workflow and defaults, we can operate the services using either the source
# workflow _or_ the hcp/run workflow directly. The settings in this file should
# result in the same/interchangable usage, and that is how we can maintain this
# operation/production-focussed workflow while developing in the dev/debug
# workflow.


# In the dev/debug workflow, "make" is always run from the top-level directory
# of the source tree, puts all build-related and other generated artifacts
# under ./build, with HCP related stuff under ./build/hcp, and the runtime
# state (and logs, [etc]) under ./build/hcp/run
TOP ?= $(shell pwd)
HCP_RUN_TOP ?= $(TOP)/build/hcp/run

# In the dev/debug workflow, the default "DSPACE" (naming prefix used for all
# objects on the local Docker instance) "DTAG" (colon-separated suffix for all
# container images) are;
HCP_RUN_DSPACE ?= safeboot_hcp_
SAFEBOOT_HCP_DTAG ?= :devel

# In the dev/debug workflow, all containers default to attaching to a network
# called "$(DSPACE)network_hcp";
HCP_RUN_DNETWORKS ?= $(HCP_RUN_DSPACE)network_hcp

# In the dev/debug workflow, the required script is at this path;
HCP_RUN_ASSIST_CLEANUP ?= $(TOP)/hcp/assist_cleanup.sh

# In the dev/debug workflow, the default "util_image" (for doing
# container-based cleanup) is this;
HCP_RUN_UTIL_IMAGE ?= debian:bullseye-slim

# Application knobs
HCP_RUN_ATTEST_REMOTE_REPO := git://enrollsvc_repl/enrolldb
HCP_RUN_ATTEST_UPDATE_TIMER := 10
HCP_RUN_SWTPM_ENROLL_HOSTNAME := example_host.wherever.xyz
HCP_RUN_SWTPM_ENROLL_URL := http://enrollsvc_mgmt:5000/v1/add
HCP_RUN_CLIENT_TPM2TOOLS_TCTI := swtpm:host=swtpmsvc,port=9876
HCP_RUN_CLIENT_ATTEST_URL := http://attestsvc_hcp:8080

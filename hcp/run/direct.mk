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
# objects on the local Docker instance) is;
HCP_RUN_DSPACE ?= safeboot_hcp_

# In the dev/debug workflow, all containers default to attaching to a network
# called "$(DSPACE)network_hcp";
HCP_RUN_DNETWORKS ?= $(HCP_RUN_DSPACE)network_hcp

# In the dev/debug workflow, the required script is at this path;
HCP_RUN_ASSIST_CLEANUP ?= $(TOP)/hcp/assist_cleanup.sh

# In the dev/debug workflow, the default "util_image" (for doing
# container-based cleanup) is this;
HCP_RUN_UTIL_IMAGE ?= debian:bullseye-slim

# For good measure, provide a default rule that lists the targets that can be
# used!
default:
	@echo ""
	@echo "Direct usage of safeboot 'hcp/run' operational rules."
	@echo ""
	@echo "Current settings;"
	@echo "   HCP_RUN_TOP = $(HCP_RUN_TOP)"
	@echo "   HCP_RUN_DSPACE = $(HCP_RUN_DSPACE)"
	@echo "   HCP_RUN_DNETWORKS = $(HCP_RUN_DNETWORKS)"
	@echo "   HCP_RUN_UTIL_IMAGE = $(HCP_RUN_UTIL_IMAGE)"
	@echo ""
	@echo "To instantiate a service (i.e. initialize its state);"
	@echo "   make enrollsvc_init  # Enrollment Service"
	@echo "   make attestsvc_init  # Attestation Service"
	@echo "   make swtpmsvc_init   # Software TPM Service"
	@echo ""
	@echo "Likewise, to cleanup and remove a service (its state);"
	@echo "   make {enroll,attest,swtpm}svc_clean"
	@echo ""
	@echo "To start or stop a service;"
	@echo "   make {enroll,attest,swtpm}svc_{start,stop}"
	@echo ""
	@echo "To run a function;"
	@echo "   make client_start    # run the attestation client"
	@echo "   make caboodle_start  # bash shell in a 'caboodle' container"
	@echo ""

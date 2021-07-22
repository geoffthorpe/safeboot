HCP_SRC := $(TOP)/hcp
HCP_OUT := $(TOP)/build/hcp

$(HCP_OUT): | build
MDIRS += $(HCP_OUT)

# Used in dependency chains, as a change in these files can have effects that
# require rebuilding other things.
HCP_DEPS_COMMON := $(TOP)/Makefile $(HCP_SRC)/settings.mk $(HCP_SRC)/Makefile

# Utility script to simplify the workflow
ASSIST_CLEANUP=$(HCP_SRC)/assist_cleanup.sh

# Configuration settings. (From wherever. A developer, a CI pipeline, some
# package-building machinery, ...)
include hcp/settings.mk

# A "base platform" Docker image is created, and used as a basis for deriving
# two kinds of images;
# - a "builder" container image, containing tool-chains and other extras to
#   facilitate the building of safeboot submodules.
# - application container images, providing the different services, side-cars,
#   and utilities that constitue HCP.
include hcp/base/Makefile

# A "builder" docker image is created that can host safeboot's building of
# submodule code (rather it than building directly in the host environment,
# which can be undesirable, unreliable, or impossible for many reasons).
include hcp/builder/Makefile

# Rules for building submodules (using "builder")
include hcp/submodules/Makefile

# TODO: the creating, destroy, starting, and stopping of instances (both
# Enrollment and Attestation) is currently mingled into the Makefiles that
# build the service containers. This will change. But for now, we want those
# instances to connect to each other on a docker network, so provide the
# definitions and support before including the Enrollment/Attestation Service
# Makefiles.
include hcp/testnetwork.Makefile

# Enrollment Service
include hcp/enrollsvc/Makefile

# Attestation Service
include hcp/attestsvc/Makefile

# This target allows you to shell into a running container (using docker exec).
# If CID is set, it attempts to shell into the container it identifies,
# otherwise a listing of running containers is given.

enter:
ifeq (,$(CID))
	$Qecho "To shell into a running container, select the desired container by setting CID to"
	$Qecho "the corresponding 'CONTAINER ID'. Note, you only need to specify enough of the"
	$Qecho "initial hexadecimal characters to distinguish it from other containers."
	$Qecho
	$Qecho "Currently running containers in this project;"
	$Qdocker container ls --filter=label=$(SAFEBOOT_HCP_DSPACE)all
	$Qecho
	$Qecho "E.g.:   make enter CID=f00d"
	$Qecho
else
	$Qdocker exec -it $(CID) /bin/bash
endif

# We deliberately don't use any "rm -rf" here. If the rmdir alone doesn't
# succeed, there is either a missing child cleanup hook, or one of the hooks
# isn't complete.
clean_hcp:
ifeq (yes,$(shell stat $(HCP_OUT) > /dev/null 2>&1 && echo yes))
	$Qrmdir $(HCP_OUT)
endif

# Make sure "hcp_clean" runs before "clean"
clean: clean_hcp

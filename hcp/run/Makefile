# To completely distinguish this "run" workflow from the build workflow, all
# variables are of the form HCP_RUN_*.
#
# This single-makefile workflow is factored-out of the safeboot source code
# (dev/debug workflow), so that it can also be used directly, in other
# contexts[1]. It provides makefile targets[2] that drive run-time operation of
# the HCP services/functions[3], and exposes their underlying filesystem paths
# (to allow the construction of new dependencies, which is how the source
# dev/debug workflow integrates it).
#
# [1] Direct-usage is for cases where the HCP container images are available in
# the local Docker repository, and should be used directly without any
# dependency on the presence/absence of source code, automatic rebuilding, etc.
# E.g.
#  - in a deployment pipeline (through ansible or whatever),
#  - when safeboot is being used to help do something else (e.g. develop other
#    software, do interop work, ...) and the HCP images should be used _as is_
#    (ignoring source, even if there is some).
# It helps to have only one version of this operations logic to serve the
# source dev/debug workflow as well in the various "runtime-only" use-cases.
#
# [2] The run-time operations are instantiated as makefile rules whose targets
# are (touch)files. These operations consist of;
#  - instantiation of services (creation/initialization and destruction of state)
#  - starting and stopping an instance of the service (or function).
# The includer of this workflow can define new dependencies (if desired) by
# knowing these targets. That's how the source dev/debug workflow integrates
# this, binding the operational targets to targets associated with creating and
# building of source code and container images.
#
# [3] Services are backgrounded and respond to network requests, and they have
# state. Instantiation of a service is equivalent to creating that initial
# state, which persists across stops and restarts of the service (instance).
# Services can consist of multiple containers operating on the same (shared)
# state. Functions on the other hand are foregrounded, run-to-completion tasks,
# that have no state to initialize or share across invocations.
#
# Currently defined services;
#     - the Enrollment service; "enrollsvc-mgmt" and "enrollsvc-repl"
#     - the Attestation service; "attestsvc-repl" and "attestsvc-hcp"
#     - the Software TPM service; "swtpmsvc"
#
# Currently defined functions;
#     - HCP test attestation client; "client"
#     - Caboodle shell (bash); "caboodle"
#         (This unions all the services into a combined container that can be
#         used for development/debug. The safeboot code is all script, so much
#         can be done even inside a built image!)
#
# This workflow consumes various inputs that serve to parameterize and
# configure the services. In particular, different instances are identified by
# different inputs. The source dev/debug workflow integrates this workflow by
# setting these parameters prior to including this Makefile.
#
# To use this workflow directly, either set these inputs yourself, or put them
# in a file to be included automatically, and set HCP_RUN_SETTINGS to the path
# to that file.

ifdef HCP_RUN_SETTINGS
include $(HCP_RUN_SETTINGS)
endif

# Mandatory inputs;
#   HCP_RUN_TOP
#     - a path where the run-time state (and mgmt, logs, etc) can go.
#   HCP_RUN_DSPACE
#     - the prefix of your Docker images. Eg. if your enrollment service image
#       is called "beta_safeboot_hcp_enrollsvc", then set;
#             HCP_RUN_DSPACE=beta_safeboot_hcp_
#   HCP_RUN_DNETWORKS
#     - if you want containers to join specific Docker networks, list them in
#       this variable, otherwise set it to 'none'.
#   HCP_RUN_ASSIST_CLEANUP
#     - the safeboot source tree includes a script, assist_cleanup.sh, to
#       assist with cleanup (specifically dealing with the niggles of user
#       namespaces). It must be present and this variable must point to it.
#
# Optional inputs;
#   HCP_RUN_SERVICES
#     - the list of services that are enabled on the current host, without any
#       "svc" suffix. The default is "enroll attest swtpm". This affects rules
#       such as initall, clearall, stopall, startall, and controls whether any
#       init rules depend on other start rules. E.g. by default, attestsvc_init
#       depends on enrollsvc_start (if the enrollment service isn't running,
#       the attestation service can't initialize). But if the enrollment
#       service is running on a different machine (and "enroll" isn't part of
#       HCP_RUN_SERVICES), then we don't make such a dependency - we have to
#       hope that the operator of the multiple hosts is coordinating things.
#   HCP_RUN_UTIL_IMAGE
#     - the assist_cleanup.sh script (see HCP_RUN_ASSIST_CLEANUP) needs to
#       start a container and any "normal" Docker image will do, including any
#       of the HCP images. "debian:latest" will do also, and if this variable
#       is not set it will default to that. Set this variable explicitly though
#       if you don't want to get the warning every time you run make.
#
# This also produces various outputs, again as HCP_RUN_* variables. The hcp/run
# workflow has rules and default settings for each of the services/functions it
# knows about, and it returns to the caller;
# - a list of services/functions it will run (if the images for them are available),
# - filesystem paths for initialization and launch events for each of those
#   services/functions (makefile targets).
# The workflow can create depencies (in either direction) with these paths, as
# the dev/debug workflow does. Obviously, the dev/debug workflow already knows
# what these settings will be. But in the case of direct usage, these outputs
# are probably the sources of truth for the caller.
#
# Outputs;
#   HCP_RUN_LIST
#     - the list of services (friendly names, "enrollsvc attestsvc ...")
#     - also contains the functions ("client"), which are one-shot and
#       run-to-completion, simpler than services.
#     - for each element <svc> of this list, the following output properties
#       are produced;
#   HCP_RUN_<svc>_TGT_INIT
#     - for services, this is the target (dependency) file for state
#       initialization. Use this to define dependencies, e.g. if other things
#       depend on this service's state being initialized, or if this service
#       shouldn't initialize until some other dependency is met.
#     - for functions, this is empty.
#   HCP_RUN_<svc>_CONTAINERS
#     - the list of containers for this service. If empty, there is a single
#       canonical container.
#     - only services set this, as functions are inherently singular.
#   HCP_RUN_<svc>_TGT_START
#     - if HCP_RUN_<svc>_CONTAINERS is empty, then this indicates the target
#       (dependency) file for the starting of that canonical container. (It is
#       removed when the container or entire service is stopped.)
#     - for services, this container is backgrounded ("-d" to docker-run) and
#       can be subsequently stopped.
#     - for functions, the container is foregrounded ("-i" to docker-run) and
#       runs to completion. Also, this file is never set, so "make"ing multiple
#       times causes it to run multiple times.
#   HCP_RUN_<svc>_<c>_TGT_START
#     - for each <c> in HCP_RUN_<svc>_CONTAINERS
#     - the target (dependency) file for the starting of the corresponding
#       container.

ifeq (,$(HCP_RUN_TOP))
$(error HCP_RUN_TOP must be set for run-time state.)
endif

ifneq (yes,$(shell test -x "$(HCP_RUN_ASSIST_CLEANUP)" > /dev/null 2>&1 && echo yes))
$(error HCP_RUN_ASSIST_CLEANUP must point to the assist_cleanup.sh script)
endif

ifeq (,$(HCP_RUN_DSPACE))
$(error HCP_RUN_DSPACE must be set to the docker namespace prefix)
endif

ifeq (,$(HCP_RUN_DTAG))
$(error HCP_RUN_DTAG must be set to the required docker image tag)
endif

ifeq (,$(HCP_RUN_DNETWORKS))
$(error HCP_RUN_DNETWORKS must be 'none' or a list of Docker networks)
else
ifeq (none,$(HCP_RUN_DNETWORKS))
HCP_RUN_DNETWORKS :=
endif
endif

ifeq (yes,$(HCP_RUN_ENROLL_SIGNER_AUTOCREATE))
ifndef HCP_RUN_ENROLL_SIGNER
$(HCP_RUN_TOP)/creds/asset-signer: | $(HCP_RUN_TOP)/creds
HCP_RUN_ENROLL_SIGNER := $(HCP_RUN_TOP)/creds/asset-signer
endif
HCP_RUN_MDIRS += $(HCP_RUN_ENROLL_SIGNER)
ifndef HCP_RUN_CLIENT_VERIFIER
$(HCP_RUN_TOP)/creds/asset-verifier: | $(HCP_RUN_TOP)/creds
HCP_RUN_CLIENT_VERIFIER := $(HCP_RUN_TOP)/creds/asset-verifier
endif
HCP_RUN_MDIRS += $(HCP_RUN_CLIENT_VERIFIER)
else
ifeq (,$(HCP_RUN_ENROLL_SIGNER))
$(error HCP_RUN_ENROLL_SIGNER must be a directory with key.{priv,pem} for asset signing.)
endif
ifeq (,$(HCP_RUN_CLIENT_VERIFIER))
$(error HCP_RUN_CLIENT_VERIFIER must be a directory with key.pem for sig-validation.)
endif
endif

ifeq (,$(HCP_RUN_UTIL_IMAGE))
HCP_RUN_UTIL_IMAGE := debian:latest
$(info HCP_RUN_UTIL_IMAGE wasn't defined, using $(HCP_RUN_UTIL_IMAGE))
endif

ifeq (,$(HCP_RUN_SERVICES))
HCP_RUN_SERVICES := enroll attest swtpm
$(info HCP_RUN_SERVICES wasn't defined, using $(HCP_RUN_SERVICES))
endif

# The source dev/debug workflow gets "DTAG" from hcp/settings.mk (or the
# caller), then prepends ":" to it, then goes on to build lots of images
# accordingly. We may be called by that workflow, so DTAG may already have a
# ":" prefix.  Alternatively we may be called directly, in which case the
# caller (or direct.mk, or HCP_RUN_SETTINGS) would be passing us a DTAG that
# _doesn't_ have a ":" prefix. <sigh> This makes sure we have exactly one.
HCP_RUN_DTAG := $(shell echo $(HCP_RUN_DTAG) | sed -e "s/^:*/:/")

# Declare the sub-directories we create and use inside HCP_RUN_TOP.
HCP_RUN_STATE := $(HCP_RUN_TOP)/state
HCP_RUN_MGMT := $(HCP_RUN_TOP)/mgmt
HCP_RUN_LOGS := $(HCP_RUN_TOP)/logs
HCP_RUN_CREDS := $(HCP_RUN_TOP)/creds
HCP_RUN_MDIRS += $(HCP_RUN_TOP) $(HCP_RUN_STATE) $(HCP_RUN_MGMT) $(HCP_RUN_LOGS) $(HCP_RUN_CREDS)
$(HCP_RUN_STATE) $(HCP_RUN_MGMT) $(HCP_RUN_LOGS) $(HCP_RUN_CREDS): | $(HCP_RUN_TOP)

# Capture listings of containers, running and otherwise
HCP_RUN_LIVE_CONTAINERS := $(shell docker container ls \
			--filter label=$(HCP_RUN_DSPACE)all \
			--format "{{.Names}}" 2> /dev/null)
HCP_RUN_ALL_CONTAINERS := $(shell docker container ls -a \
			--filter label=$(HCP_RUN_DSPACE)all \
			--format "{{.Names}}" 2> /dev/null)

# $Q is used to prefix all recipe lines, which by default evaluates to "@",
# unless V (for Verbose) is defined, in which case it evaluates empty. I.e.
# this controls whether or not all recipe lines are echoed to stdout by make.
# We have an in-between requirement, to display specifically the Docker
# commands being issued, so that an admin or devel can copy and paste (and
# modify) the command lines manually. We use the "SHOW" variable to trigger
# this choice, and use $S as the corresponding prefix.
ifeq (,$V$(SHOW))
S := @
else
S :=
endif

# Provide a default rule that lists the targets that can be used!
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

# Various "<verb>all" rules
initall: $(foreach i,$(HCP_RUN_SERVICES),$(i)svc_init)
cleanall: $(foreach i,$(HCP_RUN_SERVICES),$(i)svc_clean)
startall: $(foreach i,$(HCP_RUN_SERVICES),$(i)svc_start) client_start
stopall: $(foreach i,$(HCP_RUN_SERVICES),$(i)svc_stop)

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
	$Qdocker container ls --filter=label=$(HCP_RUN_DSPACE)all
	$Qecho
	$Qecho "E.g.:   make enter CID=f00d"
	$Qecho
else
	$Qdocker exec -it $(CID) /bin/bash
endif

# Anything generating goodies under these directories should put a dependency
# from clean_hcp_run to some rule of their own to clean their stuff out. BTW,
# we should not convert this to use ASSIST_CLEANUP! Anything created by
# containers (with weird permissioning side-effects) should be cleaned up by
# service-specific cleanup rules, declaring themselves as dependencies for this
# target.
clean_hcp_run:
	$Qrm -rf $(HCP_RUN_TOP)

# hcp_run_create() defines a service or function and creates the rules for
# initializing, cleaning, starting, and stopping it. The properties are defined
# as environment variables, such that the only parameter to the
# hcp_run_create() function is the prefix to those properties.
#
# Inputs;
# $1_NAME = friendly name.
#    - the docker image is expected to be $(HCP_RUN_DSPACE)$($1_NAME).
#    - targets are defined as "$($1_NAME)_{start,stop,init,clear}".
#    - paths for state/logs/etc are also derived from this name.
# $1_CONTAINERS = names the containers that will be started for this service.
#    - the container will be labelled $(HCP_RUN_DSPACE)$(name)_$x, for each x.
#    - if this is empty, a single container is launched without any _$x suffix.
# $1_CMD_INIT = script within the container for one-time initialization.
#    - only applies to services, must be empty for functions.
# $1_CMD_<x> (for each x in $1_CONTAINERS) = what to run within the container.
#    - if $1_CONTAINERS is empty, $1_CMD (no "_<x>") is the thing to run.
# $1_MOUNT = path within the container where state should be mounted.
#    - only used for services, ignored for functions.
# $1_MOUNT_<x> (for each x in $1_CONTAINERS) = optional mount args
#    - E.g. ":ro", if container 'x' should have a read-only mount.
# $1_ARGS_<x> (for each x in $1_CONTAINERS) = x-specific args to docker-run.
#    - services are run with "-d and --cidfile", functions are run with "--rm".
#      These ARGS parameters allows us to selectively add other flags.
#    - if a function provides a shell (e.g. if $1_CMD is "bash"), you probably
#      want to add "-i" and "-t".
#    - if a function runs as part of a CI pipeline, or should support pipes for
#      stdin and stdout, you probably do _NOT_ want to add both "-i" and "-t".
#      (See "man docker-run" for more detail.)
#    - ad-hoc host mounts (e.g. mounting "escapehatch" in the "client" and
#      "caboodle" functions) can be provided this way, as "-v <src>:<dest>".
# $1_ARGS = default args to pass to docker-run
#    - Only used when there's no 'x'. E.g. during init, and for
#      single-container where $1_CONTAINERS is empty.
#    - If you also want these args for each x in $1_CONTAINERS, simply define
#      $1_ARGS and then explicitly append it to each $1_ARGS_<x>!
#
# Note, we first define a dedicated subroutine, which relies on variables set
# by the hcp_run_create() parent. Don't call the subroutine directly!
# Subroutine parameters;
# $1 = entry from $(name)_CONTAINERS, or empty for a single-container service.
# $2 = script to be run
# $3 = optional mount args

define sub_hcp_run_create_container
$(eval cname := $(strip $1))
$(eval csuffix := $(if $(cname),_$(cname),))
$(eval cstarted := $(filter $(fullName)$(csuffix),$(HCP_RUN_ALL_CONTAINERS)))
$(eval started := $(started)$(cstarted))
$(eval crunning := $(filter $(fullName)$(csuffix),$(HCP_RUN_LIVE_CONTAINERS)))
$(eval ctarget := $(HCP_RUN_MGMT)/$(name)$(csuffix).started)
$(eval cid := $(HCP_RUN_MGMT)/$(name)$(csuffix).cid)
$(eval clastExit := $(HCP_RUN_MGMT)/$(name)$(csuffix).lastExitCode)
$(eval log := $(HCP_RUN_LOGS)/$(name)$(csuffix).`date +%Y-%m-%d`)
$(eval cenvs := $($(prefix)_ARGS$(csuffix)))
$(eval HCP_RUN_$(name)$(csuffix)_TGT_START := $(ctarget))
$(eval dockFlags := $(if $(isFunction),--rm,-d --cidfile=$(cid)))
$(eval mountFlags := $(if $(isFunction),,-v $(state):$(mount)$3))
# Service start
$(if $(isFunction),,\
$(if $(NO_REINIT),\
$(ctarget): | $(initTgt),
$(ctarget): $(initTgt)))
$(ctarget):
	$Qrm -f $(cid)
	$Qrm -f $(clastExit)
	$Qecho "Starting '$(name)$(csuffix)'"
	$Sdocker run $(dockFlags) $(mountFlags) \
		--name $(HCP_RUN_DSPACE)$(name)$(csuffix) \
		--hostname $(name)$(csuffix) \
		$(if $(HCP_RUN_DNETWORKS),--network-alias $(name)$(csuffix)) \
		$(foreach i,$(HCP_RUN_DNETWORKS),--network $i ) \
		--label $(HCP_RUN_DSPACE)$(name)$(csuffix)=1 \
		--label $(HCP_RUN_DSPACE)all=1 \
		$(cenvs) \
		$(imgName) \
		$2
	$(if $(isFunction),,\
	$Qecho "Running '$(name)$(csuffix)' with CID=`cat $(cid)`"
	$Qecho "E.g. docker logs --follow `cat $(cid) | cut -c 1-6`"
	$Qtouch $$@)
$(if $(csuffix),\
$(name)_start: $(name)_start$(csuffix))
$(if $(cstarted),\
$(name)_start$(csuffix):
,\
$(name)_start$(csuffix): $(ctarget)
)
# Service stop
$(if $(isFunction),,\
$(if $(csuffix),\
$(name)_stop: $(name)_stop$(csuffix))
$(name)_stop$(csuffix): | $(HCP_RUN_LOGS)
$(name)_stop$(csuffix):
	$(if $(cstarted),$(if $(crunning),\
		$Sdocker container stop --time=0 `cat $(cid)`,\
		$Qecho "'$(name)$(csuffix)' already exited, was there a problem?")
	$Sdocker container wait `cat $(cid)` > $(clastExit)
	$Sdocker logs `cat $(cid)` >> $(log) 2>> $(log).stderr
	$Sdocker container rm `cat $(cid)`
	$Qrm -f $(ctarget)
	$Qrm -f $(cid)
	$Qecho "Stopped '$(name)$(csuffix)'"
	$Qecho "Output backed up to $(log)"))
endef

define hcp_run_create
$(eval prefix := $(strip $1))
$(eval name := $($(prefix)_NAME))
$(eval fullName := $(HCP_RUN_DSPACE)$(name))
$(eval imgName := $(HCP_RUN_DSPACE)$(name)$(HCP_RUN_DTAG))
$(eval state := $(HCP_RUN_STATE)/$(name))
$(eval containers := $($(prefix)_CONTAINERS))
$(eval cmdInit := $(strip $($(prefix)_CMD_INIT)))
$(eval isFunction := $(if $(cmdInit),,yes))
$(eval mount := $(if $(isFunction),,$($(prefix)_MOUNT)))
$(eval envs := $($(prefix)_ARGS))
$(eval started := )
$(eval initTgt := $(if $(isFunction),,$(HCP_RUN_MGMT)/$(name).initialized))
$(eval initDone := $(if $(isFunction),,$(shell stat -f $(initTgt) > /dev/null 2>&1 && echo yes)))
$(eval HCP_RUN_LIST += $(name))
$(eval HCP_RUN_$(name)_TGT_INIT := $(initTgt))
$(eval HCP_RUN_$(name)_CONTAINERS := $(containers))
# start/stop for each sub-service
$(if $(containers),\
	$(foreach i,$(containers),\
		$(eval $(call sub_hcp_run_create_container,\
			$i,$($(prefix)_CMD_$i),$($(prefix)_MOUNT_$i))))\
,\
	$(eval $(call sub_hcp_run_create_container,,$($(prefix)_CMD))))
# State initialization (only for services, skipped for functions)
$(if $(isFunction),,\
$(initTgt): | $(HCP_RUN_MGMT) $(HCP_RUN_STATE)
$(initTgt):
	$(if $(started),\
		$Qecho "Error: cannot reinitialize '$(name)' state without stopping it."
		$Qecho "Do 'make $(name)_stop' to stop it."
		$Qexit 1)
	$(if $(initDone),$(if $(FORCE),\
		$Qecho "Forcibly removing '$(name)' state"
		$QUTIL_IMAGE=$(HCP_RUN_UTIL_IMAGE) \
			$(HCP_RUN_ASSIST_CLEANUP) volume $(state),\
		$Qecho "State for '$(name)' exists, needs reinitialization."
		$Qecho "Do 'make $(name)_clean', or set FORCE=1 and I will do it."
		$Qecho "(Or set NO_REINIT=1 to override the initialization dependency.)"
		$Qexit 1))
	$Qecho "Initializing '$(name)' state"
	$Sdocker run -i --rm \
		-v $(state):$(mount) \
		--name $(HCP_RUN_DSPACE)$(name)_init \
		--hostname $(name) \
		$(if $(HCP_RUN_DNETWORKS),--network-alias $(name)) \
		$(foreach i,$(HCP_RUN_DNETWORKS),--network $i ) \
		--label $(HCP_RUN_DSPACE)$(name)_init=1 \
		--label $(HCP_RUN_DSPACE)all=1 \
		$(envs) \
		$(imgName) \
		$(cmdInit)
	$Qtouch $$@
$(name)_init: $(initTgt)
# State cleanup
$(if $(started),$(if $(FORCE),\
$(name)_clean: $(name)_stop
))
$(if $(initDone),\
clean_hcp_run: $(name)_clean
)
$(name)_clean:
	$(if $(started),$(if $(FORCE),,\
		$Qecho "Error, the '$(name)' service is running. Stop it before cleaning."
		$Qecho "(Or set FORCE=1 and I will do it.)"
		$Qexit 1))
	$(if $(shell test -d $(state) > /dev/null 2>&1 && echo yes),\
		$QUTIL_IMAGE=$(HCP_RUN_UTIL_IMAGE) \
			$(HCP_RUN_ASSIST_CLEANUP) volume $(state)
		$Qrm -f $(HCP_RUN_LOGS)/$(name)*
		$Qrm -f $(HCP_RUN_MGMT)/$(name)*
		$Qrm -f $(initTgt))
)
endef

# Declare the enrollment service
HCP_RUN_ENROLL_NAME := enrollsvc
HCP_RUN_ENROLL_CONTAINERS := mgmt repl
HCP_RUN_ENROLL_CMD_INIT := /hcp/enrollsvc/setup_enrolldb.sh
HCP_RUN_ENROLL_CMD_mgmt := /hcp/enrollsvc/run_mgmt.sh
HCP_RUN_ENROLL_CMD_repl := /hcp/enrollsvc/run_repl.sh
HCP_RUN_ENROLL_MOUNT := /enrollsvc
HCP_RUN_ENROLL_MOUNT_mgmt := :rw
HCP_RUN_ENROLL_MOUNT_repl := :ro
HCP_RUN_ENROLL_ARGS := --env HCP_ENROLLSVC_STATE_PREFIX="$(HCP_RUN_ENROLL_MOUNT)"
HCP_RUN_ENROLL_ARGS += -v $(HCP_RUN_ENROLL_SIGNER):/signer
HCP_RUN_ENROLL_ARGS += --env HCP_RUN_ENROLL_SIGNER="/signer"
HCP_RUN_ENROLL_ARGS += --env HCP_RUN_ENROLL_UWSGI="$(HCP_RUN_ENROLL_UWSGI)"
HCP_RUN_ENROLL_ARGS += --env HCP_RUN_ENROLL_UWSGI_PORT="$(HCP_RUN_ENROLL_UWSGI_PORT)"
HCP_RUN_ENROLL_ARGS += --env HCP_RUN_ENROLL_UWSGI_FLAGS="$(HCP_RUN_ENROLL_UWSGI_FLAGS)"
HCP_RUN_ENROLL_ARGS += --env HCP_RUN_ENROLL_UWSGI_OPTIONS="$(HCP_RUN_ENROLL_UWSGI_OPTIONS)"
HCP_RUN_ENROLL_ARGS += --env HCP_RUN_ENROLL_GITDAEMON="$(HCP_RUN_ENROLL_GITDAEMON)"
HCP_RUN_ENROLL_ARGS += --env HCP_RUN_ENROLL_GITDAEMON_FLAGS="$(HCP_RUN_ENROLL_GITDAEMON_FLAGS)"
HCP_RUN_ENROLL_ARGS_mgmt := $(HCP_RUN_ENROLL_ARGS) $(HCP_RUN_ENROLL_XTRA_MGMT)
HCP_RUN_ENROLL_ARGS_repl := $(HCP_RUN_ENROLL_ARGS) $(HCP_RUN_ENROLL_XTRA_REPL)
$(if $(filter enroll,$(HCP_RUN_SERVICES)),$(eval $(call hcp_run_create,HCP_RUN_ENROLL)))

# Declare the attestation service
HCP_RUN_ATTEST_NAME := attestsvc
HCP_RUN_ATTEST_CONTAINERS := repl hcp
HCP_RUN_ATTEST_CMD_INIT := /hcp/attestsvc/setup_repl.sh
HCP_RUN_ATTEST_CMD_repl := /hcp/attestsvc/run_repl.sh
HCP_RUN_ATTEST_CMD_hcp := /hcp/attestsvc/run_hcp.sh
HCP_RUN_ATTEST_MOUNT := /attestsvc
HCP_RUN_ATTEST_MOUNT_repl := :rw
HCP_RUN_ATTEST_MOUNT_hcp := :ro
HCP_RUN_ATTEST_ARGS := --env HCP_ATTESTSVC_STATE_PREFIX="$(HCP_RUN_ATTEST_MOUNT)"
HCP_RUN_ATTEST_ARGS += --env HCP_ATTESTSVC_REMOTE_REPO="$(HCP_RUN_ATTEST_REMOTE_REPO)"
HCP_RUN_ATTEST_ARGS += --env HCP_ATTESTSVC_UPDATE_TIMER="$(HCP_RUN_ATTEST_UPDATE_TIMER)"
HCP_RUN_ATTEST_ARGS += --env SAFEBOOT_UWSGI="$(HCP_RUN_ATTEST_UWSGI)"
HCP_RUN_ATTEST_ARGS += --env SAFEBOOT_UWSGI_PORT="$(HCP_RUN_ATTEST_UWSGI_PORT)"
HCP_RUN_ATTEST_ARGS += --env SAFEBOOT_UWSGI_FLAGS="$(HCP_RUN_ATTEST_UWSGI_FLAGS)"
HCP_RUN_ATTEST_ARGS += --env SAFEBOOT_UWSGI_OPTIONS="$(HCP_RUN_ATTEST_UWSGI_OPTIONS)"
HCP_RUN_ATTEST_ARGS_repl := $(HCP_RUN_ATTEST_ARGS) $(HCP_RUN_ATTEST_XTRA_REPL)
HCP_RUN_ATTEST_ARGS_hcp := $(HCP_RUN_ATTEST_ARGS) $(HCP_RUN_ATTEST_XTRA_HCP)
$(if $(filter attest,$(HCP_RUN_SERVICES)),$(eval $(call hcp_run_create,HCP_RUN_ATTEST)))

# Declare the swtpm service
HCP_RUN_SWTPM_NAME := swtpmsvc
HCP_RUN_SWTPM_CMD_INIT := /hcp/swtpmsvc/setup_swtpm.sh
HCP_RUN_SWTPM_CMD := /hcp/swtpmsvc/run_swtpm.sh
HCP_RUN_SWTPM_MOUNT := /swtpmsvc
HCP_RUN_SWTPM_ARGS := --env HCP_SWTPMSVC_STATE_PREFIX="$(HCP_RUN_SWTPM_MOUNT)"
HCP_RUN_SWTPM_ARGS += --env HCP_SWTPMSVC_ENROLL_HOSTNAME="$(HCP_RUN_SWTPM_ENROLL_HOSTNAME)"
HCP_RUN_SWTPM_ARGS += --env HCP_SWTPMSVC_ENROLL_API="$(HCP_RUN_SWTPM_ENROLL_API)"
HCP_RUN_SWTPM_ARGS += $(HCP_RUN_SWTPM_XTRA)
$(if $(filter swtpm,$(HCP_RUN_SERVICES)),$(eval $(call hcp_run_create,HCP_RUN_SWTPM)))

# Declare the client function
HCP_RUN_CLIENT_NAME := client
HCP_RUN_CLIENT_CMD_INIT :=
HCP_RUN_CLIENT_CMD := /hcp/client/run_client.sh
HCP_RUN_CLIENT_ARGS := -v $(HCP_RUN_CLIENT_VERIFIER):/verifier
HCP_RUN_CLIENT_ARGS += --env HCP_RUN_CLIENT_VERIFIER=/verifier
HCP_RUN_CLIENT_ARGS += --env HCP_RUN_CLIENT_TPM2TOOLS_TCTI="$(HCP_RUN_CLIENT_TPM2TOOLS_TCTI)"
HCP_RUN_CLIENT_ARGS += --env HCP_CLIENT_ATTEST_URL="$(HCP_RUN_CLIENT_ATTEST_URL)"
HCP_RUN_CLIENT_ARGS += -v $(shell pwd):/escapehatch
$(eval $(call hcp_run_create,HCP_RUN_CLIENT))

# Declare the caboodle function. If HCP_RUN_CABOODLE_TEST is defined, this runs
# "test-everything.sh", otherwise (by default), this runs "bash" (with "-it").
HCP_RUN_CABOODLE_NAME := caboodle
HCP_RUN_CABOODLE_CMD_INIT :=
ifeq (,$(HCP_RUN_CABOODLE_TEST))
HCP_RUN_CABOODLE_CMD := bash
HCP_RUN_CABOODLE_ARGS := -it
else
HCP_RUN_CABOODLE_CMD := /test-everything.sh
HCP_RUN_CABOODLE_ARGS :=
endif
HCP_RUN_CABOODLE_ARGS += -v $(shell pwd):/escapehatch
$(eval $(call hcp_run_create,HCP_RUN_CABOODLE))

# Inter-service dependencies;
$(if $(filter attest,$(HCP_RUN_SERVICES)),$(if $(filter enroll,$(HCP_RUN_SERVICES)),\
$(HCP_RUN_attestsvc_TGT_INIT): | $(HCP_RUN_enrollsvc_repl_TGT_START)))
$(if $(filter swtpm,$(HCP_RUN_SERVICES)),$(if $(filter enroll,$(HCP_RUN_SERVICES)),\
$(HCP_RUN_swtpmsvc_TGT_INIT): | $(HCP_RUN_enrollsvc_mgmt_TGT_START)))
$(if $(filter swtpm,$(HCP_RUN_SERVICES)),\
$(HCP_RUN_client_TGT_START): | $(HCP_RUN_swtpmsvc_TGT_START))
$(if $(filter attest,$(HCP_RUN_SERVICES)),\
$(HCP_RUN_client_TGT_START): | $(HCP_RUN_attestsvc_hcp_TGT_START))

# Same comment as the $(MDIRS) target in safeboot/Makefile
$(HCP_RUN_MDIRS):
	$Qmkdir $@

# Special handling. If HCP_RUN_ENROLL_SIGNER_AUTOCREATE is "yes", we want to
# create a lazy-init rule to construct the asset-signing key.
ifeq (yes,$(HCP_RUN_ENROLL_SIGNER_AUTOCREATE))
$(HCP_RUN_enrollsvc_TGT_INIT): | $(HCP_RUN_ENROLL_SIGNER)/key.pem
$(HCP_RUN_enrollsvc_TGT_INIT): | $(HCP_RUN_CLIENT_VERIFIER)/key.pem
$(HCP_RUN_ENROLL_SIGNER)/key.priv: | $(HCP_RUN_ENROLL_SIGNER)
	$Qopenssl genrsa -out $@
$(HCP_RUN_ENROLL_SIGNER)/key.pem: $(HCP_RUN_ENROLL_SIGNER)/key.priv
	$Qopenssl rsa -pubout -in $< -out $@
$(HCP_RUN_CLIENT_VERIFIER)/key.pem: $(HCP_RUN_ENROLL_SIGNER)/key.pem | $(HCP_RUN_CLIENT_VERIFIER)
	$Qcp $< $@
endif

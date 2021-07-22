HCP_ATTESTSVC_SRC := $(HCP_SRC)/attestsvc
HCP_ATTESTSVC_OUT := $(HCP_OUT)/attestsvc

$(HCP_ATTESTSVC_OUT): | $(HCP_OUT)
MDIRS += $(HCP_ATTESTSVC_OUT)

clean_hcp_attestsvc:
ifeq (yes,$(shell stat $(HCP_ATTESTSVC_OUT) > /dev/null 2>&1 && echo yes))
	$Qrmdir $(HCP_ATTESTSVC_OUT)
endif
# Some summary notes about the attestment service, a.k.a. "attestsvc".
#
# This service consists of two containers (distinct images), "attestsvc-hcp"
# and "attestsvc-repl", which perform complementary functions but operate on
# common state (a directory bind-mounted into both containers);
#  * The common state consists of;
#    - clones of the enrollment database, that are updated from the Enrollment
#      Service (enrollsvc-repl) and rotated by the 'attestsvc-repl' container.
#    - a "msgbus" directory, into which;
#      - the services write their stdout/stderr,
#      - control software outside the service containers can write commands to
#        be picked up by the services. Currently, this is limited to "stop"
#        functionality, which writes "die" to a file the service is
#        "tail_wait"ing, triggering it to exit.
#  * "attestsvc-hcp" provides the attestation endpoint for HCP clients (hosts).
#    - The common state is mounted read-only!
#    - After setting up the environment and dropping privileges, control is
#      passed entirely to safeboot/attest-server (outside this "hcp" source
#      tree) to accept connections and respond to attestation requests.
#  * "attestsvc-repl" handles replication and updating of (local) common state.
#    - The common state is mounted read-write.
#    - This service provides fault-tolerance and reliability;
#      - Inability to reach the Enrollment Service is logged, and results in
#        less frequent retries until connectivity is reestablished.
#      - Any failures or anomalies in the pulling of updates (non-linear
#        updates to history, merge conflicts, corruptions, ...) are rolled back
#        transactionally (and logged).
#      - The priority at all times is to preserve the integrity of the
#        enrollment database clone that is currently used by the attestation
#        endpoint. This will only get swapped out for an updated clone as/when
#        a successful update completes.
#    - A simple timeout mechanism is used (for now) to limit the rate at which
#      updates and clone-rotation occurs.
#      - This ensures that processing of an attestation request (from an HCP
#        client) occurs in a clone that is guaranteed not to change for at
#        least that timeout period.
#
# For reasons outlined in common.Dockerfile, we build an 'attestsvc-common'
# image to be a common ancestor of attestsvc-repl and attestsvc-hcp.

# wrapper targets to build the "attestsvc" images
hcp_attestsvc-repl: $(HCP_ATTESTSVC_OUT)/repl.built
hcp_attestsvc-hcp: $(HCP_ATTESTSVC_OUT)/hcp.built
hcp_attestsvc: hcp_attestsvc-repl hcp_attestsvc-hcp

# This Makefile for attestsvc is modeled heavily on the Makefile for enrollsvc.
# As such, I have removed comments in many places, not because they're not
# justified but because there is no need to repeat them. Please consult the
# other Makefile for more explanatory comments. (And please maintain the
# similarities between these files, or re-comment things if they must diverge.)

HCP_USER := lowlyuser


####################
# attestsvc-common #
####################

MDIRS += $(HCP_ATTESTSVC_OUT)/common
$(HCP_ATTESTSVC_OUT)/common: | $(HCP_ATTESTSVC_OUT)

$(HCP_ATTESTSVC_OUT)/common/common.sh: | $(HCP_ATTESTSVC_OUT)/common
$(HCP_ATTESTSVC_OUT)/common/common.sh: $(HCP_ATTESTSVC_SRC)/common.sh
$(HCP_ATTESTSVC_OUT)/common/common.sh:
	$Qcp $< $@

$(HCP_ATTESTSVC_OUT)/common/tail_wait.pl: | $(HCP_ATTESTSVC_OUT)/common
$(HCP_ATTESTSVC_OUT)/common/tail_wait.pl: $(HCP_SRC)/tail_wait.pl
$(HCP_ATTESTSVC_OUT)/common/tail_wait.pl:
	$Qcp $< $@

$(HCP_ATTESTSVC_OUT)/common.Dockerfile: | $(HCP_ATTESTSVC_OUT)
$(HCP_ATTESTSVC_OUT)/common.Dockerfile: $(HCP_ATTESTSVC_SRC)/Makefile
$(HCP_ATTESTSVC_OUT)/common.Dockerfile: $(HCP_ATTESTSVC_SRC)/common.Dockerfile
$(HCP_ATTESTSVC_OUT)/common.Dockerfile:
	$Qecho "FROM $(SAFEBOOT_HCP_DSPACE)$(HCP_BASE_IMAGE)" > $@
	$Qcat $(HCP_ATTESTSVC_SRC)/common.Dockerfile >> $@

# "docker build" to create the container image (recipe only)
$(HCP_ATTESTSVC_OUT)/common.built: $(HCP_ATTESTSVC_OUT)/common.Dockerfile
$(HCP_ATTESTSVC_OUT)/common.built: $(HCP_ATTESTSVC_OUT)/common/common.sh
$(HCP_ATTESTSVC_OUT)/common.built: $(HCP_ATTESTSVC_OUT)/common/tail_wait.pl
$(HCP_ATTESTSVC_OUT)/common.built: $(HCP_BASE_TOUCHFILE)
$(HCP_ATTESTSVC_OUT)/common.built:
	$Qdocker build -t $(SAFEBOOT_HCP_DSPACE)attestsvc-common \
	               -f $(HCP_ATTESTSVC_OUT)/common.Dockerfile \
		       --build-arg HCP_USER=$(HCP_USER) \
	               $(HCP_ATTESTSVC_OUT)/common/
	$Qtouch $@

# "docker image rm" to remove the container image (interface and recipe)
clean_hcp_attestsvc-common:
ifeq (yes,$(shell stat $(HCP_ATTESTSVC_OUT)/common.built > /dev/null 2>&1 && echo yes))
	$Qdocker image rm $(SAFEBOOT_HCP_DSPACE)attestsvc-common
	$Qrm $(HCP_ATTESTSVC_OUT)/common.built
	$Qrm $(HCP_ATTESTSVC_OUT)/common.Dockerfile
endif
ifeq (yes,$(shell stat $(HCP_ATTESTSVC_OUT)/common > /dev/null 2>&1 && echo yes))
	$Qrm -rf $(HCP_ATTESTSVC_OUT)/common
endif

##################
# attestsvc-hcp #
##################

MDIRS += $(HCP_ATTESTSVC_OUT)/hcp
$(HCP_ATTESTSVC_OUT)/hcp: | $(HCP_ATTESTSVC_OUT)

# The only local (attestsvc-specific) sources we need are two scripts. As such,
# bypass the scripting and Dockerfile-substitution gymnastics in
# attestsvc-repl.
$(HCP_ATTESTSVC_OUT)/hcp/run_hcp.sh: | $(HCP_ATTESTSVC_OUT)/hcp
$(HCP_ATTESTSVC_OUT)/hcp/run_hcp.sh: $(HCP_ATTESTSVC_SRC)/run_hcp.sh
$(HCP_ATTESTSVC_OUT)/hcp/run_hcp.sh:
	$Qcp $< $@
$(HCP_ATTESTSVC_OUT)/hcp/wrapper-attest-server.sh: | $(HCP_ATTESTSVC_OUT)/hcp
$(HCP_ATTESTSVC_OUT)/hcp/wrapper-attest-server.sh: $(HCP_ATTESTSVC_SRC)/wrapper-attest-server.sh
$(HCP_ATTESTSVC_OUT)/hcp/wrapper-attest-server.sh:
	$Qcp $< $@
HCP_ATTESTSVC_HCP_PATHS := \
	$(HCP_ATTESTSVC_OUT)/hcp/run_hcp.sh \
	$(HCP_ATTESTSVC_OUT)/hcp/wrapper-attest-server.sh

# Inject the "SAFEBOOT_SBIN" files. Same comments as for enrollsvc-hcp.
MDIRS += $(HCP_ATTESTSVC_OUT)/hcp/safeboot-sbin
MDIRS += $(HCP_ATTESTSVC_OUT)/hcp/safeboot-xtra
$(HCP_ATTESTSVC_OUT)/hcp/safeboot-sbin: | $(HCP_ATTESTSVC_OUT)/hcp
$(HCP_ATTESTSVC_OUT)/hcp/safeboot-xtra: | $(HCP_ATTESTSVC_OUT)/hcp

HCP_ATTESTSVC_SAFEBOOT_SBIN := $(shell cd $(TOP)/sbin && ls -1)
HCP_ATTESTSVC_SAFEBOOT_XTRA := functions.sh safeboot.conf
define enrollsvc_safeboot_file
$(HCP_ATTESTSVC_OUT)/hcp/safeboot-$2/$1: | $(HCP_ATTESTSVC_OUT)/hcp/safeboot-$2
$(HCP_ATTESTSVC_OUT)/hcp/safeboot-$2/$1: $(TOP)/$3/$1
$(HCP_ATTESTSVC_OUT)/hcp/safeboot-$2/$1:
	$Qcp $$< $$@
$(eval HCP_ATTESTSVC_HCP_PATHS += $(HCP_ATTESTSVC_OUT)/hcp/safeboot-$2/$1)
endef
$(foreach i,$(HCP_ATTESTSVC_SAFEBOOT_SBIN),$(eval $(call enrollsvc_safeboot_file,$i,sbin,sbin)))
$(foreach i,$(HCP_ATTESTSVC_SAFEBOOT_XTRA),$(eval $(call enrollsvc_safeboot_file,$i,xtra,.)))

# Dockerfile-generation
$(HCP_ATTESTSVC_OUT)/hcp.Dockerfile: | $(HCP_ATTESTSVC_OUT)
$(HCP_ATTESTSVC_OUT)/hcp.Dockerfile: $(HCP_ATTESTSVC_SRC)/Makefile
$(HCP_ATTESTSVC_OUT)/hcp.Dockerfile: $(HCP_ATTESTSVC_SRC)/hcp.Dockerfile
$(HCP_ATTESTSVC_OUT)/hcp.Dockerfile:
	$Qecho "FROM $(SAFEBOOT_HCP_DSPACE)attestsvc-common" > $@
	$Qcat $(HCP_ATTESTSVC_SRC)/hcp.Dockerfile >> $@

# "docker build" to create the container image (recipe only)
$(HCP_ATTESTSVC_OUT)/hcp.built: $(HCP_ATTESTSVC_OUT)/hcp.Dockerfile
$(HCP_ATTESTSVC_OUT)/hcp.built: $(HCP_ATTESTSVC_HCP_PATHS)
$(HCP_ATTESTSVC_OUT)/hcp.built: $(HCP_ATTESTSVC_OUT)/common.built
$(HCP_ATTESTSVC_OUT)/hcp.built:
	$Qdocker build -t $(SAFEBOOT_HCP_DSPACE)attestsvc-hcp \
	               -f $(HCP_ATTESTSVC_OUT)/hcp.Dockerfile \
	               $(HCP_ATTESTSVC_OUT)/hcp/
	$Qtouch $@

# "docker image rm" to remove the container image (interface and recipe)
clean_hcp_attestsvc-hcp:
ifeq (yes,$(shell stat $(HCP_ATTESTSVC_OUT)/hcp.built > /dev/null 2>&1 && echo yes))
	$Qdocker image rm $(SAFEBOOT_HCP_DSPACE)attestsvc-hcp
	$Qrm $(HCP_ATTESTSVC_OUT)/hcp.built
	$Qrm $(HCP_ATTESTSVC_OUT)/hcp.Dockerfile
endif
ifeq (yes,$(shell stat $(HCP_ATTESTSVC_OUT)/hcp > /dev/null 2>&1 && echo yes))
	$Qrm -rf $(HCP_ATTESTSVC_OUT)/hcp
endif

##################
# attestsvc-repl #
##################

MDIRS += $(HCP_ATTESTSVC_OUT)/repl
$(HCP_ATTESTSVC_OUT)/repl: | $(HCP_ATTESTSVC_OUT)

#HCP_ATTESTSVC_REPL_FILES_NOEXEC := <unused>
HCP_ATTESTSVC_REPL_FILES_EXEC := \
	run_repl.sh setup_repl.sh init_clones.sh updater_loop.sh
HCP_ATTESTSVC_REPL_FILES := $(HCP_ATTESTSVC_REPL_FILES_NOEXEC) $(HCP_ATTESTSVC_REPL_FILES_EXEC)
HCP_ATTESTSVC_REPL_PATHS := $(foreach i,$(HCP_ATTESTSVC_REPL_FILES),$(HCP_ATTESTSVC_OUT)/repl/$i)

define attestsvc_repl_file
$(HCP_ATTESTSVC_OUT)/repl/$1: | $(HCP_ATTESTSVC_OUT)/repl
$(HCP_ATTESTSVC_OUT)/repl/$1: $(HCP_ATTESTSVC_SRC)/$1
$(HCP_ATTESTSVC_OUT)/repl/$1:
	$Qcp $$< $$@
endef
$(foreach i,$(HCP_ATTESTSVC_REPL_FILES),$(eval $(call attestsvc_repl_file,$i)))

# Dockerfile-generation. Same note as for hcp.Dockerfile above.
$(HCP_ATTESTSVC_OUT)/repl.Dockerfile: | $(HCP_ATTESTSVC_OUT)
$(HCP_ATTESTSVC_OUT)/repl.Dockerfile: $(HCP_ATTESTSVC_SRC)/Makefile
$(HCP_ATTESTSVC_OUT)/repl.Dockerfile: $(HCP_ATTESTSVC_SRC)/repl.Dockerfile
$(HCP_ATTESTSVC_OUT)/repl.Dockerfile:
	$Qecho "FROM $(SAFEBOOT_HCP_DSPACE)attestsvc-common" > $@
	$Qcat $(HCP_ATTESTSVC_SRC)/repl.Dockerfile | \
	sed -e "s/HCP_ATTESTSVC_REPL_FILES_NOEXEC/$(HCP_ATTESTSVC_REPL_FILES_NOEXEC)/" | \
	sed -e "s/HCP_ATTESTSVC_REPL_FILES_EXEC/$(HCP_ATTESTSVC_REPL_FILES_EXEC)/" >> $@

# "docker build" to create the container image (recipe only)
$(HCP_ATTESTSVC_OUT)/repl.built: $(HCP_ATTESTSVC_OUT)/repl.Dockerfile
$(HCP_ATTESTSVC_OUT)/repl.built: $(HCP_ATTESTSVC_REPL_PATHS)
$(HCP_ATTESTSVC_OUT)/repl.built: $(HCP_ATTESTSVC_OUT)/common.built
$(HCP_ATTESTSVC_OUT)/repl.built:
	$Qdocker build -t $(SAFEBOOT_HCP_DSPACE)attestsvc-repl \
	               -f $(HCP_ATTESTSVC_OUT)/repl.Dockerfile \
	               $(HCP_ATTESTSVC_OUT)/repl/
	$Qtouch $@

# "docker image rm" to remove the container image (interface and recipe)
clean_hcp_attestsvc-repl:
ifeq (yes,$(shell stat $(HCP_ATTESTSVC_OUT)/repl.built > /dev/null 2>&1 && echo yes))
	$Qdocker image rm $(SAFEBOOT_HCP_DSPACE)attestsvc-repl
	$Qrm $(HCP_ATTESTSVC_OUT)/repl.built
	$Qrm $(HCP_ATTESTSVC_OUT)/repl.Dockerfile
endif
ifeq (yes,$(shell stat $(HCP_ATTESTSVC_OUT)/repl > /dev/null 2>&1 && echo yes))
	$Qrm -rf $(HCP_ATTESTSVC_OUT)/repl
endif

################
# cleanup deps #
################

clean_hcp: clean_hcp_attestsvc

clean_hcp_base: clean_hcp_attestsvc-common

clean_hcp_attestsvc: clean_hcp_attestsvc-common

clean_hcp_attestsvc-common: clean_hcp_attestsvc-hcp
clean_hcp_attestsvc-common: clean_hcp_attestsvc-repl



# TODO: Same TODO note as in enrollsvc.

# Both the attestsvc containers mount the same state, which they expect to be
# at a path set by STATE_PREFIX. -repl mounts readwrite, -hcp mounts readonly.
HCP_ATTESTSVC_STATE := $(HCP_ATTESTSVC_OUT)/run
HCP_ATTESTSVC_STATE_PREFIX := /attestsvc

# Both containers also mount this 'msgbus' directory. Each of them redirects
# their stdout/stderr to a file in this directory (of the same name as their
# container image), and each of them listens for writes to a control file (same
# name plus a "-ctrl" suffix), which is currently only used for signaling the
# service to shut down (when "die" is written to that file).
HCP_ATTESTSVC_MSGBUS := $(HCP_ATTESTSVC_OUT)/msgbus
HCP_ATTESTSVC_MSGBUS_PREFIX := /msgbus

# Attestation Service instances need to clone and update from an Enrollment
# Service instance. These settings control where attestsvc pulls from and how
# frequent the updates will be (in seconds).
HCP_ATTESTSVC_REMOTE_REPO := git://enrollsvc-repl/enrolldb
HCP_ATTESTSVC_UPDATE_TIMER := 10

# Use these has the hostnames and network aliases
HCP_ATTESTSVC_REPL_HOSTNAME := attestsvc-repl
HCP_ATTESTSVC_HCP_HOSTNAME := attestsvc-hcp

########################
# Detect current state #
########################

ifeq (yes,$(shell test -d $(HCP_ATTESTSVC_STATE) > /dev/null 2>&1 && echo yes))
HCP_ATTESTSVC_INITIALIZED := 1
endif
ifeq (yes,$(shell stat $(HCP_ATTESTSVC_OUT)/hcp.run.started > /dev/null 2>&1 && echo yes))
HCP_ATTESTSVC_HCP_RUNNING := 1
endif
ifeq (yes,$(shell stat $(HCP_ATTESTSVC_OUT)/repl.run.started > /dev/null 2>&1 && echo yes))
HCP_ATTESTSVC_REPL_RUNNING := 1
endif
ifneq (,$(HCP_ATTESTSVC_REPL_RUNNING)$(HCP_ATTESTSVC_HCP_RUNNING))
HCP_ATTESTSVC_RUNNING := 1
endif

#########################
# Global/one-time state #
#########################

# "docker run [] setup_attestdb", for one-time initialization (recipe only)
ifdef NO_REINIT
$(HCP_ATTESTSVC_OUT)/run.initialized: | $(HCP_ATTESTSVC_OUT)/repl.built
$(HCP_ATTESTSVC_OUT)/run.initialized: | $(HCP_ATTESTSVC_OUT)/hcp.built
else
$(HCP_ATTESTSVC_OUT)/run.initialized: $(HCP_ATTESTSVC_OUT)/repl.built
$(HCP_ATTESTSVC_OUT)/run.initialized: $(HCP_ATTESTSVC_OUT)/hcp.built
endif
$(HCP_ATTESTSVC_OUT)/run.initialized: | $(HCP_OUT)/testnetwork.created
$(HCP_ATTESTSVC_OUT)/run.initialized: | $(HCP_ENROLLSVC_OUT)/repl.run.started
$(HCP_ATTESTSVC_OUT)/run.initialized:
ifdef HCP_ATTESTSVC_RUNNING
	$Qecho "Can't (re)initialize 'attestsvc' state while it is running."
	$Qecho "Do 'make hcp_attestsvc_run_stop' to stop it."
	$Qexit 1
endif
ifdef HCP_ATTESTSVC_INITIALIZED
ifndef FORCE
	$Qecho "State for 'attestsvc' exists, needs reinitialization."
	$Qecho "Do 'make clean_hcp_attestsvc_run', or set FORCE=1 and I"
	$Qecho "will do it for you."
	$Qecho "(Or set NO_REINIT=1 to override the initilization dependency.)"
	$Qexit 1
endif
	$Qrm -rf $(HCP_ATTESTSVC_STATE)
endif
	$Qmkdir $(HCP_ATTESTSVC_STATE)
	$Qdocker run -i --rm \
		-v $(HCP_ATTESTSVC_STATE):$(HCP_ATTESTSVC_STATE_PREFIX) \
		--env STATE_PREFIX="$(HCP_ATTESTSVC_STATE_PREFIX)" \
		--env REMOTE_REPO="$(HCP_ATTESTSVC_REMOTE_REPO)" \
		--env UPDATE_TIMER="$(HCP_ATTESTSVC_UPDATE_TIMER)" \
		--network $(HCP_TESTNETWORK_NAME) \
		--name $(HCP_ATTESTSVC_REPL_HOSTNAME) \
		--hostname $(HCP_ATTESTSVC_REPL_HOSTNAME) \
		--network-alias $(HCP_ATTESTSVC_REPL_HOSTNAME) \
		--label $(SAFEBOOT_HCP_DSPACE)all=1 \
		--label $(SAFEBOOT_HCP_DSPACE)attestsvc=1 \
		--label $(SAFEBOOT_HCP_DSPACE)attestsvc_repl=1 \
		--label $(SAFEBOOT_HCP_DSPACE)attestsvc_repl_setup=1 \
		$(SAFEBOOT_HCP_DSPACE)attestsvc-repl \
		/hcp/setup_repl.sh
	$Qecho "Done setting up 'attestsvc' state"
	$Qtouch $@

# "docker run [] setup_attestdb", for one-time initialization (interface only)
hcp_attestsvc_run_init: $(HCP_ATTESTSVC_OUT)/run.initialized

# "rm -rf attestdb" to remove one-time initialization (interface and recipe)
ifdef HCP_ATTESTSVC_RUNNING
ifdef FORCE
clean_hcp_attestsvc_run: hcp_attestsvc_run_stop
endif
endif
clean_hcp_attestsvc_run:
ifdef HCP_ATTESTSVC_RUNNING
ifndef FORCE
	$Qecho "Error, the service appears to be running. Stop it before cleaning."
	$Qecho "(Or set FORCE=1 and I'll automatically stop it for you.)"
	$Q/bin/false
endif
endif
ifdef HCP_ATTESTSVC_INITIALIZED
	$Qrm -rf $(HCP_ATTESTSVC_STATE)
	$Qrm -rf $(HCP_ATTESTSVC_MSGBUS)
	$Qrm -f $(HCP_ATTESTSVC_OUT)/run.initialized
	$Qrm -f $(HCP_ATTESTSVC_OUT)/hcp.run.*
	$Qrm -f $(HCP_ATTESTSVC_OUT)/repl.run.*
	$Qecho "Done cleaning up 'attestsvc' state"
endif

############################################
# attestsvc (wrappers for -repl and -hcp) #
############################################

hcp_attestsvc_run_start: hcp_attestsvc-repl_run_start
hcp_attestsvc_run_start: hcp_attestsvc-hcp_run_start

hcp_attestsvc_run_stop: hcp_attestsvc-repl_run_stop
hcp_attestsvc_run_stop: hcp_attestsvc-hcp_run_stop

##################
# attestsvc-repl #
##################

# "docker run [] run_repl.sh", to start the service (recipe only)
ifndef HCP_ATTESTSVC_REPL_RUNNING
$(HCP_ATTESTSVC_OUT)/repl.run.started: | $(HCP_OUT)/testnetwork.created
$(HCP_ATTESTSVC_OUT)/repl.run.started: $(HCP_ATTESTSVC_OUT)/run.initialized
$(HCP_ATTESTSVC_OUT)/repl.run.started:
	$Qmkdir -p $(HCP_ATTESTSVC_MSGBUS)
	$Qrm -f $(HCP_ATTESTSVC_MSGBUS)/attestsvc-repl*
	$Qrm -f $(HCP_ATTESTSVC_OUT)/repl.run.cid
	$Qrm -f $(HCP_ATTESTSVC_OUT)/repl.run.lastExitCode
	$Qrm -f $(HCP_ATTESTSVC_OUT)/repl.run.signaled
	$Qdocker run -d \
		--cidfile=$(HCP_ATTESTSVC_OUT)/repl.run.cid \
		-v $(HCP_ATTESTSVC_STATE):$(HCP_ATTESTSVC_STATE_PREFIX):rw \
		--env STATE_PREFIX="$(HCP_ATTESTSVC_STATE_PREFIX)" \
		--env REMOTE_REPO="$(HCP_ATTESTSVC_REMOTE_REPO)" \
		--env UPDATE_TIMER="$(HCP_ATTESTSVC_UPDATE_TIMER)" \
		-v $(HCP_ATTESTSVC_MSGBUS):$(HCP_ATTESTSVC_MSGBUS_PREFIX) \
		--network $(HCP_TESTNETWORK_NAME) \
		--name $(HCP_ATTESTSVC_REPL_HOSTNAME) \
		--hostname $(HCP_ATTESTSVC_REPL_HOSTNAME) \
		--network-alias $(HCP_ATTESTSVC_REPL_HOSTNAME) \
		--label $(SAFEBOOT_HCP_DSPACE)all=1 \
		--label $(SAFEBOOT_HCP_DSPACE)attestsvc=1 \
		--label $(SAFEBOOT_HCP_DSPACE)attestsvc_repl=1 \
		--label $(SAFEBOOT_HCP_DSPACE)attestsvc_repl_run=1 \
		$(SAFEBOOT_HCP_DSPACE)attestsvc-repl \
		/hcp/run_repl.sh
	$Qecho "Done starting 'attestsvc-repl'"
	$Qecho "Output at; $(HCP_ATTESTSVC_MSGBUS)/attestsvc-repl"
	$Qtouch $@
endif

# "echo die > attestsvc-repl-ctrl", signal service to exit (recipe only)
ifdef HCP_ATTESTSVC_REPL_RUNNING
$(HCP_ATTESTSVC_OUT)/repl.run.signaled: $(HCP_ATTESTSVC_OUT)/repl.run.started
	$Qecho "Signaling 'attestsvc-repl' to exit"
	$Qecho "die" > $(HCP_ATTESTSVC_MSGBUS)/attestsvc-repl-ctrl
	$Qtouch $@
endif

# "docker run [] run_repl.sh", to start the service (interface only)
ifndef HCP_ATTESTSVC_REPL_RUNNING
hcp_attestsvc-repl_run_start: $(HCP_ATTESTSVC_OUT)/repl.run.started
endif
hcp_attestsvc-repl_run_start:

# "docker {wait,rm}", to stop the service (interface and recipe)
hcp_attestsvc-repl_run_stop:
ifdef HCP_ATTESTSVC_REPL_RUNNING
	$Qdocker container wait `cat $(HCP_ATTESTSVC_OUT)/repl.run.cid` > \
		$(HCP_ATTESTSVC_OUT)/repl.run.lastExitCode
	$Qdocker container rm `cat $(HCP_ATTESTSVC_OUT)/repl.run.cid`
	$Qtest `cat $(HCP_ATTESTSVC_OUT)/repl.run.lastExitCode` -eq 0 && \
		echo "attestsvc-repl exited with SUCCESS" || \
		echo "attestsvc-repl exited with FAILURE!! (probably long ago)"
	$Qrm $(HCP_ATTESTSVC_OUT)/repl.run.started
	$Qrm $(HCP_ATTESTSVC_OUT)/repl.run.signaled
	$Qrm $(HCP_ATTESTSVC_OUT)/repl.run.cid
	$Qecho "Done stopping 'attestsvc-repl'"
hcp_attestsvc-repl_run_stop: $(HCP_ATTESTSVC_OUT)/repl.run.signaled
endif

#################
# attestsvc-hcp #
#################

# "docker run [] run_hcp.sh", to start the service (recipe only)
ifndef HCP_ATTESTSVC_HCP_RUNNING
$(HCP_ATTESTSVC_OUT)/hcp.run.started: | $(HCP_OUT)/testnetwork.created
$(HCP_ATTESTSVC_OUT)/hcp.run.started: $(HCP_ATTESTSVC_OUT)/run.initialized
$(HCP_ATTESTSVC_OUT)/hcp.run.started:
	$Qmkdir -p $(HCP_ATTESTSVC_MSGBUS)
	$Qrm -f $(HCP_ATTESTSVC_MSGBUS)/attestsvc-hcp*
	$Qrm -f $(HCP_ATTESTSVC_OUT)/hcp.run.cid
	$Qrm -f $(HCP_ATTESTSVC_OUT)/hcp.run.lastExitCode
	$Qrm -f $(HCP_ATTESTSVC_OUT)/hcp.run.signaled
	$Qdocker run -d \
		--cidfile=$(HCP_ATTESTSVC_OUT)/hcp.run.cid \
		-v $(HCP_ATTESTSVC_STATE):$(HCP_ATTESTSVC_STATE_PREFIX):ro \
		--env STATE_PREFIX="$(HCP_ATTESTSVC_STATE_PREFIX)" \
		--env REMOTE_REPO="$(HCP_ATTESTSVC_REMOTE_REPO)" \
		--env UPDATE_TIMER="$(HCP_ATTESTSVC_UPDATE_TIMER)" \
		-v $(HCP_ATTESTSVC_MSGBUS):$(HCP_ATTESTSVC_MSGBUS_PREFIX) \
		--network $(HCP_TESTNETWORK_NAME) \
		--name $(HCP_ATTESTSVC_HCP_HOSTNAME) \
		--hostname $(HCP_ATTESTSVC_HCP_HOSTNAME) \
		--network-alias $(HCP_ATTESTSVC_HCP_HOSTNAME) \
		-p 8080:8080 \
		--label $(SAFEBOOT_HCP_DSPACE)all=1 \
		--label $(SAFEBOOT_HCP_DSPACE)attestsvc=1 \
		--label $(SAFEBOOT_HCP_DSPACE)attestsvc_hcp=1 \
		--label $(SAFEBOOT_HCP_DSPACE)attestsvc_hcp_run=1 \
		$(SAFEBOOT_HCP_DSPACE)attestsvc-hcp \
		/hcp/run_hcp.sh
	$Qecho "Done starting 'attestsvc-hcp'"
	$Qecho "Output at; $(HCP_ATTESTSVC_MSGBUS)/attestsvc-hcp"
	$Qtouch $@
endif

# "echo die > attestsvc-hcp-ctrl", signal service to exit (recipe only)
ifdef HCP_ATTESTSVC_HCP_RUNNING
$(HCP_ATTESTSVC_OUT)/hcp.run.signaled: $(HCP_ATTESTSVC_OUT)/hcp.run.started
	$Qecho "Signaling 'attestsvc-hcp' to exit"
	$Qecho "die" > $(HCP_ATTESTSVC_MSGBUS)/attestsvc-hcp-ctrl
	$Qtouch $@
endif

# "docker run [] run_hcp.sh", to start the service (interface only)
ifndef HCP_ATTESTSVC_HCP_RUNNING
hcp_attestsvc-hcp_run_start: $(HCP_ATTESTSVC_OUT)/hcp.run.started
endif
hcp_attestsvc-hcp_run_start:

# "docker {wait,rm}", to stop the service (interface and recipe)
hcp_attestsvc-hcp_run_stop:
ifdef HCP_ATTESTSVC_HCP_RUNNING
	$Qdocker container wait `cat $(HCP_ATTESTSVC_OUT)/hcp.run.cid` > \
		$(HCP_ATTESTSVC_OUT)/hcp.run.lastExitCode
	$Qdocker container rm `cat $(HCP_ATTESTSVC_OUT)/hcp.run.cid`
	$Qtest `cat $(HCP_ATTESTSVC_OUT)/hcp.run.lastExitCode` -eq 0 && \
		echo "attestsvc-hcp exited with SUCCESS" || \
		echo "attestsvc-hcp exited with FAILURE!! (probably long ago)"
	$Qrm $(HCP_ATTESTSVC_OUT)/hcp.run.started
	$Qrm $(HCP_ATTESTSVC_OUT)/hcp.run.signaled
	$Qrm $(HCP_ATTESTSVC_OUT)/hcp.run.cid
	$Qecho "Done stopping 'attestsvc-hcp'"
hcp_attestsvc-hcp_run_stop: $(HCP_ATTESTSVC_OUT)/hcp.run.signaled
endif

################
# cleanup deps #
################

clean_hcp_attestsvc-hcp: clean_hcp_attestsvc_run
clean_hcp_attestsvc-repl: clean_hcp_attestsvc_run
clean_hcp_testnetwork: clean_hcp_attestsvc_run

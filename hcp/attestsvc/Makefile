HCP_ATTESTSVC_SRC := $(HCP_SRC)/attestsvc
HCP_ATTESTSVC_OUT := $(HCP_OUT)/attestsvc

$(HCP_ATTESTSVC_OUT): | $(HCP_OUT)
MDIRS += $(HCP_ATTESTSVC_OUT)

# Some summary notes about the attestment service, a.k.a. "attestsvc".
#
# This service consists of two sub-services; "hcp" and "repl", which perform
# complementary functions but operate on common state (a directory bind-mounted
# into both containers);
#  * The common state consists of;
#    - clones of the enrollment database, that are updated from the Enrollment
#      Service (enrollsvc-repl) and rotated by the 'attestsvc-repl' container.
#    - a "msgbus" directory, into which;
#      - the services write their stdout/stderr,
#      - control software outside the service containers can write commands to
#        be picked up by the services. Currently, this is limited to "stop"
#        functionality, which writes "die" to a file the service is
#        "tail_wait"ing, triggering it to exit.
#  * "attestsvc::hcp" provides the attestation endpoint for HCP clients (hosts).
#    - The common state is mounted read-only!
#    - After setting up the environment and dropping privileges, control is
#      passed entirely to safeboot/attest-server (outside this "hcp" source
#      tree) to accept connections and respond to attestation requests.
#  * "attestsvc::repl" handles replication and updating of (local) common state.
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

# wrapper targets to build the "attestsvc" images
hcp_attestsvc: $(HCP_ATTESTSVC_OUT)/built

# This Makefile for attestsvc is modeled heavily on the Makefile for enrollsvc.
# As such, I have removed comments in many places, not because they're not
# justified but because there is no need to repeat them. Please consult the
# other Makefile for more explanatory comments. (And please maintain the
# similarities between these files, or re-comment things if they must diverge.)

HCP_USER := lowlyuser


#############
# attestsvc #
#############

# Include the submodule bundle
HCP_ATTESTSVC_PATHS += $(HCP_ATTESTSVC_OUT)/install.tar.gz
$(HCP_ATTESTSVC_OUT)/install.tar.gz: | $(HCP_ATTESTSVC_OUT)
$(HCP_ATTESTSVC_OUT)/install.tar.gz: $(HCP_SUBMODULES_OUT)/install.tar.gz
$(HCP_ATTESTSVC_OUT)/install.tar.gz:
	$Qcp $< $@

# And the safeboot bundle
HCP_ATTESTSVC_PATHS += $(HCP_ATTESTSVC_OUT)/safeboot.tar.gz
$(HCP_ATTESTSVC_OUT)/safeboot.tar.gz: | $(HCP_ATTESTSVC_OUT)
$(HCP_ATTESTSVC_OUT)/safeboot.tar.gz: $(HCP_SCRIPTS_OUT)/safeboot.tar.gz
$(HCP_ATTESTSVC_OUT)/safeboot.tar.gz:
	$Qcp $< $@

# And the hcp-{common,attestsvc} bundles
HCP_ATTESTSVC_PATHS += $(HCP_ATTESTSVC_OUT)/hcp-common.tar.gz
HCP_ATTESTSVC_PATHS += $(HCP_ATTESTSVC_OUT)/hcp-attestsvc.tar.gz
$(HCP_ATTESTSVC_OUT)/hcp-common.tar.gz: | $(HCP_ATTESTSVC_OUT)
$(HCP_ATTESTSVC_OUT)/hcp-common.tar.gz: $(HCP_SCRIPTS_OUT)/hcp-common.tar.gz
$(HCP_ATTESTSVC_OUT)/hcp-common.tar.gz:
	$Qcp $< $@
$(HCP_ATTESTSVC_OUT)/hcp-attestsvc.tar.gz: | $(HCP_ATTESTSVC_OUT)
$(HCP_ATTESTSVC_OUT)/hcp-attestsvc.tar.gz: $(HCP_SCRIPTS_OUT)/hcp-attestsvc.tar.gz
$(HCP_ATTESTSVC_OUT)/hcp-attestsvc.tar.gz:
	$Qcp $< $@

# Dockerfile-generation.
$(HCP_ATTESTSVC_OUT)/Dockerfile: | $(HCP_ATTESTSVC_OUT)
$(HCP_ATTESTSVC_OUT)/Dockerfile: $(HCP_ATTESTSVC_SRC)/Makefile
$(HCP_ATTESTSVC_OUT)/Dockerfile: $(HCP_ATTESTSVC_SRC)/Dockerfile
$(HCP_ATTESTSVC_OUT)/Dockerfile: $(HCP_SUBMODULES_OUT)/install.tar.gz.inject
$(HCP_ATTESTSVC_OUT)/Dockerfile: $(HCP_SCRIPTS_OUT)/safeboot.tar.gz.inject
$(HCP_ATTESTSVC_OUT)/Dockerfile: $(HCP_SCRIPTS_OUT)/hcp-common.tar.gz.inject
$(HCP_ATTESTSVC_OUT)/Dockerfile: $(HCP_SCRIPTS_OUT)/hcp-attestsvc.tar.gz.inject
$(HCP_ATTESTSVC_OUT)/Dockerfile:
	$Qecho "FROM $(SAFEBOOT_HCP_DSPACE)$(HCP_BASE_IMAGE)" > $@
	$Qcat $(HCP_ATTESTSVC_SRC)/Dockerfile >> $@
	$Qcat $(HCP_SUBMODULES_OUT)/install.tar.gz.inject >> $@
	$Qcat $(HCP_SCRIPTS_OUT)/safeboot.tar.gz.inject >> $@
	$Qcat $(HCP_SCRIPTS_OUT)/hcp-common.tar.gz.inject >> $@
	$Qcat $(HCP_SCRIPTS_OUT)/hcp-attestsvc.tar.gz.inject >> $@
	$Qecho "$(call tarball_finalize)" >> $@

# "docker build" to create the container image (recipe only)
$(HCP_ATTESTSVC_OUT)/built: $(HCP_ATTESTSVC_OUT)/Dockerfile
$(HCP_ATTESTSVC_OUT)/built: $(HCP_ATTESTSVC_PATHS)
$(HCP_ATTESTSVC_OUT)/built: $(HCP_BASE_TOUCHFILE)
$(HCP_ATTESTSVC_OUT)/built:
	$Qdocker build -t $(SAFEBOOT_HCP_DSPACE)attestsvc \
	               --label $(SAFEBOOT_HCP_DSPACE)attestsvc=1 \
	               -f $(HCP_ATTESTSVC_OUT)/Dockerfile \
	               --build-arg HCP_USER=$(HCP_USER) \
	               $(HCP_ATTESTSVC_OUT)
	$Qtouch $@

# "docker image rm" to remove the container image (interface and recipe)
clean_hcp_attestsvc:
ifneq (,$(filter $(SAFEBOOT_HCP_DSPACE)attestsvc,$(HCP_EXISTING_IMAGES)))
	$Qdocker image rm $(SAFEBOOT_HCP_DSPACE)attestsvc
endif
	$Qrm -rf $(HCP_ATTESTSVC_OUT)

################
# cleanup deps #
################

clean_hcp_base: clean_hcp_attestsvc



# TODO: Same TODO note as in enrollsvc.

# Both the attestsvc containers mount the same state, which they expect to be
# at a path set by ATTESTSVC_STATE_PREFIX.
# -repl mounts readwrite, -hcp mounts readonly.
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
ifneq (,$(filter $(SAFEBOOT_HCP_DSPACE)attestsvc-hcp,$(HCP_EXISTING_CONTAINERS)))
HCP_ATTESTSVC_HCP_RUNNING := 1
endif
ifneq (,$(filter $(SAFEBOOT_HCP_DSPACE)attestsvc-repl,$(HCP_EXISTING_CONTAINERS)))
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
$(HCP_ATTESTSVC_OUT)/run.initialized: | $(HCP_ATTESTSVC_OUT)/built
else
$(HCP_ATTESTSVC_OUT)/run.initialized: $(HCP_ATTESTSVC_OUT)/built
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
		--env HCP_ATTESTSVC_STATE_PREFIX="$(HCP_ATTESTSVC_STATE_PREFIX)" \
		--env HCP_ATTESTSVC_REMOTE_REPO="$(HCP_ATTESTSVC_REMOTE_REPO)" \
		--env HCP_ATTESTSVC_UPDATE_TIMER="$(HCP_ATTESTSVC_UPDATE_TIMER)" \
		--network $(HCP_TESTNETWORK_NAME) \
		--name $(SAFEBOOT_HCP_DSPACE)attestsvc-repl \
		--hostname $(HCP_ATTESTSVC_REPL_HOSTNAME) \
		--network-alias $(HCP_ATTESTSVC_REPL_HOSTNAME) \
		--label $(SAFEBOOT_HCP_DSPACE)attestsvc_repl_setup=1 \
		$(SAFEBOOT_HCP_DSPACE)attestsvc \
		/hcp/attestsvc/setup_repl.sh
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
	$QUTIL_IMAGE=$(SAFEBOOT_HCP_BASE) \
		$(ASSIST_CLEANUP) volume $(HCP_ATTESTSVC_STATE)
	$QUTIL_IMAGE=$(SAFEBOOT_HCP_BASE) \
		$(ASSIST_CLEANUP) volume $(HCP_ATTESTSVC_MSGBUS)
	$Qrm -f $(HCP_ATTESTSVC_OUT)/run.initialized
	$Qrm -f $(HCP_ATTESTSVC_OUT)/hcp.run.*
	$Qrm -f $(HCP_ATTESTSVC_OUT)/repl.run.*
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
		--env HCP_ATTESTSVC_STATE_PREFIX="$(HCP_ATTESTSVC_STATE_PREFIX)" \
		--env HCP_ATTESTSVC_REMOTE_REPO="$(HCP_ATTESTSVC_REMOTE_REPO)" \
		--env HCP_ATTESTSVC_UPDATE_TIMER="$(HCP_ATTESTSVC_UPDATE_TIMER)" \
		-v $(HCP_ATTESTSVC_MSGBUS):$(HCP_ATTESTSVC_MSGBUS_PREFIX) \
		--network $(HCP_TESTNETWORK_NAME) \
		--name $(SAFEBOOT_HCP_DSPACE)attestsvc-repl \
		--hostname $(HCP_ATTESTSVC_REPL_HOSTNAME) \
		--network-alias $(HCP_ATTESTSVC_REPL_HOSTNAME) \
		--label $(SAFEBOOT_HCP_DSPACE)attestsvc_repl=1 \
		--label $(SAFEBOOT_HCP_DSPACE)attestsvc_repl_run=1 \
		$(SAFEBOOT_HCP_DSPACE)attestsvc \
		/hcp/attestsvc/run_repl.sh
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
		--env HCP_ATTESTSVC_STATE_PREFIX="$(HCP_ATTESTSVC_STATE_PREFIX)" \
		--env HCP_ATTESTSVC_REMOTE_REPO="$(HCP_ATTESTSVC_REMOTE_REPO)" \
		--env HCP_ATTESTSVC_UPDATE_TIMER="$(HCP_ATTESTSVC_UPDATE_TIMER)" \
		-v $(HCP_ATTESTSVC_MSGBUS):$(HCP_ATTESTSVC_MSGBUS_PREFIX) \
		--network $(HCP_TESTNETWORK_NAME) \
		--name $(SAFEBOOT_HCP_DSPACE)attestsvc-hcp \
		--hostname $(HCP_ATTESTSVC_HCP_HOSTNAME) \
		--network-alias $(HCP_ATTESTSVC_HCP_HOSTNAME) \
		-p 8080:8080 \
		--label $(SAFEBOOT_HCP_DSPACE)attestsvc_hcp=1 \
		--label $(SAFEBOOT_HCP_DSPACE)attestsvc_hcp_run=1 \
		$(SAFEBOOT_HCP_DSPACE)attestsvc \
		/hcp/attestsvc/run_hcp.sh
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

clean_hcp_attestsvc: clean_hcp_attestsvc_run
clean_hcp_testnetwork: clean_hcp_attestsvc_run

HCP_SWTPMSVC_SRC := $(HCP_SRC)/swtpmsvc
HCP_SWTPMSVC_OUT := $(HCP_OUT)/swtpmsvc

$(HCP_SWTPMSVC_OUT): | $(HCP_OUT)
MDIRS += $(HCP_SWTPMSVC_OUT)

# wrapper target to build the "swtpm" image
hcp_swtpmsvc: $(HCP_SWTPMSVC_OUT)/built

# Include the submodule bundle
HCP_SWTPMSVC_PATHS += $(HCP_SWTPMSVC_OUT)/install.tar.gz
$(HCP_SWTPMSVC_OUT)/install.tar.gz: | $(HCP_SWTPMSVC_OUT)
$(HCP_SWTPMSVC_OUT)/install.tar.gz: $(HCP_SUBMODULES_OUT)/install.tar.gz
$(HCP_SWTPMSVC_OUT)/install.tar.gz:
	$Qcp $< $@

# And the safeboot bundle
HCP_SWTPMSVC_PATHS += $(HCP_SWTPMSVC_OUT)/safeboot.tar.gz
$(HCP_SWTPMSVC_OUT)/safeboot.tar.gz: | $(HCP_SWTPMSVC_OUT)
$(HCP_SWTPMSVC_OUT)/safeboot.tar.gz: $(HCP_SCRIPTS_OUT)/safeboot.tar.gz
$(HCP_SWTPMSVC_OUT)/safeboot.tar.gz:
	$Qcp $< $@

# And the hcp-{common,swtpmsvc} bundles
HCP_SWTPMSVC_PATHS += $(HCP_SWTPMSVC_OUT)/hcp-common.tar.gz
HCP_SWTPMSVC_PATHS += $(HCP_SWTPMSVC_OUT)/hcp-swtpmsvc.tar.gz
$(HCP_SWTPMSVC_OUT)/hcp-common.tar.gz: | $(HCP_SWTPMSVC_OUT)
$(HCP_SWTPMSVC_OUT)/hcp-common.tar.gz: $(HCP_SCRIPTS_OUT)/hcp-common.tar.gz
$(HCP_SWTPMSVC_OUT)/hcp-common.tar.gz:
	$Qcp $< $@
$(HCP_SWTPMSVC_OUT)/hcp-swtpmsvc.tar.gz: | $(HCP_SWTPMSVC_OUT)
$(HCP_SWTPMSVC_OUT)/hcp-swtpmsvc.tar.gz: $(HCP_SCRIPTS_OUT)/hcp-swtpmsvc.tar.gz
$(HCP_SWTPMSVC_OUT)/hcp-swtpmsvc.tar.gz:
	$Qcp $< $@

# Dockerfile-generation.
$(HCP_SWTPMSVC_OUT)/Dockerfile: | $(HCP_SWTPMSVC_OUT)
$(HCP_SWTPMSVC_OUT)/Dockerfile: $(HCP_SWTPMSVC_SRC)/Makefile
$(HCP_SWTPMSVC_OUT)/Dockerfile: $(HCP_SWTPMSVC_SRC)/Dockerfile
$(HCP_SWTPMSVC_OUT)/Dockerfile: $(HCP_SUBMODULES_OUT)/install.tar.gz.inject
$(HCP_SWTPMSVC_OUT)/Dockerfile: $(HCP_SCRIPTS_OUT)/safeboot.tar.gz.inject
$(HCP_SWTPMSVC_OUT)/Dockerfile: $(HCP_SCRIPTS_OUT)/hcp-common.tar.gz.inject
$(HCP_SWTPMSVC_OUT)/Dockerfile: $(HCP_SCRIPTS_OUT)/hcp-swtpmsvc.tar.gz.inject
$(HCP_SWTPMSVC_OUT)/Dockerfile:
	$Qecho "FROM $(SAFEBOOT_HCP_DSPACE)$(HCP_BASE_IMAGE)" > $@
	$Qcat $(HCP_SWTPMSVC_SRC)/Dockerfile >> $@
	$Qcat $(HCP_SUBMODULES_OUT)/install.tar.gz.inject >> $@
	$Qcat $(HCP_SCRIPTS_OUT)/safeboot.tar.gz.inject >> $@
	$Qcat $(HCP_SCRIPTS_OUT)/hcp-common.tar.gz.inject >> $@
	$Qcat $(HCP_SCRIPTS_OUT)/hcp-swtpmsvc.tar.gz.inject >> $@

# "docker build" to create the container image (recipe only)
$(HCP_SWTPMSVC_OUT)/built: $(HCP_SWTPMSVC_OUT)/Dockerfile
$(HCP_SWTPMSVC_OUT)/built: $(HCP_SWTPMSVC_PATHS)
$(HCP_SWTPMSVC_OUT)/built: $(HCP_BASE_TOUCHFILE)
$(HCP_SWTPMSVC_OUT)/built:
	$Qdocker build -t $(SAFEBOOT_HCP_DSPACE)swtpmsvc \
	               --label $(SAFEBOOT_HCP_DSPACE)swtpmsvc=1 \
	               -f $(HCP_SWTPMSVC_OUT)/Dockerfile \
	               $(HCP_SWTPMSVC_OUT)
	$Qtouch $@

# "docker image rm" to remove the container image (interface and recipe)
clean_hcp_swtpmsvc:
ifneq (,$(filter $(SAFEBOOT_HCP_DSPACE)swtpmsvc,$(HCP_EXISTING_IMAGES)))
	$Qdocker image rm $(SAFEBOOT_HCP_DSPACE)swtpmsvc
endif
	$Qrm -rf $(HCP_SWTPMSVC_OUT)

# Cleanup ordering
clean_hcp_base: clean_hcp_swtpmsvc


# TODO: same comment as in hcp/enrollsvc/Makefile

HCP_SWTPMSVC_STATE := $(HCP_SWTPMSVC_OUT)/run
HCP_SWTPMSVC_STATE_PREFIX := /swtpmsvc

HCP_SWTPMSVC_MSGBUS := $(HCP_SWTPMSVC_OUT)/msgbus
HCP_SWTPMSVC_MSGBUS_PREFIX := /msgbus

# Basically, HCP_ENROLL_HOSTNAME is the hostname that the TPM's ek.pub will be
# enrolled for, the client will set its own hostname (HCP_CLIENT_HOSTNAME) to
# match it, and the swtpmsvc will set its hostname (HCP_SWTPMSVC_HOSTNAME) with a
# prefix; "swtpmsvc-$(HCP_ENROLL_HOSTNAME)".
HCP_ENROLL_HOSTNAME := example-host

# And this is the URL that swtpmsvc needs to hit to enroll itself
HCP_ENROLL_URL := http://$(HCP_ENROLLSVC_MGMT_HOSTNAME):5000/v1/add

HCP_SWTPMSVC_HOSTNAME := swtpmsvc-$(HCP_ENROLL_HOSTNAME)

########################
# Detect current state #
########################

ifeq (yes,$(shell test -d $(HCP_SWTPMSVC_STATE) > /dev/null 2>&1 && echo yes))
HCP_SWTPMSVC_INITIALIZED := 1
endif
ifneq (,$(filter $(SAFEBOOT_HCP_DSPACE)swtpmsvc,$(HCP_EXISTING_CONTAINERS)))
HCP_SWTPMSVC_RUNNING := 1
endif

#########################
# Global/one-time state #
#########################

# "docker run [] setup_swtpm", for one-time initialization (recipe only)
ifdef NO_REINIT
$(HCP_SWTPMSVC_OUT)/run.initialized: | $(HCP_SWTPMSVC_OUT)/built
else
$(HCP_SWTPMSVC_OUT)/run.initialized: $(HCP_SWTPMSVC_OUT)/built
endif
$(HCP_SWTPMSVC_OUT)/run.initialized: | $(HCP_OUT)/testnetwork.created
$(HCP_SWTPMSVC_OUT)/run.initialized: | $(HCP_ENROLLSVC_OUT)/mgmt.run.started
$(HCP_SWTPMSVC_OUT)/run.initialized:
ifdef HCP_SWTPMSVC_RUNNING
	$Qecho "Can't (re)initialize 'swtpmsvc' state while it is running."
	$Qecho "Do 'make hcp_swtpmsvc_run_stop' to stop it."
	$Qexit 1
endif
ifdef HCP_SWTPMSVC_INITIALIZED
ifndef FORCE
	$Qecho "State for 'swtpmsvc' exists, needs reinitialization."
	$Qecho "Do 'make clean_hcp_swtpmsvc_run', or set FORCE=1 and I"
	$Qecho "will do it for you."
	$Qecho "(Or set NO_REINIT=1 to override the initilization dependency.)"
	$Qexit 1
endif
	$Qrm -rf $(HCP_SWTPMSVC_STATE)
endif
	$Qmkdir $(HCP_SWTPMSVC_STATE)
	$Qdocker run -i --rm \
		-v $(HCP_SWTPMSVC_STATE):$(HCP_SWTPMSVC_STATE_PREFIX) \
		--env HCP_SWTPMSVC_STATE_PREFIX="$(HCP_SWTPMSVC_STATE_PREFIX)" \
		--env HCP_SWTPMSVC_ENROLL_HOSTNAME="$(HCP_ENROLL_HOSTNAME)" \
		--env HCP_SWTPMSVC_ENROLL_URL="$(HCP_ENROLL_URL)" \
		--network $(HCP_TESTNETWORK_NAME) \
		--name $(SAFEBOOT_HCP_DSPACE)swtpmsvc \
		--hostname $(HCP_SWTPMSVC_HOSTNAME) \
		--network-alias $(HCP_SWTPMSVC_HOSTNAME) \
		--label $(SAFEBOOT_HCP_DSPACE)swtpmsvc_setup=1 \
		$(SAFEBOOT_HCP_DSPACE)swtpmsvc \
		/hcp/swtpmsvc/setup_swtpm.sh
	$Qecho "Done setting up 'swtpmsvc' state"
	$Qtouch $@

# "docker run [] setup_swtpm", for one-time initialization (interface only)
hcp_swtpmsvc_run_init: $(HCP_SWTPMSVC_OUT)/run.initialized

# "rm -rf swtpmsvc" to remove one-time initialization (interface and recipe)
ifdef HCP_SWTPMSVC_RUNNING
ifdef FORCE
clean_hcp_swtpmsvc_run: hcp_swtpmsvc_run_stop
endif
endif
clean_hcp_swtpmsvc_run:
ifdef HCP_SWTPMSVC_RUNNING
ifndef FORCE
	$Qecho "Error, the service appears to be running. Stop it before cleaning."
	$Qecho "(Or set FORCE=1 and I'll automatically stop it for you.)"
	$Q/bin/false
endif
endif
ifdef HCP_SWTPMSVC_INITIALIZED
	$QUTIL_IMAGE=$(SAFEBOOT_HCP_BASE) \
		$(ASSIST_CLEANUP) volume $(HCP_SWTPMSVC_STATE)
	$QUTIL_IMAGE=$(SAFEBOOT_HCP_BASE) \
		$(ASSIST_CLEANUP) volume $(HCP_SWTPMSVC_MSGBUS)
	$Qrm -f $(HCP_SWTPMSVC_OUT)/run.initialized
	$Qrm -f $(HCP_SWTPMSVC_OUT)/run.*
endif

##############
# start/stop #
##############

# "docker run [] run_swtpm.sh", to start the service (recipe only)
ifndef HCP_SWTPMSVC_RUNNING
$(HCP_SWTPMSVC_OUT)/run.started: | $(HCP_OUT)/testnetwork.created
$(HCP_SWTPMSVC_OUT)/run.started: $(HCP_SWTPMSVC_OUT)/run.initialized
$(HCP_SWTPMSVC_OUT)/run.started:
	$Qmkdir -p $(HCP_SWTPMSVC_MSGBUS)
	$Qrm -f $(HCP_SWTPMSVC_MSGBUS)/swtpmsvc*
	$Qrm -f $(HCP_SWTPMSVC_OUT)/run.cid
	$Qrm -f $(HCP_SWTPMSVC_OUT)/run.lastExitCode
	$Qrm -f $(HCP_SWTPMSVC_OUT)/run.signaled
	$Qdocker run -d \
		--cidfile=$(HCP_SWTPMSVC_OUT)/run.cid \
		-v $(HCP_SWTPMSVC_STATE):$(HCP_SWTPMSVC_STATE_PREFIX):rw \
		--env HCP_SWTPMSVC_STATE_PREFIX="$(HCP_SWTPMSVC_STATE_PREFIX)" \
		--env HCP_SWTPMSVC_ENROLL_HOSTNAME="$(HCP_ENROLL_HOSTNAME)" \
		--env HCP_SWTPMSVC_ENROLL_URL="$(HCP_ENROLL_URL)" \
		-v $(HCP_SWTPMSVC_MSGBUS):$(HCP_SWTPMSVC_MSGBUS_PREFIX) \
		--network $(HCP_TESTNETWORK_NAME) \
		--name $(SAFEBOOT_HCP_DSPACE)swtpmsvc \
		--hostname $(HCP_SWTPMSVC_HOSTNAME) \
		--network-alias $(HCP_SWTPMSVC_HOSTNAME) \
		-p 9876:9876 \
		--label $(SAFEBOOT_HCP_DSPACE)swtpmsvc_run=1 \
		$(SAFEBOOT_HCP_DSPACE)swtpmsvc \
		/hcp/swtpmsvc/run_swtpm.sh
	$Qecho "Done starting 'swtpmsvc'"
	$Qecho "Output at; $(HCP_SWTPMSVC_MSGBUS)/swtpmsvc"
	$Qtouch $@
endif

# "echo die > swtpmsvc-ctrl", signal service to exit (recipe only)
ifdef HCP_SWTPMSVC_RUNNING
$(HCP_SWTPMSVC_OUT)/run.signaled: $(HCP_SWTPMSVC_OUT)/run.started
	$Qecho "Signaling 'swtpmsvc' to exit"
	$Qecho "die" > $(HCP_SWTPMSVC_MSGBUS)/swtpmsvc-ctrl
	$Qtouch $@
endif

# "docker run [] run_swtpm.sh", to start the service (interface only)
ifndef HCP_SWTPMSVC_RUNNING
hcp_swtpmsvc_run_start: $(HCP_SWTPMSVC_OUT)/run.started
endif
hcp_swtpmsvc_run_start:

# "docker {wait,rm}", to stop the service (interface and recipe)
hcp_swtpmsvc_run_stop:
ifdef HCP_SWTPMSVC_RUNNING
	$Qdocker container wait `cat $(HCP_SWTPMSVC_OUT)/run.cid` > \
		$(HCP_SWTPMSVC_OUT)/run.lastExitCode
	$Qdocker container rm `cat $(HCP_SWTPMSVC_OUT)/run.cid`
	$Qtest `cat $(HCP_SWTPMSVC_OUT)/run.lastExitCode` -eq 0 && \
		echo "swtpmsvc exited with SUCCESS" || \
		echo "swtpmsvc exited with FAILURE!! (probably long ago)"
	$Qrm $(HCP_SWTPMSVC_OUT)/run.started
	$Qrm $(HCP_SWTPMSVC_OUT)/run.signaled
	$Qrm $(HCP_SWTPMSVC_OUT)/run.cid
	$Qecho "Done stopping 'swtpmsvc'"
hcp_swtpmsvc_run_stop: $(HCP_SWTPMSVC_OUT)/run.signaled
endif

################
# cleanup deps #
################

clean_hcp_swtpmsvc: clean_hcp_swtpmsvc_run
clean_hcp_testnetwork: clean_hcp_swtpmsvc_run

HCP_SWTPM_SRC := $(HCP_SRC)/swtpm
HCP_SWTPM_OUT := $(HCP_OUT)/swtpm

$(HCP_SWTPM_OUT): | $(HCP_OUT)
MDIRS += $(HCP_SWTPM_OUT)

# wrapper target to build the "swtpm" image
hcp_swtpm: $(HCP_SWTPM_OUT)/built

HCP_SWTPM_FILES_NOEXEC := common.sh enroll.py
HCP_SWTPM_FILES_EXEC := run_swtpm.sh setup_swtpm.sh
HCP_SWTPM_FILES := $(HCP_SWTPM_FILES_NOEXEC) $(HCP_SWTPM_FILES_EXEC)
HCP_SWTPM_PATHS := $(foreach i,$(HCP_SWTPM_FILES),$(HCP_SWTPM_OUT)/$i)

define swtpm_file
$(HCP_SWTPM_OUT)/$1: | $(HCP_SWTPM_OUT)
$(HCP_SWTPM_OUT)/$1: $(HCP_SWTPM_SRC)/$1
$(HCP_SWTPM_OUT)/$1:
	$Qcp $$< $$@
endef
$(foreach i,$(HCP_SWTPM_FILES),$(eval $(call swtpm_file,$i)))

# The bulk handling of "SWTPM_FILES" (EXEC and NOEXEC) from hcp/swtpm/ was
# scripted.
# Now add the install.tar.gz as a one-off.
HCP_SWTPM_PATHS += $(HCP_SWTPM_OUT)/install.tar.gz
$(HCP_SWTPM_OUT)/install.tar.gz: | $(HCP_SWTPM_OUT)
$(HCP_SWTPM_OUT)/install.tar.gz: $(HCP_SUBMODULES_OUT)/install.tar.gz
$(HCP_SWTPM_OUT)/install.tar.gz:
	$Qcp $< $@
# And tail_wait.pl
HCP_SWTPM_FILES_EXEC += tail_wait.pl
HCP_SWTPM_PATHS += $(HCP_SWTPM_OUT)/tail_wait.pl
$(HCP_SWTPM_OUT)/tail_wait.pl: | $(HCP_SWTPM_OUT)
$(HCP_SWTPM_OUT)/tail_wait.pl: $(HCP_SRC)/tail_wait.pl
$(HCP_SWTPM_OUT)/tail_wait.pl:
	$Qcp $< $@

# Dockerfile-generation.
$(HCP_SWTPM_OUT)/Dockerfile: | $(HCP_SWTPM_OUT)
$(HCP_SWTPM_OUT)/Dockerfile: $(HCP_SWTPM_SRC)/Makefile
$(HCP_SWTPM_OUT)/Dockerfile: $(HCP_SWTPM_SRC)/Dockerfile
$(HCP_SWTPM_OUT)/Dockerfile:
	$Qecho "FROM $(SAFEBOOT_HCP_DSPACE)$(HCP_BASE_IMAGE)" > $@
	$Qcat $(HCP_SWTPM_SRC)/Dockerfile | \
	sed -e "s/HCP_SWTPM_FILES_NOEXEC/$(HCP_SWTPM_FILES_NOEXEC)/" | \
	sed -e "s/HCP_SWTPM_FILES_EXEC/$(HCP_SWTPM_FILES_EXEC)/" >> $@

# "docker build" to create the container image (recipe only)
$(HCP_SWTPM_OUT)/built: $(HCP_SWTPM_OUT)/Dockerfile
$(HCP_SWTPM_OUT)/built: $(HCP_SWTPM_PATHS)
$(HCP_SWTPM_OUT)/built: $(HCP_BASE_TOUCHFILE)
$(HCP_SWTPM_OUT)/built:
	$Qdocker build -t $(SAFEBOOT_HCP_DSPACE)swtpm \
	               -f $(HCP_SWTPM_OUT)/Dockerfile \
	               $(HCP_SWTPM_OUT)/
	$Qtouch $@

# "docker image rm" to remove the container image (interface and recipe)
clean_hcp_swtpm:
ifeq (yes,$(shell stat $(HCP_SWTPM_OUT)/built > /dev/null 2>&1 && echo yes))
	$Qdocker image rm $(SAFEBOOT_HCP_DSPACE)swtpm
	$Qrm $(HCP_SWTPM_OUT)/built
	$Qrm $(HCP_SWTPM_OUT)/Dockerfile
endif
ifeq (yes,$(shell stat $(HCP_SWTPM_OUT) > /dev/null 2>&1 && echo yes))
	$Qrm -rf $(HCP_SWTPM_OUT)
endif

# Cleanup ordering
clean_hcp_base: clean_hcp_swtpm


# TODO: same comment as in hcp/enrollsvc/Makefile

HCP_SWTPM_STATE := $(HCP_SWTPM_OUT)/run
HCP_SWTPM_STATE_PREFIX := /swtpm

HCP_SWTPM_MSGBUS := $(HCP_SWTPM_OUT)/msgbus
HCP_SWTPM_MSGBUS_PREFIX := /msgbus

# Basically, HCP_ENROLL_HOSTNAME is the hostname that the TPM's ek.pub will be
# enrolled for, the client will set its own hostname (HCP_CLIENT_HOSTNAME) to
# match it, and the swtpm will set its hostname (HCP_SWTPM_HOSTNAME) with a
# prefix; "swtpm-$(HCP_ENROLL_HOSTNAME)".
HCP_ENROLL_HOSTNAME := example-host

# And this is the URL that swtpm needs to hit to enroll itself
HCP_ENROLL_URL := http://$(HCP_ENROLLSVC_MGMT_HOSTNAME):5000/v1/add

HCP_SWTPM_HOSTNAME := swtpm-$(HCP_ENROLL_HOSTNAME)

########################
# Detect current state #
########################

ifeq (yes,$(shell test -d $(HCP_SWTPM_STATE) > /dev/null 2>&1 && echo yes))
HCP_SWTPM_INITIALIZED := 1
endif
ifeq (yes,$(shell stat $(HCP_SWTPM_OUT)/run.started > /dev/null 2>&1 && echo yes))
HCP_SWTPM_RUNNING := 1
endif

#########################
# Global/one-time state #
#########################

# "docker run [] setup_swtpm", for one-time initialization (recipe only)
ifdef NO_REINIT
$(HCP_SWTPM_OUT)/run.initialized: | $(HCP_SWTPM_OUT)/built
else
$(HCP_SWTPM_OUT)/run.initialized: $(HCP_SWTPM_OUT)/built
endif
$(HCP_SWTPM_OUT)/run.initialized: | $(HCP_OUT)/testnetwork.created
$(HCP_SWTPM_OUT)/run.initialized: | $(HCP_ENROLLSVC_OUT)/mgmt.run.started
$(HCP_SWTPM_OUT)/run.initialized:
ifdef HCP_SWTPM_RUNNING
	$Qecho "Can't (re)initialize 'swtpm' state while it is running."
	$Qecho "Do 'make hcp_swtpm_run_stop' to stop it."
	$Qexit 1
endif
ifdef HCP_SWTPM_INITIALIZED
ifndef FORCE
	$Qecho "State for 'swtpm' exists, needs reinitialization."
	$Qecho "Do 'make clean_hcp_swtpm_run', or set FORCE=1 and I"
	$Qecho "will do it for you."
	$Qecho "(Or set NO_REINIT=1 to override the initilization dependency.)"
	$Qexit 1
endif
	$Qrm -rf $(HCP_SWTPM_STATE)
endif
	$Qmkdir $(HCP_SWTPM_STATE)
	$Qdocker run -i --rm \
		-v $(HCP_SWTPM_STATE):$(HCP_SWTPM_STATE_PREFIX) \
		--env STATE_PREFIX="$(HCP_SWTPM_STATE_PREFIX)" \
		--env ENROLL_HOSTNAME="$(HCP_ENROLL_HOSTNAME)" \
		--env ENROLL_URL="$(HCP_ENROLL_URL)" \
		--network $(HCP_TESTNETWORK_NAME) \
		--name $(HCP_SWTPM_HOSTNAME) \
		--hostname $(HCP_SWTPM_HOSTNAME) \
		--network-alias $(HCP_SWTPM_HOSTNAME) \
		--label $(SAFEBOOT_HCP_DSPACE)all=1 \
		--label $(SAFEBOOT_HCP_DSPACE)swtpm=1 \
		--label $(SAFEBOOT_HCP_DSPACE)swtpm_setup=1 \
		$(SAFEBOOT_HCP_DSPACE)swtpm \
		/hcp/setup_swtpm.sh
	$Qecho "Done setting up 'swtpm' state"
	$Qtouch $@

# "docker run [] setup_swtpm", for one-time initialization (interface only)
hcp_swtpm_run_init: $(HCP_SWTPM_OUT)/run.initialized

# "rm -rf swtpm" to remove one-time initialization (interface and recipe)
ifdef HCP_SWTPM_RUNNING
ifdef FORCE
clean_hcp_swtpm_run: hcp_swtpm_run_stop
endif
endif
clean_hcp_swtpm_run:
ifdef HCP_SWTPM_RUNNING
ifndef FORCE
	$Qecho "Error, the service appears to be running. Stop it before cleaning."
	$Qecho "(Or set FORCE=1 and I'll automatically stop it for you.)"
	$Q/bin/false
endif
endif
ifdef HCP_SWTPM_INITIALIZED
	$Qrm -rf $(HCP_SWTPM_STATE)
	$Qrm -rf $(HCP_SWTPM_MSGBUS)
	$Qrm -f $(HCP_SWTPM_OUT)/run.initialized
	$Qrm -f $(HCP_SWTPM_OUT)/run.*
	$Qecho "Done cleaning up 'swtpm' state"
endif

##############
# start/stop #
##############

# "docker run [] run_swtpm.sh", to start the service (recipe only)
ifndef HCP_SWTPM_RUNNING
$(HCP_SWTPM_OUT)/run.started: | $(HCP_OUT)/testnetwork.created
$(HCP_SWTPM_OUT)/run.started: $(HCP_SWTPM_OUT)/run.initialized
$(HCP_SWTPM_OUT)/run.started:
	$Qmkdir -p $(HCP_SWTPM_MSGBUS)
	$Qrm -f $(HCP_SWTPM_MSGBUS)/swtpm*
	$Qrm -f $(HCP_SWTPM_OUT)/run.cid
	$Qrm -f $(HCP_SWTPM_OUT)/run.lastExitCode
	$Qrm -f $(HCP_SWTPM_OUT)/run.signaled
	$Qdocker run -d \
		--cidfile=$(HCP_SWTPM_OUT)/run.cid \
		-v $(HCP_SWTPM_STATE):$(HCP_SWTPM_STATE_PREFIX):rw \
		--env STATE_PREFIX="$(HCP_SWTPM_STATE_PREFIX)" \
		--env ENROLL_HOSTNAME="$(HCP_ENROLL_HOSTNAME)" \
		--env ENROLL_URL="$(HCP_ENROLL_URL)" \
		-v $(HCP_SWTPM_MSGBUS):$(HCP_SWTPM_MSGBUS_PREFIX) \
		--network $(HCP_TESTNETWORK_NAME) \
		--name $(HCP_SWTPM_HOSTNAME) \
		--hostname $(HCP_SWTPM_HOSTNAME) \
		--network-alias $(HCP_SWTPM_HOSTNAME) \
		-p 9876:9876 \
		--label $(SAFEBOOT_HCP_DSPACE)all=1 \
		--label $(SAFEBOOT_HCP_DSPACE)swtpm=1 \
		--label $(SAFEBOOT_HCP_DSPACE)swtpm_run=1 \
		$(SAFEBOOT_HCP_DSPACE)swtpm \
		/hcp/run_swtpm.sh
	$Qecho "Done starting 'swtpm'"
	$Qecho "Output at; $(HCP_SWTPM_MSGBUS)/swtpm"
	$Qtouch $@
endif

# "echo die > swtpm-ctrl", signal service to exit (recipe only)
ifdef HCP_SWTPM_RUNNING
$(HCP_SWTPM_OUT)/run.signaled: $(HCP_SWTPM_OUT)/run.started
	$Qecho "Signaling 'swtpm' to exit"
	$Qecho "die" > $(HCP_SWTPM_MSGBUS)/swtpm-ctrl
	$Qtouch $@
endif

# "docker run [] run_swtpm.sh", to start the service (interface only)
ifndef HCP_SWTPM_RUNNING
hcp_swtpm_run_start: $(HCP_SWTPM_OUT)/run.started
endif
hcp_swtpm_run_start:

# "docker {wait,rm}", to stop the service (interface and recipe)
hcp_swtpm_run_stop:
ifdef HCP_SWTPM_RUNNING
	$Qdocker container wait `cat $(HCP_SWTPM_OUT)/run.cid` > \
		$(HCP_SWTPM_OUT)/run.lastExitCode
	$Qdocker container rm `cat $(HCP_SWTPM_OUT)/run.cid`
	$Qtest `cat $(HCP_SWTPM_OUT)/run.lastExitCode` -eq 0 && \
		echo "swtpm exited with SUCCESS" || \
		echo "swtpm exited with FAILURE!! (probably long ago)"
	$Qrm $(HCP_SWTPM_OUT)/run.started
	$Qrm $(HCP_SWTPM_OUT)/run.signaled
	$Qrm $(HCP_SWTPM_OUT)/run.cid
	$Qecho "Done stopping 'swtpm'"
hcp_swtpm_run_stop: $(HCP_SWTPM_OUT)/run.signaled
endif

################
# cleanup deps #
################

clean_hcp_swtpm: clean_hcp_swtpm_run
clean_hcp_testnetwork: clean_hcp_swtpm_run

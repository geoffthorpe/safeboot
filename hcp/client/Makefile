HCP_CLIENT_SRC := $(HCP_SRC)/client
HCP_CLIENT_OUT := $(HCP_OUT)/client

$(HCP_CLIENT_OUT): | $(HCP_OUT)
MDIRS += $(HCP_CLIENT_OUT)

# wrapper target to build the "client" image
hcp_client: $(HCP_CLIENT_OUT)/built

# Include the submodule bundle
HCP_CLIENT_PATHS += $(HCP_CLIENT_OUT)/install.tar.gz
$(HCP_CLIENT_OUT)/install.tar.gz: | $(HCP_CLIENT_OUT)
$(HCP_CLIENT_OUT)/install.tar.gz: $(HCP_SUBMODULES_OUT)/install.tar.gz
$(HCP_CLIENT_OUT)/install.tar.gz:
	$Qcp $< $@

# And the safeboot bundle
HCP_CLIENT_PATHS += $(HCP_CLIENT_OUT)/safeboot.tar.gz
$(HCP_CLIENT_OUT)/safeboot.tar.gz: | $(HCP_CLIENT_OUT)
$(HCP_CLIENT_OUT)/safeboot.tar.gz: $(HCP_SCRIPTS_OUT)/safeboot.tar.gz
$(HCP_CLIENT_OUT)/safeboot.tar.gz:
	$Qcp $< $@

# And the hcp-{common,client} bundles
HCP_CLIENT_PATHS += $(HCP_CLIENT_OUT)/hcp-common.tar.gz
HCP_CLIENT_PATHS += $(HCP_CLIENT_OUT)/hcp-client.tar.gz
$(HCP_CLIENT_OUT)/hcp-common.tar.gz: | $(HCP_CLIENT_OUT)
$(HCP_CLIENT_OUT)/hcp-common.tar.gz: $(HCP_SCRIPTS_OUT)/hcp-common.tar.gz
$(HCP_CLIENT_OUT)/hcp-common.tar.gz:
	$Qcp $< $@
$(HCP_CLIENT_OUT)/hcp-client.tar.gz: | $(HCP_CLIENT_OUT)
$(HCP_CLIENT_OUT)/hcp-client.tar.gz: $(HCP_SCRIPTS_OUT)/hcp-client.tar.gz
$(HCP_CLIENT_OUT)/hcp-client.tar.gz:
	$Qcp $< $@

# Dockerfile-generation.
$(HCP_CLIENT_OUT)/Dockerfile: | $(HCP_CLIENT_OUT)
$(HCP_CLIENT_OUT)/Dockerfile: $(HCP_CLIENT_SRC)/Makefile
$(HCP_CLIENT_OUT)/Dockerfile: $(HCP_CLIENT_SRC)/Dockerfile
$(HCP_CLIENT_OUT)/Dockerfile: $(HCP_SUBMODULES_OUT)/install.tar.gz.inject
$(HCP_CLIENT_OUT)/Dockerfile: $(HCP_SCRIPTS_OUT)/safeboot.tar.gz.inject
$(HCP_CLIENT_OUT)/Dockerfile: $(HCP_SCRIPTS_OUT)/hcp-common.tar.gz.inject
$(HCP_CLIENT_OUT)/Dockerfile: $(HCP_SCRIPTS_OUT)/hcp-client.tar.gz.inject
$(HCP_CLIENT_OUT)/Dockerfile:
	$Qecho "FROM $(SAFEBOOT_HCP_DSPACE)$(HCP_BASE_IMAGE)" > $@
	$Qcat $(HCP_CLIENT_SRC)/Dockerfile >> $@
	$Qcat $(HCP_SUBMODULES_OUT)/install.tar.gz.inject >> $@
	$Qcat $(HCP_SCRIPTS_OUT)/safeboot.tar.gz.inject >> $@
	$Qcat $(HCP_SCRIPTS_OUT)/hcp-common.tar.gz.inject >> $@
	$Qcat $(HCP_SCRIPTS_OUT)/hcp-client.tar.gz.inject >> $@

# "docker build" to create the container image (recipe only)
$(HCP_CLIENT_OUT)/built: $(HCP_CLIENT_OUT)/Dockerfile
$(HCP_CLIENT_OUT)/built: $(HCP_CLIENT_PATHS)
$(HCP_CLIENT_OUT)/built: $(HCP_BASE_TOUCHFILE)
$(HCP_CLIENT_OUT)/built:
	$Qdocker build -t $(SAFEBOOT_HCP_DSPACE)client \
	               --label $(SAFEBOOT_HCP_DSPACE)client=1 \
	               -f $(HCP_CLIENT_OUT)/Dockerfile \
	               $(HCP_CLIENT_OUT)
	$Qtouch $@

# "docker image rm" to remove the container image (interface and recipe)
clean_hcp_client:
ifneq (,$(filter $(SAFEBOOT_HCP_DSPACE)client,$(HCP_EXISTING_IMAGES)))
	$Qdocker image rm $(SAFEBOOT_HCP_DSPACE)client
endif
	$Qrm -rf $(HCP_CLIENT_OUT)

# Cleanup ordering
clean_hcp_base: clean_hcp_client



# TODO: some of the comments in hcp/enrollsvc/Makefile apply here too. There
# are some differences though, as the 'client' (unlike most everything else) is
# not a service, but a function. It doesn't have one-time initialized state,
# but still has to clean up (lazy-initialized state for output, and
# touchfiles), it doesn't start/signal/stop, doesn't background, it just runs
# synchronously and returns when done. So this makes the Makefile "template"
# deviate a little from the others.

# Consult hcp/swtpmsvc/Makefile's run-time section for more info about some of
# these settings.

HCP_CLIENT_MSGBUS := $(HCP_CLIENT_OUT)/msgbus
HCP_CLIENT_MSGBUS_PREFIX := /msgbus

HCP_ATTEST_URL := http://$(HCP_ATTESTSVC_HCP_HOSTNAME):8080
HCP_CLIENT_TCTI := swtpm:host=$(HCP_SWTPMSVC_HOSTNAME),port=9876

# Choice - is the "run_client" thing a target or a verb? Once a target is met,
# it's met, if you "make" it again there will literally be "Nothing to be done"
# (unless one of the dependencies has been updated in the meanwhile). OTOH a
# verb is something you want to happen whenever you ask for it, synchronously,
# every time. This defaults to a verb if the caller doesn't specify otherwise.
HCP_CLIENT_MODE ?= verb
ifneq (verb,$(HCP_CLIENT_MODE))
ifneq (target,$(HCP_CLIENT_MODE))
$(error HCP_CLIENT_MODE should be set to 'verb' or 'target')
endif
endif

#######
# run #
#######

# "docker run [] run_client.sh", to run the function (recipe only)
ifdef NO_REINIT
$(HCP_CLIENT_OUT)/run.done: | $(HCP_CLIENT_OUT)/built
else
$(HCP_CLIENT_OUT)/run.done: $(HCP_CLIENT_OUT)/built
endif
$(HCP_CLIENT_OUT)/run.done: | $(HCP_OUT)/testnetwork.created
$(HCP_CLIENT_OUT)/run.done: | $(HCP_SWTPMSVC_OUT)/run.started
$(HCP_CLIENT_OUT)/run.done: | $(HCP_ATTESTSVC_OUT)/hcp.run.started
$(HCP_CLIENT_OUT)/run.done:
	$Qmkdir -p $(HCP_CLIENT_MSGBUS)
	$Qrm -f $(HCP_CLIENT_MSGBUS)/client*
	$Qdocker run -i --rm \
		--env TPM2TOOLS_TCTI="$(HCP_CLIENT_TCTI)" \
		--env CLIENT_ATTEST_URL="$(HCP_ATTEST_URL)" \
		--env MSGBUS="$(HCP_CLIENT_MSGBUS)" \
		--env MSGBUS_PREFIX="$(HCP_CLIENT_MSGBUS_PREFIX)" \
		-v $(HCP_CLIENT_MSGBUS):$(HCP_CLIENT_MSGBUS_PREFIX) \
		--network $(HCP_TESTNETWORK_NAME) \
		--name $(SAFEBOOT_HCP_DSPACE)client \
		--hostname $(HCP_CLIENT_HOSTNAME) \
		--network-alias $(HCP_CLIENT_HOSTNAME) \
		--label $(SAFEBOOT_HCP_DSPACE)client_run=1 \
		$(SAFEBOOT_HCP_DSPACE)client \
		/hcp/client/run_client.sh
	$Qecho "Done starting 'client'"
	$Qecho "Output at; $(HCP_CLIENT_MSGBUS)/client"
ifeq (target,$(HCP_CLIENT_MODE))
	$Qtouch $@
endif

# "docker run [] run_client.sh", to run the function (interface only)
hcp_client_run: $(HCP_CLIENT_OUT)/run.done

###########
# cleanup #
###########

# "rm -rf client" to remove left-overs (interface and recipe)
clean_hcp_client_run:
	$QUTIL_IMAGE=$(SAFEBOOT_HCP_BASE) \
		$(ASSIST_CLEANUP) volume $(HCP_CLIENT_MSGBUS)
	$Qrm -f $(HCP_CLIENT_OUT)/run.done

################
# cleanup deps #
################

clean_hcp_client: clean_hcp_client_run
clean_hcp_testnetwork: clean_hcp_client_run

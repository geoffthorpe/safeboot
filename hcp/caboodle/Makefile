# This "caboodle" thing is a little special, relative to the other targets.
# Like hcp/client, it builds an image for use as a synchronous function, rather
# than for running asynchronous services like everything else. But unlike
# client, which provides a synchronous "_run" target to execute a particular
# script, caboodle's "_run" target runs a bash session (and adds the "-t" flag
# to the docker-run invocation).
#
# It is also special in the way it builds. It concatenates all other (relevant)
# Dockerfiles together to form a kind of "union" container. The purpose of this
# is to have an image that can run and which contains within it _all_ of the
# HCP functionality in one colocated entity. For one thing, this allows a more
# traditional "single-host" development environment for messing around with
# scripting, but puts it in one mega container as an alternative to doing it
# literally on the host.

HCP_CABOODLE_SRC := $(HCP_SRC)/caboodle
HCP_CABOODLE_OUT := $(HCP_OUT)/caboodle

$(HCP_CABOODLE_OUT): | $(HCP_OUT)
MDIRS += $(HCP_CABOODLE_OUT)

# wrapper target to build the "caboodle" image
hcp_caboodle: $(HCP_CABOODLE_OUT)/built

# Include the submodule bundle
HCP_CABOODLE_PATHS += $(HCP_CABOODLE_OUT)/install.tar.gz
$(HCP_CABOODLE_OUT)/install.tar.gz: | $(HCP_CABOODLE_OUT)
$(HCP_CABOODLE_OUT)/install.tar.gz: $(HCP_SUBMODULES_OUT)/install.tar.gz
$(HCP_CABOODLE_OUT)/install.tar.gz:
	$Qcp $< $@

# And the safeboot bundle
HCP_CABOODLE_PATHS += $(HCP_CABOODLE_OUT)/safeboot.tar.gz
$(HCP_CABOODLE_OUT)/safeboot.tar.gz: | $(HCP_CABOODLE_OUT)
$(HCP_CABOODLE_OUT)/safeboot.tar.gz: $(HCP_SCRIPTS_OUT)/safeboot.tar.gz
$(HCP_CABOODLE_OUT)/safeboot.tar.gz:
	$Qcp $< $@

# And all the hcp-{common,enrollsvc,attestsvc,swtpmsvc,client} bundles
HCP_CABOODLE_PATHS += $(HCP_CABOODLE_OUT)/hcp-common.tar.gz
HCP_CABOODLE_PATHS += $(HCP_CABOODLE_OUT)/hcp-enrollsvc.tar.gz
HCP_CABOODLE_PATHS += $(HCP_CABOODLE_OUT)/hcp-attestsvc.tar.gz
HCP_CABOODLE_PATHS += $(HCP_CABOODLE_OUT)/hcp-swtpmsvc.tar.gz
HCP_CABOODLE_PATHS += $(HCP_CABOODLE_OUT)/hcp-client.tar.gz
$(HCP_CABOODLE_OUT)/hcp-common.tar.gz: | $(HCP_CABOODLE_OUT)
$(HCP_CABOODLE_OUT)/hcp-common.tar.gz: $(HCP_SCRIPTS_OUT)/hcp-common.tar.gz
$(HCP_CABOODLE_OUT)/hcp-common.tar.gz:
	$Qcp $< $@
$(HCP_CABOODLE_OUT)/hcp-enrollsvc.tar.gz: | $(HCP_CABOODLE_OUT)
$(HCP_CABOODLE_OUT)/hcp-enrollsvc.tar.gz: $(HCP_SCRIPTS_OUT)/hcp-enrollsvc.tar.gz
$(HCP_CABOODLE_OUT)/hcp-enrollsvc.tar.gz:
	$Qcp $< $@
$(HCP_CABOODLE_OUT)/hcp-attestsvc.tar.gz: | $(HCP_CABOODLE_OUT)
$(HCP_CABOODLE_OUT)/hcp-attestsvc.tar.gz: $(HCP_SCRIPTS_OUT)/hcp-attestsvc.tar.gz
$(HCP_CABOODLE_OUT)/hcp-attestsvc.tar.gz:
	$Qcp $< $@
$(HCP_CABOODLE_OUT)/hcp-swtpmsvc.tar.gz: | $(HCP_CABOODLE_OUT)
$(HCP_CABOODLE_OUT)/hcp-swtpmsvc.tar.gz: $(HCP_SCRIPTS_OUT)/hcp-swtpmsvc.tar.gz
$(HCP_CABOODLE_OUT)/hcp-swtpmsvc.tar.gz:
	$Qcp $< $@
$(HCP_CABOODLE_OUT)/hcp-client.tar.gz: | $(HCP_CABOODLE_OUT)
$(HCP_CABOODLE_OUT)/hcp-client.tar.gz: $(HCP_SCRIPTS_OUT)/hcp-client.tar.gz
$(HCP_CABOODLE_OUT)/hcp-client.tar.gz:
	$Qcp $< $@

# Add our single, caboodle-specific script
HCP_CABOODLE_PATHS += $(HCP_CABOODLE_OUT)/test-everything.sh
$(HCP_CABOODLE_OUT)/test-everything.sh: | $(HCP_CABOODLE_OUT)
$(HCP_CABOODLE_OUT)/test-everything.sh: $(HCP_CABOODLE_SRC)/test-everything.sh
$(HCP_CABOODLE_OUT)/test-everything.sh:
	$Qcp $< $@

# Dockerfile-generation.
$(HCP_CABOODLE_OUT)/Dockerfile: | $(HCP_CABOODLE_OUT)
$(HCP_CABOODLE_OUT)/Dockerfile: $(HCP_CABOODLE_SRC)/Makefile
$(HCP_CABOODLE_OUT)/Dockerfile: $(HCP_CABOODLE_SRC)/Dockerfile
$(HCP_CABOODLE_OUT)/Dockerfile: $(HCP_ENROLLSVC_SRC)/Dockerfile
$(HCP_CABOODLE_OUT)/Dockerfile: $(HCP_ATTESTSVC_SRC)/Dockerfile
$(HCP_CABOODLE_OUT)/Dockerfile: $(HCP_SWTPMSVC_SRC)/Dockerfile
$(HCP_CABOODLE_OUT)/Dockerfile: $(HCP_CLIENT_SRC)/Dockerfile
$(HCP_CABOODLE_OUT)/Dockerfile: $(HCP_SUBMODULES_OUT)/install.tar.gz.inject
$(HCP_CABOODLE_OUT)/Dockerfile: $(HCP_SCRIPTS_OUT)/safeboot.tar.gz.inject
$(HCP_CABOODLE_OUT)/Dockerfile: $(HCP_SCRIPTS_OUT)/hcp-common.tar.gz.inject
$(HCP_CABOODLE_OUT)/Dockerfile: $(HCP_SCRIPTS_OUT)/hcp-enrollsvc.tar.gz.inject
$(HCP_CABOODLE_OUT)/Dockerfile: $(HCP_SCRIPTS_OUT)/hcp-attestsvc.tar.gz.inject
$(HCP_CABOODLE_OUT)/Dockerfile: $(HCP_SCRIPTS_OUT)/hcp-swtpmsvc.tar.gz.inject
$(HCP_CABOODLE_OUT)/Dockerfile: $(HCP_SCRIPTS_OUT)/hcp-client.tar.gz.inject
$(HCP_CABOODLE_OUT)/Dockerfile:
	$Qecho "FROM $(SAFEBOOT_HCP_DSPACE)$(HCP_BASE_IMAGE)" > $@
	$Qcat $(HCP_ENROLLSVC_SRC)/Dockerfile >> $@
	$Qcat $(HCP_ATTESTSVC_SRC)/Dockerfile >> $@
	$Qcat $(HCP_SWTPMSVC_SRC)/Dockerfile >> $@
	$Qcat $(HCP_CLIENT_SRC)/Dockerfile >> $@
	$Qcat $(HCP_SUBMODULES_OUT)/install.tar.gz.inject >> $@
	$Qcat $(HCP_SCRIPTS_OUT)/safeboot.tar.gz.inject >> $@
	$Qcat $(HCP_SCRIPTS_OUT)/hcp-common.tar.gz.inject >> $@
	$Qcat $(HCP_SCRIPTS_OUT)/hcp-enrollsvc.tar.gz.inject >> $@
	$Qcat $(HCP_SCRIPTS_OUT)/hcp-attestsvc.tar.gz.inject >> $@
	$Qcat $(HCP_SCRIPTS_OUT)/hcp-swtpmsvc.tar.gz.inject >> $@
	$Qcat $(HCP_SCRIPTS_OUT)/hcp-client.tar.gz.inject >> $@
	$Qcat $(HCP_CABOODLE_SRC)/Dockerfile >> $@

# From enrollsvc/Makefile;
DB_USER := db_user
FLASK_USER := flask_user
# From attestsvc/Makefile;
HCP_USER := lowlyuser

# "docker build" to create the container image (recipe only)
$(HCP_CABOODLE_OUT)/built: $(HCP_CABOODLE_OUT)/Dockerfile
$(HCP_CABOODLE_OUT)/built: $(HCP_CABOODLE_PATHS)
$(HCP_CABOODLE_OUT)/built: $(HCP_BASE_TOUCHFILE)
$(HCP_CABOODLE_OUT)/built:
	$Qdocker build -t $(SAFEBOOT_HCP_DSPACE)caboodle \
	               --label $(SAFEBOOT_HCP_DSPACE)caboodle=1 \
	               -f $(HCP_CABOODLE_OUT)/Dockerfile \
	               --build-arg DB_USER=$(DB_USER) \
	               --build-arg FLASK_USER=$(FLASK_USER) \
	               --build-arg HCP_USER=$(HCP_USER) \
	               $(HCP_CABOODLE_OUT)
	$Qtouch $@

# "docker image rm" to remove the container image (interface and recipe)
clean_hcp_caboodle:
ifneq (,$(filter $(SAFEBOOT_HCP_DSPACE)caboodle,$(HCP_EXISTING_IMAGES)))
	$Qdocker image rm $(SAFEBOOT_HCP_DSPACE)caboodle
endif
	$Qrm -rf $(HCP_CABOODLE_OUT)

# Cleanup ordering
clean_hcp_base: clean_hcp_caboodle



# TODO: many of the comments in hcp/client/Makefile apply here.

# These settings are about caboodle itself. The STATE and MSGBUS stuff is for
# persistence.
HCP_CABOODLE_HOSTNAME := caboodle

HCP_CABOODLE_STATE := $(HCP_CABOODLE_OUT)/state
HCP_CABOODLE_STATE_PREFIX := /state
MDIRS += $(HCP_CABOODLE_STATE)
$(HCP_CABOODLE_STATE): | $(HCP_CABOODLE_OUT)
CABOODLE_DEPS := $(HCP_CABOODLE_STATE)

HCP_CABOODLE_MSGBUS := $(HCP_CABOODLE_OUT)/msgbus
HCP_CABOODLE_MSGBUS_PREFIX := /msgbus

# The caboodle container is a union of all the functions we build and normally
# run separately. Within this container, it should be possible to run all of
# the functions in a "single-host" form. As such, we identify all the
# environment settings passed to each of the separated containers and set
# alternative values for them here and pass all of them to the docker-run
# command. With these default settings, the services and utils are configured
# to run and access each other within the same "caboodle" container, rather
# than being configured to work across multiple, separated containers.
#
# Note, the container is joined to the docker network that normally runs the
# distinct containers anyway. The idea is that you can enter the caboodle
# container and "locally" test and hack, but because it's on the network, you
# can also modify some of these settings - or ignore them - to interact with
# and debug the distinct containers on the network (if they're running).


# From enrollsvc;
#   ENROLLSVC_STATE_PREFIX
CABOODLE_ENROLLSVC_STATE := $(HCP_CABOODLE_STATE)/enrollsvc
CABOODLE_ENROLLSVC_STATE_PREFIX := $(HCP_CABOODLE_STATE_PREFIX)/enrollsvc
CABOODLE_ARGS += -v $(CABOODLE_ENROLLSVC_STATE):$(CABOODLE_ENROLLSVC_STATE_PREFIX)
CABOODLE_ARGS += --env HCP_ENROLLSVC_STATE_PREFIX="$(CABOODLE_ENROLLSVC_STATE_PREFIX)"
#   -p 5000
#   -p 9418
CABOODLE_PORTS_DEFAULT += 5000:5000 9418:9418

# From attestsvc;
#   ATTESTSVC_STATE_PREFIX
CABOODLE_ATTESTSVC_STATE := $(HCP_CABOODLE_STATE)/attestsvc
CABOODLE_ATTESTSVC_STATE_PREFIX := $(HCP_CABOODLE_STATE_PREFIX)/attestsvc
CABOODLE_ARGS += -v $(CABOODLE_ATTESTSVC_STATE):$(CABOODLE_ATTESTSVC_STATE_PREFIX)
CABOODLE_ARGS += --env HCP_ATTESTSVC_STATE_PREFIX="$(CABOODLE_ATTESTSVC_STATE_PREFIX)"
#   ATTESTSVC_REMOTE_REPO
CABOODLE_ATTESTSVC_REMOTE_REPO := git://$(HCP_CABOODLE_HOSTNAME)/enrolldb
CABOODLE_ARGS += --env HCP_ATTESTSVC_REMOTE_REPO="$(CABOODLE_ATTESTSVC_REMOTE_REPO)"
#   ATTESTSVC_UPDATE_TIMER
CABOODLE_ATTESTSVC_UPDATE_TIMER := 10
CABOODLE_ARGS += --env HCP_ATTESTSVC_UPDATE_TIMER="$(CABOODLE_ATTESTSVC_UPDATE_TIMER)"
#   -p 8080
CABOODLE_PORTS_DEFAULT += 8080:8080

# From swtpmsvc;
#   SWTPMSVC_STATE_PREFIX
CABOODLE_SWTPMSVC_STATE := $(HCP_CABOODLE_STATE)/swtpmsvc
CABOODLE_SWTPMSVC_STATE_PREFIX := $(HCP_CABOODLE_STATE_PREFIX)/swtpmsvc
CABOODLE_ARGS += -v $(CABOODLE_SWTPMSVC_STATE):$(CABOODLE_SWTPMSVC_STATE_PREFIX)
CABOODLE_ARGS += --env HCP_SWTPMSVC_STATE_PREFIX="$(CABOODLE_SWTPMSVC_STATE_PREFIX)"
#   SWTPMSVC_ENROLL_HOSTNAME
CABOODLE_SWTPMSVC_ENROLL_HOSTNAME := $(HCP_CABOODLE_HOSTNAME)
CABOODLE_ARGS += --env HCP_SWTPMSVC_ENROLL_HOSTNAME="$(CABOODLE_SWTPMSVC_ENROLL_HOSTNAME)"
#   SWTPMSVC_ENROLL_URL
CABOODLE_SWTPMSVC_ENROLL_URL := http://$(HCP_CABOODLE_HOSTNAME):5000/v1/add
CABOODLE_ARGS += --env HCP_SWTPMSVC_ENROLL_URL="$(CABOODLE_SWTPMSVC_ENROLL_URL)"
#   -p 9876
CABOODLE_PORTS_DEFAULT += 9876:9876

# From client;
#   TPM2TOOLS_TCTI
CABOODLE_TPM2TOOLS_TCTI := swtpm:host=$(HCP_CABOODLE_HOSTNAME),port=9876
CABOODLE_ARGS += --env TPM2TOOLS_TCTI="$(CABOODLE_TPM2TOOLS_TCTI)"
#   CLIENT_ATTEST_URL
CABOODLE_CLIENT_ATTEST_URL := http://$(HCP_CABOODLE_HOSTNAME):8080
CABOODLE_ARGS += --env HCP_CLIENT_ATTEST_URL="$(CABOODLE_CLIENT_ATTEST_URL)"
#   MSGBUS
CABOODLE_ARGS += --env MSGBUS="$(HCP_CABOODLE_MSGBUS)"
#   MSGBUS_PREFIX
CABOODLE_ARGS += --env MSGBUS_PREFIX="$(HCP_CABOODLE_MSGBUS_PREFIX)"

# Note, by default, caboodle will launch with all its service ports exported to
# the host, meaning that in addition to the ports being open on the container
# itself (when access across the docker network), the host will also listen on
# these ports and forward them to the caboodle container. This is fine if
# running caboodle alone to do "single-host" development, especially if you
# want to hit the web interface of enrollsvc, or git-clone the enrollment
# database, etc. _However_, if you are also launching the normal service
# containers and intend to use caboodle to access (and/or be accessed by) them,
# the attempt to bind these host ports may conflict with the same ports already
# being bound by those containers. If so, edit this value or set it before
# calling make. (Setting to the value "none" will cause no ports to be mapped
# to caboodle. Otherwise it uses the CABOODLE_PORTS_DEFAULT value that was
# built up in the previous section.)
CABOODLE_PORTS ?= $(CABOODLE_PORTS_DEFAULT)
ifeq (none,$(CABOODLE_PORTS))
CABOODLE_PORTS :=
endif

#######
# run #
#######

# "docker run [] bash", to start a session (recipe only)
ifdef NO_REINIT
$(HCP_CABOODLE_OUT)/run.done: | $(HCP_CABOODLE_OUT)/built
else
$(HCP_CABOODLE_OUT)/run.done: $(HCP_CABOODLE_OUT)/built
endif
$(HCP_CABOODLE_OUT)/run.done: | $(HCP_OUT)/testnetwork.created
$(HCP_CABOODLE_OUT)/run.done: $(CABOODLE_DEPS)
$(HCP_CABOODLE_OUT)/run.done:
	$Qmkdir -p $(HCP_CABOODLE_MSGBUS)
	$Qdocker run -it --rm \
		$(CABOODLE_ARGS) \
		-v $(HCP_CABOODLE_MSGBUS):$(HCP_CABOODLE_MSGBUS_PREFIX) \
		--network $(HCP_TESTNETWORK_NAME) \
		--name $(SAFEBOOT_HCP_DSPACE)caboodle \
		--hostname $(HCP_CABOODLE_HOSTNAME) \
		--network-alias $(HCP_CABOODLE_HOSTNAME) \
		$(foreach i,$(CABOODLE_PORTS),-p $i) \
		--label $(SAFEBOOT_HCP_DSPACE)caboodle_session=1 \
		$(SAFEBOOT_HCP_DSPACE)caboodle \
		bash
	$Qecho "Done starting 'caboodle'"
	$Qecho "Output at; $(HCP_CABOODLE_MSGBUS)/caboodle"
ifeq (target,$(HCP_CABOODLE_MODE))
	$Qtouch $@
endif

# "docker run [] bash", to start a session (interface only)
hcp_caboodle_run: $(HCP_CABOODLE_OUT)/run.done

###########
# cleanup #
###########

# "rm -rf caboodle" to remove left-overs (interface and recipe)
clean_hcp_caboodle_run:
	$QUTIL_IMAGE=$(SAFEBOOT_HCP_BASE) \
		$(ASSIST_CLEANUP) volume $(HCP_CABOODLE_STATE)
	$QUTIL_IMAGE=$(SAFEBOOT_HCP_BASE) \
		$(ASSIST_CLEANUP) volume $(HCP_CABOODLE_MSGBUS)
	$Qrm -f $(HCP_CABOODLE_OUT)/run.done

################
# cleanup deps #
################

clean_hcp_caboodle: clean_hcp_caboodle_run
clean_hcp_testnetwork: clean_hcp_caboodle_run

HCP_ENROLLSVC_SRC := $(HCP_SRC)/enrollsvc
HCP_ENROLLSVC_OUT := $(HCP_OUT)/enrollsvc

$(HCP_ENROLLSVC_OUT): | $(HCP_OUT)
MDIRS += $(HCP_ENROLLSVC_OUT)

clean_hcp_enrollsvc:
ifeq (yes,$(shell stat $(HCP_ENROLLSVC_OUT) > /dev/null 2>&1 && echo yes))
	$Qrmdir $(HCP_ENROLLSVC_OUT)
endif

# Some summary notes about the enrollment service, a.k.a. "enrollsvc".
#
# This service consists of two containers (distinct images), "enrollsvc-mgmt"
# and "enrollsvc-repl", which perform complementary functions but operate on
# common state (a directory bind-mounted into both containers);
#  * The common state consists of;
#    - the "enrollment database", currently implemented as a git repository.
#    - a "msgbus" directory, into which;
#      - the services write their stdout/stderr,
#      - control software outside the service containers can write commands to
#        be picked up by the services. Currently, this is limited to "stop"
#        functionality, which writes "die" to a file the service is
#        "tail_wait"ing, triggering it to exit.
#  * "enrollsvc-mgmt" provides the enrollment/registration functionality;
#    - The common state is mounted read-write.
#    - The enrollment interface is implemented as a flask app.
#      - API exposed at http[s]://<server>[:port]/v1/{add,query,delete,find}
#      - A human/interactive web UI lives at http[s]://<server>[:port]/
#    - Enrollment of a host+ek.pub 2-tuple triggers a (modular, configurable)
#      asset-generation process, to provision credentials and other host
#      secrets that are immediately sealed to the enrolled host's TPM and to a
#      recovery/break-glass credential before insertion into the database.
#    - The flask app runs as a non-root (FLASK_USER) account in the container.
#    - The asset-generation and database-write processes run as a different,
#      non-root (DB_USER) account in the container.
#    - The flask app handlers invoke the asset-generation and querying
#      functions via constrained sudo rules, to prevent environment
#      contamination and limit information-passing to just the command
#      arguments.
#  * "enrollsvc-repl" provides a replication service to downstream attestation
#    service instances ("attestsvc-repl").
#    - The common state is mounted read-only!
#    - The replication service uses "git-daemon" directly, running as a
#      non-root (DB_USER) account in the container.
#    - Use of the same DB_USER account (as used in the asset-generation
#      process) is to simplify file-system permissioning (user/group ownership
#      of database files).
#      - This does not leak any visibility to the asset-generation process in
#        the other container, only the database is present/shared/mounted in
#        both containers.
#      - The database (directory) is read-only at the mount level, so we don't
#        need account separation to protect the database from modification by
#        the replication functionality.
#
# For reasons outlined in common.Dockerfile, we build an 'enrollsvc-common'
# image to be a common ancestor of enrollsvc-mgmt and enrollsvc-repl.

# wrapper targets to build the "enrollsvc" images
hcp_enrollsvc-mgmt: $(HCP_ENROLLSVC_OUT)/mgmt.built
hcp_enrollsvc-repl: $(HCP_ENROLLSVC_OUT)/repl.built
hcp_enrollsvc: hcp_enrollsvc-mgmt hcp_enrollsvc-repl

# A "DB_USER" account is created so that asset-generation and DB manipulation
# doesn't require root privs.
DB_USER := db_user
# The enrollsvc-mgmt container also runs the flask app, which needs to be priv
# separated from everything else (especially from the asset-generation/DB
# code), so it has its own non-root account.
FLASK_USER := flask_user


####################
# enrollsvc-common #
####################

MDIRS += $(HCP_ENROLLSVC_OUT)/common
$(HCP_ENROLLSVC_OUT)/common: | $(HCP_ENROLLSVC_OUT)

# Set up rules for synchronising implementation files from their
# version-controlled dev location to the Docker context area. There are two
# flavors, which get substituted into the Dockerfile in the recipe lower down.
# The Dockerfile uses them to distinguish chmod 755 from 644.
HCP_ENROLLSVC_COMMON_FILES_NOEXEC := common.sh common_defs.sh
#HCP_ENROLLSVC_COMMON_FILES_EXEC := <unused>
HCP_ENROLLSVC_COMMON_FILES := $(HCP_ENROLLSVC_COMMON_FILES_NOEXEC) \
			      $(HCP_ENROLLSVC_COMMON_FILES_EXEC)
HCP_ENROLLSVC_COMMON_PATHS := $(foreach i,$(HCP_ENROLLSVC_COMMON_FILES),\
					$(HCP_ENROLLSVC_OUT)/common/$i)

define enrollsvc_common_file
$(HCP_ENROLLSVC_OUT)/common/$1: | $(HCP_ENROLLSVC_OUT)/common
$(HCP_ENROLLSVC_OUT)/common/$1: $(HCP_ENROLLSVC_SRC)/$1
$(HCP_ENROLLSVC_OUT)/common/$1:
	$Qcp $$< $$@
endef
$(foreach i,$(HCP_ENROLLSVC_COMMON_FILES),$(eval $(call enrollsvc_common_file,$i)))

# The bulk handling of "COMMON_FILES" (EXEC and NOEXEC) from hcp/enrollsvc/ was
# scripted.
# Now add hcp/tail_wait.pl (EXEC, and not from hcp/enrollsvc/!) as a one-off.
HCP_ENROLLSVC_COMMON_FILES_EXEC += tail_wait.pl
HCP_ENROLLSVC_COMMON_PATHS += $(HCP_ENROLLSVC_OUT)/common/tail_wait.pl
$(HCP_ENROLLSVC_OUT)/common/tail_wait.pl: | $(HCP_ENROLLSVC_OUT)/common
$(HCP_ENROLLSVC_OUT)/common/tail_wait.pl: $(HCP_SRC)/tail_wait.pl
$(HCP_ENROLLSVC_OUT)/common/tail_wait.pl:
	$Qcp $< $@

# Dockerfile-generation. NB: we don't just prepend our "FROM" line, we also
# make substitutions, to plug our file-lists into the Dockerfile commands.
$(HCP_ENROLLSVC_OUT)/common.Dockerfile: | $(HCP_ENROLLSVC_OUT)
$(HCP_ENROLLSVC_OUT)/common.Dockerfile: $(HCP_ENROLLSVC_SRC)/Makefile
$(HCP_ENROLLSVC_OUT)/common.Dockerfile: $(HCP_ENROLLSVC_SRC)/common.Dockerfile
$(HCP_ENROLLSVC_OUT)/common.Dockerfile:
	$Qecho "FROM $(SAFEBOOT_HCP_DSPACE)$(HCP_BASE_IMAGE)" > $@
	$Qcat $(HCP_ENROLLSVC_SRC)/common.Dockerfile | \
	sed -e "s/HCP_ENROLLSVC_COMMON_FILES_NOEXEC/$(HCP_ENROLLSVC_COMMON_FILES_NOEXEC)/" | \
	sed -e "s/HCP_ENROLLSVC_COMMON_FILES_EXEC/$(HCP_ENROLLSVC_COMMON_FILES_EXEC)/" >> $@

# "docker build" to create the container image (recipe only)
$(HCP_ENROLLSVC_OUT)/common.built: $(HCP_ENROLLSVC_OUT)/common.Dockerfile
$(HCP_ENROLLSVC_OUT)/common.built: $(HCP_ENROLLSVC_COMMON_PATHS)
$(HCP_ENROLLSVC_OUT)/common.built: $(HCP_BASE_TOUCHFILE)
$(HCP_ENROLLSVC_OUT)/common.built:
	$Qdocker build -t $(SAFEBOOT_HCP_DSPACE)enrollsvc-common \
	               -f $(HCP_ENROLLSVC_OUT)/common.Dockerfile \
		       --build-arg DB_USER=$(DB_USER) \
		       --build-arg FLASK_USER=$(FLASK_USER) \
	               $(HCP_ENROLLSVC_OUT)/common/
	$Qtouch $@

# "docker image rm" to remove the container image (interface and recipe)
clean_hcp_enrollsvc-common:
ifeq (yes,$(shell stat $(HCP_ENROLLSVC_OUT)/common.built > /dev/null 2>&1 && echo yes))
	$Qdocker image rm $(SAFEBOOT_HCP_DSPACE)enrollsvc-common
	$Qrm $(HCP_ENROLLSVC_OUT)/common.built
	$Qrm $(HCP_ENROLLSVC_OUT)/common.Dockerfile
endif
ifeq (yes,$(shell stat $(HCP_ENROLLSVC_OUT)/common > /dev/null 2>&1 && echo yes))
	$Qrm -rf $(HCP_ENROLLSVC_OUT)/common
endif

##################
# enrollsvc-repl #
##################

MDIRS += $(HCP_ENROLLSVC_OUT)/repl
$(HCP_ENROLLSVC_OUT)/repl: | $(HCP_ENROLLSVC_OUT)

# The only thing we need that isn't already in -common is the run_repl.sh
# script. As such, we bypass the scripting and Dockerfile-substitution
# gymnastics in -common (and in -mgmt).
$(HCP_ENROLLSVC_OUT)/repl/run_repl.sh: | $(HCP_ENROLLSVC_OUT)/repl
$(HCP_ENROLLSVC_OUT)/repl/run_repl.sh: $(HCP_ENROLLSVC_SRC)/run_repl.sh
$(HCP_ENROLLSVC_OUT)/repl/run_repl.sh:
	$Qcp $< $@

# Dockerfile-generation
$(HCP_ENROLLSVC_OUT)/repl.Dockerfile: | $(HCP_ENROLLSVC_OUT)
$(HCP_ENROLLSVC_OUT)/repl.Dockerfile: $(HCP_ENROLLSVC_SRC)/Makefile
$(HCP_ENROLLSVC_OUT)/repl.Dockerfile: $(HCP_ENROLLSVC_SRC)/repl.Dockerfile
$(HCP_ENROLLSVC_OUT)/repl.Dockerfile:
	$Qecho "FROM $(SAFEBOOT_HCP_DSPACE)enrollsvc-common" > $@
	$Qcat $(HCP_ENROLLSVC_SRC)/repl.Dockerfile >> $@

# "docker build" to create the container image (recipe only)
$(HCP_ENROLLSVC_OUT)/repl.built: $(HCP_ENROLLSVC_OUT)/repl.Dockerfile
$(HCP_ENROLLSVC_OUT)/repl.built: $(HCP_ENROLLSVC_OUT)/repl/run_repl.sh
$(HCP_ENROLLSVC_OUT)/repl.built: $(HCP_ENROLLSVC_OUT)/common.built
$(HCP_ENROLLSVC_OUT)/repl.built:
	$Qdocker build -t $(SAFEBOOT_HCP_DSPACE)enrollsvc-repl \
	               -f $(HCP_ENROLLSVC_OUT)/repl.Dockerfile \
	               $(HCP_ENROLLSVC_OUT)/repl/
	$Qtouch $@

# "docker image rm" to remove the container image (interface and recipe)
clean_hcp_enrollsvc-repl:
ifeq (yes,$(shell stat $(HCP_ENROLLSVC_OUT)/repl.built > /dev/null 2>&1 && echo yes))
	$Qdocker image rm $(SAFEBOOT_HCP_DSPACE)enrollsvc-repl
	$Qrm $(HCP_ENROLLSVC_OUT)/repl.built
	$Qrm $(HCP_ENROLLSVC_OUT)/repl.Dockerfile
endif
ifeq (yes,$(shell stat $(HCP_ENROLLSVC_OUT)/repl > /dev/null 2>&1 && echo yes))
	$Qrm -rf $(HCP_ENROLLSVC_OUT)/repl
endif

##################
# enrollsvc-mgmt #
##################

MDIRS += $(HCP_ENROLLSVC_OUT)/mgmt
$(HCP_ENROLLSVC_OUT)/mgmt: | $(HCP_ENROLLSVC_OUT)

# Same idea as in enrollsvc-repl above.
HCP_ENROLLSVC_MGMT_FILES_NOEXEC := \
	rest_api.py
HCP_ENROLLSVC_MGMT_FILES_EXEC := \
	run_mgmt.sh setup_enrolldb.sh init_repo.sh flask_wrapper.sh \
	op_add.sh op_query.sh op_delete.sh op_find.sh \
	cb_checkout.sh cb_commit.sh
HCP_ENROLLSVC_MGMT_FILES := $(HCP_ENROLLSVC_MGMT_FILES_NOEXEC) $(HCP_ENROLLSVC_MGMT_FILES_EXEC)
HCP_ENROLLSVC_MGMT_PATHS := $(foreach i,$(HCP_ENROLLSVC_MGMT_FILES),$(HCP_ENROLLSVC_OUT)/mgmt/$i)

define enrollsvc_mgmt_file
$(HCP_ENROLLSVC_OUT)/mgmt/$1: | $(HCP_ENROLLSVC_OUT)/mgmt
$(HCP_ENROLLSVC_OUT)/mgmt/$1: $(HCP_ENROLLSVC_SRC)/$1
$(HCP_ENROLLSVC_OUT)/mgmt/$1:
	$Qcp $$< $$@
endef
$(foreach i,$(HCP_ENROLLSVC_MGMT_FILES),$(eval $(call enrollsvc_mgmt_file,$i)))

# Set up rules for injecting "SAFEBOOT_SBIN/EXTRA" files. (Right now, I'm
# including functions.sh, safeboot.conf, and sbin/*. Perhaps an explicit list
# would be harder to maintain but still objectively "better"?)

MDIRS += $(HCP_ENROLLSVC_OUT)/mgmt/safeboot-sbin
MDIRS += $(HCP_ENROLLSVC_OUT)/mgmt/safeboot-xtra
$(HCP_ENROLLSVC_OUT)/mgmt/safeboot-sbin: | $(HCP_ENROLLSVC_OUT)/mgmt
$(HCP_ENROLLSVC_OUT)/mgmt/safeboot-xtra: | $(HCP_ENROLLSVC_OUT)/mgmt

HCP_ENROLLSVC_SAFEBOOT_SBIN := $(shell cd $(TOP)/sbin && ls -1)
HCP_ENROLLSVC_SAFEBOOT_XTRA := functions.sh safeboot.conf
define enrollsvc_safeboot_file
$(HCP_ENROLLSVC_OUT)/mgmt/safeboot-$2/$1: | $(HCP_ENROLLSVC_OUT)/mgmt/safeboot-$2
$(HCP_ENROLLSVC_OUT)/mgmt/safeboot-$2/$1: $(TOP)/$3/$1
$(HCP_ENROLLSVC_OUT)/mgmt/safeboot-$2/$1:
	$Qcp $$< $$@
$(eval HCP_ENROLLSVC_MGMT_PATHS += $(HCP_ENROLLSVC_OUT)/mgmt/safeboot-$2/$1)
endef
$(foreach i,$(HCP_ENROLLSVC_SAFEBOOT_SBIN),$(eval $(call enrollsvc_safeboot_file,$i,sbin,sbin)))
$(foreach i,$(HCP_ENROLLSVC_SAFEBOOT_XTRA),$(eval $(call enrollsvc_safeboot_file,$i,xtra,.)))

# Dockerfile-generation. Same note as for repl.Dockerfile above.
$(HCP_ENROLLSVC_OUT)/mgmt.Dockerfile: | $(HCP_ENROLLSVC_OUT)
$(HCP_ENROLLSVC_OUT)/mgmt.Dockerfile: $(HCP_ENROLLSVC_SRC)/Makefile
$(HCP_ENROLLSVC_OUT)/mgmt.Dockerfile: $(HCP_ENROLLSVC_SRC)/mgmt.Dockerfile
$(HCP_ENROLLSVC_OUT)/mgmt.Dockerfile:
	$Qecho "FROM $(SAFEBOOT_HCP_DSPACE)enrollsvc-common" > $@
	$Qcat $(HCP_ENROLLSVC_SRC)/mgmt.Dockerfile | \
	sed -e "s/HCP_ENROLLSVC_MGMT_FILES_NOEXEC/$(HCP_ENROLLSVC_MGMT_FILES_NOEXEC)/" | \
	sed -e "s/HCP_ENROLLSVC_MGMT_FILES_EXEC/$(HCP_ENROLLSVC_MGMT_FILES_EXEC)/" >> $@

# "docker build" to create the container image (recipe only)
$(HCP_ENROLLSVC_OUT)/mgmt.built: $(HCP_ENROLLSVC_OUT)/mgmt.Dockerfile
$(HCP_ENROLLSVC_OUT)/mgmt.built: $(HCP_ENROLLSVC_MGMT_PATHS)
$(HCP_ENROLLSVC_OUT)/mgmt.built: $(HCP_ENROLLSVC_OUT)/common.built
$(HCP_ENROLLSVC_OUT)/mgmt.built:
	$Qdocker build -t $(SAFEBOOT_HCP_DSPACE)enrollsvc-mgmt \
	               -f $(HCP_ENROLLSVC_OUT)/mgmt.Dockerfile \
		       --build-arg DB_USER=$(DB_USER) \
		       --build-arg FLASK_USER=$(FLASK_USER) \
	               $(HCP_ENROLLSVC_OUT)/mgmt/
	$Qtouch $@

# "docker image rm" to remove the container image (interface and recipe)
clean_hcp_enrollsvc-mgmt:
ifeq (yes,$(shell stat $(HCP_ENROLLSVC_OUT)/mgmt.built > /dev/null 2>&1 && echo yes))
	$Qdocker image rm $(SAFEBOOT_HCP_DSPACE)enrollsvc-mgmt
	$Qrm $(HCP_ENROLLSVC_OUT)/mgmt.built
	$Qrm $(HCP_ENROLLSVC_OUT)/mgmt.Dockerfile
endif
ifeq (yes,$(shell stat $(HCP_ENROLLSVC_OUT)/mgmt > /dev/null 2>&1 && echo yes))
	$Qrm -rf $(HCP_ENROLLSVC_OUT)/mgmt
endif

################
# cleanup deps #
################

clean_hcp: clean_hcp_enrollsvc

clean_hcp_base: clean_hcp_enrollsvc-common

clean_hcp_enrollsvc: clean_hcp_enrollsvc-common

clean_hcp_enrollsvc-common: clean_hcp_enrollsvc-repl
clean_hcp_enrollsvc-common: clean_hcp_enrollsvc-mgmt



# TODO: The declaring of service instances and their configuration and the
# rules for starting and stopping them should be decoupled from this Makefile,
# which should only be concerned with producing the application image(s). This
# will first require that the per-instance configuration not be baked into the
# container image! After that, this rules should be suctioned out into a
# distinct Makefile, that should depend on caller-defined environment to
# specify the per-instance details.

# Both the enrollsvc containers mount the same state, which they expect to be
# at a path set by STATE_PREFIX. -mgmt mounts readwrite, -repl mounts readonly.
HCP_ENROLLSVC_STATE := $(HCP_ENROLLSVC_OUT)/run
HCP_ENROLLSVC_STATE_PREFIX := /enrollsvc

# Both containers also mount this 'msgbus' directory. Each of them redirects
# their stdout/stderr to a file in this directory (of the same name as their
# container image), and each of them listens for writes to a control file (same
# name plus a "-ctrl" suffix), which is currently only used for signaling the
# service to shut down (when "die" is written to that file).
HCP_ENROLLSVC_MSGBUS := $(HCP_ENROLLSVC_OUT)/msgbus
HCP_ENROLLSVC_MSGBUS_PREFIX := /msgbus

# Use these has the hostnames and network aliases
HCP_ENROLLSVC_MGMT_HOSTNAME := enrollsvc-mgmt
HCP_ENROLLSVC_REPL_HOSTNAME := enrollsvc-repl

########################
# Detect current state #
########################

ifeq (yes,$(shell test -d $(HCP_ENROLLSVC_STATE) > /dev/null 2>&1 && echo yes))
HCP_ENROLLSVC_INITIALIZED := 1
endif
ifeq (yes,$(shell stat $(HCP_ENROLLSVC_OUT)/repl.run.started > /dev/null 2>&1 && echo yes))
HCP_ENROLLSVC_REPL_RUNNING := 1
endif
ifeq (yes,$(shell stat $(HCP_ENROLLSVC_OUT)/mgmt.run.started > /dev/null 2>&1 && echo yes))
HCP_ENROLLSVC_MGMT_RUNNING := 1
endif
ifneq (,$(HCP_ENROLLSVC_MGMT_RUNNING)$(HCP_ENROLLSVC_REPL_RUNNING))
HCP_ENROLLSVC_RUNNING := 1
endif

#########################
# Global/one-time state #
#########################

# "docker run [] setup_enrolldb", for one-time initialization (recipe only)
ifdef NO_REINIT
$(HCP_ENROLLSVC_OUT)/run.initialized: | $(HCP_ENROLLSVC_OUT)/mgmt.built
$(HCP_ENROLLSVC_OUT)/run.initialized: | $(HCP_ENROLLSVC_OUT)/repl.built
else
$(HCP_ENROLLSVC_OUT)/run.initialized: $(HCP_ENROLLSVC_OUT)/mgmt.built
$(HCP_ENROLLSVC_OUT)/run.initialized: $(HCP_ENROLLSVC_OUT)/repl.built
endif
$(HCP_ENROLLSVC_OUT)/run.initialized: | $(HCP_OUT)/testnetwork.created
$(HCP_ENROLLSVC_OUT)/run.initialized:
ifdef HCP_ENROLLSVC_RUNNING
	$Qecho "Can't (re)initialize 'enrollsvc' state while it is running."
	$Qecho "Do 'make hcp_enrollsvc_run_stop' to stop it."
	$Qexit 1
endif
ifdef HCP_ENROLLSVC_INITIALIZED
ifndef FORCE
	$Qecho "State for 'enrollsvc' exists, needs reinitialization."
	$Qecho "Do 'make clean_hcp_enrollsvc_run', or set FORCE=1 and I"
	$Qecho "will do it for you."
	$Qecho "(Or set NO_REINIT=1 to override the initilization dependency.)"
	$Qexit 1
endif
	$Qrm -rf $(HCP_ENROLLSVC_STATE)
endif
	$Qmkdir $(HCP_ENROLLSVC_STATE)
	$Qdocker run -i --rm \
		-v $(HCP_ENROLLSVC_STATE):$(HCP_ENROLLSVC_STATE_PREFIX) \
		--env STATE_PREFIX="$(HCP_ENROLLSVC_STATE_PREFIX)" \
		--network $(HCP_TESTNETWORK_NAME) \
		--name $(HCP_ENROLLSVC_MGMT_HOSTNAME) \
		--hostname $(HCP_ENROLLSVC_MGMT_HOSTNAME) \
		--network-alias $(HCP_ENROLLSVC_MGMT_HOSTNAME) \
		--label $(SAFEBOOT_HCP_DSPACE)all=1 \
		--label $(SAFEBOOT_HCP_DSPACE)enrollsvc=1 \
		--label $(SAFEBOOT_HCP_DSPACE)enrollsvc_mgmt=1 \
		--label $(SAFEBOOT_HCP_DSPACE)enrollsvc_mgmt_setup=1 \
		$(SAFEBOOT_HCP_DSPACE)enrollsvc-mgmt \
		/hcp/setup_enrolldb.sh
	$Qecho "Done setting up 'enrollsvc' state"
	$Qtouch $@

# "docker run [] setup_enrolldb", for one-time initialization (interface only)
hcp_enrollsvc_run_init: $(HCP_ENROLLSVC_OUT)/run.initialized

# "rm -rf enrolldb" to remove one-time initialization (interface and recipe)
ifdef HCP_ENROLLSVC_RUNNING
ifdef FORCE
clean_hcp_enrollsvc_run: hcp_enrollsvc_run_stop
endif
endif
clean_hcp_enrollsvc_run:
ifdef HCP_ENROLLSVC_RUNNING
ifndef FORCE
	$Qecho "Error, the service appears to be running. Stop it before cleaning."
	$Qecho "(Or set FORCE=1 and I'll automatically stop it for you.)"
	$Q/bin/false
endif
endif
ifdef HCP_ENROLLSVC_INITIALIZED
	$Qrm -rf $(HCP_ENROLLSVC_STATE)
	$Qrm -rf $(HCP_ENROLLSVC_MSGBUS)
	$Qrm -f $(HCP_ENROLLSVC_OUT)/run.initialized
	$Qrm -f $(HCP_ENROLLSVC_OUT)/repl.run.*
	$Qrm -f $(HCP_ENROLLSVC_OUT)/mgmt.run.*
	$Qecho "Done cleaning up 'enrollsvc' state"
endif

############################################
# enrollsvc (wrappers for -mgmt and -repl) #
############################################

hcp_enrollsvc_run_start: hcp_enrollsvc-mgmt_run_start
hcp_enrollsvc_run_start: hcp_enrollsvc-repl_run_start

hcp_enrollsvc_run_stop: hcp_enrollsvc-mgmt_run_stop
hcp_enrollsvc_run_stop: hcp_enrollsvc-repl_run_stop

##################
# enrollsvc-mgmt #
##################

# "docker run [] run_mgmt.sh", to start the service (recipe only)
ifndef HCP_ENROLLSVC_MGMT_RUNNING
$(HCP_ENROLLSVC_OUT)/mgmt.run.started: | $(HCP_OUT)/testnetwork.created
$(HCP_ENROLLSVC_OUT)/mgmt.run.started: $(HCP_ENROLLSVC_OUT)/run.initialized
$(HCP_ENROLLSVC_OUT)/mgmt.run.started:
	$Qmkdir -p $(HCP_ENROLLSVC_MSGBUS)
	$Qrm -f $(HCP_ENROLLSVC_MSGBUS)/enrollsvc-mgmt*
	$Qrm -f $(HCP_ENROLLSVC_OUT)/mgmt.run.cid
	$Qrm -f $(HCP_ENROLLSVC_OUT)/mgmt.run.lastExitCode
	$Qrm -f $(HCP_ENROLLSVC_OUT)/mgmt.run.signaled
	$Qdocker run -d \
		--cidfile=$(HCP_ENROLLSVC_OUT)/mgmt.run.cid \
		-v $(HCP_ENROLLSVC_STATE):$(HCP_ENROLLSVC_STATE_PREFIX):rw \
		--env STATE_PREFIX="$(HCP_ENROLLSVC_STATE_PREFIX)" \
		-v $(HCP_ENROLLSVC_MSGBUS):$(HCP_ENROLLSVC_MSGBUS_PREFIX) \
		--network $(HCP_TESTNETWORK_NAME) \
		--name $(HCP_ENROLLSVC_MGMT_HOSTNAME) \
		--hostname $(HCP_ENROLLSVC_MGMT_HOSTNAME) \
		--network-alias $(HCP_ENROLLSVC_MGMT_HOSTNAME) \
		-p 5000:5000 \
		--label $(SAFEBOOT_HCP_DSPACE)all=1 \
		--label $(SAFEBOOT_HCP_DSPACE)enrollsvc=1 \
		--label $(SAFEBOOT_HCP_DSPACE)enrollsvc_mgmt=1 \
		--label $(SAFEBOOT_HCP_DSPACE)enrollsvc_mgmt_run=1 \
		$(SAFEBOOT_HCP_DSPACE)enrollsvc-mgmt \
		/hcp/run_mgmt.sh
	$Qecho "Done starting 'enrollsvc-mgmt'"
	$Qecho "Output at; $(HCP_ENROLLSVC_MSGBUS)/enrollsvc-mgmt"
	$Qtouch $@
endif

# "echo die > enrollsvc-mgmt-ctrl", signal service to exit (recipe only)
ifdef HCP_ENROLLSVC_MGMT_RUNNING
$(HCP_ENROLLSVC_OUT)/mgmt.run.signaled: $(HCP_ENROLLSVC_OUT)/mgmt.run.started
	$Qecho "Signaling 'enrollsvc-mgmt' to exit"
	$Qecho "die" > $(HCP_ENROLLSVC_MSGBUS)/enrollsvc-mgmt-ctrl
	$Qtouch $@
endif

# "docker run [] run_mgmt.sh", to start the service (interface only)
ifndef HCP_ENROLLSVC_MGMT_RUNNING
hcp_enrollsvc-mgmt_run_start: $(HCP_ENROLLSVC_OUT)/mgmt.run.started
endif
hcp_enrollsvc-mgmt_run_start:

# "docker {wait,rm}", to stop the service (interface and recipe)
hcp_enrollsvc-mgmt_run_stop:
ifdef HCP_ENROLLSVC_MGMT_RUNNING
	$Qdocker container wait `cat $(HCP_ENROLLSVC_OUT)/mgmt.run.cid` > \
		$(HCP_ENROLLSVC_OUT)/mgmt.run.lastExitCode
	$Qdocker container rm `cat $(HCP_ENROLLSVC_OUT)/mgmt.run.cid`
	$Qtest `cat $(HCP_ENROLLSVC_OUT)/mgmt.run.lastExitCode` -eq 0 && \
		echo "enrollsvc-mgmt exited with SUCCESS" || \
		echo "enrollsvc-mgmt exited with FAILURE!! (probably long ago)"
	$Qrm $(HCP_ENROLLSVC_OUT)/mgmt.run.started
	$Qrm $(HCP_ENROLLSVC_OUT)/mgmt.run.signaled
	$Qrm $(HCP_ENROLLSVC_OUT)/mgmt.run.cid
	$Qecho "Done stopping 'enrollsvc-mgmt'"
hcp_enrollsvc-mgmt_run_stop: $(HCP_ENROLLSVC_OUT)/mgmt.run.signaled
endif

##################
# enrollsvc-repl #
##################

# "docker run [] run_repl.sh", to start the service (recipe only)
ifndef HCP_ENROLLSVC_REPL_RUNNING
$(HCP_ENROLLSVC_OUT)/repl.run.started: | $(HCP_OUT)/testnetwork.created
$(HCP_ENROLLSVC_OUT)/repl.run.started: $(HCP_ENROLLSVC_OUT)/run.initialized
$(HCP_ENROLLSVC_OUT)/repl.run.started:
	$Qmkdir -p $(HCP_ENROLLSVC_MSGBUS)
	$Qrm -f $(HCP_ENROLLSVC_MSGBUS)/enrollsvc-repl*
	$Qrm -f $(HCP_ENROLLSVC_OUT)/repl.run.cid
	$Qrm -f $(HCP_ENROLLSVC_OUT)/repl.run.lastExitCode
	$Qrm -f $(HCP_ENROLLSVC_OUT)/repl.run.signaled
	$Qdocker run -d \
		--cidfile=$(HCP_ENROLLSVC_OUT)/repl.run.cid \
		-v $(HCP_ENROLLSVC_STATE):$(HCP_ENROLLSVC_STATE_PREFIX):ro \
		--env STATE_PREFIX="$(HCP_ENROLLSVC_STATE_PREFIX)" \
		-v $(HCP_ENROLLSVC_MSGBUS):$(HCP_ENROLLSVC_MSGBUS_PREFIX) \
		--network $(HCP_TESTNETWORK_NAME) \
		--name $(HCP_ENROLLSVC_REPL_HOSTNAME) \
		--hostname $(HCP_ENROLLSVC_REPL_HOSTNAME) \
		--network-alias $(HCP_ENROLLSVC_REPL_HOSTNAME) \
		-p 9418:9418 \
		--label $(SAFEBOOT_HCP_DSPACE)all=1 \
		--label $(SAFEBOOT_HCP_DSPACE)enrollsvc=1 \
		--label $(SAFEBOOT_HCP_DSPACE)enrollsvc_repl=1 \
		--label $(SAFEBOOT_HCP_DSPACE)enrollsvc_repl_run=1 \
		$(SAFEBOOT_HCP_DSPACE)enrollsvc-repl \
		/hcp/run_repl.sh
	$Qecho "Done starting 'enrollsvc-repl'"
	$Qecho "Output at; $(HCP_ENROLLSVC_MSGBUS)/enrollsvc-repl"
	$Qtouch $@
endif

# "echo die > enrollsvc-repl-ctrl", signal service to exit (recipe only)
ifdef HCP_ENROLLSVC_REPL_RUNNING
$(HCP_ENROLLSVC_OUT)/repl.run.signaled: $(HCP_ENROLLSVC_OUT)/repl.run.started
	$Qecho "Signaling 'enrollsvc-repl' to exit"
	$Qecho "die" > $(HCP_ENROLLSVC_MSGBUS)/enrollsvc-repl-ctrl
	$Qtouch $@
endif

# "docker run [] run_repl.sh", to start the service (interface only)
ifndef HCP_ENROLLSVC_REPL_RUNNING
hcp_enrollsvc-repl_run_start: $(HCP_ENROLLSVC_OUT)/repl.run.started
endif
hcp_enrollsvc-repl_run_start:

# "docker {wait,rm}", to stop the service (interface and recipe)
hcp_enrollsvc-repl_run_stop:
ifdef HCP_ENROLLSVC_REPL_RUNNING
	$Qdocker container wait `cat $(HCP_ENROLLSVC_OUT)/repl.run.cid` > \
		$(HCP_ENROLLSVC_OUT)/repl.run.lastExitCode
	$Qdocker container rm `cat $(HCP_ENROLLSVC_OUT)/repl.run.cid`
	$Qtest `cat $(HCP_ENROLLSVC_OUT)/repl.run.lastExitCode` -eq 0 && \
		echo "enrollsvc-repl exited with SUCCESS" || \
		echo "enrollsvc-repl exited with FAILURE!! (probably long ago)"
	$Qrm $(HCP_ENROLLSVC_OUT)/repl.run.started
	$Qrm $(HCP_ENROLLSVC_OUT)/repl.run.signaled
	$Qrm $(HCP_ENROLLSVC_OUT)/repl.run.cid
	$Qecho "Done stopping 'enrollsvc-repl'"
hcp_enrollsvc-repl_run_stop: $(HCP_ENROLLSVC_OUT)/repl.run.signaled
endif

################
# cleanup deps #
################

clean_hcp_enrollsvc-repl: clean_hcp_enrollsvc_run
clean_hcp_enrollsvc-mgmt: clean_hcp_enrollsvc_run
clean_hcp_testnetwork: clean_hcp_enrollsvc_run

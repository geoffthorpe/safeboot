HCP_SUBMODULES_OUT := $(HCP_OUT)/submodules

$(HCP_SUBMODULES_OUT): | $(HCP_OUT)
MDIRS += $(HCP_SUBMODULES_OUT)

# "install" is a persistent directory for compiled and installed submodule
# tools. The builder container mounts this as it configures submodule code to
# compile and install to this path, and inter-submodule dependencies (headers,
# linking, ...) also use this install path to find each others' stuff.
HCP_SUBMODULES_INSTALL := $(HCP_SUBMODULES_OUT)/install
$(HCP_SUBMODULES_INSTALL): | $(HCP_SUBMODULES_OUT)
MDIRS += $(HCP_SUBMODULES_INSTALL)

# The path the "install" directory is mounted to.
HCP_SUBMODULES_INSTALL_DEST := /install

# The "docker run" preamble that mounts "install" where it should go
HCP_SUBMODULES_DOCKER_RUN := \
	docker run -i --rm \
	-v $(HCP_SUBMODULES_INSTALL):$(HCP_SUBMODULES_INSTALL_DEST)

# If we declare build targets with a normal dependency on
# $(HCP_BUILDER_OUT)/built (because we need the builder image in order to build
# submodules), then any change that updates the builder image at all will cause
# a wholesale rebuild of submodules from first principles. If instead we
# declare it with a "|" dependency, this doesn't happen (it only requires the
# builder image to exist, it won't compare timestamps).
#
# For automation sanity, we default to the meticulous case that ensures
# software is rebuilt if the build environment changes (even if the change is
# only a timestamp). Define LAZY to define the less aggressive dependencies.
ifneq (,$(LAZY))
HCP_SUBMODULES_BUILDER_DEP := | $(HCP_BUILDER_OUT)/built
else
HCP_SUBMODULES_BUILDER_DEP := $(HCP_BUILDER_OUT)/built
endif

###########
# libtpms #
###########

HCP_SUBMODULES_LIBTPMS_RUN := $(HCP_SUBMODULES_DOCKER_RUN) \
	-v $(TOP)/libtpms:/libtpms \
	$(SAFEBOOT_HCP_DSPACE)builder \
	bash -c

$(HCP_SUBMODULES_OUT)/libtpms.autogened: libtpms/autogen.sh
$(HCP_SUBMODULES_OUT)/libtpms.autogened: $(HCP_SUBMODULES_BUILDER_DEP)
$(HCP_SUBMODULES_OUT)/libtpms.autogened: | $(HCP_SUBMODULES_INSTALL)
$(HCP_SUBMODULES_OUT)/libtpms.autogened:
	$Q$(HCP_SUBMODULES_LIBTPMS_RUN) "cd /libtpms ; NOCONFIGURE=1 ./autogen.sh"
	$Qtouch $@

CMD_LIBTPMS_CFG := cd /libtpms ; ./configure --with-openssl --with-tpm2
CMD_LIBTPMS_CFG += --prefix=$(HCP_SUBMODULES_INSTALL_DEST)
$(HCP_SUBMODULES_OUT)/libtpms.configured: $(HCP_SUBMODULES_OUT)/libtpms.autogened
$(HCP_SUBMODULES_OUT)/libtpms.configured:
	$Q$(HCP_SUBMODULES_LIBTPMS_RUN) "$(CMD_LIBTPMS_CFG)"
	$Qtouch $@

CMD_LIBTPMS_COMPILE := cd /libtpms ; make $(SAFEBOOT_HCP_SUBMODULES_MAKE_PARALLEL)
$(HCP_SUBMODULES_OUT)/libtpms.compiled: $(HCP_SUBMODULES_OUT)/libtpms.configured
$(HCP_SUBMODULES_OUT)/libtpms.compiled:
	$Q$(HCP_SUBMODULES_LIBTPMS_RUN) "$(CMD_LIBTPMS_COMPILE)"
	$Qtouch $@

$(HCP_SUBMODULES_OUT)/libtpms.installed: $(HCP_SUBMODULES_OUT)/libtpms.compiled
$(HCP_SUBMODULES_OUT)/libtpms.installed:
	$Q$(HCP_SUBMODULES_LIBTPMS_RUN) "cd /libtpms ; make install"
	$Qtouch $@

#########
# swtpm #
#########

HCP_SUBMODULES_SWTPM_RUN := $(HCP_SUBMODULES_DOCKER_RUN) \
	-v $(TOP)/swtpm:/swtpm \
	$(SAFEBOOT_HCP_DSPACE)builder \
	bash -c

$(HCP_SUBMODULES_OUT)/swtpm.autogened: swtpm/autogen.sh
$(HCP_SUBMODULES_OUT)/swtpm.autogened: $(HCP_SUBMODULES_BUILDER_DEP)
$(HCP_SUBMODULES_OUT)/swtpm.autogened: | $(HCP_SUBMODULES_INSTALL)
$(HCP_SUBMODULES_OUT)/swtpm.autogened:
	$Q$(HCP_SUBMODULES_SWTPM_RUN) "cd /swtpm ; NOCONFIGURE=1 ./autogen.sh"
	$Qtouch $@

CMD_SWTPM_CFG := cd /swtpm ;
CMD_SWTPM_CFG += LIBTPMS_LIBS='-L$(HCP_SUBMODULES_INSTALL_DEST)/lib -ltpms'
CMD_SWTPM_CFG += LIBTPMS_CFLAGS='-I$(HCP_SUBMODULES_INSTALL_DEST)/include'
CMD_SWTPM_CFG += ./configure --with-openssl --with-tpm2 --prefix=$(HCP_SUBMODULES_INSTALL_DEST)

$(HCP_SUBMODULES_OUT)/swtpm.configured: $(HCP_SUBMODULES_OUT)/swtpm.autogened
$(HCP_SUBMODULES_OUT)/swtpm.configured: $(HCP_SUBMODULES_OUT)/libtpms.installed
$(HCP_SUBMODULES_OUT)/swtpm.configured:
	$Q$(HCP_SUBMODULES_SWTPM_RUN) "$(CMD_SWTPM_CFG)"
	$Qtouch $@

$(HCP_SUBMODULES_OUT)/swtpm.compiled: $(HCP_SUBMODULES_OUT)/swtpm.configured
$(HCP_SUBMODULES_OUT)/swtpm.compiled:
	$Q$(HCP_SUBMODULES_SWTPM_RUN) "cd /swtpm ; make $(SAFEBOOT_HCP_SUBMODULES_MAKE_PARALLEL)"
	$Qtouch $@

$(HCP_SUBMODULES_OUT)/swtpm.installed: $(HCP_SUBMODULES_OUT)/swtpm.compiled
$(HCP_SUBMODULES_OUT)/swtpm.installed:
	$Q$(HCP_SUBMODULES_SWTPM_RUN) "cd /swtpm ; make install"
	$Qtouch $@

##################
# install.tar.gz #
##################

TGZ_CMD := cd /put_it_here ;
TGZ_CMD += tar zcf install.tar.gz $(HCP_SUBMODULES_INSTALL_DEST) ;
TGZ_CMD += chown --reference=swtpm.installed install.tar.gz

$(HCP_SUBMODULES_OUT)/install.tar.gz: $(HCP_SUBMODULES_OUT)/swtpm.installed
$(HCP_SUBMODULES_OUT)/install.tar.gz:
	$Q$(HCP_SUBMODULES_DOCKER_RUN) \
		-v $(HCP_SUBMODULES_OUT):/put_it_here \
		$(SAFEBOOT_HCP_DSPACE)builder bash -c "$(TGZ_CMD)"

# A wrapper target to build the submodules
hcp_submodules: $(HCP_SUBMODULES_OUT)/install.tar.gz

# Cleanup sequence
# - if (out/install.tar.gz)
#   - rm out/install.tar.gz
# - if (out/swtpm.installed)
#   - cd /swtpm && make uninstall
#   - rm out/swtpm.installed
# - if (out/libtpms.installed)
#   - cd /libtpms && make uninstall
#   - rm out/libtpms.installed
# - if (out/install/ && it contains files)
#   - if (!FORCE), error and fail
#   - assist_cleanup volume /install
# - if (out/swtpm.*)
#   - assist_cleanup submodule swtpm (chown)
#   - rm out/swtpm.*
# - if (out/libtpms.*)
#   - assist_cleanup submodule libtpms (chown)
#   - rm out/libtpms.*
# - rmdir out/

ifeq (yes,$(shell stat $(HCP_SUBMODULES_INSTALL) > /dev/null 2>&1 && echo yes))
SUBMODULES_INSTALLED_FILES := $(find $(HCP_SUBMODULES_INSTALL)/ -type f 2> /dev/null)
endif

clean_hcp_submodules:
ifeq (yes,$(shell stat $(HCP_SUBMODULES_OUT) > /dev/null 2>&1 && echo yes))
ifeq (yes,$(shell stat $(HCP_SUBMODULES_OUT)/install.tar.gz > /dev/null 2>&1 && echo yes))
	$Qrm $(HCP_SUBMODULES_OUT)/install.tar.gz
endif
ifeq (yes,$(shell stat $(HCP_SUBMODULES_OUT)/swtpm.installed > /dev/null 2>&1 && echo yes))
	$Q$(HCP_SUBMODULES_SWTPM_RUN) "cd /swtpm ; make uninstall"
	$Qrm $(HCP_SUBMODULES_OUT)/swtpm.installed
endif
ifeq (yes,$(shell stat $(HCP_SUBMODULES_OUT)/libtpms.installed > /dev/null 2>&1 && echo yes))
	$Q$(HCP_SUBMODULES_LIBTPMS_RUN) "cd /libtpms ; make uninstall"
	$Qrm $(HCP_SUBMODULES_OUT)/libtpms.installed
endif
ifeq (yes,$(shell stat $(HCP_SUBMODULES_INSTALL) > /dev/null 2>&1 && echo yes))
ifneq (,$(SUBMODULES_INSTALLED_FILES))
ifneq (,$(FORCE))
	$Qecho "Error, the submodules installation directory contains files"
	$Qecho "so one of the \"uninstall\" rules is probably incomplete."
	$Qecho "Set FORCE=1 if you want me to blast it away anyway."
	$Q/bin/false
endif
endif
	$QUTIL_IMAGE=$(SAFEBOOT_HCP_BASE) \
		$(ASSIST_CLEANUP) volume $(HCP_SUBMODULES_INSTALL)
endif
ifeq (yes,$(shell stat $(HCP_SUBMODULES_OUT)/swtpm.* > /dev/null 2>&1 && echo yes))
	$QUTIL_IMAGE=$(SAFEBOOT_HCP_BASE) \
		$(ASSIST_CLEANUP) submodule $(TOP)/swtpm autogen.sh
	$Qrm $(HCP_SUBMODULES_OUT)/swtpm.*
endif
ifeq (yes,$(shell stat $(HCP_SUBMODULES_OUT)/libtpms.* > /dev/null 2>&1 && echo yes))
	$QUTIL_IMAGE=$(SAFEBOOT_HCP_BASE) \
		$(ASSIST_CLEANUP) submodule $(TOP)/libtpms autogen.sh
	$Qrm $(HCP_SUBMODULES_OUT)/libtpms.*
endif
	$Qrmdir $(HCP_SUBMODULES_OUT)
endif

# Cleanup ordering
clean_hcp_builder: clean_hcp_submodules

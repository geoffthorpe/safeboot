# "base platform" layers
#
# An _ordered_ sequence of image layers that build a "base platform".
# Everything else is derived from the result of these layers.
#     1apt-source
#         - optional, see SAFEBOOT_APT_SOURCE in workflow/settings.mk
#         - overrides or supplements the source repositories and signature keys
#           used for debian package installation.
#         - if enabled, the user should;
#           - add files (package source lists, signing keys, etc) to
#             $(HCP_BASE_SRC)/1apt-source-context,
#           - edit $(HCP_BASE_OUT)/1apt-source.Dockerfile accordingly to
#             inject those files, and
#           - list these files in SAFEBOOT_HCP_1APT_FILES so that changes to
#             them get picked up by dependency-handling.
#     2apt-usable
#         - twiddle with debconf and apt-utils to make the environment less
#           spartan and hostile.
#         - make the container image timezone-compatible with the host.
#     3add-cacerts
#         - optional, see SAFEBOOT_ADD_CACERTS in workflow/settings.mk
#         - install host-side trust roots (CA certificates).
#     4platform
#         - installs a common, base-line set of system tools that should show up
#           in all other container images.

HCP_BASE_SRC := $(HCP_SRC)/base
HCP_BASE_OUT := $(HCP_OUT)/base

$(HCP_BASE_OUT): | $(HCP_OUT)
MDIRS += $(HCP_BASE_OUT)

# For downstream (builds, apps, ...) usage;
# - Depend on $(HCP_BASE_TOUCHFILE) to ensure it is (re)built as required.
# - Use "FROM $(SAFEBOOT_HCP_DSPACE)$(HCP_BASE_IMAGE)" to derive images.
HCP_BASE_TOUCHFILE := $(HCP_BASE_OUT)/4platform.built
HCP_BASE_IMAGE := base_4platform

# A wrapper target to build the "base platform" image
hcp_base: $(HCP_BASE_TOUCHFILE)

# A change to these files automatically puts (derived) Dockerfiles out of date.
HCP_BASE_DEPS_COMMON := $(HCP_DEPS_COMMON) $(HCP_BASE_SRC)/Makefile

# LAYER: 0import
#      - inherit the debian image we're based on (per workflow/settings.mk)

$(HCP_BASE_OUT)/0import.Dockerfile: | $(HCP_BASE_OUT)
$(HCP_BASE_OUT)/0import.Dockerfile: $(HCP_BASE_DEPS_COMMON)
$(HCP_BASE_OUT)/0import.Dockerfile:
	$Qecho "FROM $(SAFEBOOT_HCP_BASE)" > $@

$(HCP_BASE_OUT)/0import.built: $(HCP_BASE_OUT)/0import.Dockerfile
$(HCP_BASE_OUT)/0import.built:
	$Qcat $(HCP_BASE_OUT)/0import.Dockerfile | \
		docker build -t $(SAFEBOOT_HCP_DSPACE)base_0import -
	$Qtouch $@

# LAYER: 1apt-source

ifdef SAFEBOOT_HCP_1APT_ENABLE

# SAFEBOOT_HCP_1APT_FILES:= $(foreach i,<files...>,$(HCP_BASE_SRC)/1apt-source-context/$i)

$(HCP_BASE_OUT)/1apt-source.Dockerfile: | $(HCP_BASE_OUT)
$(HCP_BASE_OUT)/1apt-source.Dockerfile: $(HCP_BASE_DEPS_COMMON)
$(HCP_BASE_OUT)/1apt-source.Dockerfile: $(HCP_BASE_SRC)/1apt-source.Dockerfile
$(HCP_BASE_OUT)/1apt-source.Dockerfile: $(SAFEBOOT_HCP_1APT_FILES)
$(HCP_BASE_OUT)/1apt-source.Dockerfile:
	$Qecho "FROM $(SAFEBOOT_HCP_DSPACE)base_0import" > $@
	$Qcat $(HCP_BASE_SRC)/1apt-source.Dockerfile >> $@

$(HCP_BASE_OUT)/1apt-source.built: $(HCP_BASE_OUT)/0import.built
$(HCP_BASE_OUT)/1apt-source.built: $(HCP_BASE_OUT)/1apt-source.Dockerfile
$(HCP_BASE_OUT)/1apt-source.built:
	$Qdocker build -t $(SAFEBOOT_HCP_DSPACE)base_1apt-source \
	               -f $(HCP_BASE_OUT)/1apt-source.Dockerfile \
	               $(HCP_BASE_SRC)/1apt-source-context/
	$Qtouch $@

endif # SAFEBOOT_HCP_1APT_ENABLE

# LAYER: 2apt-usable

HCP_BASE_2APT_SRC := $(HCP_BASE_SRC)/2apt-usable-context
HCP_BASE_2APT_OUT := $(HCP_BASE_OUT)/2apt-usable-context
$(HCP_BASE_2APT_OUT): | $(HCP_BASE_OUT)
MDIRS += $(HCP_BASE_2APT_OUT)

$(HCP_BASE_OUT)/2apt-usable.Dockerfile: | $(HCP_BASE_OUT)
$(HCP_BASE_OUT)/2apt-usable.Dockerfile: $(HCP_BASE_DEPS_COMMON)
$(HCP_BASE_OUT)/2apt-usable.Dockerfile: $(HCP_BASE_SRC)/2apt-usable.Dockerfile
$(HCP_BASE_OUT)/2apt-usable.Dockerfile:
ifdef SAFEBOOT_HCP_1APT_ENABLE
	$Qecho "FROM $(SAFEBOOT_HCP_DSPACE)base_1apt-source" > $@
else
	$Qecho "FROM $(SAFEBOOT_HCP_DSPACE)base_0import" > $@
endif
	$Qcat $(HCP_BASE_SRC)/2apt-usable.Dockerfile >> $@

$(HCP_BASE_2APT_OUT)/apt-proxy.sh: | $(HCP_BASE_2APT_OUT)
$(HCP_BASE_2APT_OUT)/apt-proxy.sh: $(HCP_BASE_2APT_SRC)/apt-proxy.sh
$(HCP_BASE_2APT_OUT)/apt-proxy.sh:
	$Qcp $< $@
$(HCP_BASE_2APT_OUT)/timezone: | $(HCP_BASE_2APT_OUT)
$(HCP_BASE_2APT_OUT)/timezone: /etc/timezone
$(HCP_BASE_2APT_OUT)/timezone:
	$Qcp $< $@

ifdef SAFEBOOT_HCP_1APT_ENABLE
$(HCP_BASE_OUT)/2apt-usable.built: $(HCP_BASE_OUT)/1apt-source.built
else
$(HCP_BASE_OUT)/2apt-usable.built: $(HCP_BASE_OUT)/0import.built
endif
$(HCP_BASE_OUT)/2apt-usable.built: $(HCP_BASE_OUT)/2apt-usable.Dockerfile
$(HCP_BASE_OUT)/2apt-usable.built: $(HCP_BASE_2APT_OUT)/apt-proxy.sh
$(HCP_BASE_OUT)/2apt-usable.built: $(HCP_BASE_2APT_OUT)/timezone
$(HCP_BASE_OUT)/2apt-usable.built:
	$Qdocker build -t $(SAFEBOOT_HCP_DSPACE)base_2apt-usable \
	               -f $(HCP_BASE_OUT)/2apt-usable.Dockerfile \
		       --build-arg SAFEBOOT_HCP_APT_PROXY=$(SAFEBOOT_HCP_APT_PROXY) \
	               $(HCP_BASE_2APT_OUT)/
	$Qtouch $@

# LAYER: 3add-cacerts

ifdef SAFEBOOT_HCP_3ADD_CACERTS_ENABLE

HCP_BASE_3CA_OUT := $(HCP_BASE_OUT)/3add-cacerts-context
$(HCP_BASE_3CA_OUT): | $(HCP_BASE_OUT)
MDIRS += $(HCP_BASE_3CA_OUT)

HCP_BASE_3CA_CERT_SRC := $(shell find $(HCP_BASE_OUT)/3add-cacerts-context -type f)
define hcp_base_3ca_src
	$(eval b := $(shell basename $1))
$(HCP_BASE_3CA_OUT)/$b: | $(HCP_BASE_3CA_OUT)
$(HCP_BASE_3CA_OUT)/$b: $1
$(HCP_BASE_3CA_OUT)/$b:
	$Qcp $$< $$@
$(eval HCP_BASE_3CA_CERTS += $(HCP_BASE_3CA_OUT)/$b)
endef
$(foreach i,$(HCP_BASE_3CA_CERT_SRC),$(eval $(call hcp_base_3ca_src,$i)))

$(HCP_BASE_OUT)/3add-cacerts.Dockerfile: | $(HCP_BASE_OUT)
$(HCP_BASE_OUT)/3add-cacerts.Dockerfile: $(HCP_BASE_DEPS_COMMON)
$(HCP_BASE_OUT)/3add-cacerts.Dockerfile: $(HCP_BASE_SRC)/3add-cacerts.Dockerfile
$(HCP_BASE_OUT)/3add-cacerts.Dockerfile:
	$Qecho "FROM $(SAFEBOOT_HCP_DSPACE)base_2apt-usable" > $@
	$Qcat $(HCP_BASE_SRC)/3add-cacerts.Dockerfile >> $@

$(HCP_BASE_OUT)/3add-cacerts.built: $(HCP_BASE_OUT)/2apt-usable.built
$(HCP_BASE_OUT)/3add-cacerts.built: $(HCP_BASE_OUT)/3add-cacerts.Dockerfile
$(HCP_BASE_OUT)/3add-cacerts.built: $(HCP_BASE_3CA_CERTS)
$(HCP_BASE_OUT)/3add-cacerts.built:
	$Qdocker build -t $(SAFEBOOT_HCP_DSPACE)base_3add-cacerts \
	               -f $(HCP_BASE_OUT)/3add-cacerts.Dockerfile \
	               $(HCP_BASE_3CA_OUT)/
	$Qtouch $@

endif # SAFEBOOT_HCP_3ADD_CACERTS_ENABLE

# LAYER: 4platform

$(HCP_BASE_OUT)/4platform.Dockerfile: | $(HCP_BASE_OUT)
$(HCP_BASE_OUT)/4platform.Dockerfile: $(HCP_BASE_DEPS_COMMON)
$(HCP_BASE_OUT)/4platform.Dockerfile: $(HCP_BASE_SRC)/4platform.Dockerfile
$(HCP_BASE_OUT)/4platform.Dockerfile:
ifdef SAFEBOOT_HCP_3ADD_CACERTS_ENABLE
	$Qecho "FROM $(SAFEBOOT_HCP_DSPACE)base_3add-cacerts" > $@
else
	$Qecho "FROM $(SAFEBOOT_HCP_DSPACE)base_2apt-usable" > $@
endif
	$Qcat $(HCP_BASE_SRC)/4platform.Dockerfile >> $@

ifdef SAFEBOOT_HCP_3ADD_CACERTS_ENABLE
$(HCP_BASE_OUT)/4platform.built: $(HCP_BASE_OUT)/3add-cacerts.built
else
$(HCP_BASE_OUT)/4platform.built: $(HCP_BASE_OUT)/2apt-usable.built
endif
$(HCP_BASE_OUT)/4platform.built: $(HCP_BASE_OUT)/4platform.Dockerfile
$(HCP_BASE_OUT)/4platform.built:
	$Qcat $(HCP_BASE_OUT)/4platform.Dockerfile | \
		docker build -t $(SAFEBOOT_HCP_DSPACE)base_4platform -
	$Qtouch $@

ifeq (yes,$(shell stat $(HCP_BASE_OUT) > /dev/null 2>&1 && echo yes))
clean_hcp_base:
ifeq (yes,$(shell stat $(HCP_BASE_OUT)/4platform.built > /dev/null 2>&1 && echo yes))
	$Qdocker image rm $(SAFEBOOT_HCP_DSPACE)base_4platform
	$Qrm $(HCP_BASE_OUT)/4platform.built
	$Qrm $(HCP_BASE_OUT)/4platform.Dockerfile
endif
ifeq (yes,$(shell stat $(HCP_BASE_OUT)/3add-cacerts.built > /dev/null 2>&1 && echo yes))
	$Qdocker image rm $(SAFEBOOT_HCP_DSPACE)base_3add-cacerts
	$Qrm $(HCP_BASE_OUT)/3add-cacerts.built
	$Qrm $(HCP_BASE_OUT)/3add-cacerts.Dockerfile
	$Qrm -rf $(HCP_BASE_3CA_OUT)
endif
ifeq (yes,$(shell stat $(HCP_BASE_OUT)/2apt-usable.built > /dev/null 2>&1 && echo yes))
	$Qdocker image rm $(SAFEBOOT_HCP_DSPACE)base_2apt-usable
	$Qrm $(HCP_BASE_OUT)/2apt-usable.built
	$Qrm $(HCP_BASE_OUT)/2apt-usable.Dockerfile
	$Qrm -rf $(HCP_BASE_2APT_OUT)
endif
ifeq (yes,$(shell stat $(HCP_BASE_OUT)/1apt-source.built > /dev/null 2>&1 && echo yes))
	$Qdocker image rm $(SAFEBOOT_HCP_DSPACE)base_1apt-source
	$Qrm $(HCP_BASE_OUT)/1apt-source.built
	$Qrm $(HCP_BASE_OUT)/1apt-source.Dockerfile
endif
ifeq (yes,$(shell stat $(HCP_BASE_OUT)/0import.built > /dev/null 2>&1 && echo yes))
	$Qdocker image rm $(SAFEBOOT_HCP_DSPACE)base_0import
	$Qrm $(HCP_BASE_OUT)/0import.Dockerfile
	$Qrm $(HCP_BASE_OUT)/0import.built
endif
	$Qrmdir $(HCP_BASE_OUT)
endif

# Cleanup ordering
clean_hcp: clean_hcp_base

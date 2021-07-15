HCP_BUILDER_SRC := $(HCP_SRC)/builder
HCP_BUILDER_OUT := $(HCP_OUT)/builder

$(HCP_BUILDER_OUT): | $(HCP_OUT)
MDIRS += $(HCP_BUILDER_OUT)

# A wrapper target to build the "builder" image
hcp_builder: $(HCP_BUILDER_OUT)/built

$(HCP_BUILDER_OUT)/Dockerfile: | $(HCP_BUILDER_OUT)
$(HCP_BUILDER_OUT)/Dockerfile: $(HCP_BUILDER_SRC)/Makefile
$(HCP_BUILDER_OUT)/Dockerfile: $(HCP_BUILDER_SRC)/Dockerfile
$(HCP_BUILDER_OUT)/Dockerfile:
	$Qecho "FROM $(SAFEBOOT_HCP_DSPACE)$(HCP_BASE_IMAGE)" > $@
	$Qcat $(HCP_BUILDER_SRC)/Dockerfile >> $@

$(HCP_BUILDER_OUT)/built: $(HCP_BUILDER_OUT)/Dockerfile
$(HCP_BUILDER_OUT)/built: $(HCP_BASE_TOUCHFILE)
$(HCP_BUILDER_OUT)/built:
	$Qcat $(HCP_BUILDER_OUT)/Dockerfile | \
		docker build -t $(SAFEBOOT_HCP_DSPACE)builder -
	$Qtouch $@

clean_hcp_builder:
ifeq (yes,$(shell stat $(HCP_BUILDER_OUT) > /dev/null 2>&1 && echo yes))
ifeq (yes,$(shell stat $(HCP_BUILDER_OUT)/built > /dev/null 2>&1 && echo yes))
	$Qdocker image rm $(SAFEBOOT_HCP_DSPACE)builder
	$Qrm $(HCP_BUILDER_OUT)/built
endif
	$Qrm -f $(HCP_BUILDER_OUT)/Dockerfile
	$Qrmdir $(HCP_BUILDER_OUT)
endif

# Cleanup ordering
clean_hcp_base: clean_hcp_builder

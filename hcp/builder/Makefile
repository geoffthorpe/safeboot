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
		docker build -t $(SAFEBOOT_HCP_DSPACE)builder \
			--label $(SAFEBOOT_HCP_DSPACE)builder=1 -
	$Qtouch $@

clean_hcp_builder:
ifneq (,$(filter $(SAFEBOOT_HCP_DSPACE)builder,$(HCP_EXISTING_IMAGES)))
	$Qdocker image rm $(SAFEBOOT_HCP_DSPACE)builder
endif
	$Qrm -rf $(HCP_BUILDER_OUT)

# Cleanup ordering
clean_hcp_base: clean_hcp_builder

HCP_TESTNETWORK_NAME := $(SAFEBOOT_HCP_DSPACE)network_hcp

# "docker network create" the network (recipe only)
$(HCP_OUT)/testnetwork.created: | $(HCP_OUT)
$(HCP_OUT)/testnetwork.created:
	$Qdocker network create \
		--label $(SAFEBOOT_HCP_DSPACE)all=1 \
		--label $(HCP_TESTNETWORK_NAME)=1 \
		$(HCP_TESTNETWORK_NAME)
	$Qtouch $@

# "docker network create" the network (interface only)
hcp_testnetwork: $(HCP_OUT)/testnetwork.created

# "docker network rm" the network (interface and recipe)
clean_hcp_testnetwork:
ifneq (,$(filter $(HCP_TESTNETWORK_NAME),$(HCP_EXISTING_NETWORKS)))
	$Qdocker network rm $(HCP_TESTNETWORK_NAME)
endif
	$Qrm -f $(HCP_OUT)/testnetwork.created

# Cleanup ordering
clean_hcp: clean_hcp_testnetwork

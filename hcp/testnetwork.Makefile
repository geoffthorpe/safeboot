HCP_TESTNETWORK_NAME := $(SAFEBOOT_HCP_DSPACE)network_hcp

# "docker network create" the network (recipe only)
$(HCP_OUT)/testnetwork.created: | $(HCP_OUT)
$(HCP_OUT)/testnetwork.created:
	$Qdocker network create $(HCP_TESTNETWORK_NAME)
	$Qtouch $@

# "docker network create" the network (interface only)
hcp_testnetwork: $(HCP_OUT)/testnetwork.created

# "docker network rm" the network (interface and recipe)
clean_hcp_testnetwork:
ifeq (yes,$(shell stat $(HCP_OUT)/testnetwork.created > /dev/null 2>&1 && echo yes))
	$Qdocker network rm $(HCP_TESTNETWORK_NAME)
	$Qrm $(HCP_OUT)/testnetwork.created
endif

# Cleanup ordering
clean_hcp: clean_hcp_testnetwork

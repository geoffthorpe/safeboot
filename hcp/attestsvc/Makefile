HCP_ATTESTSVC_SRC := $(HCP_SRC)/attestsvc
HCP_ATTESTSVC_OUT := $(HCP_OUT)/attestsvc
HCP_ATTESTSVC_DNAME := $(SAFEBOOT_HCP_DSPACE)attestsvc$(SAFEBOOT_HCP_DTAG)

$(HCP_ATTESTSVC_OUT): | $(HCP_OUT)
MDIRS += $(HCP_ATTESTSVC_OUT)

# Some summary notes about the attestment service, a.k.a. "attestsvc".
#
# This service consists of two sub-services; "hcp" and "repl", which perform
# complementary functions but operate on common state (a directory bind-mounted
# into both containers);
#  * The common state consists of;
#    - clones of the enrollment database, that are updated from the Enrollment
#      Service (enrollsvc-repl) and rotated by the 'attestsvc-repl' container.
#    - a "msgbus" directory, into which;
#      - the services write their stdout/stderr,
#      - control software outside the service containers can write commands to
#        be picked up by the services. Currently, this is limited to "stop"
#        functionality, which writes "die" to a file the service is
#        "tail_wait"ing, triggering it to exit.
#  * "attestsvc::hcp" provides the attestation endpoint for HCP clients (hosts).
#    - The common state is mounted read-only!
#    - After setting up the environment and dropping privileges, control is
#      passed entirely to safeboot/attest-server (outside this "hcp" source
#      tree) to accept connections and respond to attestation requests.
#  * "attestsvc::repl" handles replication and updating of (local) common state.
#    - The common state is mounted read-write.
#    - This service provides fault-tolerance and reliability;
#      - Inability to reach the Enrollment Service is logged, and results in
#        less frequent retries until connectivity is reestablished.
#      - Any failures or anomalies in the pulling of updates (non-linear
#        updates to history, merge conflicts, corruptions, ...) are rolled back
#        transactionally (and logged).
#      - The priority at all times is to preserve the integrity of the
#        enrollment database clone that is currently used by the attestation
#        endpoint. This will only get swapped out for an updated clone as/when
#        a successful update completes.
#    - A simple timeout mechanism is used (for now) to limit the rate at which
#      updates and clone-rotation occurs.
#      - This ensures that processing of an attestation request (from an HCP
#        client) occurs in a clone that is guaranteed not to change for at
#        least that timeout period.

# wrapper targets to build the "attestsvc" images
hcp_attestsvc: $(HCP_ATTESTSVC_OUT)/built

# This Makefile for attestsvc is modeled heavily on the Makefile for enrollsvc.
# As such, I have removed comments in many places, not because they're not
# justified but because there is no need to repeat them. Please consult the
# other Makefile for more explanatory comments. (And please maintain the
# similarities between these files, or re-comment things if they must diverge.)

HCP_USER := lowlyuser


#############
# attestsvc #
#############

# Include the submodule bundle
HCP_ATTESTSVC_PATHS += $(HCP_ATTESTSVC_OUT)/install.tar.gz
$(HCP_ATTESTSVC_OUT)/install.tar.gz: | $(HCP_ATTESTSVC_OUT)
$(HCP_ATTESTSVC_OUT)/install.tar.gz: $(HCP_SUBMODULES_OUT)/install.tar.gz
$(HCP_ATTESTSVC_OUT)/install.tar.gz:
	$Qcp $< $@

# And the safeboot bundle
HCP_ATTESTSVC_PATHS += $(HCP_ATTESTSVC_OUT)/safeboot.tar.gz
$(HCP_ATTESTSVC_OUT)/safeboot.tar.gz: | $(HCP_ATTESTSVC_OUT)
$(HCP_ATTESTSVC_OUT)/safeboot.tar.gz: $(HCP_SCRIPTS_OUT)/safeboot.tar.gz
$(HCP_ATTESTSVC_OUT)/safeboot.tar.gz:
	$Qcp $< $@

# And the hcp-{common,attestsvc} bundles
HCP_ATTESTSVC_PATHS += $(HCP_ATTESTSVC_OUT)/hcp-common.tar.gz
HCP_ATTESTSVC_PATHS += $(HCP_ATTESTSVC_OUT)/hcp-attestsvc.tar.gz
$(HCP_ATTESTSVC_OUT)/hcp-common.tar.gz: | $(HCP_ATTESTSVC_OUT)
$(HCP_ATTESTSVC_OUT)/hcp-common.tar.gz: $(HCP_SCRIPTS_OUT)/hcp-common.tar.gz
$(HCP_ATTESTSVC_OUT)/hcp-common.tar.gz:
	$Qcp $< $@
$(HCP_ATTESTSVC_OUT)/hcp-attestsvc.tar.gz: | $(HCP_ATTESTSVC_OUT)
$(HCP_ATTESTSVC_OUT)/hcp-attestsvc.tar.gz: $(HCP_SCRIPTS_OUT)/hcp-attestsvc.tar.gz
$(HCP_ATTESTSVC_OUT)/hcp-attestsvc.tar.gz:
	$Qcp $< $@

# Dockerfile-generation.
$(HCP_ATTESTSVC_OUT)/Dockerfile: | $(HCP_ATTESTSVC_OUT)
$(HCP_ATTESTSVC_OUT)/Dockerfile: $(HCP_ATTESTSVC_SRC)/Makefile
$(HCP_ATTESTSVC_OUT)/Dockerfile: $(HCP_ATTESTSVC_SRC)/Dockerfile
$(HCP_ATTESTSVC_OUT)/Dockerfile: $(HCP_SUBMODULES_OUT)/install.tar.gz.inject
$(HCP_ATTESTSVC_OUT)/Dockerfile: $(HCP_SCRIPTS_OUT)/safeboot.tar.gz.inject
$(HCP_ATTESTSVC_OUT)/Dockerfile: $(HCP_SCRIPTS_OUT)/hcp-common.tar.gz.inject
$(HCP_ATTESTSVC_OUT)/Dockerfile: $(HCP_SCRIPTS_OUT)/hcp-attestsvc.tar.gz.inject
$(HCP_ATTESTSVC_OUT)/Dockerfile:
	$Qecho "FROM $(HCP_BASE_DNAME)" > $@
	$Qcat $(HCP_ATTESTSVC_SRC)/Dockerfile >> $@
	$Qcat $(HCP_SUBMODULES_OUT)/install.tar.gz.inject >> $@
	$Qcat $(HCP_SCRIPTS_OUT)/safeboot.tar.gz.inject >> $@
	$Qcat $(HCP_SCRIPTS_OUT)/hcp-common.tar.gz.inject >> $@
	$Qcat $(HCP_SCRIPTS_OUT)/hcp-attestsvc.tar.gz.inject >> $@
	$Qecho "$(call tarball_finalize)" >> $@

# "docker build" to create the container image (recipe only)
$(HCP_ATTESTSVC_OUT)/built: $(HCP_ATTESTSVC_OUT)/Dockerfile
$(HCP_ATTESTSVC_OUT)/built: $(HCP_ATTESTSVC_PATHS)
$(HCP_ATTESTSVC_OUT)/built: $(HCP_BASE_TOUCHFILE)
$(HCP_ATTESTSVC_OUT)/built:
	$Qdocker build -t $(HCP_ATTESTSVC_DNAME) \
	               -f $(HCP_ATTESTSVC_OUT)/Dockerfile \
	               --build-arg HCP_USER=$(HCP_USER) \
	               $(HCP_ATTESTSVC_OUT)
	$Qtouch $@

# "docker image rm" to remove the container image (interface and recipe)
clean_hcp_attestsvc: | preclean_hcp
ifneq (,$(filter $(HCP_ATTESTSVC_DNAME),$(HCP_EXISTING_IMAGES)))
	$Qdocker image rm $(HCP_ATTESTSVC_DNAME)
endif
	$Qrm -rf $(HCP_ATTESTSVC_OUT)

################
# cleanup deps #
################

clean_hcp_base: clean_hcp_attestsvc

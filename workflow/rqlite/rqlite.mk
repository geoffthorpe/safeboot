# We derive an image from the base platform
# This installs the run_rqlite.sh script, which runs based on env-var inputs.
IMAGES += rqlite-base
rqlite-base_EXTENDS := $(ibase-RESULT)
rqlite-base_PATH := $(TOPDIR)/workflow/rqlite

# Declare a network for the cluster to run on
NETWORKS += n-rqlite

# Loop to dynamically generate all the nodes
# For each i from 1 to $(NUM_NODES);
#  - i is left-padded with zeroes to be exactly 3 digits. E.g. "018" rather
#    than "18".
#  - image and rqlite 'node-id' are "rqlite-node-$i"
#  - only every 5th node is read-write, the remainder are read-only

NUM_NODES ?= 20
NODES := $(shell seq --format="%03g" --separator=" " 1 $(NUM_NODES))
RW_NODES := $(shell seq --format="%03g" --separator=" " 1 5 $(NUM_NODES))
define rqlite_loop
	$(eval i := $(strip $1))
	$(eval n := rqlite-node-$i)
	$(eval m := $(if $(filter $i,$(RW_NODES)),rw,ro))
	$(eval IMAGES += $n)
	$(eval $n_EXTENDS := rqlite-base)
	$(eval $n_NOPATH := true)
	$(eval $n_DOCKERFILE := /dev/null)
	$(eval $n_NETWORKS := n-rqlite)
	$(eval $n_COMMANDS := shell run)
	$(eval $n_VOLUMES := vtailwait)
	$(eval $n_run_COMMAND := /run_rqlite.sh)
	$(eval $n_run_PROFILES := detach_join)
	$(eval $n_run_HIDE := true)
	$(eval $n_run_MSGBUS := $(DEFAULT_CRUD)/msgbus_rqlite)
	$(eval $n_shell_MSGBUS := $(DEFAULT_CRUD)/msgbus_rqlite)
	$(eval $n_ARGS_DOCKER_RUN := \
		--env=HTTP_ADDR=$n:4001 \
		--env=HTTP_ADV_ADDR=$n:4001 \
		--env=RAFT_ADDR=$n:4002 \
		--env=RAFT_ADV_ADDR=$n:4002 \
		--env=NODE_ID=$n \
		--env=MODE=$m)
endef
$(foreach i,$(NODES),$(eval $(call rqlite_loop,i)))

# Have Mariner process that, before we generate some more rules
$(eval $(call do_mariner))

# Now we can define rules that use attributes produced by Mariner

define rqlite_loop_post
	$(eval i := $(strip $1))
	$(eval n := rqlite-node-$i)
	$(eval $(call mkout_rule,$n_start,$($n_run_JOINFILE)))
	$(eval T1 := $$Qecho Issuing stop command for $n)
	$(eval T2 := $$Qecho "stop" > $($n_run_MSGBUS)/stop-$n)
	$(eval $(call mkout_rule,$($n_run_MSGBUS)/stop-$n,$n_start,T1 T2))
	$(eval $(call mkout_rule,$($n_run_DONEFILE),$($n_run_MSGBUS)/stop-$n))
	$(eval $(call mkout_rule,$n_stop,$($n_run_DONEFILE)))
endef
$(foreach i,$(NODES),$(eval $(call rqlite_loop_post,i)))

# Generate again
$(eval $(call do_mariner))

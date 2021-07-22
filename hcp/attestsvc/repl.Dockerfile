# The 'mgmt' image builds on top of 'common' (common.Dockerfile)

# We need some upstream stuff
RUN apt-get install -y git

# NOTE: in addition to getting prepended with an auto-generated "FROM" line,
# this Dockerfile also undergoes a pass through 'sed' to turn the
# HCP_ATTESTSVC_REPL_FILES_* definitions into their corresponding file-lists.
# Just mentioning in case you were wondering why they weren't escaped. :-)

# We need some local stuff
#COPY HCP_ATTESTSVC_REPL_FILES_NOEXEC /hcp/    # unused
COPY HCP_ATTESTSVC_REPL_FILES_EXEC /hcp/

# Explicit perms on files copied from host to image. I.e. don't get tripped up
# by build-host umasks and other chmod-y things.
#RUN cd /hcp && chmod 644 HCP_ATTESTSVC_REPL_FILES_NOEXEC    # unused
RUN cd /hcp && chmod 755 HCP_ATTESTSVC_REPL_FILES_EXEC

# The 'mgmt' image builds on top of 'common' (common.Dockerfile)

# We need some upstream stuff
RUN apt-get install -y python3 python3-flask jq procmail
RUN apt-get install -y file time sudo

# NOTE: in addition to getting prepended with an auto-generated "FROM" line,
# this Dockerfile also undergoes a pass through 'sed' to turn the
# HCP_ENROLLSVC_MGMT_FILES_* definitions into their corresponding file-lists.
# Just mentioning in case you were wondering why they weren't escaped. :-)

# /hcp already exists, but we have things destined for /hcp/safeboot-sbin
RUN mkdir /safeboot
RUN mkdir /safeboot/sbin

# We need some local stuff
COPY HCP_ENROLLSVC_MGMT_FILES_NOEXEC /hcp/
COPY HCP_ENROLLSVC_MGMT_FILES_EXEC /hcp/
COPY safeboot-xtra/* /safeboot/
COPY safeboot-sbin/* /safeboot/sbin/

# Explicit perms on files copied from host to image. I.e. don't get tripped up
# by build-host umasks and other chmod-y things.
RUN cd /hcp && chmod 644 HCP_ENROLLSVC_MGMT_FILES_NOEXEC
RUN cd /hcp && chmod 755 HCP_ENROLLSVC_MGMT_FILES_EXEC
RUN chmod 644 /safeboot/*
RUN chmod 755 /safeboot/sbin
RUN chmod 755 /safeboot/sbin/*

# common.Dockerfile created DB_USER and FLASK_USER, so we inherit that, but it
# is only in this image that we open privilege-separated pinholes between them.
# The following puts a sudo configuration into place for FLASK_USER to be able
# to invoke (only) the 4 /hcp/op_<verb>.sh scripts as DB_USER.
RUN echo "# sudo rules for enrollsvc-mgmt" > /etc/sudoers.d/hcp
RUN echo "Cmnd_Alias HCP = /hcp/op_add.sh,/hcp/op_delete.sh,/hcp/op_find.sh,/hcp/op_query.sh" >> /etc/sudoers.d/hcp
RUN echo "Defaults !lecture" >> /etc/sudoers.d/hcp
RUN echo "Defaults !authenticate" >> /etc/sudoers.d/hcp
RUN echo "$FLASK_USER ALL = ($DB_USER) HCP" >> /etc/sudoers.d/hcp

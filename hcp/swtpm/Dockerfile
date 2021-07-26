# We need some upstream stuff
RUN apt-get install -y python3-yaml python3-distutils python3-cryptography json-glib-tools
RUN apt-get install -y python3-requests python3-openssl

# NOTE: in addition to getting prepended with an auto-generated "FROM" line,
# this Dockerfile also undergoes a pass through 'sed' to turn the
# HCP_SWTPM_FILES_* definitions into their corresponding file-lists.
# Just mentioning in case you were wondering why they weren't escaped. :-)

# We need some local stuff
COPY HCP_SWTPM_FILES_NOEXEC /hcp/
COPY HCP_SWTPM_FILES_EXEC /hcp/
COPY install.tar.gz /

# Explicit perms on files copied from host to image. I.e. don't get tripped up
# by build-host umasks and other chmod-y things.
RUN cd /hcp && chmod 644 HCP_SWTPM_FILES_NOEXEC
RUN cd /hcp && chmod 755 HCP_SWTPM_FILES_EXEC
RUN chmod 644 /install.tar.gz

# Extract the submodules build (install.tar.gz) and remove the tarball
RUN cd / && tar zxf install.tar.gz && rm install.tar.gz

# This container image is to serve as a common ancestor for the 'mgmt' and
# 'repl' images. It's not a question of image size - we previously derived
# 'mgmt' from 'repl' and this gave essentially the same outcome. Rather, this
# is about dependencies and rebuild-thrashing. Previously, any innocuous code
# change in 'repl' would cause Dockerfile-processing to cease using cached
# results as soon as it injected a modified file into the image. By dependency,
# this would then cause the entire 'mgmt' container image to rebuild _uncached_
# also. Factoring out a common ancestor relieves the 'mgmt' container of this
# thrashing, which helps because it does most of downloading!

RUN apt-get install -y git

# Note, the reason we want the same DB_USER account in both container images is
# to simplify ownership and permissions for manipulating the DB, which is
# mounted read-only into 'repl' and read-write into 'mgmt'. Creating the
# accounts here ensures that the uid and gid are the same in both images. (E.g.
# running useradd in both Dockerfiles wouldn't guarantee this.)
#
# Security note: there are some subtleties about environment values that aren't
# visible here but are worth knowing about. See common.sh for the gritty
# details.

ARG DB_USER
RUN useradd -m -s /bin/bash $DB_USER
ENV DB_USER=$DB_USER

ARG FLASK_USER
RUN useradd -m -s /bin/bash $FLASK_USER
ENV FLASK_USER=$FLASK_USER

# We have constraints to support older Debian versions whose 'git' packages
# assume "master" as a default branch name and don't honor the defaultBranch
# configuration setting. If more recent distro versions change their defaults
# (e.g. to "main"), we know that such versions will also honor this
# configuration setting to override such defaults. So in the interests of
# maximum interoperability we go with "master", whilst acknowledging that this
# goes against coding guidelines in many environments. If you have no such
# legacy distro constraints and wish to (or must) adhere to revised naming
# conventions, please alter this setting accordingly.
RUN git config --system init.defaultBranch master

# Updates to the enrollment database take the form of git commits, which must
# have a user name and email address. The following suffices in general, but
# modify it to your heart's content; it is of no immediate consequence to
# anything else in the HCP architecture. (That said, you may have or want
# higher-layer interpretations, from an operational perspective. E.g. if the
# distinct repos from multiple regions/sites are being mirrored and inspected
# for more than backup/restore purposes, perhaps the identity in the commits is
# used to disambiguate them?)
RUN su -c "git config --global user.email 'do-not-reply@nowhere.special'" - $DB_USER
RUN su -c "git config --global user.name 'Host Cryptographic Provisioning (HCP)'" - $DB_USER

# Both images put their goodies in /hcp.
RUN mkdir /hcp

# NOTE: in addition to getting prepended with an auto-generated "FROM" line,
# this Dockerfile also undergoes a pass through 'sed' to turn the
# HCP_ENROLLSVC_BASE_FILES_* definitions into their corresponding file-lists.
# Just mentioning in case you were wondering why they weren't escaped. :-)

# We need some local stuff
COPY HCP_ENROLLSVC_COMMON_FILES_NOEXEC /hcp/
COPY HCP_ENROLLSVC_COMMON_FILES_EXEC /hcp/

# Explicit perms on files copied from host to image. I.e. don't get tripped up
# by build-host umasks and other chmod-y things.
RUN cd /hcp && chmod 644 HCP_ENROLLSVC_COMMON_FILES_NOEXEC
RUN cd /hcp && chmod 755 HCP_ENROLLSVC_COMMON_FILES_EXEC

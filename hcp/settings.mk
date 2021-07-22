# All Docker objects created by this workflow will be prefixed with this string
# in order to allow multiple independent environments to be built and tested on
# the same host system.
SAFEBOOT_HCP_DSPACE?=safeboot_

# Specify the underlying (debian-based) docker image to use as the system
# environment for all operations.
# - This will affect the versions of numerous system packages that get
#   installed and used, which may affect the compatibility of any resulting
#   artifacts.
# - This gets used directly in the FROM command of the generated Dockerfile, so
#   "Docker semantics" apply here (in terms of whether it is pulling an image
#   or a Dockerfile, whether it pulls a named image from a default repository
#   or one that is specified explicitly, etc).
SAFEBOOT_HCP_BASE?=debian:bullseye-slim
#SAFEBOOT_HCP_BASE?=internal.dockerhub.mycompany.com/library/debian:buster-slim

# If defined, the "1apt-source" layer in hcp/base will be used, allowing apt to
# use an alternative source of debian packages, trust different package signing
# keys, etc.
# See hcp/base/Makefile for details.
#SAFEBOOT_HCP_1APT_ENABLE:=1

# If defined, the "3add-cacerts" layer in hcp/base will be injected, allow
# host-side trust roots (CA certificates) to be installed.
# See hcp/base/Makefile for details.
#SAFEBOOT_HCP_3ADD_CACERTS_ENABLE:=1
#SAFEBOOT_HCP_3ADD_CACERTS_PATH:=/opt/my-company-ca-certificates

# If defined, the "2apt-usable" layer in hcp/base will tweak the apt
# configuration to use the given URL as a (caching) proxy for downloading deb
# packages. It will also set the "Queue-Mode" to "access", which essentially
# serializes the pulling of packages. (I tried a couple of different
# purpose-built containers for proxying and all would glitch sporadically when
# apt unleashed its parallel goodness upon them. That instability may be in
# docker networking itself. Serializing slows the downloading noticably, but
# the whole point is that once the cache has a copy of everything, package
# downloads go considerably faster, and the lack of parallelism goes largely
# unnoticed.)
#
# docker run --name apt-cacher-ng --init -d --restart=always \
#  --publish 3142:3142 \
#  --volume /srv/docker/apt-cacher-ng:/var/cache/apt-cacher-ng \
#  sameersbn/apt-cacher-ng:3.3-20200524
#
#SAFEBOOT_HCP_APT_PROXY:=http://172.17.0.1:3142

# These flags get passed to "make" when compiling submodules. "-j" on its own
# allows make to spawn arbitrarily many processes at once, whereas "-j 4" caps
# the parallelism to 4.
SAFEBOOT_HCP_BUILDER_MAKE_PARALLEL := -j 16
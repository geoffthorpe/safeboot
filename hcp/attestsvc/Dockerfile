RUN apt-get install -y git
RUN apt-get install -y python3-yaml python3-flask
RUN apt-get install -y uwsgi-plugin-python3

ARG HCP_USER
RUN useradd -m -s /bin/bash $HCP_USER
ENV HCP_USER=$HCP_USER

# The build system derives a build Dockerfile from this source Dockerfile, and
# appends tarball-injection logic when it does so. Hence this comment!

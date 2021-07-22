# The same comments apply here as in hcp/enrollsvc/common.Dockerfile

ARG HCP_USER
RUN useradd -m -s /bin/bash $HCP_USER
ENV HCP_USER=$HCP_USER

RUN mkdir /hcp

COPY common.sh tail_wait.pl /hcp/

RUN cd /hcp && chmod 644 common.sh
RUN cd /hcp && chmod 755 tail_wait.pl

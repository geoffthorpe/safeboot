RUN apt-get install -y python3-yaml python3-distutils python3-cryptography
RUN apt-get install -y file
ARG HOSTIDX
ARG SUBMODULES
ARG DIR
ARG SERVER
ARG TPM2TOOLS_TCTI
ENV HOSTIDX=$HOSTIDX
ENV SUBMODULES=$SUBMODULES
ENV DIR=$DIR
ENV SERVER=$SERVER
ENV TPM2TOOLS_TCTI=$TPM2TOOLS_TCTI
COPY run_client.sh /
RUN chmod 755 /run_client.sh

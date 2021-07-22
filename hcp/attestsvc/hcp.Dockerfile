# The 'hcp' image builds on top of common.Dockerfile

# We need some upstream stuff
RUN apt-get install -y python3-yaml

# /hcp already exists, but we have things for /safeboot and /etc too.
RUN mkdir /safeboot
RUN mkdir /safeboot/sbin
RUN mkdir /etc/safeboot

# We need local two scripts and the safeboot stuff
COPY run_hcp.sh wrapper-attest-server.sh /hcp/
COPY safeboot-xtra/* /etc/safeboot/
COPY safeboot-sbin/* /safeboot/sbin/
RUN cd /hcp && chmod 755 run_hcp.sh wrapper-attest-server.sh
RUN chmod 644 /etc/safeboot/*
RUN chmod 755 /safeboot/sbin/*

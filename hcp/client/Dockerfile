# We need some upstream stuff
RUN apt-get install -y python3-yaml python3-distutils python3-cryptography
RUN apt-get install -y file

# /hcp already exists, but we have things for /safeboot and /etc too.
RUN mkdir /safeboot
RUN mkdir /safeboot/sbin
RUN mkdir /etc/safeboot

# We need local two scripts and the safeboot stuff
COPY run_client.sh /hcp/
COPY safeboot-xtra/* /etc/safeboot/
COPY safeboot-sbin/* /safeboot/sbin/
RUN chmod 755 /hcp/run_client.sh
RUN chmod 644 /etc/safeboot/*
RUN chmod 755 /safeboot/sbin/*

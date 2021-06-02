# The following borrow heavily from;
# https://github.com/easeway/dockers/blob/master/simpleca/Dockerfile
RUN apt-get install -y socat curl bash openssl lighttpd
ADD ./server /app
RUN chmod a+rx /app/bin/* /app/cgi/*
COPY run_x509.sh /
RUN chmod 755 /run_x509.sh
COPY setup_x509.sh /
RUN chmod 755 /setup_x509.sh

# Most of the following is pinched from;
# https://github.com/rqlite/rqlite-docker/blob/master/5.12.1/Dockerfile
# which is the source for the rqlite/rqlite image on dockerhub.
#
# I don't use the dockerhub image directly though, because I want to have all
# the goodies from the $(ibase-RESULT) image, including the fact that it's our
# standardized debian baseline and has the set of utils we commonly expect.
# Also, the original recipe does a few things we want to steer clear of;
# - it deliberately cripples 'apt' once finished, so that the container isn't
#   extensible and remains purpose-specific.
# - it does some strange monkeying around with the VOLUME Dockerfile command.
# - the CMD/ENTRYPOINT stuff is a bit of an anti-Mariner land-mine, so this
#   Dockerfile takes the liberty of being less surprising.

ENV RQLITE_VERSION=5.12.1
RUN curl -L https://github.com/rqlite/rqlite/releases/download/v${RQLITE_VERSION}/rqlite-v${RQLITE_VERSION}-linux-amd64.tar.gz -o rqlite-v${RQLITE_VERSION}-linux-amd64.tar.gz && \
	tar xvfz rqlite-v${RQLITE_VERSION}-linux-amd64.tar.gz && \
	cp rqlite-v${RQLITE_VERSION}-linux-amd64/rqlited /bin && \
	cp rqlite-v${RQLITE_VERSION}-linux-amd64/rqlite /bin && \
	rm -rf rqlite-v${RQLITE_VERSION}-linux-amd64 && \
	rm -rf rqlite-v${RQLITE_VERSION}-linux-amd64.tar.gz
RUN mkdir -p /rqlite/file
COPY run_rqlite.sh /
RUN chmod 755 /run_rqlite.sh

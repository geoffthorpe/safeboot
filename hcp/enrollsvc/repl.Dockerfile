# The 'repl' image builds on top of common.Dockerfile

# We need one script
COPY run_repl.sh /hcp/
RUN cd /hcp && chmod 755 run_repl.sh

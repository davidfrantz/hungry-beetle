FROM davidfrantz/base as builder

# disable interactive frontends
ENV DEBIAN_FRONTEND=noninteractive 

# Environment variables
ENV SOURCE_DIR $HOME/src/hungry-beetle

# Copy src to SOURCE_DIR
RUN mkdir -p $SOURCE_DIR
WORKDIR $SOURCE_DIR
COPY --chown=docker:docker . .

# Build, install
RUN echo "building hungry-beetle" && \
  make && \
  sudo make install

#FROM davidfrantz/hungry-beetle:latest as hungry-beetle

WORKDIR /home/docker


FROM ubuntu:latest

# install git
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y apt-utils debconf-utils dialog && \
    apt-get install -y git vim sudo rsync

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

# add ssh directory
RUN mkdir -m 700 /root/.ssh

RUN mkdir /workspace
COPY docker_entrypoint.sh /workspace
RUN chmod +x /workspace/docker_entrypoint.sh

WORKDIR /workspace
RUN git clone https://github.com/NVIDIA/deepops.git

RUN ./deepops/scripts/setup.sh

FROM ubuntu:focal

# Install required packages
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    python3 \
    python3-pip \
    python2 \
    git \
    sudo \
    wget \
    cmake \
    binutils \
    libunwind-dev \
    libboost-dev \
    zlib1g-dev \
    libsnappy-dev \
    liblz4-dev \
    g++-9 \
    g++-9-multilib \
    doxygen \
    libconfig++-dev \
    libboost-dev \
    vim \
    bc \
    unzip \
    gosu

RUN update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-9 1

RUN pip install matplotlib

RUN mkdir -p /simpoint_traces

# DynamoRIO package
WORKDIR /root
RUN wget https://github.com/DynamoRIO/dynamorio/releases/download/release_10.0.0/DynamoRIO-Linux-10.0.0.tar.gz
RUN tar --no-same-owner -xzvf DynamoRIO-Linux-10.0.0.tar.gz
ENV DYNAMORIO_HOME=/root/DynamoRIO-Linux-10.0.0/

# Build fingerprint client
COPY fingerprint_src fingerprint_src/
RUN mkdir ./fingerprint_src/build
WORKDIR ./fingerprint_src/build
RUN cmake -DDynamoRIO_DIR=$DYNAMORIO_HOME/cmake ..
RUN make
RUN cp ./libfpg.so /home/libfpg.so

# Install Scarab dependencies
WORKDIR /root
RUN wget -nc https://software.intel.com/sites/landingpage/pintool/downloads/pin-3.15-98253-gb56e429b1-gcc-linux.tar.gz
RUN tar --no-same-owner -xzvf pin-3.15-98253-gb56e429b1-gcc-linux.tar.gz

# Env to build Scarab
ENV PIN_ROOT /root/pin-3.15-98253-gb56e429b1-gcc-linux
ENV SCARAB_ENABLE_PT_MEMTRACE 1
ENV LD_LIBRARY_PATH /root/pin-3.15-98253-gb56e429b1-gcc-linux/extras/xed-intel64/lib
ENV LD_LIBRARY_PATH /root/pin-3.15-98253-gb56e429b1-gcc-linux/intel64/runtime/pincrt:$LD_LIBRARY_PATH

# Build SimPoint 3.2
# Reference:
# https://github.com/intel/pinplay-tools/blob/main/pinplay-scripts/PinPointsHome/Linux/bin/Makefile
WORKDIR /root
RUN git clone https://github.com/kofyou/SimPoint.3.2.git
RUN make -C SimPoint.3.2
RUN ln -s SimPoint.3.2/bin/simpoint ./simpoint

ENV DOCKER_BUILDKIT 1
ENV COMPOSE_DOCKER_CLI_BUILD 1

RUN pip install gdown
WORKDIR /

RUN gdown https://drive.google.com/uc?id=1Z4ouWgNrkNnezrq7wxk4OXBpRBm-2CzA
RUN tar --no-same-owner -xzvf cse220_traces.tar.gz

WORKDIR /root
RUN git clone https://github.com/Litz-Lab/scarab.git
WORKDIR /root/scarab
RUN pip3 install -r bin/requirements.txt
WORKDIR /root/scarab/src
RUN make

COPY cse220/run_exp_using_descriptor.py /usr/local/bin
COPY cse220/run_cse220.sh /usr/local/bin
RUN sed -i '1s/^/#!\/usr\/bin\/env python3\n/' /usr/local/bin/run_exp_using_descriptor.py

COPY andy.sh /root

# Start your application
CMD ["/bin/bash"]

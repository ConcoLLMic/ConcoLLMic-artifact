# Use the final stage from AFL++
FROM aflplusplus AS oggenc

USER root

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    build-essential libogg-dev libvorbis-dev gettext && \
    rm -rf /var/lib/apt/lists/*


# -------------------------------------------------------------
# Download and extract oggenc
# -------------------------------------------------------------
WORKDIR /
RUN git clone https://github.com/xiph/vorbis-tools.git
WORKDIR /vorbis-tools
RUN git reset --hard 235540c05ad3f9cdc673ca09c237c9a9b5bda6eb

WORKDIR /

RUN cp -r vorbis-tools /vorbis-tools-gcov && cp -r vorbis-tools /vorbis-tools-aflplusplus


# -------------------------------------------------------------
# Build oggenc with GCOV
# -------------------------------------------------------------
WORKDIR /vorbis-tools-gcov
RUN CC=gcc CXX=g++ CFLAGS="-fprofile-arcs -ftest-coverage" CXXFLAGS="-fprofile-arcs -ftest-coverage" ./autogen.sh
RUN CC=gcc CXX=g++ CFLAGS="-fprofile-arcs -ftest-coverage" CXXFLAGS="-fprofile-arcs -ftest-coverage" ./configure --disable-shared
RUN CC=gcc CXX=g++ CFLAGS="-fprofile-arcs -ftest-coverage" CXXFLAGS="-fprofile-arcs -ftest-coverage" make


# -------------------------------------------------------------
# Build oggenc with Symcc
# -------------------------------------------------------------

WORKDIR /vorbis-tools-aflplusplus
RUN AFL_USE_ASAN=1 AFL_USE_UBSAN=1 CC=afl-cc CXX=afl-c++ ./autogen.sh
RUN AFL_USE_ASAN=1 AFL_USE_UBSAN=1 CC=afl-cc CXX=afl-c++ ./configure --disable-shared
RUN AFL_USE_ASAN=1 AFL_USE_UBSAN=1 CC=afl-cc CXX=afl-c++ make


# -------------------------------------------------------------
# Prepare testing directory
# -------------------------------------------------------------

COPY ./seeds /seeds
COPY ./run.sh /run.sh
COPY ./coverage.sh /coverage.sh

CMD ["/bin/bash"]

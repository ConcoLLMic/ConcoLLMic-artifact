# Use the final stage from SymCC
FROM concolic AS oggenc



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
RUN mv vorbis-tools /vorbis-tools-gcov
COPY ./vorbis-tools-instr.tar.gz vorbis-tools-instr.tar.gz
RUN tar -xzf vorbis-tools-instr.tar.gz


# -------------------------------------------------------------
# Build oggenc with GCOV
# -------------------------------------------------------------
WORKDIR /vorbis-tools-gcov
RUN CC=gcc CXX=g++ CFLAGS="-fprofile-arcs -ftest-coverage" CXXFLAGS="-fprofile-arcs -ftest-coverage" ./autogen.sh
RUN CC=gcc CXX=g++ CFLAGS="-fprofile-arcs -ftest-coverage" CXXFLAGS="-fprofile-arcs -ftest-coverage" ./configure --disable-shared
RUN CC=gcc CXX=g++ CFLAGS="-fprofile-arcs -ftest-coverage" CXXFLAGS="-fprofile-arcs -ftest-coverage" make


# -------------------------------------------------------------
# Build oggenc with instrumentation
# -------------------------------------------------------------

WORKDIR /vorbis-tools-instr
RUN bash ./autogen.sh
RUN ./configure --disable-shared
RUN make


# -------------------------------------------------------------
# Prepare testing directory
# -------------------------------------------------------------

COPY ./seed_execs /seed_execs
COPY ./run.sh /run.sh
COPY ./coverage.sh /coverage.sh

CMD ["/bin/bash"]

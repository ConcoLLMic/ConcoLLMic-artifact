FROM symsan AS oggenc

USER root

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    build-essential gettext autoconf automake libogg-dev libvorbis-dev libtool && \
    rm -rf /var/lib/apt/lists/*

# -------------------------------------------------------------
# Download and extract oggenc
# -------------------------------------------------------------
RUN git clone https://github.com/xiph/vorbis-tools.git /vorbis-tools-symsan
WORKDIR /vorbis-tools-symsan
RUN git reset --hard 235540c05ad3f9cdc673ca09c237c9a9b5bda6eb
RUN cp -r /vorbis-tools-symsan /vorbis-tools-gcov


# -------------------------------------------------------------
# Build oggenc with GCOV
# -------------------------------------------------------------
WORKDIR /vorbis-tools-gcov
RUN CC=gcc CXX=g++ CFLAGS="-fprofile-arcs -ftest-coverage" ./autogen.sh
RUN CC=gcc CXX=g++ CFLAGS="-fprofile-arcs -ftest-coverage" ./configure --disable-shared
RUN CC=gcc CXX=g++ CFLAGS="-fprofile-arcs -ftest-coverage" make


# -------------------------------------------------------------
# Download and build libogg and libvorbis
# -------------------------------------------------------------
WORKDIR /
RUN git clone https://gitlab.xiph.org/xiph/ogg.git /ogg
WORKDIR /ogg
RUN CC=/workdir/symsan/build/bin/ko-clang CXX=/work/symsan/build/bin/ko-clang++ ./autogen.sh
RUN CC=/workdir/symsan/build/bin/ko-clang CXX=/work/symsan/build/bin/ko-clang++ ./configure --disable-shared
RUN CC=/workdir/symsan/build/bin/ko-clang CXX=/work/symsan/build/bin/ko-clang++ make
RUN CC=/workdir/symsan/build/bin/ko-clang CXX=/work/symsan/build/bin/ko-clang++ make install

RUN ldconfig

WORKDIR /
RUN git clone https://gitlab.xiph.org/xiph/vorbis.git /vorbis
WORKDIR /vorbis
RUN CC=/workdir/symsan/build/bin/ko-clang CXX=/work/symsan/build/bin/ko-clang++ ./autogen.sh
RUN CC=/workdir/symsan/build/bin/ko-clang CXX=/work/symsan/build/bin/ko-clang++ ./configure --disable-shared
RUN CC=/workdir/symsan/build/bin/ko-clang CXX=/work/symsan/build/bin/ko-clang++ make
RUN CC=/workdir/symsan/build/bin/ko-clang CXX=/work/symsan/build/bin/ko-clang++ make install

RUN ldconfig

# -------------------------------------------------------------
# Build oggenc with Symsan and instrumented libs
# -------------------------------------------------------------

WORKDIR /vorbis-tools-symsan
RUN CC=/workdir/symsan/build/bin/ko-clang CXX=/workdir/symsan/build/bin/ko-clang++ ./autogen.sh
RUN CC=/workdir/symsan/build/bin/ko-clang CXX=/workdir/symsan/build/bin/ko-clang++ ./configure --disable-shared
RUN CC=/workdir/symsan/build/bin/ko-clang CXX=/workdir/symsan/build/bin/ko-clang++ make


# -------------------------------------------------------------
# Prepare testing directory
# -------------------------------------------------------------

COPY ./seeds /seeds
COPY ./run.sh /run.sh
COPY ./coverage.sh /coverage.sh

CMD ["/bin/bash"]

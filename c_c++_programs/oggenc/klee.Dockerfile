FROM klee
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    libogg-dev libvorbis-dev gettext autoconf automake libtool && \
    rm -rf /var/lib/apt/lists/*

# -------------------------------------------------------------
# Download and build libvorbis
# -------------------------------------------------------------
WORKDIR /
RUN git clone https://gitlab.xiph.org/xiph/vorbis.git
WORKDIR /vorbis
RUN CC="wllvm" CXX="wllvm++" ./autogen.sh
RUN CC="wllvm" CXX="wllvm++" ./configure --disable-shared --enable-static
RUN CC="wllvm" CXX="wllvm++" make
RUN extract-bc lib/.libs/libvorbis.a
RUN extract-bc lib/.libs/libvorbisenc.a
RUN extract-bc lib/.libs/libvorbisfile.a

# -------------------------------------------------------------
# Download and extract oggenc
# -------------------------------------------------------------
WORKDIR /
RUN git clone https://github.com/xiph/vorbis-tools.git
WORKDIR /vorbis-tools
RUN git reset --hard 235540c05ad3f9cdc673ca09c237c9a9b5bda6eb

WORKDIR /
RUN cp -r vorbis-tools /vorbis-tools-gcov && cp -r vorbis-tools /vorbis-tools-klee

# -------------------------------------------------------------
# Build oggenc with GCOV
# -------------------------------------------------------------
WORKDIR /vorbis-tools-gcov
RUN CC=gcc CXX=g++ CFLAGS="-fprofile-arcs -ftest-coverage" CXXFLAGS="-fprofile-arcs -ftest-coverage" ./autogen.sh
RUN CC=gcc CXX=g++ CFLAGS="-fprofile-arcs -ftest-coverage" CXXFLAGS="-fprofile-arcs -ftest-coverage" ./configure --disable-shared
RUN CC=gcc CXX=g++ CFLAGS="-fprofile-arcs -ftest-coverage" CXXFLAGS="-fprofile-arcs -ftest-coverage" make


# -------------------------------------------------------------
# Build oggenc with Klee
# -------------------------------------------------------------

WORKDIR /vorbis-tools-klee
RUN CC="wllvm" CXX="wllvm++" ./autogen.sh
RUN CC="wllvm" CXX="wllvm++" ./configure --disable-nls CFLAGS="-g -O1 -Xclang -disable-llvm-passes -D__NO_STRING_INLINES -D_FORTIFY_SOURCE=0 -U__OPTIMIZE__"
RUN CC="wllvm" CXX="wllvm++" make
RUN extract-bc oggenc/oggenc


# -------------------------------------------------------------
# Prepare testing directory
# -------------------------------------------------------------

COPY ./seeds_klee /seeds
COPY ./run.sh /run.sh
COPY ./coverage.sh /coverage.sh

RUN chmod +x /run.sh
RUN chmod +x /coverage.sh

CMD ["/bin/bash"]

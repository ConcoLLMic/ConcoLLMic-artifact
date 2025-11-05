# Use the final stage from Symsan
FROM symsan AS oggenc

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

RUN cp -r vorbis-tools /vorbis-tools-gcov && cp -r vorbis-tools /vorbis-tools-symsan


# -------------------------------------------------------------
# Build oggenc with GCOV
# -------------------------------------------------------------
WORKDIR /vorbis-tools-gcov
RUN CC=gcc CXX=g++ CFLAGS="-fprofile-arcs -ftest-coverage" CXXFLAGS="-fprofile-arcs -ftest-coverage" ./autogen.sh
RUN CC=gcc CXX=g++ CFLAGS="-fprofile-arcs -ftest-coverage" CXXFLAGS="-fprofile-arcs -ftest-coverage" ./configure --disable-shared
RUN CC=gcc CXX=g++ CFLAGS="-fprofile-arcs -ftest-coverage" CXXFLAGS="-fprofile-arcs -ftest-coverage" make


# -------------------------------------------------------------
# Build oggenc with Symsan
# -------------------------------------------------------------

RUN echo "fun:vorbis_*=uninstrumented" >> /workdir/symsan/build/lib/symsan/dfsan_abilist.txt
RUN echo "fun:vorbis_*=discard" >> /workdir/symsan/build/lib/symsan/dfsan_abilist.txt
RUN echo "fun:ogg_*=uninstrumented" >> /workdir/symsan/build/lib/symsan/dfsan_abilist.txt
RUN echo "fun:ogg_*=discard" >> /workdir/symsan/build/lib/symsan/dfsan_abilist.txt
RUN echo "fun:oggpackB_*=uninstrumented" >> /workdir/symsan/build/lib/symsan/dfsan_abilist.txt
RUN echo "fun:oggpackB_*=discard" >> /workdir/symsan/build/lib/symsan/dfsan_abilist.txt
RUN echo "fun:oggpack_*=uninstrumented" >> /workdir/symsan/build/lib/symsan/dfsan_abilist.txt
RUN echo "fun:oggpack_*=discard" >> /workdir/symsan/build/lib/symsan/dfsan_abilist.txt
RUN echo "fun:ov_*=uninstrumented" >> /workdir/symsan/build/lib/symsan/dfsan_abilist.txt
RUN echo "fun:ov_*=discard" >> /workdir/symsan/build/lib/symsan/dfsan_abilist.txt
# https://github.com/R-Fuzz/fuzzbench/blob/4f179fbea4588c4ddcaf25688a654e29453e2050/fuzzers/symsan_aflplusplus/fuzzer.py#L89

# WORKDIR /
# RUN git clone https://gitlab.xiph.org/xiph/ogg.git /ogg
# WORKDIR /ogg
# RUN CC=/workdir/symsan/build/bin/ko-clang CXX=/workdir/symsan/build/bin/ko-clang++ ./autogen.sh
# RUN CC=/workdir/symsan/build/bin/ko-clang CXX=/workdir/symsan/build/bin/ko-clang++ ./configure
# RUN CC=/workdir/symsan/build/bin/ko-clang CXX=/workdir/symsan/build/bin/ko-clang++ make
# RUN CC=/workdir/symsan/build/bin/ko-clang CXX=/workdir/symsan/build/bin/ko-clang++ make install

# WORKDIR /
# RUN git clone https://gitlab.xiph.org/xiph/vorbis.git /vorbis
# WORKDIR /vorbis
# RUN CC=/workdir/symsan/build/bin/ko-clang CXX=/workdir/symsan/build/bin/ko-clang++ ./autogen.sh
# RUN CC=/workdir/symsan/build/bin/ko-clang CXX=/workdir/symsan/build/bin/ko-clang++ ./configure
# RUN CC=/workdir/symsan/build/bin/ko-clang CXX=/workdir/symsan/build/bin/ko-clang++ make
# RUN CC=/workdir/symsan/build/bin/ko-clang CXX=/workdir/symsan/build/bin/ko-clang++ make install


WORKDIR /vorbis-tools-symsan
RUN  CC=/workdir/symsan/build/bin/ko-clang CXX=/workdir/symsan/build/bin/ko-clang++ ./autogen.sh
RUN  CC=/workdir/symsan/build/bin/ko-clang CXX=/workdir/symsan/build/bin/ko-clang++ ./configure --disable-shared
RUN  CC=/workdir/symsan/build/bin/ko-clang CXX=/workdir/symsan/build/bin/ko-clang++ make VERBOSE=1


# -------------------------------------------------------------
# Prepare testing directory
# -------------------------------------------------------------

COPY ./seeds /seeds
COPY ./run.sh /run.sh
COPY ./coverage.sh /coverage.sh

CMD ["/bin/bash"]

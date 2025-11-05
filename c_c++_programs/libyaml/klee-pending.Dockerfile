FROM experiment7pending
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update --allow-releaseinfo-change && apt-get install -y \
    gettext autoconf automake libtool lcov && \
    rm -rf /var/lib/apt/lists/*

ENV LLVM_COMPILER="clang"

# -------------------------------------------------------------
# Download and build libyaml with GCOV
# -------------------------------------------------------------
WORKDIR /
RUN git clone https://github.com/yaml/libyaml.git
RUN cp -r libyaml libyaml-klee; cp -r libyaml libyaml-gcov

WORKDIR /libyaml-gcov
RUN bash ./bootstrap
RUN CC=gcc CXX=g++ CFLAGS="-fprofile-arcs -ftest-coverage" CXXFLAGS="-fprofile-arcs -ftest-coverage" ./configure --disable-shared
RUN CC=gcc CXX=g++ CFLAGS="-fprofile-arcs -ftest-coverage" CXXFLAGS="-fprofile-arcs -ftest-coverage" make

# -------------------------------------------------------------
# Build libyaml with Klee
# -------------------------------------------------------------
WORKDIR /libyaml-klee
RUN bash ./bootstrap
RUN CC="wllvm" CXX="wllvm++" ./configure --disable-nls CFLAGS="-g -O1 -Xclang -disable-llvm-passes -D__NO_STRING_INLINES -D_FORTIFY_SOURCE=0 -U__OPTIMIZE__"
RUN CC="wllvm" CXX="wllvm++" make
RUN extract-bc ./src/.libs/libyaml.so
RUN extract-bc ./tests/.libs/run-parser-test-suite
RUN llvm-link ./tests/.libs/run-parser-test-suite.bc ./src/.libs/libyaml.so.bc -o ./tests/run-parser-test-suite.bc 

COPY ./run.sh /run.sh
COPY ./coverage.sh /coverage.sh

RUN chmod +x /run.sh
RUN chmod +x /coverage.sh

CMD ["/bin/bash"]

FROM klee
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    gettext autoconf automake libtool guile-2.2-dev && \
    rm -rf /var/lib/apt/lists/*

# -------------------------------------------------------------
# Download and build libmatheval with GCOV
# -------------------------------------------------------------
COPY test.c test.c
WORKDIR /
RUN wget https://ftp.gnu.org/gnu/libmatheval/libmatheval-1.1.11.tar.gz
RUN tar -xzf libmatheval-1.1.11.tar.gz
RUN cp -r libmatheval-1.1.11 libmatheval-gcov; cp -r libmatheval-1.1.11 libmatheval-klee
RUN cp test.c libmatheval-gcov; cp test.c libmatheval-klee; 

WORKDIR /libmatheval-gcov
RUN CC=gcc CXX=g++ CFLAGS="-fprofile-arcs -ftest-coverage" CXXFLAGS="-fprofile-arcs -ftest-coverage" ./configure
RUN CC=gcc CXX=g++ CFLAGS="-fprofile-arcs -ftest-coverage" CXXFLAGS="-fprofile-arcs -ftest-coverage" make install-exec
RUN gcc -g -fprofile-arcs -ftest-coverage -o program ./test.c lib/.libs/libmatheval.a -lm

# -------------------------------------------------------------
# Build libmatheval with Klee
# -------------------------------------------------------------
WORKDIR /libmatheval-klee
RUN CC="wllvm" CXX="wllvm++" ./configure --disable-nls CFLAGS="-g -O1 -Xclang -disable-llvm-passes -D__NO_STRING_INLINES -D_FORTIFY_SOURCE=0 -U__OPTIMIZE__"
RUN CC="wllvm" CXX="wllvm++" make install-exec
RUN extract-bc lib/.libs/libmatheval.so
RUN wllvm -g -O1 -Xclang -disable-llvm-passes -D__NO_STRING_INLINES -D_FORTIFY_SOURCE=0 -U__OPTIMIZE__ -o program ./test.c lib/.libs/libmatheval.so.bc -lm
RUN extract-bc ./program

COPY ./run.sh /run.sh
COPY ./coverage.sh /coverage.sh

RUN chmod +x /run.sh
RUN chmod +x /coverage.sh

CMD ["/bin/bash"]

FROM klee
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    gettext autoconf automake libtool wget && \
    rm -rf /var/lib/apt/lists/*

# -------------------------------------------------------------
# Download and build confetti with GCOV
# -------------------------------------------------------------
WORKDIR /
RUN wget https://github.com/hgs3/confetti/releases/download/v1.0.0-beta.4/confetti-1.0.0-beta.4.tar.gz
RUN tar -xzf confetti-1.0.0-beta.4.tar.gz; rm confetti-1.0.0-beta.4.tar.gz
RUN mv confetti-1.0.0-beta.4 confetti-gcov; cp -r confetti-gcov confetti-klee

WORKDIR /confetti-gcov
RUN CC=gcc CXX=g++ CFLAGS="-fprofile-arcs -ftest-coverage" CXXFLAGS="-fprofile-arcs -ftest-coverage" ./configure --disable-shared
RUN CC=gcc CXX=g++ CFLAGS="-fprofile-arcs -ftest-coverage" CXXFLAGS="-fprofile-arcs -ftest-coverage" make

# -------------------------------------------------------------
# Build confetti with Klee
# -------------------------------------------------------------
WORKDIR /confetti-klee
RUN autoreconf -fvi
RUN CC="wllvm" CXX="wllvm++" ./configure CFLAGS="-g -O1 -Xclang -disable-llvm-passes -D__NO_STRING_INLINES -D_FORTIFY_SOURCE=0 -U__OPTIMIZE__"
RUN CC="wllvm" CXX="wllvm++" make 
RUN extract-bc .libs/libconfetti.so
RUN extract-bc .libs/parse
RUN llvm-link .libs/libconfetti.so.bc .libs/parse.bc -o ./parse.bc 

COPY ./run.sh /run.sh
COPY ./coverage.sh /coverage.sh
COPY ./seeds_klee /seeds

RUN chmod +x /run.sh
RUN chmod +x /coverage.sh

CMD ["/bin/bash"]

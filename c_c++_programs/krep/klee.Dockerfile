FROM klee
ENV DEBIAN_FRONTEND=noninteractive

# -------------------------------------------------------------
# Download and build krep with GCOV
# -------------------------------------------------------------
WORKDIR /
RUN git clone https://github.com/davidesantangelo/krep.git
COPY Makefile.diff /krep/Makefile.diff
COPY krep.diff /krep/krep.diff
RUN cd krep && git checkout 9c4d41c && patch -p1 < Makefile.diff && patch -p1 < krep.diff
RUN cp -r krep krep-gcov; cp -r krep krep-klee
WORKDIR /krep-gcov
RUN CC=gcc CXX=g++ BASE_CFLAGS="-fprofile-arcs -ftest-coverage -flto" BASE_LDFALGS="-fprofile-arcs -ftest-coverage -flto" make

#  -------------------------------------------------------------
# Build krep with Klee
# -------------------------------------------------------------
WORKDIR /krep-klee
RUN CC="wllvm" CXX="wllvm++" make CFLAGS="-g -O1 -Xclang -disable-llvm-passes -D__NO_STRING_INLINES -D_FORTIFY_SOURCE=0 -U__OPTIMIZE__"
RUN extract-bc krep

COPY ./run.sh /run.sh
COPY ./coverage.sh /coverage.sh

RUN chmod +x /run.sh
RUN chmod +x /coverage.sh

CMD ["/bin/bash"]
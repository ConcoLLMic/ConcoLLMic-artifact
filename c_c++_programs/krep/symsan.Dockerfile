# Use the final stage from SymCC
FROM symsan

USER root

ENV DEBIAN_FRONTEND=noninteractive

# -------------------------------------------------------------
# Download and build krep with GCOV
# -------------------------------------------------------------
WORKDIR /
RUN git clone https://github.com/davidesantangelo/krep.git
COPY Makefile.diff /krep/Makefile.diff
COPY krep.diff /krep/krep.diff
RUN cd krep && git checkout 9c4d41c && patch -p1 < Makefile.diff && patch -p1 < krep.diff
RUN cp -r krep krep-gcov; cp -r krep krep-symsan
WORKDIR /krep-gcov
RUN CC=gcc CXX=g++ BASE_CFLAGS="-fprofile-arcs -ftest-coverage -flto" BASE_LDFALGS="-fprofile-arcs -ftest-coverage -flto" make

# -------------------------------------------------------------
# Build krep with SymSan
# -------------------------------------------------------------
WORKDIR /krep-symsan
RUN CC=/workdir/symsan/build/bin/ko-clang CXX=/workdir/symsan/build/bin/ko-clang++ make

# -------------------------------------------------------------
# Prepare testing directory
# -------------------------------------------------------------
COPY ./seeds /seeds
COPY ./run.sh /run.sh
COPY ./coverage.sh /coverage.sh

RUN chmod +x /run.sh
RUN chmod +x /coverage.sh

CMD ["/bin/bash"]

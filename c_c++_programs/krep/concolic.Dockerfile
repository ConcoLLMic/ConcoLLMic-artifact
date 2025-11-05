FROM concolic

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
RUN cp -r krep krep-gcov; cp -r krep krep-asan
WORKDIR /krep-gcov
RUN CC=gcc CXX=g++ CFLAGS="-fprofile-arcs -ftest-coverage" make

#  -------------------------------------------------------------
# Build krep with Sanitizer
# -------------------------------------------------------------
WORKDIR /krep-asan
RUN CC=gcc CXX=g++ CFLAGS="-fsanitize=address,undefined -fsanitize-undefined-trap-on-error -fno-sanitize-recover=all -g -O1" make

# -------------------------------------------------------------
# Build instrumented libmatheval
# -------------------------------------------------------------
WORKDIR /
COPY krep-inst.tar.gz .
RUN tar -xzf krep-inst.tar.gz
WORKDIR /krep-inst
RUN CC=gcc CXX=g++ make

# -------------------------------------------------------------
# Prepare testing directory
# -------------------------------------------------------------
COPY ./seed_execs /seed_execs
COPY ./run.sh /run.sh
COPY ./coverage.sh /coverage.sh

RUN chmod +x /run.sh
RUN chmod +x /coverage.sh

CMD ["/bin/bash"]

# Use the final stage from AFL++
FROM aflplusplus

USER root

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get install -y patch

# -------------------------------------------------------------
# Download and build krep with GCOV
# -------------------------------------------------------------
WORKDIR /
RUN git clone https://github.com/davidesantangelo/krep.git
COPY Makefile.diff /krep/Makefile.diff
COPY krep.diff /krep/krep.diff
RUN cd krep && git checkout 9c4d41c && patch -p1 < Makefile.diff && patch -p1 < krep.diff
RUN cp -r krep krep-gcov; cp -r krep krep-aflplusplus
WORKDIR /krep-gcov
RUN CC=gcc CXX=g++ BASE_CFLAGS="-fprofile-arcs -ftest-coverage -flto" BASE_LDFALGS="-fprofile-arcs -ftest-coverage -flto" make

# -------------------------------------------------------------
# Build krep with AFL++
# -------------------------------------------------------------
WORKDIR /krep-aflplusplus
RUN AFL_USE_ASAN=1 AFL_USE_UBSAN=1 CC=afl-cc CXX=afl-c++ make

# -------------------------------------------------------------
# Prepare testing directory
# -------------------------------------------------------------
COPY ./seeds /seeds
COPY ./run.sh /run.sh
COPY ./coverage.sh /coverage.sh

RUN chmod +x /run.sh
RUN chmod +x /coverage.sh

CMD ["/bin/bash"]

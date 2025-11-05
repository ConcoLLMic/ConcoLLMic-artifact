# Use the final stage from AFL++
FROM aflplusplus

USER root

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get install -y texinfo autoconf automake libtool wget


# -------------------------------------------------------------
# Download and build confetti with GCOV
# -------------------------------------------------------------
WORKDIR /
RUN wget https://github.com/hgs3/confetti/releases/download/v1.0.0-beta.4/confetti-1.0.0-beta.4.tar.gz
RUN tar -xzf confetti-1.0.0-beta.4.tar.gz; rm confetti-1.0.0-beta.4.tar.gz
RUN mv confetti-1.0.0-beta.4 confetti-gcov; cp -r confetti-gcov confetti-aflplusplus

WORKDIR /confetti-gcov
RUN CC=gcc CXX=g++ CFLAGS="-fprofile-arcs -ftest-coverage" CXXFLAGS="-fprofile-arcs -ftest-coverage" ./configure --disable-shared
RUN CC=gcc CXX=g++ CFLAGS="-fprofile-arcs -ftest-coverage" CXXFLAGS="-fprofile-arcs -ftest-coverage" make

# -------------------------------------------------------------
# Build confetti with AFL++
# -------------------------------------------------------------
WORKDIR /confetti-aflplusplus
RUN autoreconf -fvi
RUN AFL_USE_ASAN=1 AFL_USE_UBSAN=1 CC=afl-cc CXX=afl-c++ ./configure --disable-shared
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

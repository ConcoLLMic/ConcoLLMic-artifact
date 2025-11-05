# Use the final stage from SymCC
FROM symcc

USER root

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get install -y texinfo autoconf automake libtool wget && \
    rm -rf /var/lib/apt/lists/*


# -------------------------------------------------------------
# Download and build confetti with GCOV
# -------------------------------------------------------------
WORKDIR /
RUN wget https://github.com/hgs3/confetti/releases/download/v1.0.0-beta.4/confetti-1.0.0-beta.4.tar.gz
RUN tar -xzf confetti-1.0.0-beta.4.tar.gz; rm confetti-1.0.0-beta.4.tar.gz
RUN mv confetti-1.0.0-beta.4 confetti-gcov; cp -r confetti-gcov confetti-symcc

WORKDIR /confetti-gcov
RUN CC=gcc CXX=g++ CFLAGS="-fprofile-arcs -ftest-coverage" CXXFLAGS="-fprofile-arcs -ftest-coverage" ./configure --disable-shared
RUN CC=gcc CXX=g++ CFLAGS="-fprofile-arcs -ftest-coverage" CXXFLAGS="-fprofile-arcs -ftest-coverage" make

# -------------------------------------------------------------
# Build confetti with SymCC
# -------------------------------------------------------------
WORKDIR /confetti-symcc
RUN autoreconf -fvi
RUN CC=symcc CXX=sym++ ./configure
RUN CC=symcc CXX=sym++ make

# -------------------------------------------------------------
# Prepare testing directory
# -------------------------------------------------------------
COPY ./seeds /seeds
COPY ./run.sh /run.sh
COPY ./coverage.sh /coverage.sh

RUN chmod +x /run.sh
RUN chmod +x /coverage.sh

CMD ["/bin/bash"]

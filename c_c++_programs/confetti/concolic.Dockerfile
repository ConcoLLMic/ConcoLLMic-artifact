FROM concolic

USER root

ENV DEBIAN_FRONTEND=noninteractive

# -------------------------------------------------------------
# Download and build confetti with GCOV
# -------------------------------------------------------------
WORKDIR /
RUN wget https://github.com/hgs3/confetti/releases/download/v1.0.0-beta.4/confetti-1.0.0-beta.4.tar.gz
RUN tar -xzf confetti-1.0.0-beta.4.tar.gz; rm confetti-1.0.0-beta.4.tar.gz
RUN mv confetti-1.0.0-beta.4 confetti-gcov; cp -r confetti-gcov confetti-asan

WORKDIR /confetti-gcov
RUN CC=gcc CXX=g++ CFLAGS="-fprofile-arcs -ftest-coverage" CXXFLAGS="-fprofile-arcs -ftest-coverage" ./configure --disable-shared
RUN CC=gcc CXX=g++ CFLAGS="-fprofile-arcs -ftest-coverage" CXXFLAGS="-fprofile-arcs -ftest-coverage" make

#  -------------------------------------------------------------
# Build confetti with Sanitizer
# -------------------------------------------------------------
WORKDIR /confetti-asan
RUN autoreconf -fvi
RUN CC=gcc CXX=g++ CFLAGS="-fsanitize=address,undefined -fsanitize-undefined-trap-on-error -fno-sanitize-recover=all -g -O1" ./configure --disable-shared
RUN CC=gcc CXX=g++ CFLAGS="-fsanitize=address,undefined -fsanitize-undefined-trap-on-error -fno-sanitize-recover=all -g -O1" make

# -------------------------------------------------------------
# Build instrumented confetti
# -------------------------------------------------------------
WORKDIR /
COPY confetti-instr.tar.gz .
RUN tar -xzf confetti-instr.tar.gz
WORKDIR /confetti-instr
RUN autoreconf -fvi
RUN ./configure; CC=gcc CXX=g++ make

# -------------------------------------------------------------
# Prepare testing directory
# -------------------------------------------------------------
COPY ./seed_execs /seed_execs
COPY ./run.sh /run.sh
COPY ./coverage.sh /coverage.sh

RUN chmod +x /run.sh
RUN chmod +x /coverage.sh

CMD ["/bin/bash"]

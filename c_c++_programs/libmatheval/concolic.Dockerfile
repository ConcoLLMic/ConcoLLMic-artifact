FROM concolic

USER root

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    texinfo guile-2.2-dev bison && \
    rm -rf /var/lib/apt/lists/*


# -------------------------------------------------------------
# Download and build libmatheval with GCOV
# -------------------------------------------------------------
WORKDIR /
RUN wget https://ftp.gnu.org/gnu/libmatheval/libmatheval-1.1.11.tar.gz
RUN tar -xzf libmatheval-1.1.11.tar.gz
RUN cp -r libmatheval-1.1.11 libmatheval-gcov; cp -r libmatheval-1.1.11 libmatheval-asan
COPY test.c libmatheval-gcov/test.c
COPY test.c libmatheval-asan/test.c

WORKDIR /libmatheval-gcov
RUN CC=gcc CXX=g++ CFLAGS="-fprofile-arcs -ftest-coverage" CXXFLAGS="-fprofile-arcs -ftest-coverage" ./configure
RUN CC=gcc CXX=g++ CFLAGS="-fprofile-arcs -ftest-coverage" CXXFLAGS="-fprofile-arcs -ftest-coverage" make install-exec
RUN gcc -g -fprofile-arcs -ftest-coverage -o program ./test.c lib/.libs/libmatheval.a -lm

#  -------------------------------------------------------------
# Build libmatheval with Sanitizer
# -------------------------------------------------------------
WORKDIR /libmatheval-asan
RUN CC=gcc CXX=g++ CFLAGS="-fsanitize=address,undefined -fsanitize-undefined-trap-on-error -fno-sanitize-recover=all -g -O1" ./configure
RUN CC=gcc CXX=g++ CFLAGS="-fsanitize=address,undefined -fsanitize-undefined-trap-on-error -fno-sanitize-recover=all -g -O1" make install-exec
RUN gcc -fsanitize=address,undefined -fsanitize-undefined-trap-on-error -fno-sanitize-recover=all -g -O1 -o program ./test.c lib/.libs/libmatheval.a -lm

# -------------------------------------------------------------
# Build instrumented libmatheval
# -------------------------------------------------------------
WORKDIR /
COPY libmatheval-1.1.11-inst.tar.gz .
RUN tar -xzf libmatheval-1.1.11-inst.tar.gz
RUN mv libmatheval-1.1.11-inst libmatheval-instr

WORKDIR /libmatheval-instr
RUN CC=gcc CXX=g++ ./configure
RUN CC=gcc CXX=g++ make install-exec
RUN gcc -g -o program ./test.c lib/.libs/libmatheval.a -lm

# -------------------------------------------------------------
# Prepare testing directory
# -------------------------------------------------------------

COPY ./seed_execs /seed_execs
COPY ./run.sh /run.sh
COPY ./coverage.sh /coverage.sh

RUN chmod +x /run.sh
RUN chmod +x /coverage.sh

CMD ["/bin/bash"]

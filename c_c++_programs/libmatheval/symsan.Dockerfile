# Use the final stage from Symsan
FROM symsan AS bc

USER root

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get install -y texinfo guile-2.2-dev && \
    rm -rf /var/lib/apt/lists/*


# -------------------------------------------------------------
# Download and build libmatheval with GCOV
# -------------------------------------------------------------
WORKDIR /
RUN wget https://ftp.gnu.org/gnu/libmatheval/libmatheval-1.1.11.tar.gz
RUN tar -xzf libmatheval-1.1.11.tar.gz
RUN cp -r libmatheval-1.1.11 libmatheval-gcov; cp -r libmatheval-1.1.11 libmatheval-symsan 

WORKDIR /libmatheval-gcov
COPY test.c test.c
RUN CC=gcc CXX=g++ CFLAGS="-fprofile-arcs -ftest-coverage" CXXFLAGS="-fprofile-arcs -ftest-coverage" ./configure
RUN CC=gcc CXX=g++ CFLAGS="-fprofile-arcs -ftest-coverage" CXXFLAGS="-fprofile-arcs -ftest-coverage" make install-exec
RUN gcc -g -fprofile-arcs -ftest-coverage -o program ./test.c lib/.libs/libmatheval.a -lm


# -------------------------------------------------------------
# Build libmatheval with Symsan
# -------------------------------------------------------------
WORKDIR /libmatheval-symsan
COPY test.c test.c
RUN CC=/workdir/symsan/build/bin/ko-clang CXX=/workdir/symsan/build/bin/ko-clang++ ./configure
RUN CC=/workdir/symsan/build/bin/ko-clang CXX=/workdir/symsan/build/bin/ko-clang++ make install-exec
RUN /workdir/symsan/build/bin/ko-clang -g -o program ./test.c lib/.libs/libmatheval.a -lm

# -------------------------------------------------------------
# Prepare testing directory
# -------------------------------------------------------------
COPY ./seeds /seeds
COPY ./run.sh /run.sh
COPY ./coverage.sh /coverage.sh

RUN chmod +x /run.sh
RUN chmod +x /coverage.sh

CMD ["/bin/bash"]

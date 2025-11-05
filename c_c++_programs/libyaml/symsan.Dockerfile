# Use the final stage from Symsan
FROM symsan

USER root

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get install -y texinfo && \
    rm -rf /var/lib/apt/lists/*


# -------------------------------------------------------------
# Download and build libyaml with GCOV
# -------------------------------------------------------------
WORKDIR /
RUN git clone https://github.com/yaml/libyaml.git
RUN cp -r libyaml libyaml-symsan; cp -r libyaml libyaml-gcov

WORKDIR /libyaml-gcov
RUN bash ./bootstrap
RUN CC=gcc CXX=g++ CFLAGS="-fprofile-arcs -ftest-coverage" CXXFLAGS="-fprofile-arcs -ftest-coverage" ./configure  --disable-shared
RUN CC=gcc CXX=g++ CFLAGS="-fprofile-arcs -ftest-coverage" CXXFLAGS="-fprofile-arcs -ftest-coverage" make


# -------------------------------------------------------------
# Build libyaml with Symsan
# -------------------------------------------------------------
WORKDIR /libyaml-symsan
RUN bash ./bootstrap
RUN CC=/workdir/symsan/build/bin/ko-clang CXX=/workdir/symsan/build/bin/ko-clang++ ./configure
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

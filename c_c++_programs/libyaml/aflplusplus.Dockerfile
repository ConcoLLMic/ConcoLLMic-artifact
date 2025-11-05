# Use the final stage from AFL++
FROM aflplusplus AS libyaml

USER root

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get install -y texinfo && \
    rm -rf /var/lib/apt/lists/*


# -------------------------------------------------------------
# Download and build libyaml with GCOV
# -------------------------------------------------------------
WORKDIR /
RUN git clone https://github.com/yaml/libyaml.git && cd libyaml && git checkout 840b65c
RUN cp -r libyaml libyaml-aflplusplus; cp -r libyaml libyaml-gcov

WORKDIR /libyaml-gcov
RUN bash ./bootstrap
RUN CC=gcc CXX=g++ CFLAGS="-fprofile-arcs -ftest-coverage" CXXFLAGS="-fprofile-arcs -ftest-coverage" ./configure  --disable-shared
RUN CC=gcc CXX=g++ CFLAGS="-fprofile-arcs -ftest-coverage" CXXFLAGS="-fprofile-arcs -ftest-coverage" make

# -------------------------------------------------------------
# Build libyaml with AFL++
# -------------------------------------------------------------
WORKDIR /libyaml-aflplusplus
RUN bash ./bootstrap
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

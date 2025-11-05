FROM concolic

USER root

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y texinfo && \
    rm -rf /var/lib/apt/lists/*



# -------------------------------------------------------------
# Download and build libyaml with GCOV
# -------------------------------------------------------------
WORKDIR /
RUN git clone https://github.com/yaml/libyaml.git
RUN cp -r libyaml libyaml-gcov; cp -r libyaml libyaml-asan

WORKDIR /libyaml-gcov
RUN bash ./bootstrap
RUN CC=gcc CXX=g++ CFLAGS="-fprofile-arcs -ftest-coverage" CXXFLAGS="-fprofile-arcs -ftest-coverage" ./configure --disable-shared
RUN CC=gcc CXX=g++ CFLAGS="-fprofile-arcs -ftest-coverage" CXXFLAGS="-fprofile-arcs -ftest-coverage" make

#  -------------------------------------------------------------
# Build libyaml with Sanitizer
# -------------------------------------------------------------
WORKDIR /libyaml-asan
RUN bash ./bootstrap
RUN CC=gcc CXX=g++ CFLAGS="-fsanitize=address,undefined -fsanitize-undefined-trap-on-error -fno-sanitize-recover=all -g -O1" ./configure --disable-shared
RUN CC=gcc CXX=g++ CFLAGS="-fsanitize=address,undefined -fsanitize-undefined-trap-on-error -fno-sanitize-recover=all -g -O1" make    

# -------------------------------------------------------------
# Build instrumented libyaml
# -------------------------------------------------------------
WORKDIR /
COPY libyaml-0.25-inst.tar.gz .
RUN tar -xzf libyaml-0.25-inst.tar.gz
RUN mv libyaml-0.25-inst libyaml-instr

WORKDIR /libyaml-instr
RUN bash ./bootstrap
RUN CC=gcc CXX=g++ ./configure --disable-shared
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

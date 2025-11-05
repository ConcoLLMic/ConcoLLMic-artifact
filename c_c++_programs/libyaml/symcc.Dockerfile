# Use the final stage from SymCC
FROM symcc AS bc

USER root

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get install -y texinfo && \
    rm -rf /var/lib/apt/lists/*


# -------------------------------------------------------------
# Download and build libyaml with GCOV
# -------------------------------------------------------------
WORKDIR /
RUN git clone https://github.com/yaml/libyaml.git
RUN cp -r libyaml libyaml-symcc; cp -r libyaml libyaml-gcov

WORKDIR /libyaml-gcov
RUN bash ./bootstrap
RUN CC=gcc CXX=g++ CFLAGS="-fprofile-arcs -ftest-coverage" CXXFLAGS="-fprofile-arcs -ftest-coverage" ./configure  --disable-shared
RUN CC=gcc CXX=g++ CFLAGS="-fprofile-arcs -ftest-coverage" CXXFLAGS="-fprofile-arcs -ftest-coverage" make

# -------------------------------------------------------------
# Build libyaml with SymCC
# -------------------------------------------------------------
WORKDIR /libyaml-symcc
RUN bash ./bootstrap
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

FROM concolic

USER root

ENV DEBIAN_FRONTEND=noninteractive

# Install Go
WORKDIR /
ENV GO_VERSION=1.22.2
RUN wget https://go.dev/dl/go$GO_VERSION.linux-amd64.tar.gz
RUN tar -C /usr/local -xzf go$GO_VERSION.linux-amd64.tar.gz
RUN rm go$GO_VERSION.linux-amd64.tar.gz
ENV PATH=$PATH:/usr/local/go/bin
RUN go version

# Compile protoc
RUN git clone https://github.com/protocolbuffers/protobuf.git /protobuf-inst
WORKDIR /protobuf-inst
RUN git checkout 73a5afe278170c1771993cedea6694a2700569b8
COPY protoc-instr.tar.gz .
RUN tar -xzf protoc-instr.tar.gz; rm protoc-instr.tar.gz
RUN cp protoc-instr/* src/google/protobuf/compiler/
RUN mkdir -p build && cd build && cmake .. && make -j$(nproc)

# Compile proto-gen-go plugin
RUN git clone https://github.com/protocolbuffers/protobuf-go.git
WORKDIR /protobuf-inst/protobuf-go
RUN git checkout e5d4468
COPY protoc-gen-go-instr.tar.gz .
RUN tar -xzf protoc-gen-go-instr.tar.gz; rm protoc-gen-go-instr.tar.gz
RUN cp protoc-gen-go-instr/main.go cmd/protoc-gen-go/main.go
RUN cp protoc-gen-go-instr/internal_gengo/* cmd/protoc-gen-go/internal_gengo
RUN go build ./cmd/protoc-gen-go
RUN cp protoc-gen-go ..

# Compile protoc with asan and ubsan
RUN git clone https://github.com/protocolbuffers/protobuf.git /protobuf
WORKDIR /protobuf
RUN git checkout 73a5afe278170c1771993cedea6694a2700569b8
RUN mkdir -p build && cd build && cmake ..
RUN cd build && CXXFLAGS="-g -O1 -fsanitize=address,undefined -fno-omit-frame-pointer" LDFLAGS="-fsanitize=address,undefined" make -j$(nproc)

# Compile proto-gen-go plugin with race detector
RUN git clone https://github.com/protocolbuffers/protobuf-go.git
WORKDIR /protobuf-inst/protobuf-go
RUN go build -race ./cmd/protoc-gen-go
RUN cp protoc-gen-go ..

WORKDIR /concolic-agent
COPY ./seed_execs /seed_execs
COPY ./run.sh /run.sh

CMD ["/bin/bash"]

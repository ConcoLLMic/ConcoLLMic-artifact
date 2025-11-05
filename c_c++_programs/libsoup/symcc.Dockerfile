# Use the final stage from SymCC
FROM symcc AS libsoup

USER root

ENV DEBIAN_FRONTEND=noninteractive


RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    libglib2.0-dev \
    libsqlite3-dev \
    libpsl-dev \
    glib-networking \
    ninja-build \
    libbrotli-dev \
    libkrb5-dev \
    libnghttp2-dev \
    libidn2-dev \
    libseccomp-dev \
    libini-config-dev

RUN pip3 install meson

# -------------------------------------------------------------
# Download and extract libsoup
# -------------------------------------------------------------
WORKDIR /
RUN git clone https://gitlab.gnome.org/GNOME/libsoup.git
WORKDIR /libsoup
RUN git config --global user.email "you@example.com"
RUN git config --global user.name "Your Name"
RUN git cherry-pick b26756f88d338174cdada0b618a657ada0bd3819 && git cherry-pick 07b94e27afafebf31ef3cd868866a1e383750086 && sed -i -e "s/version : glib_required_version/version : glib_required_version, static: true/" meson.build
COPY ./simple-httpd.c /libsoup/examples/simple-httpd.c

RUN cp -r /libsoup /libsoup-gcov && cp -r /libsoup /libsoup-symcc

# -------------------------------------------------------------
# Build libsoup with SymCC
# -------------------------------------------------------------
WORKDIR /libsoup-symcc
RUN CC=symcc CXX=sym++ meson setup build --buildtype=debug -Dtls_check=false -Ddefault_library=static -Dtests=false -Dfuzzing=disabled -Dpkcs11_tests=disabled
RUN CC=symcc CXX=sym++ meson compile -C build

# -------------------------------------------------------------
# Build libsoup with GCOV
# -------------------------------------------------------------
WORKDIR /libsoup-gcov
RUN CC=gcc CXX=g++ CFLAGS="-fprofile-arcs -ftest-coverage" CXXFLAGS="-fprofile-arcs -ftest-coverage" meson setup build --buildtype=debug -Dtls_check=false -Ddefault_library=static -Dtests=false -Dfuzzing=disabled -Dpkcs11_tests=disabled
RUN CC=gcc CXX=g++ CFLAGS="-fprofile-arcs -ftest-coverage" CXXFLAGS="-fprofile-arcs -ftest-coverage" meson compile -C build

# -------------------------------------------------------------
# Prepare testing directory and Preeny
# ------------------------------------------------------------- 

WORKDIR /
RUN git clone https://github.com/zardus/preeny.git /preeny
RUN cd /preeny && CC=symcc CXX=sym++ make

COPY ./seeds /seeds
COPY ./run.sh /run.sh
COPY ./coverage.sh /coverage.sh

CMD ["/bin/bash"]

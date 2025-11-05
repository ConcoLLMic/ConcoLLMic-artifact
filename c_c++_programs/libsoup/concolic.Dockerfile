# Use the final stage from SymCC
FROM concolic AS libsoup

USER root

ENV DEBIAN_FRONTEND=noninteractive


# sudo apt install libseccomp-dev
# apt install libini-config-dev


RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    libsqlite3-dev \
    libpsl-dev \
    ninja-build \
    libbrotli-dev \
    libkrb5-dev \
    libnghttp2-dev \
    libidn2-dev \
    libproxy-dev \
    gsettings-desktop-schemas \
    gsettings-desktop-schemas-dev \
    nettle-dev \
    libtasn1-6-dev \
    libp11-kit-dev \
    gettext \
    autopoint \
    libunistring-dev \
    libpcre3-dev

RUN pip3 install meson==1.4.0

WORKDIR /
RUN wget https://www.gnupg.org/ftp/gcrypt/gnutls/v3.7/gnutls-3.7.9.tar.xz && \
    tar -xf gnutls-3.7.9.tar.xz && \
    cd gnutls-3.7.9 && \
    ./configure --prefix=/usr --disable-doc && \
    make -j$(nproc) && \
    make install && \
    ldconfig && \
    cd / && \
    rm -rf gnutls-3.7.9 gnutls-3.7.9.tar.xz

# -------------------------------------------------------------
# Install glib-networking (which would also install glib)
# -------------------------------------------------------------
RUN git clone https://gitlab.gnome.org/GNOME/glib-networking.git
COPY glib-networking.patch /glib-networking.patch
WORKDIR /glib-networking
# use the latest version of glib (also built with Sanitizer enabled)
RUN patch -p1 < /glib-networking.patch

RUN meson setup build --prefix=/usr -Ddefault_library=static -Dglib:tests=false
RUN meson compile -C build
RUN meson install -C build

# -------------------------------------------------------------
# Download and extract libsoup
# -------------------------------------------------------------
WORKDIR /
# RUN git clone https://gitlab.gnome.org/GNOME/libsoup.git
# WORKDIR /libsoup
# RUN git config --global user.email "you@example.com"
# RUN git config --global user.name "Your Name"
# RUN git cherry-pick b26756f88d338174cdada0b618a657ada0bd3819 && git cherry-pick 07b94e27afafebf31ef3cd868866a1e383750086 && 

COPY ./libsoup-src.tar.gz ./libsoup-src.tar.gz
RUN tar -xzf libsoup-src.tar.gz
RUN cd libsoup-src && sed -i -e "s/version : glib_required_version/version : glib_required_version, static: true/" meson.build
RUN mv /libsoup-src /libsoup-gcov
COPY ./simple-httpd.c /libsoup-gcov/examples/simple-httpd.c

COPY ./libsoup-instr.tar.gz ./libsoup-instr.tar.gz
RUN tar -xzf libsoup-instr.tar.gz
RUN cd libsoup-instr && sed -i -e "s/version : glib_required_version/version : glib_required_version, static: true/" meson.build

# set Sanitizer flags
ENV CFLAGS="-fsanitize=address,undefined -fsanitize-undefined-trap-on-error -fno-sanitize-recover=all"   
ENV CXXFLAGS="-fsanitize=address,undefined -fsanitize-undefined-trap-on-error -fno-sanitize-recover=all"
ENV LDFLAGS="-fsanitize=address,undefined -fsanitize-undefined-trap-on-error -fno-sanitize-recover=all"

# -------------------------------------------------------------
# Build libsoup with GCOV
# -------------------------------------------------------------
WORKDIR /libsoup-gcov
RUN CC=gcc CXX=g++ CFLAGS="-fprofile-arcs -ftest-coverage" CXXFLAGS="-fprofile-arcs -ftest-coverage" meson setup build --buildtype=debug -Dtls_check=false -Ddefault_library=static -Dtests=true -Dfuzzing=disabled -Dpkcs11_tests=disabled
RUN CC=gcc CXX=g++ CFLAGS="-fprofile-arcs -ftest-coverage" CXXFLAGS="-fprofile-arcs -ftest-coverage" meson compile -C build

# -------------------------------------------------------------
# Build libsoup with instrumentation
# -------------------------------------------------------------
WORKDIR /libsoup-instr
RUN meson setup build --buildtype=debug -Dtls_check=false -Ddefault_library=static -Dtests=true -Dfuzzing=disabled -Dpkcs11_tests=disabled
RUN meson compile -C build

# -------------------------------------------------------------
# Prepare testing directory
# -------------------------------------------------------------
RUN pip3 install requests
COPY ./seed_execs /seed_execs
COPY ./run.sh /run.sh
COPY ./coverage.sh /coverage.sh

CMD ["/bin/bash"]


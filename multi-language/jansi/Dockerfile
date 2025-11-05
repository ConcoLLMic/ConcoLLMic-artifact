FROM concolic

USER root

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    make \
    openjdk-8-jdk \
    maven \
    bc \
    vim \
    && rm -rf /var/lib/apt/lists/*

# -------------------------------------------------------------
# Download jansi
# -------------------------------------------------------------
WORKDIR /
RUN git clone https://github.com/fusesource/jansi.git /jansi && cd /jansi && git reset --hard 70186aa41bef6877a83e1a0c3ed7ebe87185f377
RUN mv /jansi /jansi_cov

# copy driver
RUN mkdir -p /jansi_cov/
COPY drivers/Render /jansi_cov/RenderAPP

RUN cp -r /jansi_cov /jansi_asan

# copy instr
COPY jansi_instr.tar.gz /jansi_instr.tar.gz
RUN tar -xzf /jansi_instr.tar.gz

# -------------------------------------------------------------
# Build jansi with coverage
# -------------------------------------------------------------

WORKDIR /jansi_cov

RUN make download-includes && \
    make clean-native native OS_NAME=Linux OS_ARCH=x86_64 CC="gcc -fprofile-arcs -ftest-coverage" CXX="g++ -fprofile-arcs -ftest-coverage" && \
    mvn clean package -Dmaven.javadoc.skip=true

RUN export JANSI_PATH=$(find /jansi_cov/target -maxdepth 1 -name "jansi-*-SNAPSHOT.jar") && \
    cd /jansi_cov/RenderAPP && \
    export JAVA_SOURCE=./src && \
    export JAVA_LIB=./lib && \
    export JAVA_CLASS=./bin && \
    mkdir -p $JAVA_CLASS && \
    find $JAVA_SOURCE -name "*.java" > $JAVA_SOURCE/sources.list && \
    javac -d $JAVA_CLASS -encoding utf-8 -cp .:$JANSI_PATH -g -sourcepath $JAVA_SOURCE @$JAVA_SOURCE/sources.list && \
    cd $JAVA_CLASS && \
    jar -cvfm ../Render.jar ../MANIFEST.MF * && \
    chmod a+x ../Render.jar

# -------------------------------------------------------------
# Build jansi with instrumentation
# -------------------------------------------------------------

WORKDIR /jansi_instr

RUN make download-includes && \
    make clean-native native OS_NAME=Linux OS_ARCH=x86_64 && \
    mvn clean package -Dmaven.javadoc.skip=true -Dspotless.check.skip=true -Dspotless.apply.skip=true
# -Dspotless.check.skip=true -Dspotless.apply.skip=true used to disable code formatting check since it can change the instrumented code


RUN export JANSI_PATH=$(find /jansi_instr/target -maxdepth 1 -name "jansi-*-SNAPSHOT.jar") && \
    cd /jansi_instr/RenderAPP && \
    export JAVA_SOURCE=./src && \
    export JAVA_LIB=./lib && \
    export JAVA_CLASS=./bin && \
    mkdir -p $JAVA_CLASS && \
    find $JAVA_SOURCE -name "*.java" > $JAVA_SOURCE/sources.list && \
    javac -d $JAVA_CLASS -encoding utf-8 -cp .:$JANSI_PATH -g -sourcepath $JAVA_SOURCE @$JAVA_SOURCE/sources.list && \
    cd $JAVA_CLASS && \
    jar -cvfm ../Render.jar ../MANIFEST.MF * && \
    chmod a+x ../Render.jar


# -------------------------------------------------------------
# Build jansi with ASAN
# -------------------------------------------------------------

WORKDIR /jansi_asan

RUN make download-includes && \
    make clean-native native OS_NAME=Linux OS_ARCH=x86_64 CC="clang -fsanitize=address,undefined -fsanitize-undefined-trap-on-error -fno-sanitize-recover=all" CXX="clang++ -fsanitize=address,undefined -fsanitize-undefined-trap-on-error -fno-sanitize-recover=all" && \
    mvn clean package -Dmaven.javadoc.skip=true

RUN export JANSI_PATH=$(find /jansi_asan/target -maxdepth 1 -name "jansi-*-SNAPSHOT.jar") && \
    cd /jansi_asan/RenderAPP && \
    export JAVA_SOURCE=./src && \
    export JAVA_LIB=./lib && \
    export JAVA_CLASS=./bin && \
    mkdir -p $JAVA_CLASS && \
    find $JAVA_SOURCE -name "*.java" > $JAVA_SOURCE/sources.list && \
    javac -d $JAVA_CLASS -encoding utf-8 -cp .:$JANSI_PATH -g -sourcepath $JAVA_SOURCE @$JAVA_SOURCE/sources.list && \
    cd $JAVA_CLASS && \
    jar -cvfm ../Render.jar ../MANIFEST.MF * && \
    chmod a+x ../Render.jar


# -------------------------------------------------------------
# Prepare testing directory
# -------------------------------------------------------------

COPY ./seed_execs /seed_execs
COPY ./run.sh /run.sh

CMD ["/bin/bash"]
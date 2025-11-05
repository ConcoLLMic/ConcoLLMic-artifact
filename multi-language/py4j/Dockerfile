FROM concolic

USER root
ENV DEBIAN_FRONTEND=noninteractive

# Install JDK
RUN apt-get update && \
    apt-get install -y openjdk-17-jdk && \
    apt-get clean

RUN java -version && javac -version

# Unzip instrumented code
WORKDIR /
COPY py4j-inst.tar.gz .
RUN tar -xzf py4j-inst.tar.gz
WORKDIR /py4j-inst

# Install as Python package
COPY py4j0.10.9.9.jar .
RUN mkdir py4j-python/py4j-java
RUN cp py4j0.10.9.9.jar py4j-python/py4j-java/py4j0.10.9.9.jar
RUN pip install .

WORKDIR /concolic-agent
COPY ./seed_execs /seed_execs
COPY ./run.sh /run.sh

CMD ["/bin/bash"]

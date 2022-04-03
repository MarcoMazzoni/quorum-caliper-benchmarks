
#Create image layer pulling QUORUM from git and installing GOLANG
FROM ubuntu:18.04 as builder 

ARG QUORUM_VERSION=2.3.0

WORKDIR /work

RUN apt-get update && \
    apt-get install -y \
            build-essential \
            git \
            libdb-dev \
            libsodium-dev \
            libtinfo-dev \
            sysvbanner \
            unzip \
            wget \
            zlib1g-dev \
            openjdk-8-jdk \
            maven 


RUN  git clone https://github.com/wg/wrk.git wrk && \
    cd wrk && \
    make && \
    cd .. && \
    # move the executable to somewhere in your PATH, ex:
    mv wrk /usr/local/bin

#Tessera 
RUN git clone https://github.com/jpmorganchase/tessera.git && \
    cd tessera && \
    mvn -DskipTests install && \
    cd ..

# Golang
ENV GOREL go1.12.7.linux-amd64.tar.gz
ENV PATH $PATH:/usr/local/go/bin


RUN wget -q https://dl.google.com/go/${GOREL} && \
    tar xfz $GOREL && \
    mv go /usr/local/go && \
    rm -f $GOREL

# Istanbul tools
RUN git clone https://github.com/jpmorganchase/istanbul-tools.git istanbul && \
    cd istanbul && \
    make && \
    cp build/bin/istanbul /usr/local/bin/ && \
    cd .. && rm -rf istanbul

#Quorum
RUN git clone https://github.com/jpmorganchase/quorum.git && \
    cd quorum && \
    git checkout v$QUORUM_VERSION && \
    make all && \
    cp build/bin/geth /usr/local/bin && \
    cp build/bin/bootnode /usr/local/bin && \
    cd .. && \
    rm -rf quorum

#-----------------------------------------------------------------

# Create final docker image 
FROM ubuntu:18.04 

RUN apt-get update && \
    apt-get install -y --no-install-recommends software-properties-common && \
    add-apt-repository ppa:ethereum/ethereum && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        libdb-dev \
        libleveldb-dev \
        libsodium-dev \
        zlib1g-dev\
        libtinfo-dev \
        solc \
        git \
        openjdk-8-jdk \
        maven && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir /.ethereum && \
    chown -R 1000:1000 /.ethereum && \
    groupadd -g 1000 geth && useradd -u 1000 -g 1000 -s /bin/bash geth && \
    mkdir /home/geth && chown 1000:1000 -R /home/geth 


#RUN  add-apt-repository ppa:ethereum/ethereum 

#RUN  git clone https://github.com/wg/wrk.git wrk && \
#    cd wrk && \
#    make && \
#    cd .. && \
    # move the executable to somewhere in your PATH, ex:
#    mv wrk /usr/local/bin

#COPY --from builder /usr/local/bin/wrk /usr/local/bin

COPY --from=builder /work/tessera/tessera-dist/tessera-app/target/tessera-app-*app.jar /tessera/tessera-app.jar
COPY --from=builder \
        /usr/local/bin/istanbul \
        /usr/local/bin/geth \
        /usr/local/bin/bootnode \
        /usr/local/bin/wrk \
        /usr/local/bin/

ENV SHELL=/bin/bash

CMD ["/qdata/start-node.sh"]
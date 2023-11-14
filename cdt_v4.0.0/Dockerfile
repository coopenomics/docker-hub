FROM ubuntu:latest

WORKDIR /workdir

RUN apt-get update && apt-get install -y wget cmake build-essential g++ libboost-all-dev && \
    wget https://github.com/AntelopeIO/cdt/releases/download/v4.0.0/cdt_4.0.0_amd64.deb && \
    apt install ./cdt_4.0.0_amd64.deb -y && \
    rm cdt_4.0.0_amd64.deb


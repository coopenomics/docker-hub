FROM ubuntu:latest

WORKDIR /workdir

RUN apt-get update && apt-get install -y wget && \
    wget https://github.com/AntelopeIO/leap/releases/download/v4.0.4/leap_4.0.4-ubuntu22.04_amd64.deb && \
    apt-get install -y ./leap*.deb -y && \
    rm leap_4.0.4-ubuntu22.04_amd64.deb



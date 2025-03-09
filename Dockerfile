# Базовый образ
FROM ubuntu:22.04

# Настройки для непрерывной установки
ENV DEBIAN_FRONTEND=noninteractive
ENV NEEDRESTART_MODE=a

# Установка зависимостей для блокчейна и CDT
RUN apt-get update && apt-get install -y \
    build-essential \
    clang \
    clang-tidy \
    cmake \
    git \
    libcurl4-openssl-dev \
    libgmp-dev \
    llvm-11-dev \
    libxml2-dev \
    opam \
    ocaml-interp \
    python3 \
    python3-pip \
    time \
    file \
    zlib1g-dev \
    g++-10 \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Установка Python-зависимостей
RUN python3 -m pip install --no-cache-dir pygments

# Настройки Git для стабильного клонирования
RUN git config --global http.postBuffer 1048576000 \
    && git config --global http.lowSpeedLimit 0 \
    && git config --global http.lowSpeedTime 999999 \
    && git config --global core.compression 0 \
    && git config --global fetch.fsckObjects false \
    && git config --global submodule.fetchJobs 1 \
    && git config --global http.version HTTP/1.1 \
    && git config --global transfer.fsckObjects false \
    && git config --global gc.auto 0 \
    && git config --global pack.threads "1" \
    && git config --global pack.window "0" \
    && git config --global pack.deltaCacheSize "256m"

# Клонирование блокчейна с минимальной историей
RUN git clone --depth=1 --branch dicoop https://github.com/coopenomics/coopos /blockchain \
    && cd /blockchain \
    && git submodule update --init --recursive --depth=1

# Сборка блокчейна
RUN cd /blockchain \
    && mkdir -p build && cd build \
    && cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH=/usr/lib/llvm-11 .. \
    && make -j"$(nproc)" \
    && make install

# Клонирование CDT с минимальной историей и переключение на ветку dicoop
RUN git clone --depth=1 --branch dicoop https://github.com/coopenomics/cdt /cdt \
    && cd /cdt \
    && git submodule update --init --recursive --depth=1

# Сборка CDT (без `make package`)
RUN cd /cdt \
    && mkdir build \
    && cd build \
    && cmake .. \
    && make -j"$(nproc)" \
    && make install

# Дефолтная команда
CMD ["/bin/bash"]


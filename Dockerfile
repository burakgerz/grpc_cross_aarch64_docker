FROM ubuntu:18.04 as build-env
RUN apt-get update && \
    apt-get install --no-install-recommends --yes \
    autoconf \
    build-essential \
    ca-certificates \
    g++-6-aarch64-linux-gnu \
    gcc-6-aarch64-linux-gnu \
    git \
    libssl-dev \
    libtool \
    pkg-config \
    wget && \
    wget -q -O cmake-linux.sh https://github.com/Kitware/CMake/releases/download/v3.16.1/cmake-3.16.1-Linux-x86_64.sh && \
    sh cmake-linux.sh -- --skip-license --prefix=/usr && \
    rm cmake-linux.sh && \
    update-ca-certificates


# Clone and build
RUN git clone --depth 1 -b v1.39.1 https://github.com/grpc/grpc --recursive --shallow-submodules grpc && \
    MAX_CORES=16 && \
    GRPC_BASE_DIR=/grpc && \
    mkdir -p $GRPC_BASE_DIR/cmake/build && \
    cd $GRPC_BASE_DIR/cmake/build && \
    cmake ../.. && \
    make -j$MAX_CORES && \
# Build dependencies and install
    cmake ../.. -DgRPC_INSTALL=ON \
        -DCMAKE_BUILD_TYPE=Release \
        -DgRPC_ABSL_PROVIDER=module \
        -DgRPC_CARES_PROVIDER=module \
        -DgRPC_PROTOBUF_PROVIDER=module \
        -DgRPC_RE2_PROVIDER=module \
        -DgRPC_SSL_PROVIDER=module \
        -DgRPC_ZLIB_PROVIDER=module && \
    make -j$MAX_CORES && \
    make -j$MAX_CORES install && \
# Build and install gRPC for the host architecture.    
    cmake  \
        -DCMAKE_BUILD_TYPE=Release \
        -DgRPC_INSTALL=ON \
        -DgRPC_BUILD_TESTS=OFF \
        -DgRPC_SSL_PROVIDER=package \
        ../.. && \
    make -j$MAX_CORES install && \
# Build and install absl for x86
    mkdir -p $GRPC_BASE_DIR/third_party/abseil-cpp/cmake/build && \
    cd $GRPC_BASE_DIR/third_party/abseil-cpp/cmake/build && \
    cmake -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_POSITION_INDEPENDENT_CODE=TRUE \
      ../.. && \
    make -j$MAX_CORES install 


COPY ./toolchain.cmake /tmp/toolchain.cmake
# Build and install absl for ARM
RUN MAX_CORES=16 && \
    GRPC_BASE_DIR=/grpc && \
    mkdir -p $GRPC_BASE_DIR/third_party/abseil-cpp/cmake/build_arm && \
    cd $GRPC_BASE_DIR/third_party/abseil-cpp/cmake/build_arm && \
    cmake -DCMAKE_TOOLCHAIN_FILE=/tmp/toolchain.cmake \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/tmp/install \
        -DCMAKE_POSITION_INDEPENDENT_CODE=TRUE \
      ../.. && \
    make -j$MAX_CORES install && \
# Build and install gRPC for ARM
    mkdir -p $GRPC_BASE_DIR/cmake/build_arm && \
    cd $GRPC_BASE_DIR/cmake/build_arm && \
    cmake \
            -DCMAKE_TOOLCHAIN_FILE=/tmp/toolchain.cmake \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=/tmp/install \
        ../.. && \
    make -j$MAX_CORES install

FROM build-env AS deploy-env

COPY ./src .

# Build helloworld example for ARM.
RUN MAX_CORES=16 && \
    mkdir -p /cmake/build_arm && \
    cd /cmake/build_arm && \
    cmake -DCMAKE_TOOLCHAIN_FILE=/tmp/toolchain.cmake \
      -DCMAKE_BUILD_TYPE=Release \
      -Dabsl_DIR=/tmp/stage/lib/cmake/absl \
      -DProtobuf_DIR=/tmp/stage/lib/cmake/protobuf \
      -DgRPC_DIR=/tmp/stage/lib/cmake/grpc \
      ../.. && \
    make -j$MAX_CORES

# Build for x86
RUN MAX_CORES=16 && \
    mkdir -p /cmake/build && \
    cd /cmake/build && \
    cmake ../.. && \
    make -j$MAX_CORES

FROM scratch
COPY --from=deploy-env /cmake /

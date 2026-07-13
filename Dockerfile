ARG RUST_ACCUMULATOR_REV=e5f6cfc13b075282fc0580700a66ce693c5d2d53

FROM rust:1-bookworm AS rust-accumulator-build
ARG RUST_ACCUMULATOR_REV
ENV CARGO_REGISTRIES_CRATES_IO_PROTOCOL=sparse
RUN git clone https://github.com/cardano-scaling/rust-accumulator.git \
    && cd rust-accumulator \
    && git checkout ${RUST_ACCUMULATOR_REV} \
    && cd rust_accumulator \
    && cargo build --release --locked \
    && mkdir -p /opt/rust-accumulator/include /opt/rust-accumulator/lib/pkgconfig \
    && cp -p target/release/librust_accumulator.a /opt/rust-accumulator/lib/ \
    && cp -p ../include/rust_accumulator.h /opt/rust-accumulator/include/ \
    && printf "prefix=/usr/local\nlibdir=\${prefix}/lib\nincludedir=\${prefix}/include\n\nName: librust_accumulator\nDescription: Rust Accumulator Library\nVersion: 0.1.0\nLibs: -L\${libdir} -lrust_accumulator\nCflags: -I\${includedir}\n" > /opt/rust-accumulator/lib/pkgconfig/librust_accumulator.pc

FROM ghcr.io/blinklabs-io/haskell:9.6.7-3.12.1.0-3 AS hydra-node-build
# Install hydra-node
ARG NODE_VERSION=2.2.0
ENV NODE_VERSION=${NODE_VERSION}
RUN echo "Building tags/${NODE_VERSION}..." \
    && echo tags/${NODE_VERSION} > /CARDANO_BRANCH \
    && git clone https://github.com/cardano-scaling/hydra.git \
    && cd hydra \
    && git tag \
    && git checkout tags/${NODE_VERSION} \
    && echo "with-compiler: ghc-${GHC_VERSION}" >> cabal.project.local \
    && echo "tests: False" >> cabal.project.local \
    && cabal update
RUN apt-get update -y && apt-get install -y etcd-server libsnappy-dev protobuf-compiler
COPY --from=rust-accumulator-build /opt/rust-accumulator/ /usr/local/
RUN cd hydra \
    && cabal build hydra-node \
    && mkdir -p /root/.local/bin/ \
    && cp -p dist-newstyle/build/$(uname -m)-linux/ghc-${GHC_VERSION}/hydra-node-${NODE_VERSION}/x/hydra-node/build/hydra-node/hydra-node /root/.local/bin/

FROM ghcr.io/blinklabs-io/cardano-cli:11.0.0.0-1 AS cardano-cli
FROM ghcr.io/blinklabs-io/cardano-configs:20260707-2 AS cardano-configs

FROM debian:bookworm-slim AS hydra-node
COPY --from=hydra-node-build /usr/local/lib/ /usr/local/lib/
COPY --from=hydra-node-build /root/.local/bin/hydra-* /usr/local/bin/
COPY --from=cardano-configs /config/ /opt/cardano/config/
RUN apt-get update -y && \
    apt-get install -y \
      bc \
      curl \
      etcd-client \
      etcd-server \
      iproute2 \
      jq \
      libffi8 \
      libgmp10 \
      libnuma1 \
      libsnappy1v5 \
      pkg-config \
      procps \
      socat \
      wget \
      zlib1g && \
    rm -rf /var/lib/apt/lists/* && \
    chmod +x /usr/local/bin/*
ENTRYPOINT ["/usr/local/bin/hydra-node"]

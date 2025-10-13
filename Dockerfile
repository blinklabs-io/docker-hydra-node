FROM ghcr.io/blinklabs-io/haskell:9.6.6-3.12.1.0-2 AS hydra-node-build
# Install hydra-node
ARG NODE_VERSION=0.22.4
ENV NODE_VERSION=${NODE_VERSION}
RUN echo "Building tags/${NODE_VERSION}..." \
    && echo tags/${NODE_VERSION} > /CARDANO_BRANCH \
    && git clone https://github.com/input-output-hk/hydra.git \
    && cd hydra \
    && git tag \
    && git checkout tags/${NODE_VERSION} \
    && echo "with-compiler: ghc-${GHC_VERSION}" >> cabal.project.local \
    && echo "tests: False" >> cabal.project.local \
    && cabal update
RUN apt-get update -y && apt-get install -y libsnappy-dev protobuf-compiler etcd-server
RUN cd hydra \
    && cabal build hydra-node \
    && mkdir -p /root/.local/bin/ \
    && cp -p dist-newstyle/build/$(uname -m)-linux/ghc-${GHC_VERSION}/hydra-node-${NODE_VERSION}/x/hydra-node/build/hydra-node/hydra-node /root/.local/bin/

FROM ghcr.io/blinklabs-io/cardano-cli:10.12.0.0-1 AS cardano-cli
FROM ghcr.io/blinklabs-io/cardano-configs:20251009-1 AS cardano-configs

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

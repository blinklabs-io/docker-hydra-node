FROM ghcr.io/blinklabs-io/haskell:9.6.6-3.12.1.0-1 AS hydra-node-build
# Install hydra-node
ARG NODE_VERSION=0.20.0
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
RUN cd hydra \
    && cabal build hydra-node \
    && mkdir -p /root/.local/bin/ \
    && cp -p dist-newstyle/build/$(uname -m)-linux/ghc-${GHC_VERSION}/hydra-node-${NODE_VERSION}/x/hydra-node/build/hydra-node/hydra-node /root/.local/bin/

FROM ghcr.io/blinklabs-io/cardano-cli:10.4.0.0-1 AS cardano-cli
FROM ghcr.io/blinklabs-io/cardano-configs:20250213-1 AS cardano-configs

FROM debian:bookworm-slim AS hydra-node
COPY --from=hydra-node-build /root/.local/bin/hydra-* /usr/local/bin/
COPY --from=cardano-configs /config/ /opt/cardano/config/
# RUN apt-get update -y && \
#   apt-get install -y \
#     bc \
#     curl \
#     iproute2 \
#     jq \
#     libffi8 \
#     libgmp10 \
#     liblmdb0 \
#     libncursesw5 \
#     libnuma1 \
#     libsystemd0 \
#     libssl3 \
#     libtinfo6 \
#     llvm-14-runtime \
#     netbase \
#     pkg-config \
#     procps \
#     socat \
#     sqlite3 \
#     wget \
#     zlib1g && \
#   rm -rf /var/lib/apt/lists/* && \
#   chmod +x /usr/local/bin/*
# EXPOSE 3001 12788 12798
# ENTRYPOINT ["/usr/local/bin/entrypoint"]

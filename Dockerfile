# syntax=docker/dockerfile:1
#
# Bitcoind image built from the official Bitcoin Core release tarball.
# The tarball's sha256 is pinned, and the SHA256SUMS signature is checked
# against builder keys vendored in keys/ (source: bitcoin-core/guix.sigs).
#
# Build:  docker build --build-arg BITCOIN_VERSION=31.1 \
#                     --build-arg BITCOIN_SHA256=$(...) -t bitcoind:31.1 .

ARG BITCOIN_VERSION=31.1
ARG BITCOIN_SHA256=

FROM debian:trixie-slim AS fetch
ARG BITCOIN_VERSION
ARG BITCOIN_SHA256

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl gnupg \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp
COPY keys/ /tmp/keys/

RUN set -eux; \
    base="https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}"; \
    curl -fsSLO "$base/bitcoin-${BITCOIN_VERSION}-x86_64-linux-gnu.tar.gz"; \
    curl -fsSLO "$base/SHA256SUMS"; \
    curl -fsSLO "$base/SHA256SUMS.asc"; \
    gpg --batch --import /tmp/keys/*.gpg; \
    # require at least two good signatures from the vendored builder keys
    gpg --verify SHA256SUMS.asc SHA256SUMS 2>&1 | tee /tmp/gpg.log; \
    good=$(grep -c '^gpg: Good signature' /tmp/gpg.log || true); \
    test "$good" -ge 2; \
    tarball="bitcoin-${BITCOIN_VERSION}-x86_64-linux-gnu.tar.gz"; \
    if [ -n "${BITCOIN_SHA256}" ]; then \
      echo "${BITCOIN_SHA256}  ${tarball}" | sha256sum -c -; \
    else \
      grep " ${tarball}$" SHA256SUMS | sha256sum -c -; \
    fi; \
    mkdir -p /out; \
    tar -xzf "$tarball" --strip-components=2 -C /out \
      "bitcoin-${BITCOIN_VERSION}/bin/bitcoind" \
      "bitcoin-${BITCOIN_VERSION}/bin/bitcoin-cli" \
      "bitcoin-${BITCOIN_VERSION}/bin/bitcoin-tx" \
      "bitcoin-${BITCOIN_VERSION}/bin/bitcoin-util" \
      "bitcoin-${BITCOIN_VERSION}/bin/bitcoin-wallet"; \
    test -x /out/bitcoind

FROM debian:trixie-slim
ARG BITCOIN_VERSION

RUN apt-get update \
 && apt-get install -y --no-install-recommends libatomic1 \
 && rm -rf /var/lib/apt/lists/* \
 && groupadd -g 1000 bitcoin \
 && useradd -u 1000 -g 1000 -m -d /bitcoin -s /usr/sbin/nologin bitcoin

COPY --from=fetch /out/ /usr/local/bin/

LABEL org.opencontainers.image.title="bitcoind" \
      org.opencontainers.image.description="Bitcoin Core, built from the signed upstream tarball" \
      org.opencontainers.image.version="${BITCOIN_VERSION}" \
      org.opencontainers.image.source="https://github.com/rpenido/bitcoind-image" \
      org.opencontainers.image.licenses="MIT"

USER 1000:1000
ENV HOME=/bitcoin

EXPOSE 8332 8333
ENTRYPOINT ["bitcoind", "-datadir=/bitcoin/.bitcoin"]
